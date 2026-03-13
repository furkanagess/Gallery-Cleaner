part of 'swipe_page.dart';

// Public wrapper for album picker (used by swipe_tab.dart)
Future<void> presentAlbumPicker({
  required BuildContext context,
  required List<pm.AssetPathEntity> albums,
  required pm.AssetPathEntity? selectedAlbum,
  required ValueChanged<pm.AssetPathEntity?> onSelected,
}) async {
  return _presentAlbumPicker(
    context: context,
    albums: albums,
    selectedAlbum: selectedAlbum,
    onSelected: onSelected,
  );
}

// Public wrapper for delete success dialog (used by blur_tab.dart and duplicate_tab.dart)
Future<void> showDeleteSuccessDialog(
  BuildContext context,
  int deletedCount, {
  double deletedSizeMB = 0.0,
}) async {
  return _showDeleteSuccessDialog(
    context,
    deletedCount,
    deletedSizeMB: deletedSizeMB,
  );
}


