# Swipe Page - Tasarım Promptu

## Genel Bakış

**Swipe Page**, uygulamanın ana ekranıdır. Kullanıcılar burada fotoğrafları swipe ederek tutma veya silme kararı verir. Ayrıca blur ve duplicate detection sekmeleri de bu sayfada bulunur.

**Yol (Route)**: `/swipe`  
**Sekmeler**: 3 adet (Swipe, Blur, Duplicate)  
**Ana Özellik**: Tinder tarzı swipe mekanizması

---

## Tasarım Hedefleri

1. **Hızlı Karar**: Kullanıcı fotoğrafları hızlıca değerlendirebilmeli
2. **Görsel Odak**: Fotoğraf net ve büyük görünmeli
3. **Sezgisel**: Swipe hareketleri doğal ve akıcı olmalı
4. **Bilgilendirici**: Kullanıcı durumu her zaman bilmeli (limit, albüm, vb.)

---

## Layout Yapısı

### 1. AppBar

#### 1.1. Başlık

- **Metin**: Uygulama adı (lokalize)
- **Hizalama**: Ortalanmış
- **Stil**: `titleLarge`, `w800`

#### 1.2. Tab Bar

- **Sekmeler**: 3 adet
  1. **Swipe Tab**: `swipe_rounded` ikonu + "Swipe" metni
  2. **Blur Tab**: Blur detection indicator (özel widget)
  3. **Duplicate Tab**: Duplicate detection indicator (özel widget)
- **Stil**:
  - Yükseklik: `56px`
  - Seçili: `primary` rengi, `w700`, `13px`
  - Seçili değil: `onSurface` %60, `w500`, `13px`
  - Letter spacing: `0.3` (seçili), `0.2` (seçili değil)

#### 1.3. Actions

- **History Button**:
  - Pulse animasyonu ile
  - Scan sırasında devre dışı
- **Settings Button**:
  - `settings` ikonu
  - Scan sırasında devre dışı (gri, tooltip ile uyarı)

### 2. Swipe Tab İçeriği

#### 2.1. Üst Bilgi Çubuğu (Status Card)

- **Layout**: Yatay satır
- **Sol Taraf**: Silme hakkı göstergesi
  - Free kullanıcı: "X deletes left today" + progress bar
  - Premium kullanıcı: "Unlimited" badge
- **Sağ Taraf**: Albüm seçici
  - Aktif albüm adı
  - "Change Album" butonu/chip
  - Tıklanınca bottom sheet açılır
- **Stil**:
  - Yükseklik: `48-56px`
  - Arka plan: `surfaceContainerHighest`
  - Border radius: `16-20px`
  - Padding: `12-16px` yatay
  - Gölge: Hafif, yumuşak

#### 2.2. Ana Fotoğraf Kartı Alanı

- **Kart Boyutu**:
  - Genişlik: Maksimum `480px`
  - Oran: `3:4` (dikey fotoğraf)
  - Konum: Yatayda ortalanmış, dikeyde ortada
- **Kart Stili**:
  - Border radius: `20px`
  - Gölge: Yumuşak, çok katmanlı
  - Fotoğraf: `BoxFit.cover`
- **Swipe Davranışı**:
  - **Sağ kaydırma** → Keep (yeşil overlay + check icon)
  - **Sol kaydırma** → Delete (kırmızı overlay + trash icon)
  - **Yukarı kaydırma** → Skip (opsiyonel)
  - **Rotasyon**: Sürükleme sırasında hafif rotasyon
  - **Overlay**: Sürükleme mesafesine göre görünürlük artar

#### 2.3. Swipe İpuçları

- **Konum**: Kartın hemen altında
- **İçerik**: Küçük chip'ler
  - "Swipe left to delete" (kırmızı ikon)
  - "Swipe right to keep" (yeşil ikon)
  - "Tap undo to restore" (opsiyonel)
- **Stil**: Küçük, dikkat dağıtmayan

#### 2.4. Alt Aksiyon Satırı

- **Layout**: Yatay satır
- **Sol Buton**: Delete
  - İkon: `trash`
  - Renk: `error` (kırmızı)
  - Stil: Filled veya outlined
- **Sağ Buton**: Keep
  - İkon: `check` veya `heart`
  - Renk: `primary` veya `success`
  - Stil: Filled
- **Orta Buton (Opsiyonel)**: Undo
  - İkon: `undo`
  - Stil: Tonal veya icon button
- **Stil**:
  - Genişlik: Tam genişlik (padding ile)
  - Yükseklik: `56px`
  - Border radius: `16px`
  - Padding: `16px` yatay

### 3. Blur Tab İçeriği

#### 3.1. Başlık ve Açıklama

- **Başlık**: "Find Blurry Photos" (lokalize)
- **Açıklama**: Blur detection açıklaması (lokalize)
- **Stil**: Ortalanmış, büyük font

#### 3.2. Scan Butonu

- **Buton**: Büyük, belirgin
- **Metin**: "Scan for Blurry Photos" (lokalize)
- **Stil**: Filled button, primary renk
- **Durumlar**:
  - Normal: Aktif
  - Scanning: Devre dışı, loading indicator

#### 3.3. İlerleme Göstergesi

- **Progress Bar**: Linear veya circular
- **Metin**: "Analyzing X of Y photos"
- **Lottie**: Tarama animasyonu (opsiyonel)

#### 3.4. Sonuçlar

- **Boş Durum**: "No blurry photos found" mesajı
- **Sonuçlar Varsa**: Results page'e yönlendirme butonu

