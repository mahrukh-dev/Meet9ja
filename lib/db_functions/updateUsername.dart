// Update username
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'isUsernameAvailable.dart';

Future<void> updateUsername(String newUsername) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'No user logged in';

    // Check if new username is available
    final isAvailable = await isUsernameAvailable(newUsername);
    if (!isAvailable) {
      throw 'Username "$newUsername" is already taken. Please choose another one.';
    }

    // Update in Firestore
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'username': newUsername.toLowerCase(),
      'username_lowercase': newUsername.toLowerCase(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Update in Firebase Auth display name
    await user.updateDisplayName(newUsername);

    print('✅ Username updated successfully to: $newUsername');
  } catch (e) {
    print('❌ Error updating username: $e');
    rethrow;
  }
}