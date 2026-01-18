import 'package:cloud_firestore/cloud_firestore.dart';

/// Get user age from Firestore by user ID
Future<int?> getUserAgeFin(String uid) async {
  try {
    print('📋 Fetching age for user UID: $uid');

    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (docSnapshot.exists) {
      final age = docSnapshot.data()?['age'] as int?;
      print('✅ User age retrieved: ${age ?? "not set"}');
      return age;
    } else {
      print('⚠️ User document not found for UID: $uid');
      return null;
    }
  } catch (e) {
    print('❌ Error fetching user age: $e');
    return null;
  }
}