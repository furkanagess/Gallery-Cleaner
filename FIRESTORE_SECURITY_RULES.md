# Firestore Güvenlik Kuralları - Kurulum Rehberi

## Sorun

`permission-denied` hatası alıyorsunuz çünkü Firestore güvenlik kuralları yazma işlemlerine izin vermiyor.

## Çözüm: Firebase Console'dan Güvenlik Kurallarını Ayarlama

### Adım 1: Firebase Console'a Giriş

1. https://console.firebase.google.com/ adresine gidin
2. Projenizi seçin: `gallerycleaner-9672d`

### Adım 2: Firestore Database'e Git

1. Sol menüden **Firestore Database** seçeneğine tıklayın
2. Üst menüden **Rules** (Kurallar) sekmesine tıklayın

### Adım 3: Güvenlik Kurallarını Güncelle

**ÖNEMLİ**: Aşağıdaki kuralları **tam olarak** kopyalayıp Firebase Console'daki Rules editörüne yapıştırın. Bu kurallar hatasız çalışacak şekilde optimize edilmiştir.

#### Seçenek 1: Basit Kurallar (Test ve Hızlı Başlangıç) ✅ ÖNERİLEN

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Analytics collection - genel istatistikler
    match /analytics/{document} {
      allow read: if true;
      allow write: if true;
    }

    // User-track collection - kullanıcı bazlı takip
    match /user-track/{userId} {
      allow read: if true;
      allow create: if true;
      allow update: if true;
      allow delete: if false;
    }
  }
}
```

#### Seçenek 2: Güvenli Kurallar (Production İçin)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Analytics collection
    match /analytics/{document} {
      allow read: if true;
      // Sadece belirli field'lar yazılabilir
      allow create: if request.resource.data.keys().hasOnly(['usersReachedZeroCount', 'lastUpdated']);
      allow update: if request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['usersReachedZeroCount', 'lastUpdated']);
      allow delete: if false;
    }

    // User-track collection
    match /user-track/{userId} {
      allow read: if true;
      // Sadece belirli field'lar yazılabilir
      allow create: if request.resource.data.keys().hasAll(['no-delete-limit', 'lastUpdated']) &&
                      request.resource.data.keys().hasOnly(['no-delete-limit', 'lastUpdated', 'userId']);
      allow update: if request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['no-delete-limit', 'lastUpdated', 'userId']);
      allow delete: if false;
    }
  }
}
```

### Adım 4: Kuralları Yayınla

1. Rules editöründe **Validate** (Doğrula) butonuna tıklayın - syntax hatası olmamalı
2. **Publish** (Yayınla) butonuna tıklayın
3. Onay mesajını kabul edin
4. Birkaç saniye bekleyin (kuralların yayılması için)

## Test Etme

Kuralları yayınladıktan sonra:

1. **30-60 saniye bekleyin** (kuralların tüm sunuculara yayılması için)
2. Uygulamayı **tamamen kapatıp yeniden açın**
3. Swipe sayfasındaki test butonuna tıklayın
4. Artık `permission-denied` hatası almamalısınız
5. Firebase Console → Firestore Database → `user-track` collection'ından kontrol edin

## Önemli Notlar

✅ **Seçenek 1 (Basit Kurallar)**:

- Test ve geliştirme için idealdir
- Hızlı kurulum
- Tüm yazma işlemlerine izin verir
- **Önerilen başlangıç seçeneği**

🔒 **Seçenek 2 (Güvenli Kurallar)**:

- Production için daha güvenlidir
- Sadece belirli field'ların güncellenmesine izin verir
- Daha fazla kontrol sağlar
- **Production'da kullanılmalı**

## Kod Yapısı Hakkında

Uygulama kodunda `set()` ile `merge: true` kullanılıyor. Bu:

- Document yoksa **create** yapar
- Document varsa **update** yapar
- Her iki durumda da çalışır

Güvenlik kuralları bu yapıyı destekler.

## Sorun Giderme

### Hala permission-denied hatası alıyorsanız:

1. ✅ **Kuralların yayınlandığını kontrol edin**

   - Firebase Console → Firestore Database → Rules
   - "Published" yazısını görmelisiniz
   - Eğer "Not published" görüyorsanız, Publish butonuna tıklayın

2. ⏱️ **Yeterince bekleyin**

   - Kuralların yayılması 30-60 saniye sürebilir
   - Acele etmeyin, bekleyin

3. 🔄 **Uygulamayı tamamen yeniden başlatın**

   - Uygulamayı tamamen kapatın (arka planda bile çalışmamalı)
   - Yeniden açın

4. 📱 **Cihazı yeniden başlatın** (gerekirse)

   - Bazen cache sorunları olabilir

5. ✅ **Kuralların doğru olduğunu kontrol edin**
   - Rules editöründe syntax hatası olmamalı
   - Kırmızı uyarılar varsa düzeltin

### Syntax Hatası Kontrolü:

- Rules editöründe **Validate** butonuna tıklayın
- Hata yoksa "Rules are valid" mesajı görünmeli
- Hata varsa kırmızı çizgilerle gösterilir

### Yaygın Hatalar:

❌ **Yanlış**: `allow write: if true;` (tek başına yeterli değil, create/update ayrı olmalı)
✅ **Doğru**: `allow create: if true; allow update: if true;`

❌ **Yanlış**: Eksik noktalı virgül veya parantez
✅ **Doğru**: Tüm syntax doğru olmalı

### Hala Çalışmıyorsa:

1. Firebase Console'da Rules sekmesinde **Simulator** kullanın
2. Test senaryosu oluşturun:
   - Location: `user-track/test123`
   - Method: `write`
   - Simulate butonuna tıklayın
   - Sonuç "Allowed" olmalı
