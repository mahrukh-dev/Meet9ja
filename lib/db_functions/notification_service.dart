// lib/db_functions/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper function to get first photo URL
  static String? getFirstPhotoUrl(Map<String, dynamic>? photos) {
    if (photos == null) return null;
    for (var i = 1; i <= 4; i++) {
      final photoUrl = photos['photo${i}url']?.toString();
      if (photoUrl != null && photoUrl.isNotEmpty && photoUrl != 'null') {
        return photoUrl;
      }
    }
    return null;
  }

  // Create a notification
  static Future<void> createNotification({
    required String type,
    required String targetUserId,
    String? fromUserId,
    String? fromUserName,
    String? fromUserPhoto,
    String? relatedUserId,
    String? postId,
    String? commentText,
    String? matchId,
  }) async {
    try {
      String notificationFromUserId;
      String notificationFromUserName;
      String notificationFromUserPhoto;

      // For mutual match notifications, use provided user data
      if (type == 'mutual_match' && fromUserId != null && fromUserName != null) {
        notificationFromUserId = fromUserId;
        notificationFromUserName = fromUserName;
        notificationFromUserPhoto = fromUserPhoto ?? '';
      } else {
        // For other notifications, use current user data
        final currentUser = _auth.currentUser;
        if (currentUser == null) return;

        final currentUserDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (!currentUserDoc.exists) return;

        final currentUserData = currentUserDoc.data()!;
        notificationFromUserId = currentUser.uid;
        notificationFromUserName = currentUserData['name'] ?? 'Someone';
        notificationFromUserPhoto = getFirstPhotoUrl(currentUserData['first_photos']) ?? '';
      }

      // Create notification data
      final notificationData = {
        'id': '${notificationFromUserId}_${DateTime.now().millisecondsSinceEpoch}',
        'type': type,
        'fromUserId': notificationFromUserId,
        'fromUserName': notificationFromUserName,
        'fromUserPhoto': notificationFromUserPhoto,
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
          .doc(notificationData['id'] as String?)
          .set(notificationData);

      print('✅ Notification created: $type for user $targetUserId');
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  // Create mutual match notification specifically
  // Create mutual match notification specifically
  static Future<void> createMutualMatchNotification({
    required String targetUserId,
    required String fromUserId,
    required String fromUserName,
    required String fromUserPhoto,
    required String matchId,
  }) async {
    try {
      // Get target user's name for personalized message
      final targetUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();

      final targetUserData = targetUserDoc.data();
      final targetUserName = targetUserData?['name'] ?? 'You';

      final notificationId = 'mutual_match_${matchId}_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('notifications').doc(notificationId).set({
        'id': notificationId,
        'type': 'mutual_match',
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'fromUserPhoto': fromUserPhoto,
        'targetUserId': targetUserId,
        'targetUserName': targetUserName, // Add target user's name
        'relatedUserId': fromUserId,
        'matchId': matchId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Mutual match notification created for user: $targetUserId from: $fromUserName');
    } catch (e) {
      print('❌ Error creating mutual match notification: $e');
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

  // Trigger when someone likes a post
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

  // Trigger when someone goes live
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
          commentText: liveTitle,
        );
      }
    }
  }

  // Trigger when live ends
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

  // Trigger when someone gifts during live
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

  // Trigger when it's a mutual match - FIXED
  // Trigger when it's a mutual match - UPDATED VERSION
  static Future<void> onMutualMatch({
    required String user1Id,
    required String user1Name,
    required String? user1Photo,
    required String user2Id,
    required String user2Name,
    required String? user2Photo,
    required String matchId,
  }) async {
    try {
      // Create notification for user1 - from user2's perspective
      await NotificationService.createMutualMatchNotification(
        targetUserId: user1Id,
        fromUserId: user2Id,
        fromUserName: user2Name,
        fromUserPhoto: user2Photo ?? '',
        matchId: matchId,
      );

      // Create notification for user2 - from user1's perspective
      await NotificationService.createMutualMatchNotification(
        targetUserId: user2Id,
        fromUserId: user1Id,
        fromUserName: user1Name,
        fromUserPhoto: user1Photo ?? '',
        matchId: matchId,
      );

      print('✅ Mutual match notifications created: $user1Name & $user2Name');
    } catch (e) {
      print('❌ Error creating mutual match notifications: $e');
    }
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

  // Create schedule reminder notification
  static Future<void> createScheduleReminderNotification({
    required String userId,
    required String scheduleId,
    required String title,
    required String fromUserId,
    required String fromUserName,
    required String fromUserPhoto,
    required DateTime scheduledTime,
  }) async {
    try {
      await NotificationService.createNotification(
        type: 'schedule_reminder',
        targetUserId: userId,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        fromUserPhoto: fromUserPhoto,
        commentText: title,
        matchId: scheduleId,
      );
      print('✅ Schedule reminder notification created for user: $userId');
    } catch (e) {
      print('❌ Error creating schedule reminder notification: $e');
    }
  }
}