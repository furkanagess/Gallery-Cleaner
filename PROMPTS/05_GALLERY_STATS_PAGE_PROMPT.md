# Gallery Stats Page - Tasarım Promptu

## Genel Bakış

**Gallery Stats Page**, kullanıcıya galeri istatistiklerini, albüm listesini ve temizleme geçmişini gösteren detaylı bir analiz ekranıdır. İlk analiz otomatik olarak başlatılabilir.

**Yol (Route)**: `/gallery/stats`  
**Ana Özellikler**:

- Galeri genel istatistikleri
- Albüm bazlı istatistikler
- Temizleme geçmişi
- İlk analiz otomatik başlatma

---

## Tasarım Hedefleri

1. **Bilgilendirici**: Kullanıcıya galeri hakkında detaylı bilgi sunar
2. **Görsel**: İstatistikler görsel olarak sunulur
3. **Organize**: Albümler ve geçmiş düzenli bir şekilde gösterilir
4. **Etkileşimli**: Kullanıcı albümlere tıklayabilir, geçmişi görüntüleyebilir

---

## Layout Yapısı

### 1. AppBar

- **Başlık**: "Gallery Stats" (lokalize)
- **Hizalama**: Ortalanmış
- **Geri Butonu**: iOS'ta `chevron_left`, Android'de varsayılan

### 2. Ana İçerik (Scrollable)

#### 2.1. Genel İstatistikler Kartı

- **Container**:
  - Padding: `20px` (tüm yönler)
  - Arka plan: `surface`
  - Border radius: `24px`
  - Gölge: Yumuşak, çok katmanlı
- **İçerik**: 3-4 istatistik satırı
  - Toplam fotoğraf/video sayısı
  - Toplam boyut (MB/GB)
  - Albüm sayısı
  - Ortalama fotoğraf boyutu (opsiyonel)
- **Stil**: Her satır ikon + label + değer formatında

#### 2.2. Albüm Listesi Bölümü

- **Başlık**: "Albums" (lokalize)
- **Scroll**: Yatay scrollable liste
  - Scroll controller ile kontrol
  - Sol/sağ ok butonları (scroll durumuna göre görünür/gizli)
- **Albüm Kartları**:
  - Genişlik: `200px`
  - Yükseklik: `240px`
  - İçerik:
    - Albüm thumbnail (üstte, 160x160px)
    - Albüm adı (altında)
    - Fotoğraf sayısı (en altta)
  - Stil:
    - Border radius: `16px`
    - Gölge: Yumuşak
    - Tıklanabilir: InkWell efekti
- **Scroll Butonları**:
  - Sol ok: Scroll başında gizli
  - Sağ ok: Scroll sonunda gizli
  - Stil: Floating action button benzeri, yarı saydam

#### 2.3. Temizleme Geçmişi Bölümü

- **Başlık**: "Recent Activity" veya "Cleaning History" (lokalize)
- **Liste**: Dikey liste
  - Her öğe: Tarih + İşlem tipi + Detaylar
  - İşlem tipleri:
    - Manual swipe (silme/tutma)
    - Blur scan & delete
    - Duplicate scan & delete
  - Detaylar:
    - Silinen fotoğraf sayısı
    - Tutulan fotoğraf sayısı
    - Boşaltılan alan
- **Stil**:
  - Her öğe: Kart veya list tile
  - Border radius: `12-16px`
  - Padding: `16px`

#### 2.4. İlk Analiz Bölümü (Opsiyonel)

- **Durum**: İlk analiz yapılmamışsa görünür
- **İçerik**:
  - Başlık: "First Analysis" (lokalize)
  - Açıklama: İlk analiz açıklaması
  - "Start Analysis" butonu
- **Stil**: Vurgulu kart, primary renk

---

## Animasyonlar

### 1. İlk Analiz Başlatma

- **Otomatik**: Sayfa açıldığında kontrol edilir
- **Manuel**: Buton ile başlatılabilir
- **Progress**: Lottie animasyonu veya progress bar
- **Ses**: Scanner sesi (opsiyonel)

### 2. Albüm Scroll

