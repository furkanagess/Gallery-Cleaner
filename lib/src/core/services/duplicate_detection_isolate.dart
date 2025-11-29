import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';

/// Isolate içinde çalışacak hash analizi için data class
class HashAnalysisTask {
  HashAnalysisTask(this.imageBytes, this.thumbnailSize);
  final List<int> imageBytes;
  final int thumbnailSize;
}

/// Isolate içinde çalışacak hash analizi sonucu
class HashAnalysisResult {
  HashAnalysisResult({
    required this.dHash,
    required this.dHashVertical,
    required this.pHash,
    required this.aHash,
    required this.md5Hash,
    required this.histogram,
  });
  final String dHash;
  final String dHashVertical;
  final String pHash;
  final String aHash;
  final String md5Hash;
  final List<double> histogram;
}

/// Isolate içinde hash hesapla (Task 2)
Future<HashAnalysisResult> calculateHashesInIsolate(
  List<int> imageBytes,
  int thumbnailSize,
) {
  return Isolate.run(() {
    try {
      // Image decode et
      final image = img.decodeImage(Uint8List.fromList(imageBytes));
      if (image == null) {
        // Fallback hash
        final fallback = md5.convert(imageBytes).toString();
        return HashAnalysisResult(
          dHash: fallback,
          dHashVertical: fallback,
          pHash: fallback,
          aHash: fallback,
          md5Hash: fallback,
          histogram: List<double>.filled(192, 0.0),
        );
      }

      // Her hash algoritmasını hesapla
      final dHash = _calculateDHash(image);
      final dHashVertical = _calculateDHashVertical(image);
      final pHash = _calculatePHash(image);
      final aHash = _calculateAHash(image);
      final md5Hash = md5.convert(imageBytes).toString();
      final histogram = _calculateHistogram(image);

      return HashAnalysisResult(
        dHash: dHash,
        dHashVertical: dHashVertical,
        pHash: pHash,
        aHash: aHash,
        md5Hash: md5Hash,
        histogram: histogram,
      );
    } catch (e) {
      // Hata durumunda fallback hash
      final fallback = md5.convert(imageBytes).toString();
      return HashAnalysisResult(
        dHash: fallback,
        dHashVertical: fallback,
        pHash: fallback,
        aHash: fallback,
        md5Hash: fallback,
        histogram: List<double>.filled(192, 0.0),
      );
    }
  });
}

/// Hamming distance hesapla (Task 4)
int hammingDistance(int a, int b) {
  int x = a ^ b;
  int dist = 0;
  while (x != 0) {
    dist += x & 1;
    x >>= 1;
  }
  return dist;
}

/// Hamming distance hesapla (hex string için)
int hammingDistanceHex(String hash1, String hash2) {
  if (hash1.length != hash2.length) {
    return hash1.length * 4; // Her hex karakter 4 bit
  }

  int distance = 0;
  for (int i = 0; i < hash1.length; i++) {
    final char1 = hash1[i];
    final char2 = hash2[i];
    if (char1 != char2) {
      final val1 = int.parse(char1, radix: 16);
      final val2 = int.parse(char2, radix: 16);
      final xor = val1 ^ val2;
      int bitCount = 0;
      int n = xor;
      while (n > 0) {
        bitCount += n & 1;
        n >>= 1;
      }
      distance += bitCount;
    }
  }
  return distance;
}

/// Basit aHash hesapla (Task 4 örneği)
String _calculateAHash(img.Image image) {
  try {
    // 8x8 boyuta indir
    final small = img.copyResize(image, width: 8, height: 8);
    final gray = img.grayscale(small);

    // Ortalama parlaklık
    int sum = 0;
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        sum += img.getLuminance(gray.getPixel(x, y)).round();
      }
    }
    final avg = (sum / 64).toDouble();

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
    return hash.toRadixString(16);
  } catch (e) {
    return md5.convert('${image.width}_${image.height}_a'.codeUnits).toString();
  }
}

