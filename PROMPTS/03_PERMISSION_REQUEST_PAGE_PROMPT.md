# Permission Request Page - Tasarım Promptu

## Genel Bakış

**Permission Request Page**, kullanıcıdan fotoğraf galerisi erişim izni isteyen ekrandır. İki farklı durumda görüntülenir: izin verilmeden önce (izin isteme) ve izin verildikten sonra (başarı ekranı).

**Yol (Route)**: `/permission`  
**Durumlar**:

1. İzin isteniyor (permission request)
2. İzin verildi (authorized - success screen)

---

## Tasarım Hedefleri

1. **Güven Verici**: Kullanıcıya neden izin gerektiğini açıkça anlatır
2. **Bilgilendirici**: Uygulamanın özelliklerini ve faydalarını gösterir
3. **Basit**: Tek bir butonla izin ister
4. **Görsel**: İkonlar ve görsel öğelerle desteklenir

---

## Layout Yapısı - İzin İsteniyor Durumu

### 1. Arka Plan Dekorasyonu

- **Dekoratif Daireler**:
  - Üst sağ: 220x220px, `primary` %10 opaklık
    - Konum: `top: -60, right: -40`
  - Alt sol: 160x160px, `tertiary` %10 opaklık
    - Konum: `bottom: -40, left: -20`

### 2. Ana İçerik (Ortalanmış)

#### 2.1. Ana İkon

- **İkon**: `photo_library_outlined`
- **Boyut**: 120px
- **Renk**: `primary`
- **Konum**: Üstte, ortalanmış
- **Spacing**: Altında 32px boşluk

#### 2.2. Başlık

- **Metin**: "We Need Your Access" (lokalize)
- **Stil**:
  - Font: `headlineLarge`
  - Font ağırlığı: `bold`
  - Hizalama: Ortalanmış
  - Renk: `onSurface`
- **Spacing**: İkonun 32px altında, açıklamanın 16px üstünde

#### 2.3. Açıklama Metni

- **Metin**: İzin açıklaması (lokalize)
- **Stil**:
  - Font: `bodyLarge`
  - Renk: `onSurface` %80 opaklık
  - Hizalama: Ortalanmış
  - Line height: Normal
- **Spacing**: Başlığın 16px altında, özellik kartının 24px üstünde

#### 2.4. Özellik Kartı

- **Container**:
  - Maksimum genişlik: 400px
  - Padding: `24px` (tüm yönler)
  - Arka plan: `surface`
  - Border radius: `20px`
  - Gölge: `black` %6, 16px blur, `(0, 8)` offset
- **İçerik**: 3 özellik satırı
  - Her satır: İkon + Başlık + Açıklama
  - Aralarında 16px boşluk

**Özellik 1: Quick Cleanup**

- İkon: `swipe`, `primaryContainer` içinde
- Başlık: "Quick Cleanup" (lokalize)
- Açıklama: Swipe özelliği açıklaması (lokalize)

**Özellik 2: Blur Detection**

- İkon: `blur_on`, `primaryContainer` içinde
- Başlık: "Blur Photo Detection - AI Powered" (lokalize)
- Açıklama: Blur detection açıklaması (lokalize)

**Özellik 3: Duplicate Detection**

- İkon: `content_copy`, `primaryContainer` içinde
- Başlık: "Duplicate Photo Detection - AI Powered" (lokalize)
- Açıklama: Duplicate detection açıklaması (lokalize)

#### 2.5. İzin İsteme Butonu

- **Buton**: `FilledButton.icon`
- **İkon**: `lock_open`
- **Metin**: "Allow Access" (lokalize)
- **Stil**:
  - Genişlik: Tam genişlik (max 400px)
  - Padding: `16px` dikey
  - Arka plan: `primary`
  - Renk: `onPrimary`
- **Spacing**: Özellik kartının 32px altında

#### 2.6. Ayarlar Butonu

- **Buton**: `TextButton`
- **Metin**: "Open Settings" (lokalize)
- **Stil**: Varsayılan TextButton stili
- **Spacing**: İzin butonunun 12px altında
- **Fonksiyon**: Sistem ayarlarını açar

---

## Layout Yapısı - İzin Verildi Durumu

### 1. AppBar

- **Başlık**: Uygulama adı (lokalize)
- **Hizalama**: Ortalanmış
- **Arka plan**: Şeffaf (`transparent`)
- **Elevation**: 0

### 2. Ana İçerik

#### 2.1. Başlık Bölümü

- **Başlık**: "Start Cleaning" (lokalize)
- **Stil**:
  - Font: `displaySmall`
  - Font ağırlığı: `w800`
  - Line height: `1.05`
- **Spacing**: Üstte 16px, altında 12px

#### 2.2. Açıklama Metni

- **Metin**: Swipe kartları açıklaması (lokalize)
- **Stil**:
  - Font: `bodyLarge`
  - Renk: `onSurface` %90 opaklık
- **Spacing**: Başlığın 12px altında, özellik chip'lerinin 20px üstünde

#### 2.3. Özellik Chip'leri

- **Layout**: `Wrap` widget'ı
- **Spacing**: 8px (yatay ve dikey)
- **Chip'ler**:
  1. "Quick Swipe" (swipe ikonu)
  2. "Drag to Folder" (folder_open ikonu)
  3. "Undo Safety" (undo ikonu)
- **Chip Stili**:
  - Arka plan: `surface`
  - Border: `dividerColor` %40, 1px
  - Border radius: `999px` (tam yuvarlak)
  - Padding: `12px` yatay, `8px` dikey
  - İçerik: İkon (16px, primary) + Metin (bodySmall)

