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
      print('📱 Starting image picker...');

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (pickedFile != null) {
        print('✅ Image picked successfully: ${pickedFile.path}');
        return File(pickedFile.path);
      } else {
        print('ℹ️ User cancelled image selection');
        return null;
      }
    } catch (e) {
      print('❌ Error in pickImageFromGallery: $e');

      if (e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('permission') ||
          e.toString().contains('Permission')) {
        throw 'Gallery access denied. Please grant photo permission in app settings.';
      } else {
        throw 'Failed to pick image. Please try again.';
      }
    }
  }

  // Pick multiple images
  static Future<List<File>> pickMultipleImagesFromGallery() async {
    try {
      print('📱 Starting multiple image picker...');

      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (pickedFiles.isNotEmpty) {
        print('✅ ${pickedFiles.length} images picked successfully');
        return pickedFiles.map((xFile) => File(xFile.path)).toList();
      } else {
        print('ℹ️ No images selected');
        return [];
      }
    } catch (e) {
      print('❌ Error in pickMultipleImagesFromGallery: $e');

      if (e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('permission')) {
        throw 'Gallery access denied. Please grant photo permission in app settings.';
      }

      throw 'Failed to pick images. Please try again.';
    }
  }

  // Upload image to Firebase Storage - IMPROVED
  static Future<String> uploadImage({
    required File imageFile,
    required String userId,
    required String imageType,
  }) async {
    try {
      print('📤 Uploading image: $imageType for user: $userId');

      if (!await imageFile.exists()) {
        throw 'Image file not found';
      }

      // Get file size for logging
      final fileLength = await imageFile.length();
      print('📁 File size: ${(fileLength / 1024 / 1024).toStringAsFixed(2)} MB');

      // Generate unique filename with user ID
      String fileName = '${userId}_${imageType}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // Create storage reference in user's folder
      Reference storageRef = _storage.ref().child('users/$userId/profile_photos/$fileName');

      print('📁 Storage path: users/$userId/profile_photos/$fileName');

      // Upload file with metadata
      UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
            'imageType': imageType,
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for completion
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Image uploaded successfully for user $userId');
      print('🔗 Download URL: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image for user $userId: $e');
      throw 'Failed to upload image. Please try again. Error: ${e.toString()}';
    }
  }

  // Upload multiple photos for first_photos - IMPROVED
  static Future<Map<String, String>> uploadFirstPhotos({
    required String userId,
    required List<File> photoFiles,
  }) async {
    try {
      print('📤 Starting upload of ${photoFiles.length} photos for user: $userId');

      if (photoFiles.isEmpty) {
        throw 'No photos to upload';
      }

      Map<String, String> photoUrls = {
        'photo1url': '',
        'photo2url': '',
        'photo3url': '',
        'photo4url': '',
      };

      // Upload each photo with error handling
      for (int i = 0; i < photoFiles.length; i++) {
        if (i >= 4) {
          print('⚠️ Maximum 4 photos allowed, skipping extras');
          break;
        }

        try {
          print('📤 Uploading photo ${i + 1} of ${photoFiles.length} for user $userId');
          String downloadUrl = await uploadImage(
            imageFile: photoFiles[i],
            userId: userId,
            imageType: 'photo${i + 1}',
          );

          photoUrls['photo${i + 1}url'] = downloadUrl;
          print('✅ Photo ${i + 1} uploaded successfully for user $userId');

        } catch (e) {
          print('❌ Failed to upload photo ${i + 1} for user $userId: $e');
          // Set empty string for failed uploads but continue with others
          photoUrls['photo${i + 1}url'] = '';
        }
      }

      print('✅ All photos processed for user $userId. Results: $photoUrls');
      return photoUrls;
    } catch (e) {
      print('❌ Error in uploadFirstPhotos for user $userId: $e');
      throw 'Failed to upload photos: ${e.toString()}';
    }
  }

  // Delete image from storage
  static Future<void> deleteImage(String imageUrl) async {
    try {
      if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
        Reference storageRef = _storage.refFromURL(imageUrl);
        await storageRef.delete();
        print('✅ Image deleted successfully');
      }
    } catch (e) {
      print('❌ Error deleting image: $e');
      // Don't throw, as this is usually for cleanup
    }
  }
}