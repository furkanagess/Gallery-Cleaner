## Gallery Cleaner – Stitch Tasarım Promptu

Bu doküman, **Gallery Cleaner** uygulaması için Stitch / UI tasarım modellerine verilecek **tek parça, kapsamlı ve profesyonel bir prompt** içerir. Aşağıdaki metni olduğu gibi Stitch’e verebilir veya ihtiyacına göre parçalar halinde kullanabilirsin.

---

### 1. Kısa Özet (High-level brief)

Design a mobile app called **“Gallery Cleaner”**.  
The app helps users **clean up their photo gallery** fast, safely, and intelligently by:

- Letting users **swipe photos** to decide whether to **keep** or **delete** them (Tinder-style card deck).
- Automatically finding **blurry photos** and showing them in a dedicated cleaning flow.
- Automatically finding **duplicate / very similar photos** and suggesting which ones to delete.
- Offering a **premium plan** with unlimited cleaning, no ads, and a more “pro” experience.

The design should target **both iOS and Android** with a modern, cross-platform look (Material 3 + iOS polish).  
The overall feeling: **trustworthy, clean, minimal, “smart”, and slightly playful**.

---

### 2. Genel Görsel Stil & Tasarım Dili

#### 2.1. Look & feel

- **Modern, clean, and premium**; feels like a featured App Store / Play Store app.
- Combine **Material 3 structure** (elevated surfaces, shape system) with **iOS clarity** (crisp typography, clean navigation).
- Use **rounded corners** generously (16–24 px on cards, 20+ px on bottom sheets).
- Favor **soft shadows**, subtle gradients, and occasional blurred surfaces instead of flat, harsh shapes.
- No heavy skeuomorphism; keep shapes and shadows **light and airy**.

#### 2.2. Renk Paleti

- Support **light and dark theme**.
- **Primary color**: a confident but friendly tone (blue/teal or purple) that suggests “smart technology” and “trust”.
- **Background**:
  - Use layered surfaces like `background`, `surface`, `surfaceVariant`, `surfaceContainerHighest`.
  - Distinguish elevations subtly with different shades and slight shadows.
- **Accents**:
  - Green for “keep/success”.
  - Red for “delete/danger”.
  - Yellow/amber for “warnings” (e.g., nearing delete limit).

#### 2.3. Tipografi

- A **clean, sans-serif** font with good legibility (SF Pro / Roboto / Inter-like).
- Clear hierarchy:
  - **Title / Headline**: used for screen titles and primary messaging.
  - **Subtitle**: short explanations under titles.
  - **Body**: main descriptive text.
  - **Caption / Label**: smaller labels for pills, chips, badges.
- Slightly **tighter letter-spacing** for main titles to feel premium, but keep body text very readable.

#### 2.4. Komponent Tarzı

- **Cards**:
  - Rounded corners (16–24 px).
  - Soft border (1 px, low-opacity outline) and lightweight drop shadow.
  - Used for summary boxes, settings sections, premium info, scan descriptions.
- **Chips / Pills**:
  - Rounded, compact.
  - Used for small filters, tips, badges (e.g., “Swipe left to delete”).
- **Buttons**:
  - Primary buttons: filled with primary color, full-width when needed.
  - Secondary buttons: outlined or tonal with subtle emphasis.
  - Icons + labels when possible to increase clarity.
- **Bottom Sheets**:
  - High-radius top corners (20–28 px).
  - Drag handle at top (small rounded bar).
  - Scrollable lists with clean dividers and clear selection state.

#### 2.5. Motion & Feedback

- Smooth, **subtle animations**; no aggressive or distracting movements.
- **Swipe card movement**:
  - Card rotates slightly with drag.
  - Keep/Delete indicators fade in proportionally to drag distance.
- **Buttons**:
  - Slight scale-up (e.g., 1.02) and shadow increase on press.
- **Shimmer**:
  - Used as skeleton loading UI for main swipe card, buttons, and sections.
  - Colors adapt to light/dark mode with low-contrast, soft gradients.

---

### 3. Navigasyon & Bilgi Mimarisi

Tasarlanması gereken ana alanlar:

