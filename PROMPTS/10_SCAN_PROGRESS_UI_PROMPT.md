# Scan Progress UI - Tasarım Promptu

## Genel Bakış

**Scan Progress UI**, blur veya duplicate taraması sırasında gösterilen full-screen overlay ekranıdır. Kullanıcıya tarama ilerlemesini, durumu ve iptal seçeneğini sunar.

**Kullanım**: Hem Blur Tab hem de Duplicate Tab'da kullanılır  
**Durum**: Tarama başladığında otomatik gösterilir, tarama bitince gizlenir  
**Ana Özellikler**:

- Lottie animasyonu
- İlerleme göstergesi
- Uyarı mesajı
- İptal butonu

---

## Tasarım Hedefleri

1. **Bilgilendirici**: Kullanıcı tarama durumunu her zaman bilmeli
2. **Engelleyici**: Kullanıcı tarama sırasında sayfadan ayrılmamalı
3. **Görsel**: Animasyonlu ve ilgi çekici
4. **Kontrollü**: Kullanıcı isterse taramayı iptal edebilmeli

---

## Layout Yapısı

### 1. Ana Container

- **Konum**: Full-screen overlay (Center widget içinde)
- **Padding**: `32px` (tüm yönler)
- **Arka Plan**: `background` (mevcut sayfa arka planı)
- **Blur**: Hafif blur efekti (opsiyonel, arka planı bulanıklaştırmak için)

### 2. Lottie Animasyonu

- **Dosya**: `assets/lottie/gallery_loading.json`
- **Boyut**: 180x180px
- **Konum**: Üstte, ortalanmış
- **Stil**:
  - `BoxFit.contain`
  - `repeat: true`
  - `animate: true`
- **Spacing**: Altında 24px boşluk

### 3. Başlık

- **Metin**:
  - Blur: "Scanning Blurry Photos" (lokalize)
  - Duplicate: "Scanning Duplicate Photos" (lokalize)
- **Stil**:
  - Font: `titleMedium`
  - Font ağırlığı: `w600`
  - Renk: `onSurface`
  - Hizalama: Ortalanmış
- **Spacing**: Lottie'nin 24px altında, açıklamanın 12px üstünde

### 4. Açıklama Metni

- **Metin**: "This may take a few seconds" (lokalize)
- **Stil**:
  - Font: `bodyMedium`
  - Renk: `onSurface` %70 opaklık
  - Hizalama: Ortalanmış
- **Spacing**: Başlığın 12px altında, uyarı kartının 24px üstünde

### 5. Uyarı Kartı

- **Container**:
  - Padding: `20px` yatay, `16px` dikey
  - Arka plan: `warningLight` %40 opaklık
  - Border radius: `16px`
  - Border: `warning` %70, 2px
  - Gölge: `warning` %20, 8px blur, 1px spread
- **İçerik**:
  - İkon: `warning_amber_rounded`, 28px, `warning` rengi
  - Metin: "Do not leave the screen during scan" (lokalize)
    - Stil: `bodyLarge`, `w700`, 15px, `warning` rengi
    - Hizalama: Ortalanmış
- **Layout**: Row, ikon + metin
- **Spacing**: Açıklamanın 24px altında, progress card'ın 16px üstünde

### 6. Progress Card

- **Container**:
  - Padding: `16px` (tüm yönler)
  - Arka plan: `surface` veya `surfaceContainerHighest`
  - Border radius: `16px`
  - Border: `outline` %20, 1px
  - Gölge: Yumuşak
- **İçerik**:
  - **Başlık**: Aktif albüm adı veya fallback label
    - Stil: `bodyLarge`, `w600`
    - Renk: `onSurface`
  - **Progress Bar**: Linear progress indicator
    - Değer: `processedCount / totalCount`
    - Renk: `primary`
    - Yükseklik: `8px`
    - Border radius: `4px`
  - **Metin**: "X of Y photos" (lokalize)
    - Stil: `bodyMedium`
    - Renk: `onSurface` %70 opaklık
- **Spacing**: Uyarı kartının 16px altında, stop butonunun 24px üstünde

### 7. Stop Butonu

- **Buton**: `FilledButton.icon`
- **İkon**: `stop`, 20px
- **Metin**: "Stop" (lokalize)
- **Stil**:
  - Padding: `24px` yatay, `16px` dikey
  - Arka plan: `error`
  - Renk: `onError`
  - Border radius: `12px`
  - Border: `error` %90, 1.5px
- **Fonksiyon**:
  - Tıklanınca tarama iptal edilir
  - Provider'ın `cancel()` metodu çağrılır
- **Spacing**: Progress card'ın 24px altında

---

## Durumlar

### 1. Tarama Başladı

- Lottie animasyonu başlar
- Progress card görünür (0% ile başlar)
- Uyarı mesajı görünür
- Stop butonu aktif

### 2. Tarama Devam Ediyor

- Lottie animasyonu devam eder
- Progress card güncellenir (processedCount / totalCount)
- Aktif albüm adı güncellenir
- Uyarı mesajı görünür
- Stop butonu aktif

