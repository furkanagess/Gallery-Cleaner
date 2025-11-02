## Gallery Cleaner – Tinder Benzeri Gallery Organizer (Flutter + Riverpod)

Modern, kullanıcı dostu bir galeri düzenleyici. Kullanıcı; fotoğrafları Tinder mantığında sağ/sol kaydırarak hızlıca “Tut/Sil” kararları verebilir. Ayrıca üstte yer alan klasör hedeflerine (user-defined) kartı sürükleyip bırakarak fotoğrafları ilgili klasörlere taşıyabilir.

### Hedefler

- **Hızlı karar**: Tek el ile swipe (sağ: tut, sol: sil) akışı.
- **Sürükle-bırak taşıma**: Üstte dinamik klasör hedefleri; karta sürükle-bırak ile taşıma.
- **Modern UI**: M3 teması, akışkan animasyonlar, haptics, boş durumlar ve erişilebilirlik.
- **Güvenli ve kontrollü**: Silme onayı, geri al (undo) ve tarihçe (history) ile güvenli işlemler.
- **Performans**: Büyük galerilerde akıcı gezinti, thumbnail optimizasyonu.

---

## Mimari ve Teknolojiler

- **State management**: Riverpod (`flutter_riverpod`).
- **Medya erişimi**: `photo_manager` (galeri okuma, izinler, silme/taşıma).
- **İzinler**: `permission_handler` (platform izni akışı).
- **Yönlendirme**: `go_router`.
- **Animasyonlar**: `animations` ve/veya `flutter_animate`.
- **Depolama/Yol**: `path_provider` (lokal ayarlar, cache).
- **Yardımcılar**: `vibration`/`HapticFeedback`, `logger`, `intl` (opsiyonel).

> Not: iOS/Android platformlarında silme/taşıma davranışları `photo_manager` kısıtlarına tabidir. iOS’ta “Recently Deleted” klasörü vb. platform farklarını dikkate alın.

---

## Klasör Yapısı (Öneri)

```
lib/
  src/
    app/
      app.dart                // MaterialApp + Router + Theme
      router.dart             // go_router tanımı
      theme/
        app_theme.dart        // M3 renkler, tipografi, component theming
    core/
      services/
        media_library_service.dart   // PhotoManager ile okuma/silme/taşıma
      models/
        photo_item.dart              // Medya model/DTO
        folder_target.dart
      utils/
        debouncer.dart, logger.dart
    features/
      onboarding/
        presentation/
          permissions_page.dart
      gallery/
        application/
          gallery_providers.dart     // Riverpod providers/selectors
        presentation/
          pages/
            swipe_page.dart          // Ana swipe ekranı
          widgets/
            photo_swipe_deck.dart    // Swipe kart destesi
            top_folder_targets.dart  // Üst hedef şeritleri (drag targets)
            action_chips.dart
      settings/
        presentation/
          settings_page.dart         // Klasör yönetimi vb.
    common/
      widgets/
        app_scaffold.dart
        async_value_view.dart
        empty_state.dart
        error_view.dart
```

---

## Ana Akışlar

- **Onboarding/İzinler**: Medya izni talebi, kısmi erişim desteği, rehberlik.
- **Galeri Endeksi**: Fotoğrafları sayfalayarak/akıllı preload ile listeleme.
- **Swipe Deck**: Sağ = Tut, Sol = Sil; momentum, snap, geri çağır (rewind) desteği.
- **Klasör Hedefleri**: Üst şerit; drag enter/leave geri bildirimi, drop ile taşıma.
- **Undo/History**: Son işlemleri geri alma; kısa süreli SnackBar eylemi + kalıcı geçmiş.
- **Ayarlar**: Klasör tanımlama/sıralama, varsayılan davranışlar, güvenlik onayları.

---

## UX / UI İlkeleri

