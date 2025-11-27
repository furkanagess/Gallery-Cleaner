# Duplicate Tab UI - Tasarım Promptu

## Genel Bakış

**Duplicate Tab**, kullanıcıların kopya ve benzer fotoğrafları tarayıp bulmasını ve silmesini sağlayan sekmedir. İki ana durumu vardır: tarama öncesi form ve tarama sonrası sonuçlar.

**Konum**: Swipe Page içinde, Tab Bar'da üçüncü sekme  
**Ana Özellikler**:

- Duplicate fotoğraf taraması
- Grup bazlı sonuçlar görünümü
- Toplu silme işlemi
- Tarama ilerleme takibi

---

## Tasarım Hedefleri

1. **Açıklayıcı**: Kullanıcıya duplicate detection'ın ne olduğunu net bir şekilde anlatır
2. **Görsel**: Duplicate fotoğraflar grup halinde gösterilir
3. **Etkileşimli**: Tarama başlatma ve sonuçları görüntüleme kolaydır
4. **Bilgilendirici**: İstatistikler ve ilerleme durumu açıkça gösterilir

---

## Layout Yapısı - Tarama Öncesi (Scan Form)

### 1. Ana Container

- **Padding**: `16px` (tüm yönler)
- **Arka Plan**: `background`
- **Scroll**: Dikey scrollable (içerik uzunsa)

### 2. Başlık ve Açıklama Bölümü

- **Başlık**: "Find Duplicates" (lokalize)
  - Stil: `headlineMedium`, `w800`, ortalanmış
  - Renk: `onSurface`
  - Spacing: Üstte 24px, altta 12px
- **Açıklama**: Duplicate detection açıklaması (lokalize)
  - Stil: `bodyLarge`, ortalanmış
  - Renk: `onSurface` %80 opaklık
  - Spacing: Başlığın 12px altında, görselin 24px üstünde

### 3. Görsel İllüstrasyon (Opsiyonel)

- **Container**: 200x200px, ortalanmış
- **Arka Plan**: `tertiaryContainer` %30 opaklık
- **Border Radius**: `20px`
- **İçerik**:
  - Üst üste binen 2 fotoğraf kartı (140x140px)
  - Sağda: Link ikonu (tertiary rengi, daire içinde)
  - Alt sağda: "2x" badge'i (tertiary rengi, copy ikonu ile)
  - Gölge: Çok katmanlı, derinlik hissi

### 4. Bilgi Kartı

- **Container**:
  - Padding: `20px` (tüm yönler)
  - Arka plan: `surface`
  - Border radius: `20px`
  - Border: `outline` %10, 1px
  - Gölge: Yumuşak
- **İçerik**:
  - İkon: `content_copy` veya `collections`
  - Başlık: "How it works" (lokalize)
  - Açıklama: Duplicate detection nasıl çalışır açıklaması (lokalize)
  - Özellikler listesi (opsiyonel):
    - AI-powered similarity detection
    - On-device processing
    - Privacy-safe
    - Group-based organization

### 5. Tarama Butonu

- **Konum**: Ekranın altında, sabit (Positioned widget)
- **Buton**: `FilledButton.icon` veya özel modern buton
- **İkon**: `search_rounded` veya `content_copy`
- **Metin**: "Start Scan" veya "Scan for Duplicates" (lokalize)
- **Stil**:
  - Genişlik: Tam genişlik (padding ile)
  - Yükseklik: `56px`
  - Padding: `16px` dikey
  - Arka plan: `primary` gradient veya solid
  - Border: `primary` %90, 1.5px
  - Gölge: Yumuşak, pulse efekti (opsiyonel)
- **Durumlar**:
  - Normal: Aktif, tıklanabilir
  - Loading: Devre dışı, loading indicator
  - Error: Kırmızı border, hata mesajı

---

## Layout Yapısı - Tarama Sonrası (Results View)

### 1. İstatistik Kartları

- **Layout**: 3 kart, yan yana
- **Padding**: `16px` yatay, `12px` üst
- **Kart 1 - Grup Sayısı**:
  - İkon: `collections_rounded`, 18px
  - Değer: Duplicate grup sayısı (büyük, bold)
  - Label: "Group" (lokalize)
  - Renk: `secondary`
  - Stil: Gradient arka plan, border, gölge
- **Kart 2 - Fotoğraf Sayısı**:
  - İkon: `photo_library_rounded`, 18px
  - Değer: Toplam duplicate fotoğraf sayısı (büyük, bold)
  - Label: "Photo" (lokalize)
  - Renk: `primary`
  - Stil: Gradient arka plan, border, gölge
- **Kart 3 - Boşaltılacak Alan**:
  - İkon: `storage_rounded`, 18px
  - Değer: MB cinsinden (büyük, bold)
  - Label: "Space to Save" (lokalize)
  - Renk: `accent`
  - Stil: Gradient arka plan, border, gölge

### 2. Duplicate Grid'i

- **Layout**: GridView, 2-3 sütun
- **Öğe Boyutu**: Ekran genişliğine göre (yaklaşık 150-180px)
- **İçerik**:
  - Fotoğraf thumbnail (`BoxFit.cover`)
  - Grup numarası badge (opsiyonel, sol üstte)
    - Stil: Küçük, yarı saydam, secondary rengi
    - Metin: Grup numarası (örn: "Group 1")
  - Seçim checkbox (opsiyonel, toplu silme için)
