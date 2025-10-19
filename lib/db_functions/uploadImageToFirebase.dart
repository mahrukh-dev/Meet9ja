import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

Future<String?> uploadImageToFirebase(File imageFile) async {
  try {
    // Create a unique file name using timestamp + original name
    String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';

    // Get Firebase Storage reference
    final storageRef = FirebaseStorage.instance.ref().child(
      'uploads/$fileName',
    );

    // Start upload
    UploadTask uploadTask = storageRef.putFile(imageFile);

    // Wait until complete
    TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);

    // Get download URL
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  } catch (e) {
    print('Error uploading image: $e');
    return null;
  }
}
