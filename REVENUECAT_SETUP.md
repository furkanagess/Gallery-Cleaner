# RevenueCat Yapılandırma Rehberi

Bu rehber, Android ve iOS için RevenueCat offerings yapılandırmasını adım adım açıklar.

## Hata: "There are no products registered in the RevenueCat dashboard for your offerings"

Bu hata, RevenueCat dashboard'unda offerings yapılandırılmadığında ortaya çıkar. Aşağıdaki adımları takip ederek sorunu çözebilirsiniz.

## Adım 1: Google Play Console'da In-App Product Oluşturma (Android)

1. [Google Play Console](https://play.google.com/console) açın
2. Uygulamanızı seçin
3. **Monetize** > **Products** > **In-app products** bölümüne gidin
4. **Create product** butonuna tıklayın
5. Aşağıdaki bilgileri girin:
   - **Product ID**: `lifetime_gallery_cleaner_premium`
   - **Name**: Gallery Cleaner Premium (veya istediğiniz isim)
   - **Description**: Lifetime premium access (veya istediğiniz açıklama)
   - **Price**: İstediğiniz fiyat (ör: $9.99)
   - **Status**: **Active** olarak ayarlayın
6. **Save** butonuna tıklayın

**Önemli**: Ürün oluşturulduktan sonra Google'ın onayı birkaç saat sürebilir. Ürün aktif olana kadar RevenueCat'te görünmeyebilir.

## Adım 2: App Store Connect'te In-App Purchase Oluşturma (iOS)

1. [App Store Connect](https://appstoreconnect.apple.com) açın
2. Uygulamanızı seçin
3. **Features** > **In-App Purchases** bölümüne gidin
4. **+** butonuna tıklayın
5. **Non-Consumable** seçin (lifetime purchase için)
6. Aşağıdaki bilgileri girin:
   - **Reference Name**: Gallery Cleaner Premium
   - **Product ID**: `lifetime_gallery_cleaner_premium`
   - **Price**: İstediğiniz fiyat
7. **Save** butonuna tıklayın
8. Ürünü **Submit for Review** yapın

## Adım 3: RevenueCat Dashboard'da Product Ekleme

1. [RevenueCat Dashboard](https://app.revenuecat.com) açın
2. Projenizi seçin
3. **Products** bölümüne gidin
4. **Add Product** butonuna tıklayın
5. Aşağıdaki bilgileri girin:
   - **Identifier**: `lifetime_gallery_cleaner_premium`
   - **Type**: **Non-Subscription** (lifetime purchase için)
6. **Google Play Console** ve **App Store Connect**'teki ürün ID'lerini eşleştirin:
   - Android: `lifetime_gallery_cleaner_premium`
   - iOS: `lifetime_gallery_cleaner_premium`
7. **Save** butonuna tıklayın

## Adım 4: RevenueCat Dashboard'da Entitlement Oluşturma

1. RevenueCat Dashboard'da **Entitlements** bölümüne gidin
2. **Add Entitlement** butonuna tıklayın
3. Aşağıdaki bilgileri girin:
   - **Identifier**: `premium`
   - **Display Name**: Premium (veya istediğiniz isim)
4. Oluşturduğunuz product'ı (`lifetime_gallery_cleaner_premium`) bu entitlement'a ekleyin
5. **Save** butonuna tıklayın

## Adım 5: RevenueCat Dashboard'da Offering Oluşturma

1. RevenueCat Dashboard'da **Offerings** bölümüne gidin
2. **Add Offering** butonuna tıklayın
3. Aşağıdaki bilgileri girin:
   - **Identifier**: `gallerycleanerpremium`
   - **Display Name**: Gallery Cleaner Premium (veya istediğiniz isim)
4. **Packages** bölümünde **Add Package** butonuna tıklayın
5. Aşağıdaki bilgileri girin:
   - **Identifier**: `$rc_lifetime` (veya istediğiniz identifier)
   - **Type**: **Lifetime**
   - **Product**: `lifetime_gallery_cleaner_premium` seçin
6. Bu package'ı **premium** entitlement'a bağlayın
7. **Save** butonuna tıklayın
8. Offering'i **Current** olarak işaretleyin (varsayılan offering olması için)

## Adım 6: Yapılandırma Kontrolü

Yapılandırmanın doğru olduğundan emin olmak için:

1. RevenueCat Dashboard'da **Offerings** bölümüne gidin
2. `gallerycleanerpremium` offering'inin **Current** olarak işaretli olduğundan emin olun
3. Offering'in içinde package'ın göründüğünden emin olun
4. Package'ın product ID'sinin `lifetime_gallery_cleaner_premium` olduğundan emin olun
5. Product'ın Google Play Console (Android) ve App Store Connect (iOS)'te aktif olduğundan emin olun

## Adım 7: Test Etme

1. Uygulamayı test cihazında çalıştırın
2. Premium satın alma sayfasına gidin
3. Fiyatın göründüğünden emin olun
4. Satın alma işlemini test edin

**Test için**: RevenueCat'te **Sandbox** modunu kullanabilirsiniz. Google Play Console ve App Store Connect'te test hesapları oluşturun.

## Sorun Giderme

### Hata: "ConfigurationError - There are no products registered"

**Çözüm**:
- Google Play Console'da ürünün **Active** olduğundan emin olun
- App Store Connect'te ürünün **Ready to Submit** veya **Approved** olduğundan emin olun
- RevenueCat Dashboard'da product'ın doğru eşleştirildiğinden emin olun
- Offering'in **Current** olarak işaretli olduğundan emin olun

### Hata: "Product not found"

**Çözüm**:
- Product ID'nin (`lifetime_gallery_cleaner_premium`) tüm platformlarda aynı olduğundan emin olun
- RevenueCat Dashboard'da product'ın hem Android hem iOS için eşleştirildiğinden emin olun
- Ürünün Google Play Console ve App Store Connect'te aktif olduğundan emin olun

### Fiyat Görünmüyor

**Çözüm**:
- Offering'in **Current** olarak işaretli olduğundan emin olun
- Package'ın offering'e eklendiğinden emin olun
- Product'ın package'a eklendiğinden emin olun
- Uygulamayı yeniden başlatın (cache temizleme)

## API Key'ler

Uygulama şu API key'leri kullanıyor:

- **Android**: `goog_RDHXtiyMMTNFGrseBxSNVpiLrfB`
- **iOS**: `appl_oKgzJzDDTXyZunWhwqbociivoVP`

Bu key'ler `lib/src/core/services/revenuecat_service.dart` dosyasında tanımlıdır.

## Daha Fazla Bilgi

- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [How to Configure Offerings](https://rev.cat/how-to-configure-offerings)
- [Why Are Offerings Empty?](https://rev.cat/why-are-offerings-empty)