- **Smooth Scroll**: 300ms, easeOut
- **Ok Butonları**: Fade in/out animasyonu
- **Kartlar**: Hover/press scale efekti

### 3. Geçmiş Listesi

- **Fade In**: Her öğe sırayla görünür
- **Slide**: Sağdan sola slide efekti (opsiyonel)

---

## Durumlar

### 1. Loading Durumu

- **Genel İstatistikler**: Shimmer skeleton
- **Albüm Listesi**: Shimmer skeleton kartlar
- **Geçmiş**: Shimmer skeleton list items

### 2. Boş Durum

- **Albüm Yok**: "No albums found" mesajı
- **Geçmiş Yok**: "No cleaning history" mesajı
- **İllüstrasyon**: Boş durum ikonu/illüstrasyonu

### 3. Error Durumu

- **Hata Mesajı**: Kırmızı, ortalanmış
- **Retry Butonu**: "Try Again" butonu

### 4. Normal Durum

- Tüm veriler görünür
- Tüm butonlar aktif

---

## Renk Sistemi

### İstatistik Kartları

- **Arka Plan**: `surface` veya `primaryContainer`
- **İkon**: `primary` rengi
- **Metin**: `onSurface`

### Albüm Kartları

- **Arka Plan**: `surface`
- **Border**: `outline` %20
- **Thumbnail**: Fotoğraf veya placeholder

### Geçmiş Öğeleri

- **Arka Plan**: `surface` veya `surfaceContainerHighest`
- **Vurgu**: İşlem tipine göre (primary, error, success)

---

## Responsive Tasarım

- **Minimum Genişlik**: 320px
- **Maksimum Genişlik**: 600px (tabletler için ortalanmış)
- **Albüm Kart Genişliği**: Sabit 200px
- **Padding**: `16-24px` (ekran boyutuna göre)

---

## Erişilebilirlik

- **Ekran Okuyucu**: Tüm istatistikler ve öğeler okunabilir
- **Renk Kontrastı**: WCAG AA standartlarına uygun
- **Buton Boyutları**: Minimum 44x44px dokunma alanı
- **Scroll**: Klavye ile erişilebilir

---

## Teknik Detaylar

### Widget Yapısı

```
Scaffold
└── SafeArea
    ├── AppBar
    └── SingleChildScrollView
        └── Column
            ├── Container (general stats)
            ├── Section (album list)
            │   ├── Title
            │   ├── Stack
            │   │   ├── Horizontal ScrollView
            │   │   ├── Left Arrow (conditional)
            │   │   └── Right Arrow (conditional)
            ├── Section (cleaning history)
            │   ├── Title
            │   └── ListView
            └── Container (first analysis - conditional)
```

### Önemli Notlar

- `galleryStatsProvider` ile istatistikler yüklenir
- `reviewHistoryController` ile geçmiş yüklenir
- İlk analiz kontrolü `_checkAndStartFirstAnalysis` ile yapılır
- Albüm scroll controller listener ile ok butonları kontrol edilir
- Scanner sesi `SoundService` ile çalınır (opsiyonel)

---

## Örnek Görsel Açıklama

**Genel Görünüm:**

- Üstte AppBar
- Genel istatistikler kartı (büyük, vurgulu)
- Albüm listesi (yatay scroll, ok butonları ile)
- Temizleme geçmişi (dikey liste)
- İlk analiz bölümü (opsiyonel, vurgulu)

**Albüm Kartı:**

- Üstte thumbnail (160x160px, yuvarlatılmış)
- Altında albüm adı (bold)
- En altta fotoğraf sayısı (küçük, secondary renk)

**Geçmiş Öğesi:**

- Sol tarafta ikon (işlem tipine göre)
- Ortada tarih ve işlem detayları
- Sağda chevron (opsiyonel)

---

## Sonuç

Gallery Stats Page, kullanıcıya galeri hakkında kapsamlı bilgi sunan, albümleri görsel olarak gösteren ve temizleme geçmişini takip eden detaylı bir analiz ekranıdır. Tüm bilgiler düzenli ve erişilebilir bir şekilde sunulmalıdır.


