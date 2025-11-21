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

  // Pick video from gallery
  static Future<File?> pickVideoFromGallery() async {
    try {
      print('📱 Starting video picker...');

      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5), // 5 minute limit
      );

      if (pickedFile != null) {
        print('✅ Video picked successfully: ${pickedFile.path}');
        return File(pickedFile.path);
      } else {
        print('ℹ️ User cancelled video selection');
        return null;
      }
    } catch (e) {
      print('❌ Error in pickVideoFromGallery: $e');

      if (e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('permission') ||
          e.toString().contains('Permission')) {
        throw 'Gallery access denied. Please grant video permission in app settings.';
      } else {
        throw 'Failed to pick video. Please try again.';
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

  // Upload image to Firebase Storage
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

  // Upload post image
  static Future<String> uploadPostImage({
    required File imageFile,
    required String userId,
  }) async {
    try {
      print('📤 Uploading post image for user: $userId');

      // Generate unique filename
      String fileName = '${userId}_post_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // Create storage reference in user's posts folder
      Reference storageRef = _storage.ref().child('users/$userId/posts/$fileName');

      print('📁 Storage path: users/$userId/posts/$fileName');

      // Upload file
      UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
            'type': 'post',
          },
        ),
      );

      // Wait for completion
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Post image uploaded successfully');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading post image: $e');
      throw 'Failed to upload post image: $e';
    }
  }

  // Upload post video
  static Future<String> uploadPostVideo({
    required File videoFile,
    required String userId,
  }) async {
    try {
      print('📤 Uploading post video for user: $userId');

      // Generate unique filename
      String fileName = '${userId}_post_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Create storage reference in user's posts folder
      Reference storageRef = _storage.ref().child('users/$userId/posts/$fileName');

      print('📁 Storage path: users/$userId/posts/$fileName');

      // Get file size for logging
      final fileLength = await videoFile.length();
      print('📁 Video file size: ${(fileLength / 1024 / 1024).toStringAsFixed(2)} MB');

      // Upload file with metadata
      UploadTask uploadTask = storageRef.putFile(
        videoFile,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
            'type': 'post_video',
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Video upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for completion
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Post video uploaded successfully');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading post video: $e');
      throw 'Failed to upload video: ${e.toString()}';
    }
  }

  // Upload story media
  static Future<String> uploadStoryMedia({
    required File mediaFile,
    required String userId,
    required String mediaType, // 'image' or 'video'
  }) async {
    try {
      print('📤 Uploading story media for user: $userId');

      // Generate unique filename
      String fileExtension = path.extension(mediaFile.path);
      String fileName = '${userId}_story_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      // Create storage reference in user's stories folder
      Reference storageRef = _storage.ref().child('users/$userId/stories/$fileName');

      print('📁 Storage path: users/$userId/stories/$fileName');

      // Upload file
      UploadTask uploadTask = storageRef.putFile(
        mediaFile,
        SettableMetadata(
          contentType: mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
            'type': 'story',
            'mediaType': mediaType,
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Story upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for completion
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Story media uploaded successfully');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading story media: $e');
      throw 'Failed to upload story: $e';
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

  // Delete video from storage
  static Future<void> deleteVideo(String videoUrl) async {
    try {
      if (videoUrl.isNotEmpty && videoUrl.startsWith('http')) {
        Reference storageRef = _storage.refFromURL(videoUrl);
        await storageRef.delete();
        print('✅ Video deleted successfully');
      }
    } catch (e) {
      print('❌ Error deleting video: $e');
      // Don't throw, as this is usually for cleanup
    }
  }

  // Delete story media from storage
  static Future<void> deleteStoryMedia(String mediaUrl) async {
    try {
      if (mediaUrl.isNotEmpty && mediaUrl.startsWith('http')) {
        Reference storageRef = _storage.refFromURL(mediaUrl);
        await storageRef.delete();
        print('✅ Story media deleted successfully');
      }
    } catch (e) {
      print('❌ Error deleting story media: $e');
      // Don't throw, as this is for cleanup
    }
  }
}