1. **Main Swipe Screen (Home, `/swipe`)** – tek tek fotoğraf üzerinden karar verilen ana ekran.
2. **Scan Tabs (Blur & Duplicates)** – bulanık ve kopya fotoğraflar için tarama sekmeleri.
3. **Scan Results & Cleaning Summary** – işlem sonrası özet ve history.
4. **Settings Screen** – tema, dil, değerlendirme, premium durumu.
5. **Premium Paywall Screen** – satın alma / yükseltme ekranı.
6. **Dialogs & Bottom Sheets** – albüm seçici, onay diyalogları, premium başarı vs.

Navigasyon yapısı:

- Uygulama açılışında kullanıcı çoğunlukla **Swipe Screen**’e gelir (ana deneyim).
- Scan deneyimi, Swipe deneyiminden veya menüden erişilebilen ayrı bir sekme/ekran olabilir.
- Settings, genellikle bir ikon veya menüden ulaşılabilen ayrı bir route olarak konumlanır.

---

### 4. Main Swipe Screen – Çekirdek Deneyim

Bu ekran, kullanıcıların **fotoğrafları hızlıca temizlediği** kalp noktasıdır.

#### 4.1. Üst Bilgi Çubuğu / Status Card

- Ekranın üst kısmında, yatay bir **bilgi kartı**:
  - Sol tarafta:
    - Kullanıcının **günlük/oturumluk silme hakkı** (özellikle free kullanıcı için).
    - Örnek: “15 deletes left today”, bir progress göstergesi veya küçük badge ile.
  - Sağ tarafta:
    - **Aktif albüm adı** ve **“Change album”** tetikleyicisi (chip, buton veya küçük bir satır).
    - Tıklandığında **bottom sheet albüm seçici** açılır.
- Görünüm:
  - Yükseklik: yaklaşık 48–56 px.
  - Arka plan: `surfaceContainerHighest` veya benzeri, hafif gölgeli.
  - Köşeler: yuvarlatılmış (16–20 px).

#### 4.2. Ana Fotoğraf Kartı Alanı

- Ekranın ortasında, **tek bir fotoğraf kartı**:
  - Oran: yaklaşık `3:4` (dikey fotoğraf kartı).
  - Konum: yatayda ortalanmış, maksimum genişlik ~480 px, dikeyde ortada.
  - Kartın üzerinde:
    - Fotoğrafın kendisi.
    - Hafif yuvarlatılmış kenarlar (~20 px).
    - Subtle shadow.
- **Swipe davranışı**:
  - Sağ kaydırma → **Keep** (yeşil tonlu overlay + check icon).
  - Sol kaydırma → **Delete** (kırmızı tonlu overlay + trash icon).
  - Opsiyonel: yukarı kaydırma → “Skip” veya “Favorite”.
  - Kart sürüklenirken:
    - Hafif rotate efekt.
    - Şeffaf overlayler (Keep/Delete) sürükleme mesafesine göre görünürlüğünü artırır.

#### 4.3. Swipe İpuçları Satırı

- Kartın hemen altında, **küçük chip tipi** öğeler:
  - “Swipe left to delete” – kırmızı ikonlu küçük chip.
  - “Swipe right to keep” – yeşil ikonlu küçük chip.
  - Opsiyonel üçüncü chip: “Tap undo to restore last photo”.
- Amaç:
  - İlk defa gelen kullanıcı için davranışları netleştirmek.
  - Sonradan bu satır hafifçe küçültülebilir veya daha az belirgin hale getirilebilir.

#### 4.4. Alt Aksiyon Satırı

- Ekranın alt kısmında, genişçe bir aksiyon barı:
  - **Sol buton**: Delete
    - İkon: trash.
    - Renk: danger (kırmızı varyant), ton olarak background ile uyumlu.
  - **Sağ buton**: Keep
    - İkon: check / heart.
    - Renk: primary.
  - **Orta küçük buton (opsiyonel)**: Undo
    - İkon: undo arrow.
    - Tonal buton veya ikon butonu olarak.
- Tüm butonlar:
  - Büyük enough hit-area.
  - Kısa, net label’lar.

#### 4.5. Yükleme & Shimmer Durumu

- Fotoğraflar veya istatistikler yüklenirken:
  - Üstteki status bar, swipe kartı ve alt aksiyonlar için **shimmer skeleton** kullan.
  - Bileşen şekilleri:
    - Üst bilgi çubuğu → geniş yatay shimmer blok.
    - Ana foto bölgesi → büyük dikdörtgen shimmer.
    - Swipe ipuçları → 2–3 küçük dikdörtgen shimmer.
    - Alt butonlar → iki geniş dikdörtgen shimmer.