### 3. Tarama Tamamlandı

- Overlay gizlenir
- Results view gösterilir
- (Otomatik olarak results sayfasına yönlendirme yapılabilir)

### 4. Tarama İptal Edildi

- Overlay gizlenir
- Scan form'a geri dönülür
- İptal mesajı gösterilebilir (opsiyonel)

---

## Renk Sistemi

### Genel

- **Arka Plan**: `background` (mevcut sayfa arka planı)
- **Metin**: `onSurface`

### Uyarı Kartı

- **Arka Plan**: `warningLight` %40
- **Border**: `warning` %70
- **İkon ve Metin**: `warning` rengi

### Progress Card

- **Arka Plan**: `surface` veya `surfaceContainerHighest`
- **Progress Bar**: `primary` rengi
- **Metin**: `onSurface`

### Stop Butonu

- **Arka Plan**: `error` (kırmızı)
- **Border**: `error` %90
- **Metin**: `onError` (beyaz)

---

## Animasyonlar

### 1. Lottie Animasyonu

- **Dosya**: `gallery_loading.json`
- **Süre**: Sürekli tekrar eder
- **Hız**: Normal (1.0x)

### 2. Progress Bar

- **Güncelleme**: Her %1 artışta güncellenir (throttled)
- **Animasyon**: Smooth, 200-300ms geçiş
- **Eğri**: `easeInOut`

### 3. Fade In/Out

- **Giriş**: Fade in + slide up (300ms)
- **Çıkış**: Fade out + slide down (300ms)

---

## PopScope Davranışı

### Geri Tuşu Engelleme

- **PopScope**: `canPop: !isScanning`
- **onPopInvoked**:
  - Eğer tarama devam ediyorsa:
    - Pop işlemi engellenir
    - SnackBar gösterilir: "Do not leave the screen during scan" (lokalize)
    - SnackBar stili:
      - Arka plan: `errorContainer`
      - Süre: 3 saniye
      - Behavior: Floating

---

## Responsive Tasarım

- **Minimum Genişlik**: 320px
- **Maksimum Genişlik**: 600px (tabletler için ortalanmış)
- **Padding**: `32px` (küçük ekranlarda `24px` olabilir)
- **Lottie Boyutu**: 180x180px (küçük ekranlarda 150x150px)

---

## Erişilebilirlik

- **Ekran Okuyucu**:
  - "Scanning [type] photos" mesajı okunur
  - Progress durumu okunur (X of Y photos)
  - Stop butonu okunur
- **Renk Kontrastı**: WCAG AA standartlarına uygun
- **Buton Boyutları**: Minimum 44x44px dokunma alanı
- **Animasyon**: Kullanıcı tercihlerine saygı gösterilir (reduced motion)

---

## Teknik Detaylar

### Widget Yapısı

```
Center
└── Padding
    └── Column
        ├── SizedBox (Lottie animation)
        ├── Text (title)
        ├── Text (description)
        ├── Container (warning card)
        ├── SizedBox (spacing)
        ├── _ScanProgressCard
        ├── SizedBox (spacing)
        └── FilledButton (stop)
```

### Progress Card Widget Yapısı

```
Container
└── Column
    ├── Text (album name / title)
    ├── SizedBox (spacing)
    ├── LinearProgressIndicator
    └── Text (X of Y photos)
```

### Önemli Notlar

- `isScanning` durumu provider'dan kontrol edilir
- Progress güncellemeleri throttled (her 50ms'de bir, %1 artışlarla)
- `currentAlbum` durumu aktif albüm adını gösterir
- `processedCount` ve `totalCount` ile progress hesaplanır
- `cancel()` metodu ile tarama iptal edilir
- PopScope ile geri tuşu engellenir

---

## Örnek Görsel Açıklama

**Genel Görünüm:**

- Ortada büyük Lottie animasyonu (180x180px, dönen galeri animasyonu)
- Altında başlık: "Scanning Blurry Photos" veya "Scanning Duplicate Photos"
- Altında açıklama: "This may take a few seconds"
- Altında uyarı kartı (sarı/amber tonları, warning ikonu ile)
- Altında progress card (albüm adı + progress bar + "X of Y photos")
- En altta kırmızı "Stop" butonu

**Progress Card Detayı:**

- Üstte albüm adı (örn: "Camera")
- Ortada progress bar (mavi, doluyor)
- Altta "150 of 500 photos" metni

---

## Ses Efekti (Opsiyonel)

### Scanner Sound

- **Dosya**: `assets/sound/scanner.mp3`
- **Başlatma**: Tarama başladığında
- **Durdurma**: Tarama bittiğinde veya iptal edildiğinde
- **Kontrol**: `SoundService` ile yönetilir

---

## Sonuç

Scan Progress UI, kullanıcıya tarama durumunu net bir şekilde gösteren, görsel olarak çekici ve bilgilendirici bir overlay ekranıdır. Kullanıcı her zaman ne olduğunu bilmeli ve isterse taramayı iptal edebilmelidir.