- **Stil**:
  - Border radius: `12px`
  - Gölge: Hafif
  - Tıklanabilir: Detay sayfasına gider (opsiyonel)
- **Padding**: `16px` (tüm yönler)

### 3. Silme Butonu

- **Konum**: Ekranın altında, sabit
- **Buton**: `FilledButton.icon`
- **İkon**: `delete_outline`
- **Metin**: "Delete All Duplicates" (lokalize)
- **Stil**:
  - Genişlik: Tam genişlik
  - Yükseklik: `56px`
  - Padding: `16px` dikey
  - Arka plan: `error` %85 opaklık
  - Border: `error` %90, 1.5px
  - Renk: `onError`
- **Fonksiyon**:
  - Tıklanınca onay dialog'u gösterir
  - Onaylandığında toplu silme yapar
  - Başarı dialog'u gösterir

---

## Durumlar

### 1. Tarama Öncesi (Scan Form)

- Başlık ve açıklama görünür
- Görsel illüstrasyon görünür
- Bilgi kartı görünür
- Tarama butonu aktif

### 2. Tarama Sırasında

- Full-screen overlay gösterilir
- Lottie animasyonu oynatılır
- Progress card görünür
- Uyarı mesajı görünür
- Stop butonu görünür
- (Detaylar için Scan Progress UI Prompt'a bakın)

### 3. Sonuçlar Var

- İstatistik kartları görünür
- Grid dolu
- Silme butonu aktif

### 4. Sonuç Yok

- İstatistik kartları gizli
- Grid yerine boş durum mesajı
- "Start New Scan" butonu

---

## Renk Sistemi

### Tarama Öncesi

- **Arka Plan**: `background`
- **Kartlar**: `surface`
- **Vurgu**: `primary` ve `tertiary` (duplicate için)

### Sonuçlar

- **İstatistik Kartları**:
  - Groups: `secondary` gradient
  - Photos: `primary` gradient
  - Space: `accent` gradient
- **Grid**: Normal fotoğraf görünümü
- **Silme Butonu**: `error` (kırmızı)

---

## Animasyonlar

### 1. Tarama Butonu

- **Hover/Press**: Hafif scale efekti (1.02)
- **Pulse**: Sürekli pulse animasyonu (opsiyonel, dikkat çekmek için)
- **Ripple**: Material ripple efekti

### 2. Grid Yükleme

- **Fade In**: Her öğe sırayla görünür
- **Scale**: 0.95'ten 1.0'a scale animasyonu

### 3. Silme İşlemi

- **Progress**: Loading indicator
- **Başarı**: Success dialog

---

## Responsive Tasarım

- **Minimum Genişlik**: 320px
- **Maksimum Genişlik**: 600px (tabletler için ortalanmış)
- **Grid Sütun Sayısı**:
  - Küçük ekran: 2 sütun
  - Büyük ekran: 3 sütun
- **Padding**: `16px` (ekran boyutuna göre)

---

## Erişilebilirlik

- **Ekran Okuyucu**: Tüm metinler ve butonlar okunabilir
- **Renk Kontrastı**: WCAG AA standartlarına uygun
- **Buton Boyutları**: Minimum 44x44px dokunma alanı
- **Grid**: Klavye ile erişilebilir

---

## Teknik Detaylar

### Widget Yapısı - Scan Form

```
Stack
└── Padding
    └── Column
        ├── Text (title)
        ├── Text (description)
        ├── Container (illustration - optional)
        ├── Container (info card)
        └── Spacer
└── Positioned (scan button)
```

### Widget Yapısı - Results View

```
Stack
└── Padding
    └── Column
        ├── Row (stat cards - 3 cards)
        └── Expanded (grid view)
└── Positioned (delete button)
```

### Önemli Notlar

- `duplicateDetectionProvider` ile durum yönetilir
- `isScanning` durumunda full-screen overlay gösterilir
- `hasCompletedScan` veya sonuçlar varsa results view gösterilir
- Limit kontrolü yapılır (free kullanıcılar için)
- Grup bazlı organizasyon kullanılır

---

## Örnek Görsel Açıklama

**Scan Form:**

- Üstte büyük başlık: "Find Duplicates"
- Altında açıklama metni
- Ortada görsel illüstrasyon (üst üste binen fotoğraflar, link ikonu, "2x" badge)
- Bilgi kartı (nasıl çalışır açıklaması)
- Altta büyük, vurgulu "Start Scan" butonu

**Results View:**

- Üstte 3 istatistik kartı (yan yana)
- Ortada grid (2-3 sütun, duplicate fotoğraflar, grup numaraları ile)
- Altta kırmızı "Delete All Duplicates" butonu

---

## Sonuç

Duplicate Tab, kullanıcıların kopya ve benzer fotoğrafları kolayca bulup temizlemesini sağlayan, görsel ve bilgilendirici bir sekmedir. Tarama öncesi form açıklayıcı, sonuçlar görünümü ise etkileşimli ve kullanışlı olmalıdır.
