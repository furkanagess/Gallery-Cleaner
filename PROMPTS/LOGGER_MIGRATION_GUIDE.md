# Logger Migration Guide

Tüm uygulamadaki `debugPrint` kullanımları `AppLogger` ile değiştirilmelidir.

## Kullanım

### Import Ekle
```dart
import '../utils/app_logger.dart';
// veya
import 'package:gallery_cleaner/src/core/utils/app_logger.dart';
```

### Log Seviyeleri

1. **Debug** - Detaylı bilgi (geliştirme sırasında)
   ```dart
   AppLogger.d('Debug mesajı');
   ```

2. **Info** - Bilgilendirme
   ```dart
   AppLogger.i('✅ İşlem tamamlandı');
   ```

3. **Warning** - Uyarı
   ```dart
   AppLogger.w('⚠️ Uyarı mesajı');
   ```

4. **Error** - Hata
   ```dart
   AppLogger.e('❌ Hata mesajı', error, stackTrace);
   ```

5. **Fatal** - Kritik hata
   ```dart
   AppLogger.f('💥 Kritik hata', error, stackTrace);
   ```

### Tag'li Loglama (Servis/Modül bazlı)

```dart
AppLogger.logWithTag('BlurDetection', 'Tarama başladı', level: Level.info);
```

### Extension Kullanımı

```dart
'Mesaj'.logD('Tag');  // Debug
'Mesaj'.logI('Tag');  // Info
'Mesaj'.logW('Tag');  // Warning
'Mesaj'.logE('Tag', error, stackTrace);  // Error
```

## Migration Checklist

- [x] `main.dart` - ✅ Tamamlandı
- [x] `blur_detection_service.dart` - ✅ Tamamlandı
- [x] `photo_cache_service.dart` - ✅ Tamamlandı
- [ ] `duplicate_detection_service.dart` - ⚠️ Kısmen tamamlandı (düzeltme gerekli)
- [ ] `preferences_service.dart`
- [ ] `media_library_service.dart`
- [ ] `in_app_purchase_service.dart`
- [ ] `apple_search_ads_service.dart`
- [ ] `ads_initializer.dart`
- [ ] `rewarded_ads_service.dart`
- [ ] `interstitial_ads_service.dart`
- [ ] `revenuecat_service.dart`
- [ ] Diğer servisler ve feature'lar

## Örnek Dönüşüm

**Önce:**
```dart
debugPrint('✅ [BlurDetection] İşlem tamamlandı');
debugPrint('⚠️ [BlurDetection] Uyarı: $message');
debugPrint('❌ [BlurDetection] Hata: $e');
```

**Sonra:**
```dart
AppLogger.i('✅ [BlurDetection] İşlem tamamlandı');
AppLogger.w('⚠️ [BlurDetection] Uyarı: $message');
AppLogger.e('❌ [BlurDetection] Hata: $e', e, stackTrace);
```

## Notlar

- Release build'de sadece `Level.info` ve üzeri loglar gösterilir
- Debug build'de tüm loglar gösterilir
- Logger otomatik olarak zaman damgası, stack trace ve renkli çıktı sağlar

