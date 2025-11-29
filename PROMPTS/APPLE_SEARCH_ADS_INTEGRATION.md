# Apple Search Ads Entegrasyonu - RevenueCat

Bu dokümantasyon, Gallery Cleaner uygulamasında Apple Search Ads entegrasyonunun nasıl yapılandırıldığını açıklar.

## 📋 Genel Bakış

Apple Search Ads entegrasyonu, RevenueCat dashboard'unda yapılandırılmıştır. Uygulama, iOS'ta AdServices framework'ünü kullanarak attribution token'ı otomatik olarak toplar ve RevenueCat'e gönderir.

## 🔧 Yapılandırma Bilgileri

RevenueCat dashboard'undan alınan yapılandırma bilgileri:

### Public Key
```
-----BEGIN PUBLIC KEY-----
MFkwEwYHKOZIzjOCAQYIKOZIzj0DAQcDQgAEGdHc6BIMESyi50hJ0W+NWfAd3bZx
b4YA2XO7kzloORD/btiXoHth9zO9F6d1TF01850+FI+FJVQRu7fxgzEHww==
-----END PUBLIC KEY-----
```

### API Bilgileri
- **Client ID**: `SEARCHADS.aeb3ef5f-0c5a-4f2a-99c8-fca83f25a9`
- **Team ID**: `SEARCHADS.hgw3ef3p-0w7a-8a2n-77c8-scv83f25a7`
- **Key ID**: `a273d0d3-4d9e-458c-a173-0db8619ca7d7`

> **Not**: Bu bilgiler RevenueCat dashboard'unda yapılandırılmıştır ve backend tarafında kullanılır. SDK tarafında sadece attribution token'ı toplamak yeterlidir.

## 🏗️ Mimari

### 1. Flutter Servisi
**Dosya**: `lib/src/core/services/apple_search_ads_service.dart`

Bu servis:
- iOS'ta AdServices framework'ünden attribution token'ı alır
- Token'ı RevenueCat SDK'sına gönderir (otomatik)
- Hata durumlarını yönetir

### 2. iOS Native Plugin
**Dosya**: `ios/Runner/AppleSearchAdsPlugin.swift`

Bu plugin:
- AdServices framework'ünü kullanır
- Attribution token'ı Flutter'a iletir
- iOS 14.3+ gerektirir

### 3. Entegrasyon Noktası
**Dosya**: `lib/main.dart`

Apple Search Ads servisi, RevenueCat başlatıldıktan sonra otomatik olarak başlatılır.

## 🚀 Nasıl Çalışır?

1. **Uygulama Başlatma**: 
   - RevenueCat initialize edilir
   - Apple Search Ads servisi initialize edilir

2. **Attribution Token Toplama**:
   - iOS'ta AdServices framework'ü kullanılır
   - Eğer kullanıcı bir Apple Search Ad'ına tıkladıysa, token mevcut olur
   - Token yoksa (normal durum), bu bir hata değildir

3. **RevenueCat'e Gönderme**:
   - RevenueCat SDK'sı otomatik olarak attribution token'ı toplar ve gönderir
   - RevenueCat backend'i, token'ı Apple Search Ads API'sine gönderir
   - Attribution doğrulanır ve RevenueCat dashboard'unda görüntülenir

## 📱 Gereksinimler

- **iOS**: 14.3 veya üzeri (AdServices framework için)
- **RevenueCat SDK**: v9.0.0 veya üzeri
- **RevenueCat Dashboard**: Apple AdServices entegrasyonu yapılandırılmış olmalı

## ✅ Doğrulama

### RevenueCat Dashboard'da Kontrol

1. RevenueCat Dashboard > Integrations > Apple AdServices
2. "Basic integration" bölümünde yeşil onay işareti olmalı
3. "Advanced integration" bölümünde yapılandırma bilgileri görünmeli

### Uygulama Loglarında Kontrol

Uygulama başlatıldığında şu loglar görünmelidir:

```
🟦 [AppleSearchAds] Initializing Apple Search Ads attribution...
✅ [AppleSearchAds] Attribution token received (eğer token varsa)
✅ [AppleSearchAds] Attribution token sent to RevenueCat
✅ [AppleSearchAds] Initialization complete
```

Eğer kullanıcı bir Apple Search Ad'ına tıklamadıysa:

```
⚠️ [AppleSearchAds] No attribution token available (user may not have clicked an Apple Search Ad)
```

Bu normal bir durumdur ve hata değildir.

## 🔍 Sorun Giderme

### Attribution Token Alınamıyor

**Sorun**: Loglarda "No attribution token available" görünüyor.

**Çözüm**: Bu normal bir durumdur. Attribution token sadece kullanıcı bir Apple Search Ad'ına tıkladığında mevcut olur. Test için:
1. Apple Search Ads kampanyası oluşturun
2. Test cihazınızı kampanyaya ekleyin
3. Test ad'ına tıklayın
4. Uygulamayı açın

### iOS 14.3 Altında Çalışmıyor

**Sorun**: "AdServices framework requires iOS 14.3 or later" hatası.

**Çözüm**: AdServices framework iOS 14.3+ gerektirir. Daha eski iOS sürümlerinde attribution çalışmaz.

### RevenueCat Dashboard'da Görünmüyor

**Sorun**: Attribution RevenueCat dashboard'unda görünmüyor.

**Çözüm**:
1. RevenueCat dashboard'da Apple AdServices entegrasyonunun yapılandırıldığından emin olun
2. Public Key, Client ID, Team ID ve Key ID'nin doğru olduğunu kontrol edin
3. Apple Search Ads hesabınızda API kullanıcısının oluşturulduğunu ve gerekli izinlere sahip olduğunu kontrol edin

## 📚 Ek Kaynaklar

- [RevenueCat Apple Search Ads Dokümantasyonu](https://docs.revenuecat.com/docs/apple-search-ads)
- [Apple AdServices Framework Dokümantasyonu](https://developer.apple.com/documentation/adservices)
- [Apple Search Ads API Dokümantasyonu](https://developer.apple.com/documentation/apple_search_ads_api)

## 🔐 Güvenlik Notları

- Public Key, Client ID, Team ID ve Key ID bilgileri RevenueCat dashboard'unda saklanır
- Bu bilgiler backend tarafında kullanılır, client tarafında sadece attribution token toplanır
- Attribution token'lar hassas bilgi içermez ve güvenli bir şekilde iletilir

## 📝 Notlar

- Attribution token sadece kullanıcı bir Apple Search Ad'ına tıkladığında mevcut olur
- Token yoksa bu bir hata değildir - kullanıcı normal yollarla uygulamayı indirmiş olabilir
- RevenueCat SDK'sı otomatik olarak attribution token'ı toplar ve gönderir
- Manuel olarak token göndermeye gerek yoktur (SDK otomatik yapar)

