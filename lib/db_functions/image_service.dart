import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meet9ja/db_functions/permission_service.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
class ImageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _imagePicker = ImagePicker();

  // Pick image from gallery with robust permission handling
  static Future<File?> pickImageFromGallery() async {
    try {
      print('📱 Starting image picker process...');

      // First, check if we have permission
      bool hasPermission = await PermissionService.hasPhotoPermission();

      if (!hasPermission) {
        print('📱 Requesting photo permission...');
        hasPermission = await PermissionService.requestPhotoPermission();

        if (!hasPermission) {
          throw 'Gallery access permission denied. Please enable photo access in your device settings.';
        }
      }

      print('📱 Permission granted, picking image...');
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

      // Handle permission-related errors
      if (e.toString().contains('permission') ||
          e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('Permission')) {
        throw 'Photo access permission required. Please grant permission in app settings to select photos.';
      }

      throw 'Failed to pick image: $e';
    }
  }

  // Pick multiple images
  static Future<List<File>> pickMultipleImagesFromGallery() async {
    try {
      print('📱 Starting multiple image picker process...');

      // Check permission first
      bool hasPermission = await PermissionService.hasPhotoPermission();

      if (!hasPermission) {
        hasPermission = await PermissionService.requestPhotoPermission();

        if (!hasPermission) {
          throw 'Gallery access permission denied. Please enable photo access in your device settings.';
        }
      }

      print('📱 Permission granted, picking multiple images...');
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

      if (e.toString().contains('permission') ||
          e.toString().contains('PERMISSION_DENIED')) {
        throw 'Photo access permission required. Please grant permission in app settings to select photos.';
      }

      throw 'Failed to pick images: $e';
    }
  }

  // Upload image to Firebase Storage
  static Future<String> uploadImage({
    required File imageFile,
    required String userId,
    required String imageType,
  }) async {
    try {
      print('📤 Uploading image: $imageType for user: $userId');

      // Validate file
      if (!await imageFile.exists()) {
        throw 'Image file not found or inaccessible';
      }

      // Generate unique filename
      String fileName = '${userId}_${imageType}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // Create storage reference
      Reference storageRef = _storage.ref().child('users/$userId/$fileName');

      // Upload file with metadata
      UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for completion
      TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Image uploaded successfully. URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      throw 'Failed to upload image. Please try again.';
    }
  }

  // Upload multiple photos for first_photos
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
          print('📤 Uploading photo ${i + 1} of ${photoFiles.length}');
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
          photoUrls['photo${i + 1}url'] = '';
        }
      }

      print('✅ All photos processed. Results: $photoUrls');
      return photoUrls;
    } catch (e) {
      print('❌ Error in uploadFirstPhotos: $e');
      throw 'Failed to upload photos: ${e.toString()}';
    }
  }

  // Delete image from storage (optional cleanup)
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