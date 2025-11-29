# Duplicate ve Blur Tespiti Performans Optimizasyonu

## 1. Tam boyutlu fotoğraf yerine küçük thumbnail üzerinde çalış

Blur ve duplicate tespiti için 4000x3000 resmi analiz etmene gerek yok; 128x128 / 256x256 işini görür.

### Yapı:

- **Android:** MediaStore'dan thumbnail al
- **iOS:** PHImageManager ile `targetSize` küçük istek gönder
- **Flutter tarafında:** `image` paketini kullanıyorsan resmi 128x128'e resize et, sonra işlem yap.

```dart
import 'package:image/image.dart' as img;

img.Image downscaleForAnalysis(img.Image original) {
  const target = 128;
  return img.copyResize(
    original,
    width: target,
    height: target,
    interpolation: img.Interpolation.average,
  );
}
```

Bu tek başına CPU + RAM kullanımını ciddi azaltır.

## 2. Ağır işleri mutlaka isolate'ta çalıştır (UI'den ayır)

Blur score ve hash hesaplama main isolate'ta olmamalı.

```dart
import 'dart:isolate';
import 'package:image/image.dart' as img;

class AnalysisTask {
  AnalysisTask(this.bytes);
  final List<int> bytes;
}

class AnalysisResult {
  AnalysisResult({required this.blurScore, required this.hash});
  final double blurScore;
  final int hash;
}

Future<AnalysisResult> analyzeImageInIsolate(List<int> bytes) {
  return Isolate.run(() async {
    final image = img.decodeImage(bytes)!;
    final small = downscaleForAnalysis(image);
    final blurScore = computeBlurScore(small);
    final hash = computePerceptualHash(small);
    return AnalysisResult(blurScore: blurScore, hash: hash);
  });
}
```

**Özet:** UI → dosya yolunu al → bytes oku → Isolate.run içine ver → sonuç dönünce UI'yı güncelle.

## 3. Blur tespiti için hızlı bir metrik kullan (variance of Laplacian)

Gözle görülen blur için "mükemmel ML modeli" değil, basit ama hızlı bir metrik yeterli.

```dart
double computeBlurScore(img.Image image) {
  // 1) Gri ton
  final gray = img.grayscale(image);

  // 2) Basit Laplacian kernel
  final kernel = [
    [0, 1, 0],
    [1, -4, 1],
    [0, 1, 0],
  ];

  double sum = 0;
  double sumSq = 0;
  int count = 0;

  for (var y = 1; y < gray.height - 1; y++) {
    for (var x = 1; x < gray.width - 1; x++) {
      int conv = 0;
      for (var ky = -1; ky <= 1; ky++) {
        for (var kx = -1; kx <= 1; kx++) {
          final p = gray.getPixel(x + kx, y + ky);
          final v = img.getLuminance(p);
          conv += v * kernel[ky + 1][kx + 1];
        }
      }
      sum += conv;
      sumSq += conv * conv;
      count++;
    }
  }

  // Variance = E[X²] - E[X]²
  final mean = sum / count;
  final variance = (sumSq / count) - (mean * mean);
  return variance;
}
```

## 4. Duplicate tespiti için O(n²) karşılaştırma yapma → hash ve bucket kullan

Klasik hata: her fotoyu her foto ile karşılaştırmak.

**Onun yerine:**

1. Her foto için perceptual hash üret (int veya BigInt)
2. Hash'leri bir `Map<int, List<Photo>>` içinde tut
3. Hamming distance'i sadece aynı bucket veya yakın hash'ler arasında karşılaştır

**Basit bir aHash örneği:**

```dart
int computePerceptualHash(img.Image image) {
  // 8x8 boyuta indir
  final small = img.copyResize(image, width: 8, height: 8);
  final gray = img.grayscale(small);

  // Ortalama parlaklık
  int sum = 0;
  for (var y = 0; y < gray.height; y++) {
    for (var x = 0; x < gray.width; x++) {
      sum += img.getLuminance(gray.getPixel(x, y));
    }
  }
  final avg = sum / 64;

  // Bitleri oluştur
  int hash = 0;
  int bitIndex = 0;
  for (var y = 0; y < gray.height; y++) {
    for (var x = 0; x < gray.width; x++) {
      final v = img.getLuminance(gray.getPixel(x, y));
      if (v > avg) {
        hash |= (1 << bitIndex);
      }
      bitIndex++;
    }
  }
  return hash;
}
```

**Sonra:**

```dart
int hammingDistance(int a, int b) {
  int x = a ^ b;
  int dist = 0;
  while (x != 0) {
    dist += x & 1;
    x >>= 1;
  }
  return dist;
}
```

Duplicate sayılacak fotoğraflar için `distance <= 5` gibi bir threshold seçebilirsin.

## 5. Her açılışta sıfırdan tarama yapma → indeksle & cache'le

Her açılışta tüm galeriyi taramak büyük zaman kaybı.

**İlk çalıştırmada:**

- Tüm fotoğrafları tarayıp hash + blurScore + lastModified + path bilgilerini bir local DB'ye (Hive / sqflite) yaz.

**Sonraki açılışlarda:**

- Sadece "lastModified tarihi değişmiş veya yeni eklenen" fotoğrafları yeniden analiz et.
- Kullanıcıya "Scanning 12 new photos..." gibi gösterebilirsin.

Bu sayede ikinci girişten itibaren tarama süresi dramatik şekilde kısalır.
