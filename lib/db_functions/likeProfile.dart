// Like a profile - updated for your DB structure
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'createMatchRecord.dart';
import 'createMutualMatch.dart';
import 'notification_service.dart';

// Update your existing likeProfile function or create this new one
Future<void> likeProfile(String targetUserId) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw 'User not logged in';

    final currentUserId = currentUser.uid;
    final firestore = FirebaseFirestore.instance;

    // First, check if the target user has already liked the current user
    final targetUserDoc = await firestore.collection('users').doc(targetUserId).get();
    bool isMutualMatch = false;

    if (targetUserDoc.exists) {
      final targetData = targetUserDoc.data() as Map<String, dynamic>;
      final targetLikedProfiles = List<String>.from(targetData['liked_profiles'] ?? []);

      // Check if target has already liked current user
      isMutualMatch = targetLikedProfiles.contains(currentUserId);
    }

    // Update current user's liked_profiles array
    await firestore.collection('users').doc(currentUserId).update({
      'liked_profiles': FieldValue.arrayUnion([targetUserId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Get user data for notifications
    final currentUserDoc = await firestore.collection('users').doc(currentUserId).get();
    final currentUserData = currentUserDoc.data() as Map<String, dynamic>;

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

    final currentUserName = currentUserData['name'] ?? 'User';
    final currentUserPhoto = getFirstPhotoUrl(currentUserData['first_photos']);

    if (isMutualMatch) {
      // It's a mutual match! Create mutual match record
      await createMutualMatch(currentUserId, targetUserId);

      // Send mutual match notification to both users
      final targetUserName = targetUserDoc.data()?['name'] ?? 'User';
      final targetUserPhoto = getFirstPhotoUrl(targetUserDoc.data()?['first_photos']);

      // Notify target user about the match
      await NotificationTriggers.onMutualMatch(
        user1Id: currentUserId,
        user1Name: currentUserName,
        user1Photo: currentUserPhoto,
        user2Id: targetUserId,
        user2Name: targetUserName,
        user2Photo: targetUserPhoto,
        matchId: '${currentUserId}_$targetUserId',
      );
    } else {
      // Create regular match record
      await createMatchRecord(currentUserId, targetUserId, 'like');

      // Send profile like notification to target user
      await NotificationService.createNotification(
        type: 'profile_like',
        targetUserId: targetUserId,
        fromUserId: currentUserId,
        fromUserName: currentUserName,
        fromUserPhoto: currentUserPhoto ?? '',
      );
    }

    print('✅ ${isMutualMatch ? 'Mutual match created' : 'Profile liked'}: $targetUserId');
  } catch (e) {
    print('❌ Error liking profile: $e');
    throw 'Failed to like profile: $e';
  }
}