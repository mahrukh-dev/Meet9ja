import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Uuid _uuid = Uuid();

  // Upload image to Firebase Storage
  static Future<String> uploadImage(File imageFile, String userId, String conversationId) async {
    try {
      String fileName = '${_uuid.v4()}.jpg';
      String path = 'chat_images/$conversationId/$fileName';

      TaskSnapshot snapshot = await _storage.ref(path).putFile(imageFile);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      throw 'Failed to upload image: $e';
    }
  }

  // Upload voice note to Firebase Storage
  static Future<String> uploadVoiceNote(File audioFile, String userId, String conversationId) async {
    try {
      String fileName = '${_uuid.v4()}.m4a';
      String path = 'voice_notes/$conversationId/$fileName';

      TaskSnapshot snapshot = await _storage.ref(path).putFile(
        audioFile,
        SettableMetadata(
          contentType: 'audio/mp4',
        ),
      );

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading voice note: $e');
      throw 'Failed to upload voice note: $e';
    }
  }

  // Delete file from storage
  static Future<void> deleteFile(String url) async {
    try {
      if (url.contains('firebasestorage.googleapis.com')) {
        Reference ref = _storage.refFromURL(url);
        await ref.delete();
      }
    } catch (e) {
      print('❌ Error deleting file: $e');
    }
  }
}