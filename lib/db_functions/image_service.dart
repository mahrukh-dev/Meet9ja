import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class ImageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _imagePicker = ImagePicker();

  // Pick image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('❌ Error picking image: $e');
      throw 'Failed to pick image: $e';
    }
  }

  // Upload image to Firebase Storage and return download URL
  static Future<String> uploadImage({
    required File imageFile,
    required String userId,
    required String imageType, // 'profile', 'photo1', 'photo2', etc.
  }) async {
    try {
      print('📤 Uploading image: $imageType for user: $userId');

      // Generate unique filename
      String fileName = '${userId}_${imageType}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // Create reference
      Reference storageRef = _storage.ref().child('users/$userId/$fileName');

      // Upload file
      UploadTask uploadTask = storageRef.putFile(imageFile);

      // Wait for upload to complete
      TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      throw 'Failed to upload image: $e';
    }
  }

  // Upload multiple photos for first_photos
  static Future<Map<String, String>> uploadFirstPhotos({
    required String userId,
    required List<File> photoFiles,
  }) async {
    try {
      print('📤 Uploading ${photoFiles.length} photos for user: $userId');

      Map<String, String> photoUrls = {
        'photo1url': '',
        'photo2url': '',
        'photo3url': '',
        'photo4url': '',
      };

      // Upload each photo
      for (int i = 0; i < photoFiles.length; i++) {
        if (i >= 4) break; // Maximum 4 photos

        try {
          String downloadUrl = await uploadImage(
            imageFile: photoFiles[i],
            userId: userId,
            imageType: 'photo${i + 1}',
          );

          photoUrls['photo${i + 1}url'] = downloadUrl;
          print('✅ Photo ${i + 1} uploaded successfully');
        } catch (e) {
          print('❌ Failed to upload photo ${i + 1}: $e');
          // Continue with other photos even if one fails
        }
      }

      return photoUrls;
    } catch (e) {
      print('❌ Error uploading first photos: $e');
      throw 'Failed to upload photos: $e';
    }
  }

  // Delete image from storage
  static Future<void> deleteImage(String imageUrl) async {
    try {
      if (imageUrl.isNotEmpty) {
        Reference storageRef = _storage.refFromURL(imageUrl);
        await storageRef.delete();
        print('✅ Image deleted successfully');
      }
    } catch (e) {
      print('❌ Error deleting image: $e');
      // Don't throw error for delete failures
    }
  }
}