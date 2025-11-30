# Results Page - Tasarım Promptu

## Genel Bakış

**Results Page**, blur veya duplicate detection taraması sonrasında bulunan fotoğrafları gösteren ve toplu silme işlemi yapılabilen ekrandır. İki farklı tip için aynı sayfa kullanılır: blur ve duplicate.

**Yol (Route)**: `/results/:type` (type: 'blur' veya 'duplicate')  
**Ana Özellikler**:

- Bulunan fotoğrafların grid görünümü
- İstatistik kartları (sayı, boyut)
- Toplu silme butonu
- Boş durum mesajı

---

## Tasarım Hedefleri

1. **Görsel**: Fotoğraflar net ve büyük görünmeli
2. **Bilgilendirici**: İstatistikler açıkça gösterilmeli
3. **Etkileşimli**: Toplu silme kolay olmalı
4. **Güvenli**: Silme işlemi onay gerektirmeli

---

## Layout Yapısı

### 1. AppBar

- **Geri Butonu**: Sol tarafta, `arrow_back_rounded` ikonu
- **Başlık**:
  - Blur: "Blurry Photos" (lokalize)
  - Duplicate: "Duplicates" (lokalize)
- **Stil**: `titleLarge`, `w800`

### 2. İstatistik Kartları

#### Blur Results için:

- **Layout**: 2 kart, yan yana
  1. **Fotoğraf Sayısı**:
     - İkon: `photo_library_rounded`
     - Değer: Bulunan bulanık fotoğraf sayısı
     - Label: "Photo" (lokalize)
     - Renk: `primary`
  2. **Boşaltılacak Alan**:
     - İkon: `storage_rounded`
     - Değer: MB cinsinden
     - Label: "Space to Save" (lokalize)
     - Renk: `accent`

#### Duplicate Results için:

- **Layout**: 3 kart, yan yana
  1. **Grup Sayısı**:
     - İkon: `collections_rounded`
     - Değer: Duplicate grup sayısı
     - Label: "Group" (lokalize)
     - Renk: `secondary`
  2. **Fotoğraf Sayısı**:
     - İkon: `photo_library_rounded`
     - Değer: Toplam duplicate fotoğraf sayısı
     - Label: "Photo" (lokalize)
     - Renk: `primary`
  3. **Boşaltılacak Alan**:
     - İkon: `storage_rounded`
     - Değer: MB cinsinden
     - Label: "Space to Save" (lokalize)
     - Renk: `accent`

**Kart Stili**:

- Padding: `14-16px` (yatay ve dikey)
- Border radius: `16-20px`
- Gradient arka plan (accent rengine göre)
- Border: Accent rengi, düşük opaklık
- Gölge: Yumuşak, çok katmanlı
- İçerik: İkon (container içinde) + Değer + Label

### 3. Fotoğraf Grid'i

#### Blur Grid:

- **Layout**: GridView, 2-3 sütun
- **Öğe Boyutu**: Ekran genişliğine göre (yaklaşık 150-180px)
- **İçerik**:
  - Fotoğraf thumbnail
  - Blur score badge (opsiyonel, sol üstte)
- **Stil**:
  - Border radius: `12px`
  - Gölge: Hafif
  - Tıklanabilir: Detay sayfasına gider (opsiyonel)

#### Duplicate Grid:

- **Layout**: GridView, 2-3 sütun
- **Öğe Boyutu**: Ekran genişliğine göre (yaklaşık 150-180px)
- **İçerik**:
  - Fotoğraf thumbnail
  - Grup numarası badge (opsiyonel)
  - Seçim checkbox (opsiyonel, toplu silme için)
- **Stil**:
  - Border radius: `12px`
  - Gölge: Hafif
  - Tıklanabilir: Detay sayfasına gider (opsiyonel)

### 4. Silme Butonu

- **Konum**: Ekranın altında, sabit
- **Buton**: `FilledButton.icon`
- **İkon**: `delete_outline`
- **Metin**:
  - Blur: "Delete All Blurry Photos" (lokalize)
  - Duplicate: "Delete All Duplicates" (lokalize)
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

### 5. Boş Durum

#### Blur için:

- **İkon**: `image_not_supported_rounded`, 64px
- **Başlık**: "No Blurry Photos Found" (lokalize)
- **Açıklama**:
  - "Scan completed successfully" (lokalize)
  - "Your gallery looks sharp. Great job!" (lokalize)
- **Buton**: "Start New Scan" (lokalize)

