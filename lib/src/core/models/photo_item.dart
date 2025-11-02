import 'package:photo_manager/photo_manager.dart' as pm;

class PhotoItem {
  final String id;
  final int width;
  final int height;
  final DateTime? createDateTime;
  final DateTime? modifiedDateTime;
  final pm.AssetType type;

  const PhotoItem({
    required this.id,
    required this.width,
    required this.height,
    required this.createDateTime,
    required this.modifiedDateTime,
    required this.type,
  });

  static PhotoItem fromAsset(pm.AssetEntity entity) {
    return PhotoItem(
      id: entity.id,
      width: entity.width,
      height: entity.height,
      createDateTime: entity.createDateTime,
      modifiedDateTime: entity.modifiedDateTime,
      type: entity.type,
    );
  }
}


