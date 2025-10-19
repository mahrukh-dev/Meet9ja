import 'package:permission_handler/permission_handler.dart';

class PermissionService {

  // Request photo permission (handles all Android versions automatically)
  static Future<bool> requestPhotoPermission() async {
    try {
      print('📱 Requesting gallery access permission...');

      // Let image_picker handle the permission internally
      // We'll just check if we have any form of gallery access
      bool hasPermission = await hasPhotoPermission();

      if (!hasPermission) {
        print('📱 No permission found, requesting...');

        // Request the most appropriate permission
        PermissionStatus status;

        try {
          // Try Android 13+ photos permission first
          status = await Permission.photos.request();
          print('📱 Android 13+ photos permission result: $status');
        } catch (e) {
          // Fall back to storage permission for older Android
          print('📱 Falling back to storage permission');
          status = await Permission.storage.request();
          print('📱 Storage permission result: $status');
        }

        return status.isGranted;
      }

      return true;
    } catch (e) {
      print('❌ Error requesting photo permission: $e');
      return false;
    }
  }

  // Check if we have photo permission - SIMPLIFIED VERSION
  static Future<bool> hasPhotoPermission() async {
    try {
      print('📱 Checking photo permissions...');

      // Check both permissions
      final photosStatus = await Permission.photos.status;
      final storageStatus = await Permission.storage.status;

      print('📱 Photos permission: $photosStatus');
      print('📱 Storage permission: $storageStatus');

      bool hasAccess = photosStatus.isGranted || storageStatus.isGranted;
      print('📱 Has gallery access: $hasAccess');

      return hasAccess;
    } catch (e) {
      print('❌ Error checking photo permissions: $e');
      return false;
    }
  }

  // Check if permission is permanently denied
  static Future<bool> isPermissionPermanentlyDenied() async {
    try {
      final photosStatus = await Permission.photos.status;
      final storageStatus = await Permission.storage.status;

      return photosStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied;
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