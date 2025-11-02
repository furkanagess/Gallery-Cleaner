import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

enum GalleryPermissionStatus {
  unknown,
  authorized,
  denied,
  permanentlyDenied, // Not distinguished currently; treated as denied in logic
}

class PermissionsController extends StateNotifier<GalleryPermissionStatus> {
  PermissionsController() : super(GalleryPermissionStatus.unknown);

  Future<void> refresh() async {
    final status = await _readCurrentStatus();
    state = status;
  }

  Future<GalleryPermissionStatus> _readCurrentStatus() async {
    // Check permission status without prompting dialog
    // requestPermissionExtend() won't show dialog if permission was already granted/denied
    final result = await pm.PhotoManager.requestPermissionExtend();
    if (result.isAuth) return GalleryPermissionStatus.authorized;
    // Check if access was previously granted (but might need refresh)
    if (result.hasAccess == true) return GalleryPermissionStatus.authorized;
    return GalleryPermissionStatus.denied;
  }

  Future<bool> request() async {
    final result = await pm.PhotoManager.requestPermissionExtend();
    final ok = result.isAuth || result.hasAccess == true;
    state = ok ? GalleryPermissionStatus.authorized : GalleryPermissionStatus.denied;
    return ok;
  }

  Future<void> openSettings() async {
    await pm.PhotoManager.openSetting();
  }
}

final permissionsControllerProvider =
    StateNotifierProvider<PermissionsController, GalleryPermissionStatus>((ref) {
  return PermissionsController();
});


