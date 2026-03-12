import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

Future<int> estimateAssetSize(pm.AssetEntity asset) async {
  try {
    bool? isLocal;
    try {
      isLocal = await asset.isLocallyAvailable();
      if (isLocal == false) {
        debugPrint(
          '⚠️ [AssetSizeHelper] Asset ${asset.id} is not stored locally. Skipping file read.',
        );
        throw const _RemoteAssetException();
      }
    } catch (e) {
      debugPrint(
        '⚠️ [AssetSizeHelper] Could not determine local availability for asset ${asset.id}: $e',
      );
    }

    final file = await asset.file;
    if (file != null) {
      final exists = await file.exists();
      if (exists) {
        return await file.length();
      }
    }
  } on _RemoteAssetException {
    // Asset is stored in iCloud / not locally available. We'll fall back to thumbnail size.
  } on PlatformException catch (e) {
    debugPrint(
      '⚠️ [AssetSizeHelper] Platform exception while reading asset file (${asset.id}): ${e.code} - ${e.message}',
    );
  } on FileSystemException catch (e) {
    debugPrint(
      '⚠️ [AssetSizeHelper] File system exception while reading asset file (${asset.id}): ${e.message}',
    );
  } catch (e) {
    debugPrint(
      '⚠️ [AssetSizeHelper] Unexpected error while reading asset file (${asset.id}): $e',
    );
  }

  try {
    final Uint8List? thumb = await asset.thumbnailData;
    if (thumb != null) {
      return thumb.lengthInBytes;
    }
  } catch (e) {
    debugPrint(
      '⚠️ [AssetSizeHelper] Failed to obtain thumbnail size for asset (${asset.id}): $e',
    );
  }

  return 0;
}

class _RemoteAssetException implements Exception {
  const _RemoteAssetException();
}
