// Update user profile
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> updateUserProfile(Map<String, dynamic> updates) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'No user logged in';

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      ...updates,
      'updated_at': FieldValue.serverTimestamp(),
    });
    print('✅ User profile updated successfully');
  } catch (e) {
    print('❌ Error updating user profile: $e');
    throw 'Failed to update profile: $e';
  }
}
