import 'package:permission_handler/permission_handler.dart';

class PermissionService {

  // Request photo permission (handles all Android versions automatically)
  static Future<bool> requestPhotoPermission() async {
    try {
      print('📱 Requesting gallery access permission...');

      // The image_picker plugin handles Android version differences internally
      // We just need to request the appropriate permission
      Permission permission;

      // Try to use photos permission (Android 13+)
      try {
        // Check if photos permission is available
        await Permission.photos.status;
        permission = Permission.photos;
        print('📱 Using photos permission (Android 13+)');
      } catch (e) {
        // Fall back to storage permission (Android 12 and lower)
        permission = Permission.storage;
        print('📱 Using storage permission (Android 12-)');
      }

      final status = await permission.request();
      print('📱 Permission status: $status');

      return status.isGranted;
    } catch (e) {
      print('❌ Error requesting photo permission: $e');
      return false;
    }
  }

  // Check if we have photo permission
  static Future<bool> hasPhotoPermission() async {
    try {
      // Check both possible permissions
      bool hasPhotosPermission = false;
      bool hasStoragePermission = false;

      try {
        final photosStatus = await Permission.photos.status;
        hasPhotosPermission = photosStatus.isGranted;
      } catch (e) {
        // Photos permission not available on this device
        hasPhotosPermission = false;
      }

      try {
        final storageStatus = await Permission.storage.status;
        hasStoragePermission = storageStatus.isGranted;
      } catch (e) {
        // Storage permission not available on this device
        hasStoragePermission = false;
      }

      print('📱 Photos permission granted: $hasPhotosPermission');
      print('📱 Storage permission granted: $hasStoragePermission');

      return hasPhotosPermission || hasStoragePermission;
    } catch (e) {
      print('❌ Error checking permissions: $e');
      return false;
    }
  }

  // Check if permission is permanently denied
  static Future<bool> isPermissionPermanentlyDenied() async {
    try {
      bool photosPermanentlyDenied = false;
      bool storagePermanentlyDenied = false;

      try {
        final photosStatus = await Permission.photos.status;
        photosPermanentlyDenied = photosStatus.isPermanentlyDenied;
      } catch (e) {
        photosPermanentlyDenied = false;
      }

      try {
        final storageStatus = await Permission.storage.status;
        storagePermanentlyDenied = storageStatus.isPermanentlyDenied;
      } catch (e) {
        storagePermanentlyDenied = false;
      }

      return photosPermanentlyDenied || storagePermanentlyDenied;
    } catch (e) {
      print('❌ Error checking permanent denial: $e');
      return false;
    }
  }

  // Open app settings
  static Future<bool> openAppSettings() async {
    try {
      await openAppSettings();
      return true;
    } catch (e) {
      print('❌ Error opening app settings: $e');
      return false;
    }
  }
}