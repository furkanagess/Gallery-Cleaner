# Splash Page - Tasarım Promptu

## Genel Bakış

**Splash Page**, uygulamanın ilk açılış ekranıdır. Kullanıcıya uygulamanın markasını ve değer önerisini sunan, kısa bir animasyon gösteren ve ardından kullanıcıyı uygun sayfaya yönlendiren bir ekrandır.

**Yol (Route)**: `/splash`  
**Süre**: Animasyon tamamlandıktan sonra otomatik yönlendirme (yaklaşık 1-2 saniye)

---

## Tasarım Hedefleri

1. **İlk İzlenim**: Modern, profesyonel ve güvenilir bir görünüm
2. **Marka Kimliği**: Uygulama adı ve değer önerisi net bir şekilde sunulmalı
3. **Yumuşak Geçiş**: Animasyonlu bir deneyim, sonrasında akıcı yönlendirme
4. **Minimalist**: Gereksiz öğelerden arındırılmış, odaklanmış bir tasarım

---

## Layout Yapısı

### 1. Arka Plan Katmanları

- **Ana Arka Plan**: `colorScheme.background` (light/dark mode'a göre)
- **Dekoratif Elementler**:
  - Üst sağda: Büyük, yumuşak gradient dairesel şekil (300x300px)
    - Renk: `accent` rengi, %15 opaklık
    - Konum: `top: -100, right: -80`
  - Alt solda: İkinci gradient dairesel şekil (350x350px)
    - Renk: `secondary` rengi, %12 opaklık
    - Konum: `bottom: -120, left: -100`
- **Efekt**: Radial gradient, yumuşak geçişler, hafif blur efekti

### 2. Ana İçerik Alanı (Ortalanmış)

#### 2.1. Lottie Animasyonu

- **Boyut**: 280x280px
- **Konum**: Ekranın ortasında, dikey ve yatayda merkezlenmiş
- **Stil**:
  - Dairesel container içinde
  - Çok katmanlı gölge efekti:
    - Birincil gölge: `primary` rengi, %25 opaklık, 40px blur, 8px spread
    - İkincil gölge: `accent` rengi, %15 opaklık, 60px blur, 4px spread
  - Offset: `(0, 12)` ve `(0, 20)`
- **Renk Filtresi**:
  - Light mode: `textPrimary` rengi
  - Dark mode: `textPrimary` rengi
  - Blend mode: `srcATop`
- **Animasyon**:
  - Dosya: `assets/lottie/loading.json`
  - Tekrar: Hayır (repeat: false)
  - Animasyon tamamlandığında otomatik yönlendirme

#### 2.2. Uygulama Adı

- **Metin**: "Gallery Cleaner"
- **Stil**:
  - Font: `headlineLarge`
  - Font ağırlığı: `w800` (extra bold)
  - Font boyutu: `32px`
  - Letter spacing: `-0.5`
  - Renk: `textPrimary`
- **Gradient Efekti**:
  - Shader mask ile uygulanır
  - Light mode: `textPrimary` → `textPrimary` %85 opaklık
  - Dark mode: `textPrimary` → `textPrimary` %70 opaklık
  - Yön: Sol üstten sağ alta
- **Gölge Efektleri**:
  - Birincil gölge: `glowShadowColor` %25, 12px blur, `(0, 4)` offset
  - İkincil gölge: `glowShadowColor` %35, 20px blur, `(0, 8)` offset
- **Konum**: Lottie animasyonunun 48px altında

#### 2.3. Alt Başlık

- **Metin**: "Clean & organize gallery with AI.\nRemove duplicates and blurry shots easily."
- **Stil**:
  - Font: `titleMedium`
  - Font ağırlığı: `w500` (medium)
  - Font boyutu: `16px`
  - Letter spacing: `0.3`
  - Line height: `1.4`
  - Renk: `textSecondary` %90 opaklık
  - Hizalama: Ortalanmış
- **Konum**: Uygulama adının 12px altında

---

## Renk Sistemi

### Light Mode

- **Arka Plan**: Açık renkli `background`
- **Metin Birincil**: Koyu renk (`textPrimary`)
- **Metin İkincil**: Orta ton (`textSecondary`)
- **Vurgu Rengi**: `primary` veya `accent`

### Dark Mode

- **Arka Plan**: Koyu renkli `background`
- **Metin Birincil**: Açık renk (`textPrimary`)
- **Metin İkincil**: Orta ton (`textSecondary`)
- **Vurgu Rengi**: `primary` veya `accent`

---

## Animasyon ve Geçişler

### 1. Lottie Animasyonu

- **Yükleme**: Dosya yüklendiğinde otomatik başlar
- **Süre**: Animasyonun tamamı (composition.duration)
- **Tamamlanma**: Animasyonun çeyreği tamamlandığında yönlendirme yapılır
- **Callback**: `onLoaded` callback'i ile süre hesaplanır

### 2. Yönlendirme Mantığı

1. **Onboarding Kontrolü**:
   - Tamamlanmamışsa → `/onboarding`
   - Tamamlanmışsa → İzin kontrolü
2. **İzin Kontrolü**:
   - Verilmişse → `/swipe` (300ms gecikme ile)
   - Verilmemişse → `/permission`

### 3. Geçiş Animasyonu

- Platform geçiş animasyonları kullanılır
- Yumuşak, doğal bir geçiş

---

## Durumlar

### 1. Normal Durum

- Lottie animasyonu oynatılır
- Tüm metinler görünür
- Dekoratif elementler gösterilir

### 2. Yönlendirme Sırasında

- Animasyon devam eder
- Kullanıcı etkileşimi engellenmez (ama gereksiz)
- Arka planda yönlendirme mantığı çalışır

---

## Responsive Tasarım

- **Minimum Genişlik**: 320px (küçük telefonlar)
- **Maksimum Genişlik**: 600px (tabletler için ortalanmış)
- **Dikey Hizalama**: Tüm içerik dikeyde ortalanmış
- **Yatay Hizalama**: Tüm içerik yatayda ortalanmış

---

## Erişilebilirlik

- **Ekran Okuyucu**: Uygulama adı ve alt başlık okunabilir
- **Renk Kontrastı**: WCAG AA standartlarına uygun
- **Animasyon**: Kullanıcı tercihlerine saygı gösterilir (reduced motion)

---

## Teknik Detaylar

### Widget Yapısı

```
Scaffold
└── Container (background)
    └── Stack
        ├── Positioned (decorative circle 1)
        ├── Positioned (decorative circle 2)
        └── Center
            └── Column
                ├── Container (Lottie animation)
                ├── SizedBox (spacing)
                ├── ShaderMask (app name)
                ├── SizedBox (spacing)
                └── Text (subtitle)
```

### Önemli Notlar

- `SafeArea` kullanılmaz (tam ekran deneyim)
- `extendBodyBehindAppBar` kullanılmaz
- Animasyon tamamlanmadan önce yönlendirme yapılmaz
- `mounted` kontrolü her async işlemde yapılır

---

## Örnek Görsel Açıklama

**Light Mode:**

- Açık gri/bej arka plan
- Üst sağda mavi tonlu yumuşak daire
- Alt solda mor/teal tonlu yumuşak daire
- Ortada büyük, animasyonlu Lottie ikonu (koyu renk)
- Altında kalın, gradient efektli "Gallery Cleaner" yazısı
- En altta açıklayıcı alt başlık metni

**Dark Mode:**

- Koyu gri/siyah arka plan
- Aynı dekoratif daireler (daha düşük opaklık)
- Lottie ikonu açık renk
- Metinler açık renk tonlarında
- Genel olarak daha yumuşak, düşük kontrastlı bir görünüm

---

## Sonuç

Splash Page, kullanıcıya uygulamanın modern ve profesyonel olduğunu hissettiren, marka kimliğini net bir şekilde sunan ve yumuşak bir geçiş sağlayan minimalist bir ekrandır. Tüm animasyonlar ve geçişler akıcı olmalı, kullanıcı deneyimini bozmamalıdır.


