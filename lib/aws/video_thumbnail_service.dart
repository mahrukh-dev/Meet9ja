import 'dart:io';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

class VideoThumbnailService {
  // Generate thumbnail from local video file
  static Future<File?> generateThumbnailFromFile(File videoFile) async {
    try {
      final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 75,
      );

      if (thumbnailPath != null) {
        return File(thumbnailPath);
      }
      return null;
    } catch (e) {
      print('❌ Error generating thumbnail from file: $e');
      return null;
    }
  }

  // Generate thumbnail from video URL
  static Future<Uint8List?> generateThumbnailFromUrl(String videoUrl) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 75,
      );
      return uint8list;
    } catch (e) {
      print('❌ Error generating thumbnail from URL: $e');
      return null;
    }
  }

  // Upload thumbnail to Firebase Storage
  static Future<String> uploadThumbnail(
      File thumbnailFile,
      String userId,
      String postId,
      ) async {
    try {
      final String fileName = 'thumbnails/$userId/${postId}_thumbnail.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      await storageRef.putFile(thumbnailFile);
      final String downloadUrl = await storageRef.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading thumbnail: $e');
      throw 'Failed to upload thumbnail: $e';
    }
  }
}