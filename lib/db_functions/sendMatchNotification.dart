
// Send match notification (placeholder for notification service)
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> sendMatchNotification(String user1Id, String user2Id) async {
  try {
    // Get user names for notification
    final user1Doc = await FirebaseFirestore.instance.collection('users').doc(user1Id).get();
    final user2Doc = await FirebaseFirestore.instance.collection('users').doc(user2Id).get();

    final user1Name = user1Doc.data()?['name'] ?? 'Someone';
    final user2Name = user2Doc.data()?['name'] ?? 'Someone';

    // Create notification for user 1
    await FirebaseFirestore.instance.collection('notifications').add({
      'UID': user1Id,
      'title': 'It\'s a match! 🎉',
      'message': 'You and $user2Name have liked each other',
      'type': 'match',
      'related_user_id': user2Id,
      'read': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Create notification for user 2
    await FirebaseFirestore.instance.collection('notifications').add({
      'UID': user2Id,
      'title': 'It\'s a match! 🎉',
      'message': 'You and $user1Name have liked each other',
      'type': 'match',
      'related_user_id': user1Id,
      'read': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    print('✅ Match notifications sent');
  } catch (e) {
    print('❌ Error sending match notifications: $e');
  }
}

