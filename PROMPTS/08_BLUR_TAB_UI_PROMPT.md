# Blur Tab UI - Tasarım Promptu

## Genel Bakış

**Blur Tab**, kullanıcıların bulanık fotoğrafları tarayıp bulmasını ve silmesini sağlayan sekmedir. İki ana durumu vardır: tarama öncesi form ve tarama sonrası sonuçlar.

**Konum**: Swipe Page içinde, Tab Bar'da ikinci sekme  
**Ana Özellikler**:

- Bulanık fotoğraf taraması
- Sonuçların grid görünümü
- Toplu silme işlemi
- Tarama ilerleme takibi

---

## Tasarım Hedefleri

1. **Açıklayıcı**: Kullanıcıya blur detection'ın ne olduğunu net bir şekilde anlatır
2. **Görsel**: Bulanık fotoğraflar net bir şekilde gösterilir
3. **Etkileşimli**: Tarama başlatma ve sonuçları görüntüleme kolaydır
4. **Bilgilendirici**: İstatistikler ve ilerleme durumu açıkça gösterilir

---

## Layout Yapısı - Tarama Öncesi (Scan Form)

### 1. Ana Container

- **Padding**: `16px` (tüm yönler)
- **Arka Plan**: `background`
- **Scroll**: Dikey scrollable (içerik uzunsa)

### 2. Başlık ve Açıklama Bölümü

- **Başlık**: "Find Blurry Photos" (lokalize)
  - Stil: `headlineMedium`, `w800`, ortalanmış
  - Renk: `onSurface`
  - Spacing: Üstte 24px, altta 12px
- **Açıklama**: Blur detection açıklaması (lokalize)
  - Stil: `bodyLarge`, ortalanmış
  - Renk: `onSurface` %80 opaklık
  - Spacing: Başlığın 12px altında, görselin 24px üstünde

### 3. Görsel İllüstrasyon (Opsiyonel)

- **Container**: 200x200px, ortalanmış
- **Arka Plan**: `errorContainer` %30 opaklık
- **Border Radius**: `20px`
- **İçerik**:
  - Bulanık fotoğraf örneği veya blur ikonu
  - Gradient overlay (primary → secondary)
  - Uyarı badge'i (sağ üstte)

### 4. Bilgi Kartı

- **Container**:
  - Padding: `20px` (tüm yönler)
  - Arka plan: `surface`
  - Border radius: `20px`
  - Border: `outline` %10, 1px
  - Gölge: Yumuşak
- **İçerik**:
  - İkon: `info_outline` veya `blur_on`
  - Başlık: "How it works" (lokalize)
  - Açıklama: Blur detection nasıl çalışır açıklaması (lokalize)
  - Özellikler listesi (opsiyonel):
    - AI-powered detection
    - On-device processing
    - Privacy-safe

### 5. Tarama Butonu

- **Konum**: Ekranın altında, sabit (Positioned widget)
- **Buton**: `FilledButton.icon` veya özel modern buton
- **İkon**: `search_rounded` veya `blur_on`
- **Metin**: "Start Scan" veya "Scan for Blurry Photos" (lokalize)
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

- **Layout**: 2 kart, yan yana
- **Padding**: `16px` yatay, `12px` üst
- **Kart 1 - Fotoğraf Sayısı**:
  - İkon: `photo_library_rounded`, 18px
  - Değer: Bulunan bulanık fotoğraf sayısı (büyük, bold)
  - Label: "Photo" (lokalize)
  - Renk: `primary`
  - Stil: Gradient arka plan, border, gölge
- **Kart 2 - Boşaltılacak Alan**:
  - İkon: `storage_rounded`, 18px
  - Değer: MB cinsinden (büyük, bold)
  - Label: "Space to Save" (lokalize)
  - Renk: `accent`
  - Stil: Gradient arka plan, border, gölge

### 2. Fotoğraf Grid'i

- **Layout**: GridView, 2-3 sütun
- **Öğe Boyutu**: Ekran genişliğine göre (yaklaşık 150-180px)
- **İçerik**:
  - Fotoğraf thumbnail (`BoxFit.cover`)
  - Blur score badge (opsiyonel, sol üstte)
    - Stil: Küçük, yarı saydam, error rengi
    - Metin: Blur score (örn: "0.85")
- **Stil**:
  - Border radius: `12px`
  - Gölge: Hafif
  - Tıklanabilir: Detay dialog'una gider
- **Padding**: `16px` (tüm yönler)

### 3. Silme Butonu

- **Konum**: Ekranın altında, sabit
- **Buton**: `FilledButton.icon`
- **İkon**: `delete_outline`
- **Metin**: "Delete All Blurry Photos" (lokalize)
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
- **Vurgu**: `primary` ve `error` (blur için)

### Sonuçlar

- **İstatistik Kartları**:
  - Primary: `primary` gradient
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
        ├── Row (stat cards)
        └── Expanded (grid view)
└── Positioned (delete button)
```

### Önemli Notlar

- `blurDetectionProvider` ile durum yönetilir
- `isScanning` durumunda full-screen overlay gösterilir
- `hasCompletedScan` veya sonuçlar varsa results view gösterilir
- Limit kontrolü yapılır (free kullanıcılar için)

---

## Örnek Görsel Açıklama

**Scan Form:**

- Üstte büyük başlık: "Find Blurry Photos"
- Altında açıklama metni
- Ortada görsel illüstrasyon (bulanık fotoğraf örneği)
- Bilgi kartı (nasıl çalışır açıklaması)
- Altta büyük, vurgulu "Start Scan" butonu

**Results View:**

- Üstte 2 istatistik kartı (yan yana)
- Ortada grid (2-3 sütun, bulanık fotoğraflar, blur score badge'leri ile)
- Altta kırmızı "Delete All Blurry Photos" butonu

---

## Sonuç

Blur Tab, kullanıcıların bulanık fotoğrafları kolayca bulup temizlemesini sağlayan, görsel ve bilgilendirici bir sekmedir. Tarama öncesi form açıklayıcı, sonuçlar görünümü ise etkileşimli ve kullanışlı olmalıdır.








