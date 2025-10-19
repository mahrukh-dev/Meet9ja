// Check if there's a match between two users
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<bool> checkForMatch(String targetUserId) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final matchSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('UID', isEqualTo: currentUser.uid)
        .where('matched_user_ID', isEqualTo: targetUserId)
        .where('status', isEqualTo: 'match')
        .limit(1)
        .get();

    return matchSnapshot.docs.isNotEmpty;
  } catch (e) {
    print('❌ Error checking for match: $e');
    return false;
  }
}