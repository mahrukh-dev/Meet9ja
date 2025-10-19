
// Get current user profile
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<Map<String, dynamic>?> getCurrentUserProfile() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data();
  } catch (e) {
    print('❌ Error getting current user profile: $e');
    return null;
  }
}
