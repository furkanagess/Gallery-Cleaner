import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

/// Silme hakkı sıfırlanma takip servisi
/// Firestore'da kaç kullanıcının silme hakkını bitirdiğini takip eder
class DeleteLimitTrackerService {
  static DeleteLimitTrackerService? _instance;
  static DeleteLimitTrackerService get instance {
    _instance ??= DeleteLimitTrackerService._();
    return _instance!;
  }

  DeleteLimitTrackerService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Genel analytics için
  static const String _collectionPath = 'analytics';
  static const String _documentId = 'delete_limit_stats';
  static const String _counterField = 'usersReachedZeroCount';

  /// Silme hakkı sıfıra düştüğünde çağrılır
  /// Analytics counter'ı 1 artırır
  Future<void> trackDeleteLimitReachedZero() async {
    try {
      AppLogger.i(
        '📊 [DeleteLimitTracker] Silme hakkı sıfırlandı, Firestore\'a kayıt ekleniyor...',
      );

      final analyticsDocRef = _firestore
          .collection(_collectionPath)
          .doc(_documentId);

      await analyticsDocRef.set(
        {
          _counterField: FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      AppLogger.i(
        '✅ [DeleteLimitTracker] Analytics counter güncellendi',
      );
    } catch (e, stackTrace) {
      _handleFirestoreError(e, 'analytics', stackTrace);
      // Hata olsa bile uygulamanın çalışmaya devam etmesi için hata fırlatmıyoruz
    }
  }

  /// Firestore hatalarını özel olarak handle et
  void _handleFirestoreError(dynamic error, String collection, [StackTrace? stackTrace]) {
    final errorString = error.toString();
    
    // Permission-denied hatasını özel olarak handle et
    if (errorString.contains('permission-denied') || 
        errorString.contains('PERMISSION_DENIED')) {
      AppLogger.w(
        '⚠️ [DeleteLimitTracker] Firestore güvenlik kuralları hatası ($collection). '
        'Firebase Console\'dan güvenlik kurallarını ayarlamanız gerekiyor. '
        'Detaylar için FIRESTORE_SECURITY_RULES.md dosyasına bakın.',
      );
      AppLogger.w(
        '📝 [DeleteLimitTracker] Gerekli kurallar: '
        'analytics collection\'ı için read/write izinleri',
      );
    } else {
      // Diğer hatalar
      AppLogger.e(
        '❌ [DeleteLimitTracker] Firestore hatası ($collection): $error',
        error,
        stackTrace,
      );
    }
    // Hata olsa bile uygulamanın çalışmaya devam etmesi için hata fırlatmıyoruz
  }

  /// Toplam kaç kullanıcının silme hakkını bitirdiğini al
  /// (Admin/analiz amaçlı kullanılabilir)
  Future<int> getTotalUsersReachedZero() async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(_documentId)
          .get();

      if (!doc.exists) {
        return 0;
      }

      final data = doc.data();
      return data?[_counterField] as int? ?? 0;
    } catch (e, stackTrace) {
      AppLogger.e(
        '❌ [DeleteLimitTracker] Firestore okuma hatası: $e',
        e,
        stackTrace,
      );
      return 0;
    }
  }

}