- Renk:
  - Light mode’da: açık gri, hafif gradient highlight.
  - Dark mode’da: koyu ama kontrastı düşük, göz yormayan tonlar.

#### 4.6. Albüm Değiştirme Etkileşimi

- Status kartının sağında veya swipe alanına yakın bir yerde:
  - “Album: [Album Name]” chip’i ya da küçük bir “Change Album” butonu.
  - Tıklandığında **bottom sheet**:
    - Başlık: “Select album to view”.
    - Üstte handle bar.
    - Albüm listesi:
      - Her satırda ikon (kutu/folder), albüm adı, opsiyonel foto sayısı.
      - Seçili albüm için sağda check işareti.

---

### 5. Blur & Duplicate Scan Ekranları

Swipe deneyiminin yanı sıra, kullanıcılar **bulanık** ve **kopya** fotoğrafları tarayan özel sekmelere sahiptir.

#### 5.1. Genel Yerleşim

- Ekranın üstünde bir **segmented control / tab bar**:
  - “Blurry Photos”
  - “Duplicates”
- Altında her sekme için:
  - Başlık.
  - Kısa açıklama.
  - Büyük, belirgin bir **Scan / Start Scan** butonu.
  - Tahmini süre veya etki bilgisi (ör. “~2–3 minutes for 5,000 photos”).
  - Uyarı / açıklama kartı (örn. “You will always confirm deletions before they happen”).

#### 5.2. Blur Scan Tab

- Görsel tema:
  - Lens, netlik, bulanıklık metaforları.
  - Bulanık bir fotoğrafın netleştiği illüstrasyon.
- İçerik:
  - Title: “Find blurry photos”.
  - Description: “We scan your gallery to detect out-of-focus photos so you can remove them with one swipe.”
  - CTA: “Scan for blurry photos”.

#### 5.3. Duplicate Scan Tab

- Görsel tema:
  - Üst üste binen fotoğraflar, çoğaltılmış kareler.
  - Hafif çakışan iki fotoğraf kartı, üzerinde check iconu.
- İçerik:
  - Title: “Find duplicates”.
  - Description: “We search for duplicate and very similar photos so you can keep the best ones.”
  - CTA: “Scan for duplicates”.

#### 5.4. Tarama İlerleme Durumu

- Tarama başladıktan sonra:
  - Üstte bir progress bar veya dairesel indicator.
  - Metin: “Analyzing X of Y photos”.
  - Lottie tarzı animasyon:
    - Örneğin, dönen lens veya taranan fotoğraf akışı.
  - Ana CTA devre dışı:
    - Label “Scanning…” ve hafif loading indicator.

#### 5.5. Sonuç / Boş Durumlar

- **Hiç bulanık foto yoksa**:
  - Başlık: “No blurry photos found”.
  - Destek metni: “Your gallery looks sharp. Great job!”.
  - İllüstrasyon: net ve mutlu bir fotoğraf veya kamera.
- **Hiç kopya yoksa**:
  - Başlık: “No duplicates found”.
  - Destek metni: “Your gallery is already tidy.”.
  - İllüstrasyon: düzenli bir fotoğraf ızgarası metaforu.

---

### 6. Sonuç Ekranları & History

Tarama veya yoğun temizleme işlemleri sonrası, kullanıcıya **ne kazandığını** gösteren bir özet alanı tasarla.

#### 6.1. Özet Kartı

- İçerik:
  - **Deleted photos** sayısı.
  - **Space freed** (MB / GB).
  - **Kept photos** sayısı.
- Görsel:
  - Trash icon → silinenler.
  - Cloud / drive icon → boşalan alan.
  - Check icon → tutulanlar.
- Yerleşim:
  - Tek büyük kart içinde 2–3 kolon veya satır olarak.
  - Card’ın altında küçük bir “View history” butonu veya linki.

#### 6.2. History Görünümü (Opsiyonel)

- Son temizlik oturumları listesi:
  - Her satır:
    - Tarih-saat.
    - “X photos deleted, Y kept”.
    - İşlemin tipi (Manual / Blur / Duplicate).
    - Opsiyonel: ilgili albüm adı.
  - Sağda chevron (›) ile detay sayfasına geçiş hissi.

---

