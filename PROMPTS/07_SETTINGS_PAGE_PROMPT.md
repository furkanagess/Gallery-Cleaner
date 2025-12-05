# Settings Page - Tasarım Promptu

## Genel Bakış

**Settings Page**, uygulama ayarlarını, tema ve dil seçeneklerini, premium durumunu ve uygulama değerlendirmesini içeren kapsamlı bir ayarlar ekranıdır.

**Yol (Route)**: `/settings`  
**Ana Özellikler**:

- Tema seçimi (Light/Dark/System)
- Dil seçimi (Türkçe/English/Spanish)
- Uygulama değerlendirme
- Premium durumu ve yükseltme

---

## Tasarım Hedefleri

1. **Organize**: Ayarlar mantıklı gruplar halinde düzenlenmiş
2. **Erişilebilir**: Tüm ayarlar kolayca erişilebilir
3. **Görsel**: Premium bölümü vurgulu
4. **Basit**: Karmaşık ayarlar yok, sade ve anlaşılır

---

## Layout Yapısı

### 1. AppBar

- **Başlık**: "Settings" (lokalize)
- **Hizalama**: Ortalanmış
- **Geri Butonu**:
  - iOS: `chevron_left` (Cupertino)
  - Android: Varsayılan back arrow
- **Stil**: Varsayılan AppBar stili

### 2. Ana İçerik (Scrollable)

#### 2.1. Tema ve Dil Kartı

- **Container**:
  - Padding: `16px` (tüm yönler)
  - Arka plan: `surfaceContainerHighest` %30
  - Border radius: `20px`
  - Border: `outline` %10, 1px
- **İçerik**: 2 bölüm (divider ile ayrılmış)

**Tema Bölümü:**

- **Başlık**: İkon (`palette_outlined`, 18px) + "Theme" (lokalize)
- **Seçici**: 3 chip (yan yana)
  1. **Light**: `light_mode` ikonu + "Light" (lokalize)
  2. **Dark**: `dark_mode` ikonu + "Dark" (lokalize)
  3. **System**: `brightness_auto` ikonu + "System" (lokalize)
- **Stil**:
  - Container: `surfaceContainerHighest` %50, 12px radius
  - Seçili chip: `primary` %15 arka plan, border
  - Pasif chip: Şeffaf

**Dil Bölümü:**

- **Başlık**: İkon (`language_outlined`, 18px) + "Language" (lokalize)
- **Seçici**: 3 chip (yan yana)
  1. **Türkçe**: 🇹🇷 bayrak + "Turkish" (lokalize)
  2. **English**: 🇬🇧 bayrak + "English" (lokalize)
  3. **Spanish**: 🇪🇸 bayrak + "Spanish" (lokalize)
- **Stil**: Tema seçici ile aynı

#### 2.2. Uygulama Değerlendirme Bölümü

- **Container**:
  - Padding: `16px` (tüm yönler)
  - Gradient arka plan: `primaryContainer` → `secondaryContainer`
  - Border radius: `20px`
  - Border: `primary` %15, 1.5px
  - Gölge: Yumuşak
- **İçerik**:
  - Sol: İkon container (48x48px)
    - Gradient: `primary` → `secondary`
    - İkon: `star_rounded` (Android) veya `star_fill` (iOS), 24px, beyaz
  - Orta: Metin
    - Başlık: "Rate this app" (lokalize), `titleMedium`, `w800`
    - Açıklama: "Help us with a quick review" (lokalize), `bodySmall`
  - Sağ: Ok ikonu (`arrow_forward_ios_rounded`, 16px)
- **Fonksiyon**: Tıklanınca App Store/Play Store'a yönlendirir

#### 2.3. Premium Bölümü

**Premium Olmayan Kullanıcı:**

- **Container**:
  - Padding: `20px` (tüm yönler)
  - Gradient arka plan: `surfaceContainerHighest` → `primaryContainer`
  - Border radius: `24px`
  - Border: `primary` %20, 1.5px
  - Gölge: Yumuşak, çok katmanlı
- **İçerik**:
  - **Üst Satır**: İkon + Başlık + Açıklama
    - İkon: `workspace_premium_rounded`, 56x56px, gradient daire
    - Başlık: "Go Premium" (lokalize), `headlineSmall`, `w900`
    - Açıklama: Premium açıklaması (lokalize), `bodyMedium`
  - **Özellik Pills**: 3 adet (yan yana, wrap)
    1. "Unlimited" (`all_inclusive_rounded`)
    2. "Ad Free" (`block_rounded`)
    3. "Priority" (`verified_rounded`)
  - **Buton**: "Upgrade to Premium" (lokalize)
    - Stil: Filled button, primary renk, tam genişlik
- **Fonksiyon**: Tıklanınca `/paywall` sayfasına gider

**Premium Kullanıcı:**

- **Container**:
  - Padding: `20px` (tüm yönler)
  - Arka plan: `surface`
  - Border radius: `20px`
  - Border: `primary` %15, 1.5px
  - Gölge: Yumuşak
