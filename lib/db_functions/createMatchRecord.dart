
// Create match record in matches collection
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> createMatchRecord(String user1Id, String user2Id, String status) async {
  try {
    final matchId = '${user1Id}_$user2Id';
    final matchRef = FirebaseFirestore.instance.collection('matches').doc(matchId);

    await matchRef.set({
      'matchId': matchId,
      'UID': user1Id,
      'matched_user_ID': user2Id,
      'status': status,
      'time_stamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('✅ Created match record: $matchId with status: $status');
  } catch (e) {
    print('❌ Error creating match record: $e');
  }
}