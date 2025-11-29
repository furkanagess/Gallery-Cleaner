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
      return GalleryPermissionStatus.denied;
    } catch (e) {
      debugPrint('⚠️ [PermissionsController] _readCurrentStatus error: $e');
      // Hata durumunda denied olarak döndür
      return GalleryPermissionStatus.denied;
    }
  }

  Future<bool> request() async {
    try {
      final result = await pm.PhotoManager.requestPermissionExtend();
      final ok = result.isAuth || result.hasAccess == true;
      emit(ok ? GalleryPermissionStatus.authorized : GalleryPermissionStatus.denied);
      return ok;
    } catch (e) {
      debugPrint('⚠️ [PermissionsController] request error: $e');
      emit(GalleryPermissionStatus.denied);
      return false;
    }
  }

  Future<void> openSettings() async {
    await pm.PhotoManager.openSetting();
  }
}