### 7. Settings Ekranı

Settings ekranı, **tema, dil, değerlendirme ve premium durumunu** net ve modern bir kart yapısıyla sunar.

#### 7.1. AppBar

- Title: “Settings”.
- Ortalanmış başlık.
- iOS’ta:
  - Solda `chevron_left` tarzı back butonu.
  - Navigasyon stack’ine bağlı olarak geri gider veya `/swipe`’e döner.
- Android’de:
  - Varsayılan back arrow kullanımı kabul edilebilir.

#### 7.2. Tema & Dil Kartı

- Tek bir büyük kart içerisinde **iki satır**:
  - Satır 1: Theme
    - İkon: palette.
    - Label: “Theme”.
    - Altında:
      - 3 seçenekli compact selector:
        - “System”
        - “Light”
        - “Dark”
      - Segment kontrol veya üçlü pill grubu.
  - Satır 2: Language
    - İkon: language globe.
    - Label: “Language”.
    - Altında:
      - Desteklenen diller için küçük pill veya dropdown (örn. English, Türkçe vs.).
- Kart stili:
  - Arka plan: `surfaceContainerHighest` benzeri, hafif opak.
  - Kenarlar: 20 px radius, hafif border ve ince shadow.

#### 7.3. Rate App Bölümü

- Ayrı bir kart veya list-style tile:
  - İkon: star.
  - Title: “Rate this app”.
  - Subtitle: “Help us with a quick review”.
  - Sağda küçük bir chevron veya dış link göstergesi.

#### 7.4. Premium Bölümü

İki farklı duruma göre tasarla:

1. **Premium olmayan kullanıcı**:
   - Gradient arka plan (surface + primaryContainer harmanı).
   - Büyük premium icon (crown veya workspace_premium).
   - Title: “Go Premium”.
   - Kısa açıklama satırı.
   - Madde madde faydalar:
     - Unlimited cleaning.
     - No ads.
     - Priority detection.
   - Tüm kart bir **büyük CTA** gibi çalışır:
     - Tıklandığında paywall ekranına gider.

2. **Premium kullanıcı**:
   - Daha sade, beyaz/surface kart.
   - Premium icon gradient arka planlı küçük bir karede.
   - Title: “You are Premium”.
   - Yanında veya altında “Active” badge’i (yeşil check iconlu).
   - 2–3 satırlık feature list (icon + kısa label).
   - En altta küçük bir bilgi notu:
     - “Lifetime access to all premium features” gibi güven verici bir cümle.

#### 7.5. Footer – Versiyon

- Ekranın en altında, ortalanmış:
  - “v1.0.0” gibi versiyon bilgisi.
  - Renk olarak `onSurface`’un düşük opaklık versiyonu.

---

### 8. Premium Paywall & Başarı Diyalogları

#### 8.1. Premium Paywall Ekranı

- **Hero Alanı** (üst kısım):
  - Büyük premium illüstrasyonu:
    - Örn. parlayan fotoğraf galerisi, sihirli değnek, yıldızlı bir overlay.
  - Başlık:
    - Örnek: “Clean your gallery 10x faster”.
  - Alt başlık:
    - Kısa bir cümleyle tüm faydaları özetler.

- **Özellik Listesi**:
  - Bullet’lar:
    - “Unlimited cleaning across all albums”
    - “Remove all ads”
    - “Smart blur & duplicate detection included”
    - “Priority experience and faster scanning”
  - Her bullet yanında küçük bir icon (check, bolt, star vb.).

- **Fiyatlandırma Alanı**:
  - Tek ana ürün (örn. Lifetime veya Subscription).
  - Kart içinde:
    - Fiyat.
    - Süre (monthly / yearly / lifetime).
    - Varsa deneme süresi bilgisi.

- **CTA Butonları**:
  - Ana CTA:
    - Örn. “Continue” / “Upgrade now”.
    - Geniş, primary renkli buton.
  - İkincil buton / link:
    - “Restore purchases”.
  - Alt kısım:
    - Küçük fontla Terms & Privacy linkleri.

#### 8.2. Premium Başarı Diyaloğu

- Küçük fakat çarpıcı bir modal:
  - Büyük icon veya mini animasyon (confetti, star, premium badge).
  - Başlık: “You’re Premium!”.
  - Kısa açıklama:
    - Örn. “Unlimited cleaning unlocked. Enjoy a faster, ad-free experience.”
  - Tek ana buton:
    - “Continue”.
  - Arka planda hafif blur veya koyulaştırılmış overlay.