- **İçerik**:
  - **Üst Satır**: İkon + Başlık + Status
    - İkon: `workspace_premium_rounded`, 48x48px, gradient kare
    - Başlık: "You are Premium" (lokalize), `titleLarge`, `w800`
    - Status: `check_circle_rounded` + "Active" (lokalize), success rengi
  - **Divider**: İnce, `outline` %10
  - **Özellikler Listesi**: 3 satır
    1. "Unlimited" (`all_inclusive_rounded`)
    2. "Ad Free" (`block_rounded`)
    3. "Priority" (`verified_rounded`)
    - Her satır: İkon container + Metin + Check ikonu
  - **Bilgi Notu**:
    - Container: `primaryContainer` %40, 12px radius
    - İkon: `auto_awesome_rounded`
    - Metin: "Lifetime access to all premium features" (lokalize)

#### 2.4. Versiyon Bilgisi

- **Konum**: Ekranın en altında
- **Metin**: "v1.0.0"
- **Stil**: `bodySmall`, `onSurface` %50, 12px
- **Hizalama**: Ortalanmış

---

## Animasyonlar

### 1. Chip Seçimi

- **Animasyon**: 200-300ms, easeInOut
- **Efekt**: Arka plan ve border değişimi

### 2. Premium Kartı

- **Hover/Press**: Hafif scale efekti (1.02)
- **Ripple**: Material ripple efekti

### 3. Rate App Kartı

- **Hover/Press**: Hafif scale efekti
- **Ripple**: Material ripple efekti

---

## Durumlar

### 1. Normal Durum

- Tüm ayarlar görünür
- Tüm butonlar aktif
- Seçili değerler vurgulu

### 2. Premium Yükleniyor

- Premium bölümü: Shimmer skeleton veya gizli

### 3. Premium Hata

- Premium bölümü: Gizli veya hata mesajı

---

## Renk Sistemi

### Tema/Dil Kartı

- **Arka Plan**: `surfaceContainerHighest` %30
- **Seçili Chip**: `primary` %15 arka plan, `primary` border
- **Pasif Chip**: Şeffaf

### Rate App Kartı

- **Gradient**: `primaryContainer` → `secondaryContainer`
- **İkon**: `primary` → `secondary` gradient
- **Metin**: `onSurface`

### Premium Kartı (Free)

- **Gradient**: `surfaceContainerHighest` → `primaryContainer`
- **İkon**: `primary` → `accent` gradient
- **Buton**: `primary` renk

### Premium Kartı (Premium)

- **Arka Plan**: `surface`
- **İkon**: `primary` gradient
- **Status**: `success` rengi
- **Bilgi Notu**: `primaryContainer` %40

---

## Responsive Tasarım

- **Minimum Genişlik**: 320px
- **Maksimum Genişlik**: 600px (tabletler için ortalanmış)
- **Padding**: `16px` (tüm yönler)
- **Kart Genişliği**: Tam genişlik (padding ile)

---

## Erişilebilirlik

- **Ekran Okuyucu**: Tüm ayarlar ve butonlar okunabilir
- **Renk Kontrastı**: WCAG AA standartlarına uygun
- **Buton Boyutları**: Minimum 44x44px dokunma alanı
- **Chip'ler**: Kolay seçilebilir

---

## Teknik Detaylar

### Widget Yapısı

```
Scaffold
└── SafeArea
    ├── AppBar
    └── SingleChildScrollView
        └── Padding
            └── Column
                ├── Container (theme & language)
                ├── SizedBox (spacing)
                ├── _RateAppSection
                ├── SizedBox (spacing)
                ├── _PremiumSection
                ├── SizedBox (spacing)
                └── Center (version)
```

### Önemli Notlar

- `themeModeProvider` ile tema durumu yönetilir
- `localeProvider` ile dil durumu yönetilir
- `isPremiumProvider` ile premium durumu kontrol edilir
- Rate app: Platform'a göre App Store/Play Store URL'i
- Premium: `/paywall` sayfasına yönlendirme

---

## Örnek Görsel Açıklama

**Genel Görünüm:**

- Üstte AppBar
- Tema ve dil kartı (2 bölüm, divider ile)
- Rate app kartı (gradient, vurgulu)
- Premium kartı (büyük, vurgulu)
- Versiyon bilgisi (en altta, küçük)

**Premium Kartı (Free):**

- Gradient arka plan
- Büyük premium ikonu (gradient daire)
- "Go Premium" başlığı
- 3 özellik pill'i
- Büyük "Upgrade" butonu

**Premium Kartı (Premium):**

- Sade arka plan
- Premium ikonu (gradient kare)
- "You are Premium" başlığı
- "Active" badge'i (yeşil)
- 3 özellik satırı (check işaretli)
- Bilgi notu (lifetime access)

---

## Sonuç

Settings Page, kullanıcıya uygulama ayarlarını kolayca yönetme imkanı sunan, premium durumunu net bir şekilde gösteren ve uygulama değerlendirmesini teşvik eden düzenli bir ekrandır. Tüm ayarlar erişilebilir ve anlaşılır olmalıdır.








