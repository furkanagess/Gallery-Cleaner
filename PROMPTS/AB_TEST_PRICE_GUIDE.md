# A/B Test Rehberi - Fiyat Testi ($3.99 vs $4.99)

Bu rehber, bazı kullanıcılara $3.99, bazılarına $4.99 göstermek için A/B test kurulumunu açıklar.

---

## 🎯 Yöntem 1: İki Farklı Product ID (Basit Yöntem)

Bu yöntem, iki farklı product ID oluşturup kullanıcı bazlı olarak hangi product'ı göstereceğimize karar vermemizi sağlar.

### Adım 1: Store'larda İkinci Product Oluşturma

#### 1.1. Google Play Console (Android)

1. [Google Play Console](https://play.google.com/console) açın
2. **Monetize** > **Products** > **In-app products** bölümüne gidin
3. **Create product** butonuna tıklayın
4. Aşağıdaki bilgileri girin:
   - **Product ID**: `lifetime_gallery_cleaner_premium_ab_test`
   - **Name**: Gallery Cleaner Premium (A/B Test)
   - **Description**: Lifetime premium access (A/B Test variant)
   - **Price**: **$3.99**
   - **Status**: **Active**
5. **Save** butonuna tıklayın

**Not**: Mevcut `lifetime_gallery_cleaner_premium` ürününün fiyatını **$4.99** olarak ayarlayın (eğer değilse).

#### 1.2. App Store Connect (iOS)

1. [App Store Connect](https://appstoreconnect.apple.com) açın
2. **Features** > **In-App Purchases** bölümüne gidin
3. **+** butonuna tıklayın
4. **Non-Consumable** seçin
5. Aşağıdaki bilgileri girin:
   - **Reference Name**: Gallery Cleaner Premium (A/B Test)
   - **Product ID**: `lifetime_gallery_cleaner_premium_ab_test`
   - **Price**: **$3.99** (Tier 3)
6. **Save** butonuna tıklayın
7. Ürünü **Submit for Review** yapın

**Not**: Mevcut `lifetime_gallery_cleaner_premium` ürününün fiyatını **$4.99** olarak ayarlayın (eğer değilse).

### Adım 2: RevenueCat Dashboard'da İkinci Product Ekleme

1. [RevenueCat Dashboard](https://app.revenuecat.com) açın
2. **Products** bölümüne gidin
3. **Add Product** butonuna tıklayın
4. Aşağıdaki bilgileri girin:
   - **Identifier**: `lifetime_gallery_cleaner_premium_ab_test`
   - **Type**: **Non-Subscription**
5. **Google Play Console** ve **App Store Connect**'teki ürün ID'lerini eşleştirin:
   - Android: `lifetime_gallery_cleaner_premium_ab_test`
   - iOS: `lifetime_gallery_cleaner_premium_ab_test`
6. **Save** butonuna tıklayın

### Adım 3: RevenueCat'te İkinci Offering Oluşturma

1. RevenueCat Dashboard'da **Offerings** bölümüne gidin
2. **Add Offering** butonuna tıklayın
3. Aşağıdaki bilgileri girin:
   - **Identifier**: `gallerycleanerpremium_ab_test`
   - **Display Name**: Gallery Cleaner Premium (A/B Test)
4. **Packages** bölümünde **Add Package** butonuna tıklayın
5. Aşağıdaki bilgileri girin:
   - **Identifier**: `$rc_lifetime_ab_test`
   - **Type**: **Lifetime**
   - **Product**: `lifetime_gallery_cleaner_premium_ab_test` seçin
6. Bu package'ı **premium** entitlement'a bağlayın
7. **Save** butonuna tıklayın
8. **Current** olarak işaretlemeyin (sadece test için)

### Adım 4: Kodda A/B Test Mantığı Ekleme

Kodda kullanıcı bazlı olarak hangi product'ı göstereceğimize karar vereceğiz. Kullanıcı ID'sinin son hanesine göre %50-%50 dağıtım yapacağız.

---

## 🎯 Yöntem 2: RevenueCat Experiments (Önerilen - Daha Gelişmiş)

RevenueCat Experiments, A/B test yapmak için daha gelişmiş bir yöntemdir. Dashboard'dan yönetilebilir ve daha detaylı analiz sağlar.

### Adım 1: RevenueCat Dashboard'da Experiment Oluşturma

1. [RevenueCat Dashboard](https://app.revenuecat.com) açın
2. **Experiments** bölümüne gidin
3. **Create Experiment** butonuna tıklayın
4. Aşağıdaki bilgileri girin:
   - **Name**: Price A/B Test ($3.99 vs $4.99)
   - **Description**: Testing conversion rates between $3.99 and $4.99
   - **Traffic Split**: %50 - %50 (veya istediğiniz oran)
5. **Variants** bölümünde:
   - **Variant A**: Mevcut offering (`gallerycleanerpremiumoffering`) - $4.99
   - **Variant B**: Yeni offering (`gallerycleanerpremium_ab_test`) - $3.99
6. **Save** butonuna tıklayın
7. Experiment'i **Activate** edin

### Adım 2: Kodda Experiment Desteği Ekleme

RevenueCat SDK otomatik olarak experiment'leri yönetir. Kodda özel bir şey yapmanıza gerek yok, ancak experiment sonuçlarını loglamak için ek kod ekleyebiliriz.

---

## 📝 Kod Değişiklikleri

Aşağıdaki kod değişikliklerini yapmanız gerekecek:

### 1. RevenueCat Service'e A/B Test Desteği Ekleme

`lib/src/core/services/revenuecat_service.dart` dosyasına A/B test mantığı ekleyeceğiz.

### 2. Paywall Page'de A/B Test Desteği

`lib/src/features/settings/presentation/paywall_page.dart` dosyasında A/B test mantığını kullanacağız.

---

## ✅ Test Etme

1. Uygulamayı test cihazında çalıştırın
2. Premium satın alma sayfasına gidin
3. Farklı kullanıcılar için farklı fiyatların göründüğünü kontrol edin
4. Her iki fiyat için de satın alma işlemini test edin

---

## 📊 Sonuçları İzleme

### RevenueCat Dashboard'da İzleme

1. **Experiments** bölümüne gidin
2. Experiment'in durumunu kontrol edin
3. Her variant için:
   - Conversion rate
   - Revenue
   - Customer count
   - Diğer metrikler

### Analiz

- **Variant A ($4.99)**: Daha yüksek ARPU, düşük conversion
- **Variant B ($3.99)**: Daha düşük ARPU, yüksek conversion
- **Hangi variant daha iyi?**: Toplam gelir ve conversion rate'e göre karar verin

---

## 🎯 Önerilen Test Süresi

- **Minimum**: 2 hafta
- **Önerilen**: 4 hafta
- **İdeal**: 6-8 hafta (istatistiksel anlamlılık için)

---

## 📚 Ek Kaynaklar

- [RevenueCat Experiments Documentation](https://docs.revenuecat.com/docs/experiments)
- [A/B Testing Best Practices](https://docs.revenuecat.com/docs/experiments-best-practices)

---

**Son Güncelleme**: Bu rehber A/B test kurulumu için hazırlanmıştır. Kod değişiklikleri için aşağıdaki bölüme bakın.