---

### 9. Free vs Premium Göstergeleri & Reklam Mantığı

#### 9.1. Free Kullanıcılar

- Üst bilgi kartında veya swipe ekranında:
  - “Deletes left today” tarzı bir sayaç veya progress bar.
  - Limit azaldıkça:
    - Sayaç rengi yavaş yavaş warning tonuna döner (amber).
    - Kullanıcıyı premium veya rewarded ad yönüne **kibarca** teşvik eden metinler.
- “Watch an ad to get more deletes” gibi seçenekler:
  - Ayrı bir diyalog veya sheet içinde görünebilir.
  - Kısa açıklama + tek CTA butonu.

#### 9.2. Premium Kullanıcılar

- Sınırlamalar (delete limit vs.) tamamen kaldırılır.
- Ana ekranda küçük bir premium badge:
  - Örn. appBar’da app adı yanında küçük crown iconu.
- Settings içindeki premium kart, “You are Premium” statüsünü temiz bir şekilde gösterir.

#### 9.3. Reklamların Görsel Konumu

- Reklamlar (interstitial / rewarded) **ana layout’un parçası olarak çizilmez**, sadece:
  - “Watch a short ad to…” şeklindeki metinler veya aksiyon butonları tasarlanır.
  - Gerçek reklam görseli tasarımın dışında tutulur.

---

### 10. Onboarding, Empty, Loading & Error Durumları

#### 10.1. İlk Açılış & İzin Onboarding’i

- Kullanıcı henüz galeri erişimi vermemişse:
  - Büyük, dostça bir illüstrasyon:
    - Fotoğraf yığını, kilit, izin metaforu vb.
  - Başlık:
    - “Allow access to clean your gallery”.
  - Body text:
    - Kısa, güven verici açıklama:
      - “We only analyze your photos on-device to help you clean up space. You stay in control.”
  - Tek büyük CTA:
    - “Grant access to photos”.

#### 10.2. Boş Galeri / Albüm

- Albümde temizlenecek fotoğraf yoksa:
  - Başlık: “Nothing to clean here”.
  - Destek metni:
    - “Try another album or scan for blurry/duplicate photos.”
  - Butonlar:
    - “Change album”
    - “Go to scans”

#### 10.3. Yükleme & Shimmer

- Uygulama içindeki pek çok noktada (swipe ekranı, scan ekranı vs.):
  - Shimmer skeleton’lar:
    - Top bar.
    - Kartlar.
    - Butonlar.
  - Animasyon hızları yumuşak ve gözü yormayacak şekilde ayarlı.

#### 10.4. Hata Durumları

- Örneğin, tarama servisi hata verirse:
  - Icon: uyarı üçgeni veya broken cloud.
  - Başlık: “Something went wrong”.
  - Kısa açıklama:
    - “We couldn’t finish this scan. Please try again.”
  - CTA:
    - “Try again” butonu.

---

### 11. Mikro Etkileşimler & İnce Detaylar

- **Ripple / Tap Feedback**:
  - Tüm tıklanabilir kartlar ve butonlar, yuvarlak köşeli ripple veya highlight efekti ile tepki verir.
- **Swipe Kart**:
  - Kart geri bırakıldığında yay etkisiyle (spring) orijinal konuma döner.
  - Silme/keep eşiği geçildiğinde kart hızlanarak ekrandan çıkar.
- **Bottom Sheets**:
  - Açılışta hafif yukarı doğru fade + slide animasyonu.
  - Kapanırken aşağı doğru slide + küçülen shadow.
- **Iconography**:
  - Basit, line tabanlı iconlar; gerektiğinde doldurulmuş varyantları (filled) vurgu için kullan.
  - Tutarlılık: aynı tür aksiyonlarda aynı ikon kullanımı.

---

### 12. Genel Hedef

Use all of the above details to design a complete, cohesive, and delightful UI system for the **Gallery Cleaner** app.  
The final design should:

- Make **cleaning photos feel fast, safe, and satisfying**.
- Communicate clearly where each photo will go (kept vs deleted).
- Encourage users to upgrade to premium in a **friendly, non-aggressive** way.
- Feel like a **top-tier, App Store-featured app** that users trust with their memories.


