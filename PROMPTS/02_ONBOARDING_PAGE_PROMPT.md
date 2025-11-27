# Onboarding Page - Tasarım Promptu

## Genel Bakış

**Onboarding Page**, kullanıcıya uygulamanın temel özelliklerini tanıtan, 3 sayfalık bir tanıtım ekranıdır. Her sayfa farklı bir özelliği vurgular ve kullanıcıyı uygulamayı kullanmaya teşvik eder.

**Yol (Route)**: `/onboarding`  
**Sayfa Sayısı**: 3 slide  
**Navigasyon**: Sağa kaydırma veya "Continue" butonu ile ilerleme, "Skip" butonu ile atlama

---

## Tasarım Hedefleri

1. **Eğitici**: Kullanıcıya uygulamanın temel özelliklerini öğretir
2. **Görsel**: Her özellik için görsel illüstrasyonlar
3. **Hızlı**: Kullanıcı isterse hızlıca atlayabilir
4. **Etkileşimli**: Swipe ve buton ile ilerleme

---

## Layout Yapısı

### 1. Üst Bar (Skip Butonu)

- **Konum**: Sağ üst köşe
- **Padding**: `24px` yatay, `8px` üst
- **Buton Stili**:
  - Arka plan: `surface` %80 opaklık
  - Border: `outline` %20 opaklık, 1px
  - Border radius: `12px`
  - Gölge: Hafif, yumuşak (`black` %4, 8px blur)
  - İçerik: Ok ikonu (arrow_forward, 16px) + "Skip" metni
  - Renk: `onSurface` %70-80 opaklık
- **Görünürlük**: Son sayfada gizlenir

### 2. Ana İçerik Alanı (PageView)

- **Yapı**: `PageView` widget'ı
- **Fizik**: Yatay kaydırma
- **Sayfalar**: 3 adet slide

#### Slide 1: Swipe Özelliği
- **İllüstrasyon**:
  - Container: 200x300px, `primaryContainer` rengi
  - Border radius: `20px`
  - İçerik:
    - Fotoğraf kartı: 180x280px, `surface` rengi, 16px radius
    - Sol tarafta: Kırmızı daire içinde X ikonu (delete göstergesi)
    - Sağ tarafta: Yeşil daire içinde check ikonu (keep göstergesi)
- **Başlık**: "Swipe Left to Delete" (lokalize)
- **Açıklama**: Swipe özelliğinin açıklaması (lokalize)

#### Slide 2: Blur Detection
- **İllüstrasyon**:
  - Container: 220x220px, `errorContainer` %30 opaklık
  - Border radius: `20px`
  - İçerik:
    - Bulanık fotoğraf örneği: 180x180px
    - Gradient arka plan (primary → secondary)
    - Ortada: `blur_on` ikonu (60px, error rengi)
    - Sağ üstte: Uyarı badge'i (error rengi, daire içinde warning ikonu)
- **Başlık**: "Find Blurry Photos" (lokalize)
- **Açıklama**: Blur detection özelliğinin açıklaması (lokalize)

#### Slide 3: Duplicate Detection
- **İllüstrasyon**:
  - Container: 220x220px, `tertiaryContainer` %30 opaklık
  - Border radius: `20px`
  - İçerik:
    - Üst üste binen 2 fotoğraf kartı (140x140px)
    - Sağda: Link ikonu (tertiary rengi, daire içinde)
    - Alt sağda: "2x" badge'i (tertiary rengi, copy ikonu ile)
- **Başlık**: "Find Duplicates" (lokalize)
- **Açıklama**: Duplicate detection özelliğinin açıklaması (lokalize)

### 3. Sayfa Göstergeleri (Page Indicators)

- **Konum**: Alt içerik ile buton arasında
- **Padding**: `24px` dikey
- **Stil**:
  - Yatay hizalama: Ortalanmış
  - Aktif indicator: 24px genişlik, 8px yükseklik, `primary` rengi
  - Pasif indicator: 8px genişlik, 8px yükseklik, `primary` %30 opaklık
  - Border radius: `4px`
  - Animasyon: 300ms, easeInOut
  - Aralık: 4px yatay

### 4. Alt Aksiyon Butonu

