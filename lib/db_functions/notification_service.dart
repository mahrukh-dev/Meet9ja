// lib/db_functions/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;


  // Trigger when someone likes post
  static Future<void> onPostLike({
    required String targetUserId,
    required String postId,
  }) async {
    await NotificationService.createNotification(
      type: 'post_like',
      targetUserId: targetUserId,
      postId: postId,
    );
  }

  // Create a notification
  static Future<void> createNotification({
    required String type,
    required String targetUserId,
    String? relatedUserId,
    String? postId,
    String? commentText,
    String? matchId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get current user data for notification details
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!currentUserDoc.exists) return;

      final currentUserData = currentUserDoc.data()!;
      final currentUserName = currentUserData['name'] ?? 'Someone';
      final currentUserPhoto =
          currentUserData['first_photos']?['photo1url'] ?? '';

      // Create notification data
      final notificationData = {
        'id': '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}',
        'type': type,
        'fromUserId': currentUser.uid,
        'fromUserName': currentUserName,
        'fromUserPhoto': currentUserPhoto,
        'targetUserId': targetUserId,
        'relatedUserId': relatedUserId,
        'postId': postId,
        'commentText': commentText,
        'matchId': matchId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add to notifications collection
      await _firestore
          .collection('notifications')
          .doc(notificationData['id'])
          .set(notificationData);

      print('✅ Notification created: $type for user $targetUserId');
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  // Get user notifications stream
  static Stream<QuerySnapshot> getUserNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  static Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('targetUserId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }

  // Get unread notifications count
  static Stream<int> getUnreadNotificationsCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }
}

// Notification triggers for different activities
class NotificationTriggers {
  // Trigger when someone likes profile
  static Future<void> onProfileLike(String targetUserId) async {
    await NotificationService.createNotification(
      type: 'profile_like',
      targetUserId: targetUserId,
    );
  }

  // Trigger when someone likes a post - FIXED
  static Future<void> onPostLike({
    required String targetUserId,
    required String postId,
    required String likerUserId,
  }) async {
    // Only send notification if the liker is not the post owner
    if (targetUserId != likerUserId) {
      await NotificationService.createNotification(
        type: 'post_like',
        targetUserId: targetUserId,
        postId: postId,
        relatedUserId: likerUserId,
      );
    }
  }

  // Trigger when someone goes live - NEW
  static Future<void> onUserLive({
    required String userId,
    required String liveId,
    required String liveTitle,
  }) async {
    // Get user's followers
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data()!;
      final followers = List<String>.from(userData['followers'] ?? []);

      // Send notification to all followers
      for (final followerId in followers) {
        await NotificationService.createNotification(
          type: 'user_live',
          targetUserId: followerId,
          relatedUserId: userId,
          matchId: liveId,
          commentText: liveTitle, // Using commentText field for live title
        );
      }
    }
  }

  // Trigger when live ends - NEW
  static Future<void> onLiveEnded({
    required String userId,
    required String liveId,
    required int viewerCount,
  }) async {
    await NotificationService.createNotification(
      type: 'live_ended',
      targetUserId: userId,
      matchId: liveId,
      commentText: 'Your live ended with $viewerCount viewers',
    );
  }

  // Trigger when someone gifts during live - NEW
  static Future<void> onLiveGift({
    required String targetUserId,
    required String gifterUserId,
    required String giftType,
    required int giftValue,
  }) async {
    await NotificationService.createNotification(
      type: 'live_gift',
      targetUserId: targetUserId,
      relatedUserId: gifterUserId,
      commentText: 'Sent you $giftType worth $giftValue coins',
    );
  }


  // Trigger when it's a mutual match
  static Future<void> onMutualMatch(String user1Id, String user2Id) async {
    // Create notification for user1
    await NotificationService.createNotification(
      type: 'mutual_match',
      targetUserId: user1Id,
      relatedUserId: user2Id,
      matchId: '${user1Id}_$user2Id',
    );

    // Create notification for user2
    await NotificationService.createNotification(
      type: 'mutual_match',
      targetUserId: user2Id,
      relatedUserId: user1Id,
      matchId: '${user1Id}_$user2Id',
    );
  }

  // Trigger when someone comments on post
  static Future<void> onPostComment({
    required String targetUserId,
    required String postId,
    required String commentText,
  }) async {
    await NotificationService.createNotification(
      type: 'post_comment',
      targetUserId: targetUserId,
      postId: postId,
      commentText: commentText,
    );
  }



  // Trigger when someone follows
  static Future<void> onFollow({required String targetUserId}) async {
    await NotificationService.createNotification(
      type: 'follow',
      targetUserId: targetUserId,
    );
  }

  // Trigger when someone sends a message
  static Future<void> onNewMessage({
    required String targetUserId,
    required String chatId,
  }) async {
    await NotificationService.createNotification(
      type: 'new_message',
      targetUserId: targetUserId,
      matchId: chatId,
    );
  }

  // Trigger when someone views story
  static Future<void> onStoryView({required String targetUserId}) async {
    await NotificationService.createNotification(
      type: 'story_view',
      targetUserId: targetUserId,
    );
  }

  // Trigger when someone sends a gift
  static Future<void> onGiftSent({required String targetUserId}) async {
    await NotificationService.createNotification(
      type: 'gift_received',
      targetUserId: targetUserId,
    );
  }
}