/// dHash hesapla (basitleştirilmiş)
String _calculateDHash(img.Image image) {
  try {
    final resized = img.copyResize(image, width: 33, height: 32);
    final gray = img.grayscale(resized);

    final hashBits = <bool>[];
    for (int y = 0; y < gray.height - 1 && y < 32; y++) {
      for (int x = 0; x < gray.width - 1 && x < 32; x++) {
        if (x + 1 < gray.width && y < gray.height) {
          final pixel1 = gray.getPixel(x, y);
          final pixel2 = gray.getPixel(x + 1, y);
          final gray1 = img.getLuminance(pixel1);
          final gray2 = img.getLuminance(pixel2);
          hashBits.add(gray1 > gray2);
        }
      }
    }

    if (hashBits.isEmpty) {
      return md5
          .convert('${image.width}_${image.height}_empty'.codeUnits)
          .toString();
    }

    final hashString = hashBits.map((b) => b ? '1' : '0').join();
    final hashParts = <String>[];
    const chunkSize = 63;
    for (int i = 0; i < hashString.length; i += chunkSize) {
      final end = (i + chunkSize < hashString.length)
          ? i + chunkSize
          : hashString.length;
      if (end > i && end <= hashString.length) {
        final part = hashString.substring(i, end);
        if (part.isNotEmpty && part.length <= chunkSize) {
          try {
            final paddedPart = part.length < chunkSize
                ? part.padRight(chunkSize, '0')
                : part;
            if (paddedPart.length <= chunkSize) {
              final hashInt = int.parse(paddedPart, radix: 2);
              hashParts.add(hashInt.toRadixString(16).padLeft(16, '0'));
            }
          } catch (e) {
            continue;
          }
        }
      }
    }

    if (hashParts.isEmpty) {
      return md5
          .convert('${image.width}_${image.height}_fallback'.codeUnits)
          .toString();
    }

    return hashParts.join('');
  } catch (e) {
    return md5.convert('${image.width}_${image.height}'.codeUnits).toString();
  }
}

/// dHash vertical hesapla
String _calculateDHashVertical(img.Image image) {
  try {
    final resized = img.copyResize(image, width: 33, height: 32);
    final gray = img.grayscale(resized);

    final hashBits = <bool>[];
    for (int x = 0; x < gray.width && x < 32; x++) {
      for (int y = 0; y < gray.height - 1 && y < 32; y++) {
        if (x < gray.width && y + 1 < gray.height) {
          final pixel1 = gray.getPixel(x, y);
          final pixel2 = gray.getPixel(x, y + 1);
          final gray1 = img.getLuminance(pixel1);
          final gray2 = img.getLuminance(pixel2);
          hashBits.add(gray1 > gray2);
        }
      }
    }

    final hashString = hashBits.map((b) => b ? '1' : '0').join();
    final hashParts = <String>[];
    const chunkSize = 63;
    for (int i = 0; i < hashString.length; i += chunkSize) {
      final end = (i + chunkSize < hashString.length)
          ? i + chunkSize
          : hashString.length;
      if (end > i && end <= hashString.length) {
        final part = hashString.substring(i, end);
        if (part.isNotEmpty) {
          try {
            final paddedPart = part.length < chunkSize
                ? part.padRight(chunkSize, '0')
                : part.substring(0, chunkSize);
            final hashInt = int.parse(paddedPart, radix: 2);
            hashParts.add(hashInt.toRadixString(16).padLeft(16, '0'));
          } catch (e) {
            continue;
          }
        }
      }
    }
    return hashParts.join('');
  } catch (e) {
    return md5.convert('${image.width}_${image.height}_v'.codeUnits).toString();
  }
}