#### 2.4. İstatistik Kartı

- **Container**:
  - Maksimum genişlik: 560px
  - Padding: `20px` (tüm yönler)
  - Arka plan: `surface`
  - Border radius: `28px`
  - Gölge: `black` %6, 22px blur, `(0, 12)` offset
- **İçerik Durumları**:

**Loading Durumu:**

- Lottie animasyonu: `loading.json`
- Boyut: 100x100px
- Tekrar: Evet

**Error Durumu:**

- İkon: `error_outline`, 72px, `error` rengi
- Hata mesajı (lokalize)
- "Try Again" butonu

**Success Durumu:**

- İkon: `photo_library`, 72px, `primary` rengi
- Başlık: "Gallery Info" (lokalize)
- İstatistikler:
  1. Album sayısı (folder ikonu)
  2. Fotoğraf/video sayısı (photo ikonu)
  3. Toplam boyut (storage ikonu)
- "Start Cleaning" butonu (play_arrow ikonu ile)

---

## Animasyonlar

### 1. İzin İsteme

- **Otomatik İstek**: Sayfa yüklendikten 500ms sonra otomatik olarak izin istenir
- **Buton Tıklama**: Manuel izin isteği

### 2. İzin Verildi Geçişi

- **Yönlendirme**: İzin verildikten sonra:
  1. Album listesi yüklenene kadar beklenir (max 5 saniye)
  2. Fotoğraflar yüklenene kadar beklenir (max 5 saniye)
  3. `/swipe` sayfasına yönlendirilir

### 3. Loading Animasyonu

- Lottie animasyonu: `loading.json`
- Sürekli tekrar eder

---

## Durumlar

### 1. İzin İsteniyor

- Ana ikon görünür
- Başlık ve açıklama görünür
- Özellik kartı görünür
- İzin butonu aktif
- Ayarlar butonu görünür

### 2. İzin Verildi (Loading)

- AppBar görünür
- Başlık ve açıklama görünür
- Özellik chip'leri görünür
- İstatistik kartında loading animasyonu

### 3. İzin Verildi (Error)

- AppBar görünür
- Başlık ve açıklama görünür
- Özellik chip'leri görünür
- İstatistik kartında hata mesajı ve "Try Again" butonu

### 4. İzin Verildi (Success)

- AppBar görünür
- Başlık ve açıklama görünür
- Özellik chip'leri görünür
- İstatistik kartında galeri bilgileri ve "Start Cleaning" butonu

---

## Renk Sistemi

### Light Mode

- **Arka Plan**: Açık `background`
- **Kartlar**: Açık `surface`
- **Metin**: Koyu `onSurface`
- **Vurgu**: `primary` rengi

### Dark Mode

- **Arka Plan**: Koyu `background`
- **Kartlar**: Koyu `surface`
- **Metin**: Açık `onSurface`
- **Vurgu**: `primary` rengi

---

## Responsive Tasarım

- **Minimum Genişlik**: 320px
- **Maksimum Genişlik**: 400px (izin isteniyor), 560px (izin verildi)
- **Padding**: `24px` (tüm yönler)
- **Ortalama**: Tüm içerik ortalanmış

---

## Erişilebilirlik

- **Ekran Okuyucu**: Tüm metinler okunabilir
- **Renk Kontrastı**: WCAG AA standartlarına uygun
- **Buton Boyutları**: Minimum 44x44px dokunma alanı
- **İkonlar**: Anlamlı ve açıklayıcı

---

## Teknik Detaylar

### Widget Yapısı - İzin İsteniyor

```
Scaffold
└── Stack
    ├── Positioned (decorative circle 1)
    ├── Positioned (decorative circle 2)
    └── SafeArea
        └── Padding
            └── Column
                ├── Icon
                ├── Text (title)
                ├── Text (description)
                ├── Container (features card)
                ├── FilledButton (allow access)
                └── TextButton (open settings)
```

### Widget Yapısı - İzin Verildi

```
Scaffold
└── Stack
    └── SafeArea
        └── Padding
            └── Column
                ├── Text (title)
                ├── Text (description)
                ├── Wrap (feature chips)
                ├── Spacer
                └── Container (stats card)
```

### Önemli Notlar

- İzin durumu `permissionsControllerProvider` ile takip edilir
- İzin verildiğinde `_waitForPhotosAndNavigate` fonksiyonu çalışır
- Album ve fotoğraf yükleme durumları kontrol edilir
- Maksimum bekleme süresi: 5 saniye (her kontrol 300ms'de bir)

---

## Örnek Görsel Açıklama

**İzin İsteniyor:**

- Ortada büyük fotoğraf kütüphanesi ikonu
- Altında başlık ve açıklama
- Ortada özellik kartı (3 özellik satırı)
- Altında "Allow Access" butonu
- En altta "Open Settings" butonu

**İzin Verildi:**

- Üstte AppBar
- Başlık ve açıklama
- Özellik chip'leri (3 adet)
- Ortada büyük istatistik kartı
  - İkon + başlık
  - 3 istatistik satırı
  - "Start Cleaning" butonu

---

## Sonuç

Permission Request Page, kullanıcıya neden izin gerektiğini açıkça anlatan, güven verici ve bilgilendirici bir ekrandır. İzin verildikten sonra, kullanıcıya galeri bilgilerini gösterir ve temizleme işlemine başlaması için teşvik eder.


