
// Create mutual match when both users like each other
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meet9ja/db_functions/sendMatchNotification.dart';

import 'notification_service.dart';

Future<void> createMutualMatch(String user1Id, String user2Id) async {
  try {
    final matchId = '${user1Id}_$user2Id';
    final mutualMatchId = 'mutual_$matchId';

    final matchRef = FirebaseFirestore.instance.collection('matches').doc(mutualMatchId);

    await matchRef.set({
      'matchId': mutualMatchId,
      'UID': user1Id,
      'matched_user_ID': user2Id,
      'status': 'match',
      'time_stamp': FieldValue.serverTimestamp(),
      'is_mutual': true,
    });

    // Update both users' matches array
    final batch = FirebaseFirestore.instance.batch();

    final user1Ref = FirebaseFirestore.instance.collection('users').doc(user1Id);
    batch.update(user1Ref, {
      'matches': FieldValue.arrayUnion([mutualMatchId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    final user2Ref = FirebaseFirestore.instance.collection('users').doc(user2Id);
    batch.update(user2Ref, {
      'matches': FieldValue.arrayUnion([mutualMatchId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    print('🎉 Mutual match created between $user1Id and $user2Id');

    // You could trigger a notification here

    // Trigger mutual match notifications for BOTH users
    await NotificationTriggers.onMutualMatch(user1Id, user2Id);

    await sendMatchNotification(user1Id, user2Id);

  } catch (e) {
    print('❌ Error creating mutual match: $e');
  }
}
