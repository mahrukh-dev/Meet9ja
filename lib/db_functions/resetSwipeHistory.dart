// Reset user's swipe history (for testing or account reset)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> resetSwipeHistory() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw 'User not logged in';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .update({
      'liked_profiles': [],
      'passed_profiles': [],
      'updated_at': FieldValue.serverTimestamp(),
    });

    print('✅ Swipe history reset');
  } catch (e) {
    print('❌ Error resetting swipe history: $e');
    throw 'Failed to reset swipe history: $e';
  }
}