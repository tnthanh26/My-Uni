import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ImageUploadHelper {
  /// Picks an image file and uploads it to Firebase Storage.
  /// Returns the download URL or null if cancelled/failed.
  static Future<String?> pickAndUploadImage({
    required String folder,
    void Function(bool uploading)? onUploadingStateChanged,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      onUploadingStateChanged?.call(true);

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('Không đọc được dữ liệu ảnh.');
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^\w\.\-]'), '_')}';
      final storageRef = FirebaseStorage.instance.ref().child(
        '$folder/$fileName',
      );

      final uploadTask = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: _getContentType(file.extension)),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      onUploadingStateChanged?.call(false);
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      onUploadingStateChanged?.call(false);
      rethrow;
    }
  }

  static String _getContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
