// Get user's matches
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<List<Map<String, dynamic>>> getUserMatches() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final matchesSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('UID', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'match')
        .orderBy('time_stamp', descending: true)
        .get();

    final matches = matchesSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

    // Get detailed user info for each match
    final List<Future<Map<String, dynamic>>> matchFutures = matches.map((match) async {
      final matchedUserId = match['matched_user_ID'] as String;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(matchedUserId)
          .get();

      return {
        ...match,
        'matched_user': userDoc.data(),
      };
    }).toList();

    final detailedMatches = await Future.wait(matchFutures);
    return detailedMatches;
  } catch (e) {
    print('❌ Error getting user matches: $e');
    return [];
  }
}