- **Konum**: Ekranın altında
- **Padding**: `24px` yatay, `24px` alt
- **Buton Stili**:
  - Genişlik: Tam genişlik
  - Yükseklik: `56px`
  - Border radius: `16px`
  - Gradient arka plan:
    - Son sayfa: `primary` %85 → `primary` %75
    - Diğer sayfalar: `primary` %85 → `secondary` %75
  - Border: `primary` %90, 1.5px
  - Gölge: `primary` %20, 16px blur, `(0, 8)` offset
  - Metin:
    - Son sayfa: "Start" (lokalize)
    - Diğer sayfalar: "Continue" (lokalize)
    - Font: `titleLarge`, `bold`, `onPrimary` rengi
    - Letter spacing: `0.5`

---

## Animasyonlar

### 1. Sayfa Geçişi
- **Süre**: 300ms
- **Eğri**: `easeInOut`
- **Yön**: Yatay kaydırma

### 2. Indicator Animasyonu
- **Süre**: 300ms
- **Eğri**: `easeInOut`
- **Efekt**: Genişlik değişimi (8px ↔ 24px)

### 3. Buton Animasyonu
- **Hover/Press**: Hafif scale efekti (1.02)
- **Ripple**: Material ripple efekti

---

## Durumlar

### 1. İlk Sayfa
- Skip butonu görünür
- Continue butonu aktif
- İlk indicator aktif

### 2. Orta Sayfalar
- Skip butonu görünür
- Continue butonu aktif
- İlgili indicator aktif

### 3. Son Sayfa
- Skip butonu gizli
- Start butonu aktif (farklı gradient)
- Son indicator aktif

---

## Renk Sistemi

### Light Mode
- **Arka Plan**: Açık `background`
- **Kartlar**: `surface` veya `primaryContainer`
- **Metin**: Koyu `onSurface`
- **Vurgu**: `primary` ve `secondary`

### Dark Mode
- **Arka Plan**: Koyu `background`
- **Kartlar**: Koyu `surface` veya `primaryContainer`
- **Metin**: Açık `onSurface`
- **Vurgu**: `primary` ve `secondary`

---

## Responsive Tasarım

- **Minimum Genişlik**: 320px
- **Maksimum Genişlik**: 600px (tabletler için ortalanmış)
- **Padding**: Tüm cihazlarda `24px`
- **İllüstrasyon Boyutları**: Ekran boyutuna göre ölçeklenebilir

---

## Erişilebilirlik

- **Ekran Okuyucu**: Tüm metinler okunabilir
- **Renk Kontrastı**: WCAG AA standartlarına uygun
- **Buton Boyutları**: Minimum 44x44px dokunma alanı
- **Animasyon**: Kullanıcı tercihlerine saygı gösterilir

---

## Teknik Detaylar

### Widget Yapısı
```
Scaffold
└── SafeArea
    └── Column
        ├── Padding (Skip button)
        ├── Expanded (PageView)
        ├── Padding (Page indicators)
        └── Padding (Action button)
```

### Önemli Notlar
- `PageController` kullanılır
- `_currentPage` state ile takip edilir
- Son sayfada "Start" butonuna tıklanınca onboarding tamamlanır
- Onboarding tamamlandığında `/permission` sayfasına yönlendirilir
- Skip butonu onboarding'i tamamlar ve `/permission` sayfasına yönlendirir

---

## Örnek Görsel Açıklama

**Slide 1 (Swipe):**
- Ortada büyük bir fotoğraf kartı
- Solunda kırmızı X işareti (delete)
- Sağında yeşil check işareti (keep)
- Altında başlık ve açıklama

**Slide 2 (Blur):**
- Ortada bulanık bir fotoğraf illüstrasyonu
- Üzerinde blur ikonu
- Sağ üstte uyarı badge'i
- Altında başlık ve açıklama

**Slide 3 (Duplicate):**
- Ortada üst üste binen 2 fotoğraf
- Sağda link ikonu
- Alt sağda "2x" badge'i
- Altında başlık ve açıklama

---

## Sonuç

Onboarding Page, kullanıcıya uygulamanın temel özelliklerini görsel ve anlaşılır bir şekilde sunan, hızlıca geçilebilen ve etkileşimli bir tanıtım ekranıdır. Her slide, bir özelliği vurgular ve kullanıcıyı uygulamayı kullanmaya teşvik eder.

