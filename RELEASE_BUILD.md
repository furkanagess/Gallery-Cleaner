# Android Release Build Yapılandırması

## Keystore Oluşturma

Google Play Console'a yüklemeden önce bir keystore oluşturmanız gerekiyor.

### 1. Keystore Oluştur

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Bu komut sizden şu bilgileri isteyecek:
- Keystore password (parola)
- Key password (parola)
- Adınız, organizasyonunuz vb.

**ÖNEMLİ:** Bu parolaları ve keystore dosyasını güvenli bir yerde saklayın. Kaybederseniz uygulamanızı güncelleyemezsiniz!

### 2. key.properties Dosyası Oluştur

`android/key.properties` dosyası oluşturun ve aşağıdaki bilgileri doldurun:

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

**Örnek (Mutlak yol):**
```properties
storePassword=mySecurePassword123
keyPassword=mySecurePassword123
keyAlias=upload
storeFile=/Users/furkancaglar/upload-keystore.jks
```

**Örnek (Göreli yol - keystore android klasörü içindeyse):**
```properties
storePassword=mySecurePassword123
keyPassword=mySecurePassword123
keyAlias=upload
storeFile=../upload-keystore.jks
```

**Not:** Keystore dosyasını `android/` klasörü dışında bir yere koymanız önerilir (örn: home dizininiz).

### 3. Release Build Oluştur

#### App Bundle (Önerilen - Google Play Console için):
```bash
flutter build appbundle --release
```

Oluşturulan dosya: `build/app/outputs/bundle/release/app-release.aab`

#### APK (Test için):
```bash
flutter build apk --release
```

Oluşturulan dosya: `build/app/outputs/flutter-apk/app-release.apk`

### 4. Google Play Console'a Yükleme

1. Google Play Console'a giriş yapın
2. Uygulamanızı seçin
3. "Production" veya "Internal testing" bölümüne gidin
4. "Create new release" butonuna tıklayın
5. Oluşturduğunuz `.aab` dosyasını yükleyin

## Notlar

- `key.properties` dosyası `.gitignore`'da olduğu için Git'e commit edilmeyecektir (güvenlik için)
- Keystore dosyasını da Git'e commit etmeyin
- Parolalarınızı güvenli bir yerde saklayın (password manager kullanın)
- Keystore dosyasını yedekleyin

## Sorun Giderme

Eğer hala debug imzası hatası alıyorsanız:

1. `key.properties` dosyasının doğru yerde olduğundan emin olun (`android/key.properties`)
2. Keystore dosya yolunun doğru olduğundan emin olun
3. Parolaların doğru olduğundan emin olun
4. Projeyi temizleyip yeniden build edin:
   ```bash
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```

