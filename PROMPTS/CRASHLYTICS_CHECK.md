# Firebase Crashlytics Bağlantı Kontrolü

## ✅ Uygulamanız Crashlytics'e Bağlı

### Mevcut Durum Kontrolü

1. **Dependency Kontrolü:**
   ```bash
   grep "firebase_crashlytics" pubspec.yaml
   ```
   ✅ `firebase_crashlytics: ^3.4.18` bulundu

2. **Kod Kontrolü:**
   - ✅ `main.dart` içinde Firebase Crashlytics initialize ediliyor
   - ✅ `FlutterError.onError` handler ayarlanmış
   - ✅ `PlatformDispatcher.instance.onError` handler ayarlanmış
   - ✅ `setCrashlyticsCollectionEnabled(true)` çağrılıyor

3. **Android Kontrolü:**
   ```bash
   grep -r "crashlytics" android/app/build.gradle.kts
   ```
   ✅ Plugin eklendi: `id("com.google.firebase.crashlytics")`

4. **iOS Kontrolü:**
   - ✅ Podfile.lock'da Firebase Crashlytics var
   - ✅ Xcode build phase'de Crashlytics script var

## 🧪 Crashlytics Bağlantısını Test Etme

### Yöntem 1: Manuel Crash Test (Kod Ekleyin)

Aşağıdaki kodu uygulamanızın herhangi bir yerine ekleyin (örn: Settings sayfası):

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Test için crash tetikleme
ElevatedButton(
  onPressed: () {
    FirebaseCrashlytics.instance.crash();
  },
  child: Text('Test Crash (Crashlytics)'),
)

// Test için non-fatal error gönderme
ElevatedButton(
  onPressed: () async {
    try {
      throw Exception('Test exception for Crashlytics');
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Test error from app',
        fatal: false,
      );
    }
  },
  child: Text('Test Non-Fatal Error'),
)

// Test log gönderme
ElevatedButton(
  onPressed: () {
    FirebaseCrashlytics.instance.log('Test log message from app');
  },
  child: Text('Test Log'),
)
```

### Yöntem 2: Firebase Console'da Kontrol

1. [Firebase Console](https://console.firebase.google.com/) açın
2. Projenizi seçin
3. Sol menüden **Crashlytics**'e tıklayın
4. Uygulamanızı çalıştırın ve yukarıdaki test kodunu çalıştırın
5. 5-10 dakika içinde crash'ler Console'da görünmelidir

### Yöntem 3: Log Kontrolü

Uygulamayı çalıştırırken log'larda şunu arayın:
```bash
# Android
adb logcat | grep -i crashlytics

# iOS
# Xcode Console'da "Crashlytics" ara
```

### Yöntem 4: Debug Mode Kontrolü

Debug mode'da Crashlytics çalışmaz (sadece release mode'da). Test için:

```dart
// main.dart içinde
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
  !kDebugMode, // Debug'da false, release'de true
);
```

Ancak test için geçici olarak debug'da da aktif edebilirsiniz:
```dart
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
```

## 📊 Beklenen Davranış

### ✅ Bağlantı Çalışıyorsa:
- Uygulama crash olduğunda Firebase Console'da görünür
- Non-fatal error'lar Console'da görünür
- Log'lar Console'da görünür
- 5-10 dakika içinde veriler güncellenir

### ❌ Bağlantı Çalışmıyorsa:
- Firebase Console'da hiçbir şey görünmez
- Log'larda hata mesajları olabilir
- `google-services.json` veya `GoogleService-Info.plist` eksik/yanlış olabilir
- Firebase projesi yanlış yapılandırılmış olabilir

## 🔍 Hızlı Kontrol Script'i

Terminal'de çalıştırın:

```bash
# 1. Dependency kontrolü
echo "1. Dependency Kontrolü:"
grep -i "firebase_crashlytics" pubspec.yaml

# 2. Android plugin kontrolü
echo "\n2. Android Plugin Kontrolü:"
grep -i "crashlytics" android/app/build.gradle.kts

# 3. Config dosyaları kontrolü
echo "\n3. Config Dosyaları:"
ls -la android/app/google-services.json 2>/dev/null && echo "✅ google-services.json var" || echo "❌ google-services.json yok"
ls -la ios/Runner/GoogleService-Info.plist 2>/dev/null && echo "✅ GoogleService-Info.plist var" || echo "❌ GoogleService-Info.plist yok"

# 4. Kod kontrolü
echo "\n4. Initialization Kontrolü:"
grep -A 5 "FirebaseCrashlytics" lib/main.dart
```

## ⚠️ Önemli Notlar

1. **Release Build:** Crashlytics genellikle sadece release build'lerde çalışır
2. **Gecikme:** Crash'ler Firebase Console'da görünmesi 5-10 dakika sürebilir
3. **Internet:** Cihazın internet bağlantısı olmalı
4. **Firebase Projesi:** Doğru Firebase projesine bağlı olduğundan emin olun

## 🚀 Hızlı Test

En hızlı test için:

1. Uygulamayı **release mode**'da çalıştırın
2. Yukarıdaki test crash kodunu ekleyin
3. Test crash butonuna basın
4. Uygulama crash olacak
5. Uygulamayı tekrar açın (Crashlytics crash'i raporlar)
6. 5-10 dakika sonra Firebase Console'u kontrol edin