/// pHash hesapla (basitleştirilmiş)
String _calculatePHash(img.Image image) {
  try {
    final resized = img.copyResize(image, width: 32, height: 32);
    final gray = img.grayscale(resized);

    final dctSize = 8;
    final pixels = List<List<double>>.generate(
      dctSize,
      (_) => List<double>.filled(dctSize, 0.0),
    );

    for (int y = 0; y < dctSize && y < gray.height; y++) {
      for (int x = 0; x < dctSize && x < gray.width; x++) {
        if (x < gray.width && y < gray.height) {
          final pixel = gray.getPixel(x, y);
          pixels[y][x] = img.getLuminance(pixel).toDouble();
        }
      }
    }

    // Basitleştirilmiş DCT (ortalama kullan)
    double dctMean = 0.0;
    int count = 0;
    for (int y = 0; y < dctSize; y++) {
      for (int x = 0; x < dctSize; x++) {
        if (x != 0 || y != 0) {
          dctMean += pixels[y][x];
          count++;
        }
      }
    }
    dctMean /= count;

    final hashBits = <bool>[];
    for (int y = 0; y < dctSize; y++) {
      for (int x = 0; x < dctSize; x++) {
        if (x != 0 || y != 0) {
          hashBits.add(pixels[y][x] > dctMean);
        }
      }
    }

    final hashString = hashBits.map((b) => b ? '1' : '0').join();
    final hashParts = <String>[];
    const chunkSize = 63;
    for (int i = 0; i < hashString.length; i += chunkSize) {
      final end = (i + chunkSize < hashString.length)
          ? i + chunkSize
          : hashString.length;
      if (end > i && end <= hashString.length) {
        final part = hashString.substring(i, end);
        if (part.isNotEmpty) {
          try {
            final paddedPart = part.length < chunkSize
                ? part.padRight(chunkSize, '0')
                : part.substring(0, chunkSize);
            final hashInt = int.parse(paddedPart, radix: 2);
            hashParts.add(hashInt.toRadixString(16).padLeft(16, '0'));
          } catch (e) {
            continue;
          }
        }
      }
    }
    return hashParts.join('');
  } catch (e) {
    return md5.convert('${image.width}_${image.height}_p'.codeUnits).toString();
  }
}

/// Histogram hesapla
List<double> _calculateHistogram(img.Image image) {
  try {
    final rHist = List<int>.filled(64, 0);
    final gHist = List<int>.filled(64, 0);
    final bHist = List<int>.filled(64, 0);

    final width = image.width;
    final height = image.height;
    final totalPixels = width * height;

    if (totalPixels == 0) {
      return List<double>.filled(192, 0.0);
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x < width && y < height) {
          try {
            final pixel = image.getPixel(x, y);
            final r = pixel.r.toInt().clamp(0, 255);
            final g = pixel.g.toInt().clamp(0, 255);
            final b = pixel.b.toInt().clamp(0, 255);

            final rDiv = r ~/ 4;
            final gDiv = g ~/ 4;
            final bDiv = b ~/ 4;

            final rIndex = (rDiv < 0 ? 0 : (rDiv > 63 ? 63 : rDiv));
            final gIndex = (gDiv < 0 ? 0 : (gDiv > 63 ? 63 : gDiv));
            final bIndex = (bDiv < 0 ? 0 : (bDiv > 63 ? 63 : bDiv));

            if (rIndex >= 0 && rIndex < rHist.length) rHist[rIndex]++;
            if (gIndex >= 0 && gIndex < gHist.length) gHist[gIndex]++;
            if (bIndex >= 0 && bIndex < bHist.length) bHist[bIndex]++;
          } catch (e) {
            continue;
          }
        }
      }
    }

    final normalized = <double>[];
    for (int i = 0; i < 64; i++) {
      normalized.add(rHist[i] / totalPixels);
      normalized.add(gHist[i] / totalPixels);
      normalized.add(bHist[i] / totalPixels);
    }

    return normalized;
  } catch (e) {
    return List<double>.filled(192, 0.0);
  }
}