#### Duplicate için:

- **İkon**: `collections_rounded`, 64px
- **Başlık**: "No Duplicates Found" (lokalize)
- **Açıklama**:
  - "Scan completed successfully" (lokalize)
  - "Your gallery is already tidy." (lokalize)
- **Buton**: "Start New Scan" (lokalize)

**Boş Durum Stili**:

- Container: 200x200px, gradient arka plan
- Border radius: `32px`
- Gölge: Yumuşak, çok katmanlı
- İkon: Dairesel container içinde
- Metin: Ortalanmış, büyük font
- Buton: Primary gradient, büyük

---

## Animasyonlar

### 1. Grid Yükleme

- **Fade In**: Her öğe sırayla görünür
- **Scale**: 0.95'ten 1.0'a scale animasyonu

### 2. Silme İşlemi

- **Progress**: Loading indicator
- **Başarı**: Success dialog (confetti animasyonu, opsiyonel)

### 3. Boş Durum Geçişi

- **Fade In**: Yumuşak geçiş
- **Scale**: Hafif scale efekti

---

## Durumlar

### 1. Loading Durumu

- **Grid**: Shimmer skeleton
- **İstatistikler**: Shimmer skeleton
- **Buton**: Devre dışı

### 2. Sonuçlar Var

- İstatistikler görünür
- Grid dolu
- Silme butonu aktif

### 3. Boş Durum

- İstatistikler gizli
- Grid yerine boş durum mesajı
- "Start New Scan" butonu

### 4. Silme İşlemi

- Buton: Loading indicator
- Grid: Devre dışı
- Progress: Gösterilir

---

## Renk Sistemi

### İstatistik Kartları

- **Blur**: Primary ve accent renkleri
- **Duplicate**: Secondary, primary ve accent renkleri
- **Gradient**: Accent rengine göre, düşük opaklık

### Silme Butonu

- **Arka Plan**: Error (kırmızı) %85
- **Border**: Error %90
- **Metin**: OnError (beyaz)

### Boş Durum

- **Blur**: Primary renk tonları
- **Duplicate**: Secondary renk tonları
- **Gradient**: Yumuşak, düşük opaklık

---

## Responsive Tasarım

- **Minimum Genişlik**: 320px
- **Maksimum Genişlik**: 600px (tabletler için ortalanmış)
- **Grid Sütun Sayısı**:
  - Küçük ekran: 2 sütun
  - Büyük ekran: 3 sütun
- **Kart Genişliği**: Responsive, eşit genişlik

---

## Erişilebilirlik

- **Ekran Okuyucu**: Tüm istatistikler ve butonlar okunabilir
- **Renk Kontrastı**: WCAG AA standartlarına uygun
- **Buton Boyutları**: Minimum 44x44px dokunma alanı
- **Grid**: Klavye ile erişilebilir

---

## Teknik Detaylar

### Widget Yapısı

```
Scaffold
└── Column
    ├── AppBar
    ├── Padding (stats cards)
    │   └── Row
    │       └── Expanded (stat cards)
    ├── Expanded (grid view)
    └── Container (delete button)
        └── SafeArea
            └── FilledButton
```

### Önemli Notlar

- `resultType` parametresi ile blur/duplicate ayrımı yapılır
- `blurDetectionProvider` ve `duplicateDetectionProvider` kullanılır
- Silme işlemi onay dialog'u ile korunur
- Başarı dialog'u `showDeleteSuccessDialog` ile gösterilir
- Limit kontrolü yapılır (free kullanıcılar için)

---

## Örnek Görsel Açıklama

**Blur Results:**

- Üstte 2 istatistik kartı (yan yana)
- Ortada grid (2-3 sütun, bulanık fotoğraflar)
- Altta kırmızı "Delete All Blurry Photos" butonu

**Duplicate Results:**

- Üstte 3 istatistik kartı (yan yana)
- Ortada grid (2-3 sütun, duplicate fotoğraflar, grup numaraları ile)
- Altta kırmızı "Delete All Duplicates" butonu

**Boş Durum:**

- Ortada büyük ikon (200x200px container içinde)
- Altında başlık ve açıklama
- En altta "Start New Scan" butonu

---

## Sonuç

Results Page, tarama sonuçlarını görsel ve düzenli bir şekilde sunan, toplu silme işlemini kolaylaştıran ve kullanıcıyı bilgilendiren bir ekrandır. Tüm işlemler güvenli ve onaylı olmalıdır.


