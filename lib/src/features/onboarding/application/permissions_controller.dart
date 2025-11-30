import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

enum GalleryPermissionStatus {
  unknown,
  authorized,
  denied,
  permanentlyDenied, // Not distinguished currently; treated as denied in logic
}

class PermissionsCubit extends Cubit<GalleryPermissionStatus> {
  PermissionsCubit() : super(GalleryPermissionStatus.unknown);

  Future<void> refresh() async {
    try {
      final status = await _readCurrentStatus();
      emit(status);
    } catch (e) {
      // iOS'ta ilk girişte PhotoManager henüz hazır olmayabilir
      debugPrint('⚠️ [PermissionsController] refresh error: $e');
      // Hata durumunda denied olarak işaretle
      emit(GalleryPermissionStatus.denied);
    }
  }

  Future<GalleryPermissionStatus> _readCurrentStatus() async {
    try {
      final state = await pm.PhotoManager.getPermissionState(
        requestOption: const pm.PermissionRequestOption(
          iosAccessLevel: pm.IosAccessLevel.readWrite,
        ),
      );
      if (state == pm.PermissionState.authorized ||
          state == pm.PermissionState.limited) {
        return GalleryPermissionStatus.authorized;
      }
      if (state == pm.PermissionState.denied) {
        return GalleryPermissionStatus.denied;
      }
      // NotDetermined veya başka bir durum - unknown olarak döndür
      return GalleryPermissionStatus.unknown;
    } catch (e) {
      debugPrint('⚠️ [PermissionsController] _readCurrentStatus error: $e');
      // Hata durumunda unknown olarak döndür (böylece dialog açılabilir)
      return GalleryPermissionStatus.unknown;
    }
  }

  Future<bool> request() async {
    try {
      // Butona her tıklandığında direkt sistem izin dialogunu aç
      // İzin durumunu hiç kontrol etmeden direkt requestPermissionExtend() çağır
      // Bu metod sistem izin dialogunu göstermeye çalışır
      // requestPermissionExtend() metodu:
      // - Eğer izin durumu "notDetermined" (ilk defa) ise → sistem dialogunu gösterir
      // - Eğer izin durumu "denied" ise → sistem dialogu gösterilmez (iOS/Android platform davranışı)
      // - Eğer izin durumu "authorized" ise → zaten izin verilmiş, dialog gösterilmez
      final result = await pm.PhotoManager.requestPermissionExtend(
        requestOption: const pm.PermissionRequestOption(
          iosAccessLevel: pm.IosAccessLevel.readWrite,
        ),
      );

      // İzin durumunu güncelle
      final ok = result.isAuth || result.hasAccess == true;
      if (ok) {
        emit(GalleryPermissionStatus.authorized);
      } else {
        // İzin verilmedi - durumu kontrol et
        final currentState = await pm.PhotoManager.getPermissionState(
          requestOption: const pm.PermissionRequestOption(
            iosAccessLevel: pm.IosAccessLevel.readWrite,
          ),
        );

        if (currentState == pm.PermissionState.authorized ||
            currentState == pm.PermissionState.limited) {
          emit(GalleryPermissionStatus.authorized);
        } else {
          // Denied veya notDetermined - unknown olarak işaretle
          // Kullanıcı tekrar butona tıklayabilir
          emit(GalleryPermissionStatus.unknown);
        }
      }

      return ok;
    } catch (e) {
      debugPrint('⚠️ [PermissionsController] İzin isteği hatası: $e');
      emit(GalleryPermissionStatus.unknown);
      return false;
    }
  }

  Future<void> openSettings() async {
    await pm.PhotoManager.openSetting();
  }
}
