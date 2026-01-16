// Create mutual match when both users like each other
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meet9ja/db_functions/sendMatchNotification.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

Future<void> createMutualMatch(String user1Id, String user2Id) async {
  try {
    final matchId = '${user1Id}_$user2Id';
    final mutualMatchId = 'mutual_$matchId';

    // Get both users' data for notifications
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final user1Doc = await firestore.collection('users').doc(user1Id).get();
    final user2Doc = await firestore.collection('users').doc(user2Id).get();

    if (!user1Doc.exists || !user2Doc.exists) {
      print('❌ One or both users not found');
      return;
    }

    final user1Data = user1Doc.data()!;
    final user2Data = user2Doc.data()!;

    final user1Name = user1Data['name'] ?? 'User';
    final user2Name = user2Data['name'] ?? 'User';

    // Helper function to get first photo URL
    String? getFirstPhotoUrl(Map<String, dynamic>? photos) {
      if (photos == null) return null;
      for (var i = 1; i <= 4; i++) {
        final photoUrl = photos['photo${i}url']?.toString();
        if (photoUrl != null && photoUrl.isNotEmpty && photoUrl != 'null') {
          return photoUrl;
        }
      }
      return null;
    }

    final user1Photo = getFirstPhotoUrl(user1Data['first_photos']);
    final user2Photo = getFirstPhotoUrl(user2Data['first_photos']);

    // Create match document
    final matchRef = firestore.collection('matches').doc(mutualMatchId);
    await matchRef.set({
      'matchId': mutualMatchId,
      'user1Id': user1Id,
      'user1Name': user1Name,
      'user2Id': user2Id,
      'user2Name': user2Name,
      'user1Photo': user1Photo,
      'user2Photo': user2Photo,
      'status': 'match',
      'time_stamp': FieldValue.serverTimestamp(),
      'is_mutual': true,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Update both users' matches array
    final batch = firestore.batch();

    final user1Ref = firestore.collection('users').doc(user1Id);
    batch.update(user1Ref, {
      'matches': FieldValue.arrayUnion([mutualMatchId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    final user2Ref = firestore.collection('users').doc(user2Id);
    batch.update(user2Ref, {
      'matches': FieldValue.arrayUnion([mutualMatchId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    print('🎉 Mutual match created between $user1Name and $user2Name');

    // Trigger mutual match notifications for BOTH users
    await NotificationTriggers.onMutualMatch(
      user1Id: user1Id,
      user1Name: user1Name,
      user1Photo: user1Photo,
      user2Id: user2Id,
      user2Name: user2Name,
      user2Photo: user2Photo,
      matchId: mutualMatchId,
    );

    // Optional: Also call sendMatchNotification if you have that function
    await sendMatchNotification(user1Id, user2Id);

  } catch (e) {
    print('❌ Error creating mutual match: $e');
  }
}