
// Get match history between two users
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<List<Map<String, dynamic>>> getMatchHistory(String targetUserId) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final matchSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('UID', isEqualTo: currentUser.uid)
        .where('matched_user_ID', isEqualTo: targetUserId)
        .orderBy('time_stamp', descending: true)
        .get();

    return matchSnapshot.docs.map((doc) => doc.data()).toList();
  } catch (e) {
    print('❌ Error getting match history: $e');
    return [];
  }
}