- **Modern görünüm**: M3 renk sistemi, dinamik renk (Android 12+), yuvarlatılmış kartlar, yumuşak gölgeler.
- **Tek el optimizasyonu**: Başparmak menziline uygun butonlar ve gestur’lar.
- **Net geri bildirim**: Haptics, renk kodu (sol=tehlike/kırmızı, sağ=onay/yeşil), animasyonlu ipuçları.
- **Boş/Erişim durumları**: İzin reddi, boş galeri, bitti ekranı; açıklayıcı görseller.
- **Erişilebilirlik**: Büyük metin, kontrast, TalkBack/VoiceOver etiketleri.

---

## Yol Haritası ve Görevler

1. Mimari ve Temel Kurulum

- [ ] Riverpod, go_router, photo_manager, permission_handler, animations ekle
- [ ] Uygulama teması ve router yapılandırması
- [ ] Klasör yapısını oluştur, temel dosyaları ekle

2. Onboarding ve İzin Akışı

- [ ] İzin ekranı, durum yönetimi, kılavuz
- [ ] İzin durumu değişimlerinde yönlendirme

3. Galeri Endeksi ve Sağlayıcılar

- [ ] `MediaLibraryService` ile sayfalı okuma/thumbnail
- [ ] Riverpod providers/selectors (filtre, sıralama, preload)

4. Swipe Deck (Tinder benzeri)

- [ ] Gesture/physics, sağ-sol karar, görsel durumlar
- [ ] Rewind/undo desteği, stack yönetimi

5. Tut/Sil Aksiyonları

- [ ] Silme onayı, platform farkları, güvenli silme
- [ ] Undo snackbar + kalıcı history listesi

6. Klasör Hedefleri (Drag & Drop)

- [ ] Üst hedef şeridi (dinamik, kullanıcı tanımlı)
- [ ] Drag enter/leave highlight, drop ile taşıma
- [ ] Çakışma/izin hataları ve geri bildirim

7. Ayarlar

- [ ] Klasör yönetimi (ekle/sil/sırala)
- [ ] Varsayılanlar ve gelişmiş seçenekler

8. Parlatma ve Performans

- [ ] Skeleton/placeholder, boş ve hata durumları
- [ ] Haptics, mikro animasyonlar, a11y
- [ ] Büyük galeri optimizasyonları (cache, prefetch)

9. Test ve Yayın

- [ ] Unit + Widget testleri (deck, provider’lar)
- [ ] Basit e2e/integration (izin → swipe → undo)
- [ ] iOS/Android release ayarları ve yayın kontrol listesi

---

## Kabul Kriterleri (Örnek)

- Kullanıcı, izin verdikten sonra ilk kartı görebilmeli; sağ kaydırma fotoğrafı tutmalı, sol kaydırma silme onayını tetiklemeli.
- Kartı üst hedefe sürükleyip bırakınca dosya doğru klasöre taşınmalı ve görsel geri bildirim gösterilmeli.
- İşlem sonrası 5 sn içinde Undo yapılabilmeli; history sayfasından son 50 işlem görülebilmeli.
- 10k+ fotoğrafta kaydırma akıcı olmalı (frame drop minimal).

---

## Önerilen Paketler (pubspec.yaml)

```
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0
  photo_manager: ^3.0.0
  permission_handler: ^11.3.0
  animations: ^2.0.11
  path_provider: ^2.1.3
  logger: ^2.2.0
  intl: ^0.19.0
```

> Versiyonlar Flutter/Dart sürümünüze göre güncellenebilir.

---

## Geliştirme

```bash
flutter pub get
flutter run
```

Yapılandırmalar:

- `ios/` ve `android/` için `photo_manager` ve `permission_handler` yönergelerini uygulayın (Info.plist/AndroidManifest izinleri).
- iOS için “Photo Library Usage Description” açıklamalarını ekleyin.

---

## Test Stratejisi

- Unit: provider selector’ları, servis fonksiyonları.
- Widget: `photo_swipe_deck`, `top_folder_targets` etkileşimleri.
- Integration: izin → endeks → swipe → undo → taşıma senaryosu.

---

## Notlar

- Silme iOS’ta “Recently Deleted”e gidebilir; UI bunu açıkça iletiyor olmalı.
- Büyük albümlerde bellek kullanımını düşürmek için thumbnail boyutlarını ve cache’i sınırlayın.