### 4. Duplicate Tab İçeriği

#### 4.1. Başlık ve Açıklama

- **Başlık**: "Find Duplicates" (lokalize)
- **Açıklama**: Duplicate detection açıklaması (lokalize)
- **Stil**: Ortalanmış, büyük font

#### 4.2. Scan Butonu

- **Buton**: Büyük, belirgin
- **Metin**: "Scan for Duplicates" (lokalize)
- **Stil**: Filled button, primary renk
- **Durumlar**:
  - Normal: Aktif
  - Scanning: Devre dışı, loading indicator

#### 4.3. İlerleme Göstergesi

- **Progress Bar**: Linear veya circular
- **Metin**: "Analyzing X of Y photos"
- **Lottie**: Tarama animasyonu (opsiyonel)

#### 4.4. Sonuçlar

- **Boş Durum**: "No duplicates found" mesajı
- **Sonuçlar Varsa**: Results page'e yönlendirme butonu

---

## Animasyonlar

### 1. Swipe Animasyonu

- **Sürükleme**: Parmak hareketiyle kart takip eder
- **Rotasyon**: Sürükleme mesafesine göre rotasyon (max 15-20 derece)
- **Overlay**: Sürükleme mesafesine göre fade in/out
- **Bırakma**:
  - Eşik geçildiyse: Hızlanarak ekrandan çıkar
  - Eşik geçilmediyse: Spring animasyonu ile geri döner

### 2. Kart Geçişi

- **Yeni Kart**: Aşağıdan yukarı fade + slide
- **Eski Kart**: Yukarıdan aşağı fade + slide (silme) veya sağa kayma (keep)

### 3. Buton Animasyonları

- **Press**: Scale down (0.98)
- **Release**: Scale up (1.0)
- **Ripple**: Material ripple efekti

### 4. Loading Animasyonu

- **Shimmer**: Kart, butonlar ve status bar için
- **Lottie**: Tarama sırasında

---

## Durumlar

### 1. Normal Durum

- Fotoğraf kartı görünür
- Butonlar aktif
- Status bar güncel bilgileri gösterir

### 2. Loading Durumu

- Shimmer skeleton'lar görünür
- Butonlar devre dışı
- Status bar shimmer

### 3. Boş Durum

- "No photos to review" mesajı
- "Change album" butonu
- İllüstrasyon (opsiyonel)

### 4. Limit Aşıldı

- Uyarı mesajı
- Premium veya rewarded ad butonu
- Limit bilgisi

### 5. Tarama Durumu

- Progress bar görünür
- Butonlar devre dışı
- Settings butonu devre dışı (tooltip ile uyarı)

---

## Renk Sistemi

### Swipe Overlay'leri

- **Keep (Sağ)**: Yeşil (`success`), %60-80 opaklık
- **Delete (Sol)**: Kırmızı (`error`), %60-80 opaklık

### Butonlar

- **Keep**: Primary veya success rengi
- **Delete**: Error rengi
- **Undo**: Tonal veya secondary

### Status Bar

- **Normal**: `surfaceContainerHighest`
- **Warning**: Amber/yellow tonları
- **Premium**: Primary gradient

---

## Responsive Tasarım

- **Minimum Genişlik**: 320px
- **Maksimum Genişlik**: 600px (tabletler için ortalanmış)
- **Kart Genişliği**: Maksimum 480px, ekran genişliğine göre ölçeklenir
- **Padding**: `16-24px` (ekran boyutuna göre)

---

## Erişilebilirlik

- **Ekran Okuyucu**: Tüm butonlar ve durumlar okunabilir
- **Renk Kontrastı**: WCAG AA standartlarına uygun
- **Buton Boyutları**: Minimum 44x44px dokunma alanı
- **Swipe Gesture**: Alternatif butonlar mevcut

---

## Teknik Detaylar

### Widget Yapısı

```
Scaffold
└── SafeArea
    ├── AppBar (with TabBar)
    └── TabBarView
        ├── _SwipeTab
        │   ├── Status Card
        │   ├── Photo Swipe Deck
        │   ├── Swipe Hints
        │   └── Action Buttons
        ├── _BlurTab
        │   ├── Title & Description
        │   ├── Scan Button
        │   ├── Progress Indicator
        │   └── Results
        └── _DuplicateTab
            ├── Title & Description
            ├── Scan Button
            ├── Progress Indicator
            └── Results
```

### Önemli Notlar

- `PhotoSwipeDeck` widget'ı swipe mekanizmasını yönetir
- Swipe index'i kaydedilir (her albüm için ayrı)
- "Reset to Start" butonu görünebilir (index > 0 ise)
- History butonu pulse animasyonu ile dikkat çeker
- Scan sırasında sayfa değiştirilemez (physics: NeverScrollableScrollPhysics)

---

## Örnek Görsel Açıklama

**Swipe Tab:**

- Üstte status bar (limit + albüm)
- Ortada büyük fotoğraf kartı
- Kartın altında küçük ipuçları
- Altta 2-3 buton (Delete, Keep, Undo)

**Blur/Duplicate Tab:**

- Üstte başlık ve açıklama
- Ortada büyük scan butonu
- Tarama sırasında progress bar
- Sonuçlar varsa yönlendirme butonu

---

## Sonuç

Swipe Page, uygulamanın kalbi olan, kullanıcıların fotoğrafları hızlıca değerlendirdiği ana ekrandır. Swipe mekanizması akıcı ve sezgisel olmalı, kullanıcı her zaman durumu bilmeli ve hızlı karar verebilmelidir.


