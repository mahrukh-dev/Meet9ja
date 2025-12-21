import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/live_history_model.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import 'image_service.dart';
import 'notification_service.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // ============ LIKE/UNLIKE FUNCTIONALITY ============
  static Future<void> likeProfile(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();

      // Add to current user's liked profiles
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'liked_profiles': FieldValue.arrayUnion([targetUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Add to target user's liked by
      batch.update(_firestore.collection('users').doc(targetUserId), {
        'liked_by': FieldValue.arrayUnion([currentUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Check for mutual like (match)
      final targetUserDoc = await _firestore.collection('users').doc(targetUserId).get();
      if (targetUserDoc.exists) {
        final targetData = targetUserDoc.data() as Map<String, dynamic>;
        final targetLikedProfiles = List<String>.from(targetData['liked_profiles'] ?? []);

        if (targetLikedProfiles.contains(currentUserId)) {
          // It's a match! Create a match document
          final matchId = '${currentUserId}${targetUserId}${DateTime.now().millisecondsSinceEpoch}';
          await _firestore.collection('matches').doc(matchId).set({
            'matchId': matchId,
            'user1Id': currentUserId,
            'user2Id': targetUserId,
            'matchedAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

          // Send match notification to both users
          await NotificationTriggers.onMutualMatch(
            currentUserId,
            targetUserId
          );
        }
      }

      await batch.commit();
      print('✅ Liked profile: $targetUserId');
    } catch (e) {
      print('❌ Error liking profile: $e');
      throw 'Failed to like profile: $e';
    }
  }

  static Future<void> unlikeProfile(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();

      // Remove from current user's liked profiles
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'liked_profiles': FieldValue.arrayRemove([targetUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Remove from target user's liked by
      batch.update(_firestore.collection('users').doc(targetUserId), {
        'liked_by': FieldValue.arrayRemove([currentUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print('✅ Unliked profile: $targetUserId');
    } catch (e) {
      print('❌ Error unliking profile: $e');
      throw 'Failed to unlike profile: $e';
    }
  }

  static Future<bool> checkIfLiked(String currentUserId, String targetUserId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final likedProfiles = List<String>.from(userData['liked_profiles'] ?? []);
        return likedProfiles.contains(targetUserId);
      }

      return false;
    } catch (e) {
      print('❌ Error checking like status: $e');
      return false;
    }
  }

  // ============ EXISTING FUNCTIONS ============
  // Fetch user profile data as UserModel
  static Future<UserModel?> getUserProfile(String userId) async {
    try {
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return UserModel.fromFirestore(data);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching user profile: $e');
      throw 'Failed to load user profile: $e';
    }
  }

  // Stream user profile data for real-time updates
  static Stream<UserModel?> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((
        snapshot,
        ) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return UserModel.fromFirestore(data);
      }
      return null;
    });
  }

  // Get user stats (followers, following counts)
  static Future<Map<String, int>> getUserStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;

        // Get followers count
        final followers = userData['followers'] as List<dynamic>? ?? [];
        final followersCount = followers.length;

        // Get following count
        final following = userData['following'] as List<dynamic>? ?? [];
        final followingCount = following.length;

        // For subscribers, you might need to calculate from subscriptions collection
        final subscribersCount = userData['subscribers_count'] ?? 0;

        return {
          'followers': followersCount,
          'following': followingCount,
          'subscribers': subscribersCount,
        };
      }

      return {'followers': 0, 'following': 0, 'subscribers': 0};
    } catch (e) {
      print('❌ Error fetching user stats: $e');
      return {'followers': 0, 'following': 0, 'subscribers': 0};
    }
  }

  // Update user profile
  static Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      updates['updated_at'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      print('❌ Error updating user profile: $e');
      throw 'Failed to update profile: $e';
    }
  }

  // Create a new post - UPDATED VERSION
  static Future<void> createPost({
    required String userId,
    required String caption,
    required String mediaUrl,
    required String type, // 'image' or 'video'
    String? thumbnailUrl, // Add this parameter
  }) async {
    try {
      final postRef = _firestore.collection('user_feed').doc();

      // Create post data matching PostModel structure
      final postData = {
        'ID': postRef.id,
        'UID': userId,
        'caption': caption,
        'type': type,
        'media_url': mediaUrl,
        'thumbnail_url': thumbnailUrl, // Include thumbnail URL
        'date_time': FieldValue.serverTimestamp(),
        'comments': [],
        'likes': [],
      };

      await postRef.set(postData);
      print('✅ Post created successfully: ${postRef.id}');
    } catch (e) {
      print('❌ Error creating post: $e');
      throw 'Failed to create post: $e';
    }
  }

  // Get user posts as stream
  static Stream<List<PostModel>> getUserPostsStream(String userId) {
    return _firestore
        .collection('user_feed')
        .where('UID', isEqualTo: userId)
        .orderBy('date_time', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => PostModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList();
    });
  }

  // Get single post by ID
  static Future<PostModel?> getPostById(String postId) async {
    try {
      final doc = await _firestore.collection('user_feed').doc(postId).get();
      if (doc.exists) {
        return PostModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      print('❌ Error getting post: $e');
      return null;
    }
  }

  static Future<void> likePost(String postId, String userId) async {
    try {
      final likeData = {
        'likerUID': userId,
        'date_time': Timestamp.now(),
      };

      // Get post to find owner
      final postDoc = await _firestore.collection('user_feed').doc(postId).get();
      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final postOwnerId = postData['UID'];

        // Trigger post like notification
        await NotificationTriggers.onPostLike(
          targetUserId: postOwnerId,
          postId: postId,
          likerUserId: userId,
        );
      }

      await _firestore.collection('user_feed').doc(postId).update({
        'likes': FieldValue.arrayUnion([likeData]),
      });
    } catch (e) {
      print('❌ Error liking post: $e');
      throw 'Failed to like post: $e';
    }
  }

  static Future<void> unlikePost(String postId, String userId) async {
    try {
      final postDoc = await _firestore
          .collection('user_feed')
          .doc(postId)
          .get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final likes = data['likes'] as List<dynamic>? ?? [];

        // Find the like to remove
        final likeToRemove = likes.firstWhere(
              (like) => like['likerUID'] == userId,
          orElse: () => null,
        );

        if (likeToRemove != null) {
          await _firestore.collection('user_feed').doc(postId).update({
            'likes': FieldValue.arrayRemove([likeToRemove]),
          });
        }
      }
    } catch (e) {
      print('❌ Error unliking post: $e');
      throw 'Failed to unlike post: $e';
    }
  }

  static Future<void> addComment({
    required String postId,
    required String userId,
    required String text,
  }) async {
    try {
      final commentData = {
        'commenterUID': userId,
        'date_time': Timestamp.now(),
        'text': text,
      };

      // Get post to find owner
      final postDoc = await _firestore.collection('user_feed').doc(postId).get();
      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final postOwnerId = postData['UID'];

        // Only send notification if commenter is not the post owner
        if (postOwnerId != userId) {
          await NotificationTriggers.onPostComment(
            targetUserId: postOwnerId,
            postId: postId,
            commentText: text,
          );
        }
      }

      await _firestore.collection('user_feed').doc(postId).update({
        'comments': FieldValue.arrayUnion([commentData]),
      });
    } catch (e) {
      print('❌ Error adding comment: $e');
      throw 'Failed to add comment: $e';
    }
  }

  // Create a new story
  static Future<void> createStory({
    required String userId,
    required String mediaUrl,
    required String mediaType,
  }) async {
    try {
      final storyRef = _firestore.collection('stories').doc();
      final now = DateTime.now();
      final expiresAt = now.add(
        const Duration(hours: 24),
      ); // 24-hour expiration

      final storyData = {
        'ID': storyRef.id,
        'UID': userId,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'created_at': Timestamp.fromDate(now),
        'expires_at': Timestamp.fromDate(expiresAt),
        'viewers': [],
      };

      await storyRef.set(storyData);
      print('✅ Story created successfully: ${storyRef.id}');

      // Schedule automatic deletion
      _scheduleStoryDeletion(storyRef.id, mediaUrl, expiresAt);
    } catch (e) {
      print('❌ Error creating story: $e');
      throw 'Failed to create story: $e';
    }
  }

  // Get user stories stream
  static Stream<List<StoryModel>> getUserStoriesStream(String userId) {
    try {
      return _firestore
          .collection('stories')
          .where('UID', isEqualTo: userId)
          .where('expires_at', isGreaterThan: Timestamp.now())
          .orderBy('expires_at', descending: true)
          .snapshots()
          .handleError((error) {
        print('❌ Error in stories stream: $error');
        // Return an empty list on error to prevent stream from closing
        return [];
      })
          .map((snapshot) {
        final stories = snapshot.docs
            .map((doc) => StoryModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ))
            .toList();

        print('📱 Stories stream updated: ${stories.length} stories');
        return stories;
      });
    } catch (e) {
      print('❌ Error creating stories stream: $e');
      // Return a stream that emits an empty list
      return Stream.value([]);
    }
  }

  // Get all active stories from followed users
  static Stream<List<StoryModel>> getFollowingStoriesStream(
      List<String> followingIds,
      ) {
    if (followingIds.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('stories')
        .where('UID', whereIn: followingIds)
        .where('expires_at', isGreaterThan: Timestamp.now())
        .orderBy('UID') // You'll need a composite index for this
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => StoryModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList();
    });
  }

  // Mark story as viewed
  static Future<void> markStoryAsViewed(String storyId, String userId) async {
    try {
      await _firestore.collection('stories').doc(storyId).update({
        'viewers': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      print('❌ Error marking story as viewed: $e');
    }
  }

  // Schedule automatic story deletion
  static void _scheduleStoryDeletion(
      String storyId,
      String mediaUrl,
      DateTime expiresAt,
      ) {
    final durationUntilDeletion = expiresAt.difference(DateTime.now());

    if (durationUntilDeletion.inSeconds > 0) {
      Future.delayed(durationUntilDeletion, () async {
        try {
          // Delete from Firestore
          await _firestore.collection('stories').doc(storyId).delete();
          // Delete from Storage
          await ImageService.deleteStoryMedia(mediaUrl);
          print('✅ Story automatically deleted: $storyId');
        } catch (e) {
          print('❌ Error auto-deleting story: $e');
        }
      });
    }
  }

  // Manual story deletion (if user wants to delete early)
  static Future<void> deleteStory(String storyId, String mediaUrl) async {
    try {
      await _firestore.collection('stories').doc(storyId).delete();
      await ImageService.deleteStoryMedia(mediaUrl);
      print('✅ Story deleted manually: $storyId');
    } catch (e) {
      print('❌ Error deleting story: $e');
      throw 'Failed to delete story: $e';
    }
  }

  // Follow/Unfollow user
  static Future<void> followUser(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw 'User not logged in';

      final batch = _firestore.batch();

      // Add to current user's following
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'following': FieldValue.arrayUnion([targetUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Add to target user's followers
      batch.update(_firestore.collection('users').doc(targetUserId), {
        'followers': FieldValue.arrayUnion([currentUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      print('❌ Error following user: $e');
      throw 'Failed to follow user: $e';
    }
  }

  static Future<void> unfollowUser(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw 'User not logged in';

      final batch = _firestore.batch();

      // Remove from current user's following
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'following': FieldValue.arrayRemove([targetUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Remove from target user's followers
      batch.update(_firestore.collection('users').doc(targetUserId), {
        'followers': FieldValue.arrayRemove([currentUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      print('❌ Error unfollowing user: $e');
      throw 'Failed to unfollow user: $e';
    }
  }

  // Check if current user is following target user
  static Future<bool> isFollowing(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final following = userData['following'] as List<dynamic>? ?? [];
        return following.contains(targetUserId);
      }

      return false;
    } catch (e) {
      print('❌ Error checking follow status: $e');
      return false;
    }
  }

  // Get user's feed posts
  static Stream<QuerySnapshot> getUserFeed(String userId) {
    return _firestore
        .collection('user_feed')
        .where('UID', isEqualTo: userId)
        .orderBy('date_time', descending: true)
        .snapshots();
  }

  // Get user's matches
  static Stream<QuerySnapshot> getUserMatches(String userId) {
    return _firestore
        .collection('matches')
        .where('UID', isEqualTo: userId)
        .orderBy('time_stamp', descending: true)
        .snapshots();
  }

  // Get recommended users
  static Stream<List<UserModel>> getRecommendedUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('isVerified', isEqualTo: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc.data() as Map<String, dynamic>))
        .toList());
  }

  // Get popular users
  static Stream<List<UserModel>> getPopularUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('followersCount', descending: true)
        .limit(6)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc.data() as Map<String, dynamic>))
        .toList());
  }

  // Get trending posts
  static Stream<List<PostModel>> getTrendingPosts() {
    return FirebaseFirestore.instance
        .collection('user_feed')
        .orderBy('likesCount', descending: true)
        .where('type', isEqualTo: 'video')
        .limit(4)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PostModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  // Search users
  static Stream<List<UserModel>> searchUsers(String query) {
    if (query.isEmpty) {
      return Stream.value([]);
    }

    final searchQuery = query.trim();

    // For very short queries, return empty to avoid too many results
    if (searchQuery.length < 2) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('name')
        .startAt([searchQuery])
        .endAt([searchQuery + '\uf8ff'])
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromFirestore(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Calculate age from date of birth
  static int calculateAge(String dateOfBirth) {
    try {
      final birthDate = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 25; // Default age if parsing fails
    }
  }

  // Submit profile report
  static Future<void> submitProfileReport({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    try {
      final reportId = '${reporterId}${reportedUserId}${DateTime.now().millisecondsSinceEpoch}';

      final reportData = {
        'reportId': reportId,
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'details': details,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .set(reportData);

      print('✅ Profile report submitted: $reportId');
    } catch (e) {
      print('❌ Error submitting profile report: $e');
      throw 'Failed to submit report: $e';
    }
  }

  // Get user reports
  static Future<List<Map<String, dynamic>>> getUserReports(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('reportedUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('❌ Error getting user reports: $e');
      return [];
    }
  }

  // Check if user has reported profile
  static Future<bool> hasUserReportedProfile(String reporterId, String reportedUserId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('reporterId', isEqualTo: reporterId)
          .where('reportedUserId', isEqualTo: reportedUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking if user has reported profile: $e');
      return false;
    }
  }

  // Get multiple users by IDs
  static Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return [];

      final querySnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      return querySnapshot.docs
          .map(
            (doc) =>
            UserModel.fromFirestore(doc.data() as Map<String, dynamic>),
      )
          .toList();
    } catch (e) {
      print('❌ Error fetching users by IDs: $e');
      return [];
    }
  }

  // Helper methods for UserModel
  static String? getProfilePhotoUrl(UserModel user) {
    // Try photo_url first
    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      return user.photoUrl;
    }

    // Then try first_photos
    for (var i = 1; i <= 4; i++) {
      final photoUrl = user.firstPhotos['photo${i}url'];
      if (photoUrl != null && photoUrl.toString().isNotEmpty) {
        return photoUrl.toString();
      }
    }

    return null;
  }

  static String getDisplayUsername(UserModel user) {
    return '@${user.username}';
  }

  static String getFormattedJoinDate(UserModel user) {
    final months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    return "${months[user.createdAt.month - 1]} ${user.createdAt.day}, ${user.createdAt.year}";
  }

  static String getPrimaryMode(UserModel user) {
    if (user.mode['date'] == true) return 'Date';
    if (user.mode['travel_partner'] == true) return 'Travel Partner';
    if (user.mode['BFF'] == true) return 'BFF';
    if (user.mode['bizz'] == true) return 'Bizz';
    return 'Not Set';
  }

  static bool isPremium(UserModel user) {
    return user.type == 'premium';
  }

  // Live stream functionality
  static Future<void> startLiveStream({
    required String userId,
    required String liveId,
    required String title,
  }) async {
    try {
      // Create live document
      await FirebaseFirestore.instance.collection('live_history').doc(liveId).set({
        'live_id': liveId,
        'UID': userId,
        'start_time': FieldValue.serverTimestamp(),
        'title': title,
        'status': 'active',
        'viewer_count': 0,
        'total_gift_value': 0,
      });

      // Trigger live notification to followers
      await NotificationTriggers.onUserLive(
        userId: userId,
        liveId: liveId,
        liveTitle: title,
      );

      print('✅ Live stream started and notifications sent');
    } catch (e) {
      print('❌ Error starting live stream: $e');
      throw 'Failed to start live stream: $e';
    }
  }

  static Future<List<LiveHistory>> getUserLiveHistory(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('live_history')
          .where('UID', isEqualTo: userId)
          .orderBy('end_time', descending: true)
          .limit(20)
          .get();

      return querySnapshot.docs.map((doc) {
        return LiveHistory.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print('Error getting user live history: $e');
      return [];
    }
  }

  // Schedule functionality
  static Future<List<Map<String, dynamic>>> getUserSchedules(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where('userId', isEqualTo: userId)
          .orderBy('scheduled_time', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting user schedules: $e');
      return [];
    }
  }

  static Future<void> createSchedule({
    required String userId,
    required String title,
    required String description,
    required DateTime scheduledTime,
  }) async {
    try {
      final scheduleId = 'schedule_${userId}_${scheduledTime.millisecondsSinceEpoch}';

      await FirebaseFirestore.instance.collection('schedules').doc(scheduleId).set({
        'id': scheduleId,
        'userId': userId,
        'title': title,
        'description': description,
        'scheduled_time': Timestamp.fromDate(scheduledTime),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Schedule notification for 10 minutes before the stream
      final notificationTime = scheduledTime.subtract(const Duration(minutes: 10));
      if (notificationTime.isAfter(DateTime.now())) {
        await _scheduleNotification(
          userId: userId,
          scheduleId: scheduleId,
          title: title,
          scheduledTime: scheduledTime,
          notificationTime: notificationTime,
        );
      }

      print('✅ Schedule created: $scheduleId');
    } catch (e) {
      print('❌ Error creating schedule: $e');
      throw 'Failed to create schedule: $e';
    }
  }

  static Future<void> _scheduleNotification({
    required String userId,
    required String scheduleId,
    required String title,
    required DateTime scheduledTime,
    required DateTime notificationTime,
  }) async {
    try {
      // Store the notification schedule
      await FirebaseFirestore.instance
          .collection('scheduled_notifications')
          .doc('${scheduleId}_reminder')
          .set({
        'userId': userId,
        'scheduleId': scheduleId,
        'title': title,
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'notificationTime': Timestamp.fromDate(notificationTime),
        'type': 'schedule_reminder',
        'created_at': FieldValue.serverTimestamp(),
      });

      print('✅ Scheduled notification for: $notificationTime');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
    }
  }

  static Future<void> deleteSchedule(String scheduleId) async {
    try {
      await FirebaseFirestore.instance.collection('schedules').doc(scheduleId).delete();

      // Also delete any scheduled notifications
      await FirebaseFirestore.instance
          .collection('scheduled_notifications')
          .doc('${scheduleId}_reminder')
          .delete();

      print('✅ Schedule deleted: $scheduleId');
    } catch (e) {
      print('❌ Error deleting schedule: $e');
      throw 'Failed to delete schedule: $e';
    }
  }


  // Add this to your UserService class
  static Stream<List<UserModel>> getTravelingUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .limit(8) // Get 8 random users
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc.data() as Map<String, dynamic>))
        .toList());
  }



  static Stream<List<UserModel>> getSimilarInterestsUsers() {
    final currentUserId = _auth.currentUser?.uid;
    // final currentUserId = currentUserId;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .limit(4)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc as Map<String, dynamic>))
        .toList());
  }

  static Stream<List<UserModel>> getSameGoalsUsers() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .limit(4)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc as Map<String, dynamic>))
        .toList());
  }

  // Get diamond balance (purchased currency)
  static int getDiamondBalance(UserModel user) {
    final balance = user.wallet['diamond_balance'];
    if (balance is int) return balance;
    if (balance is double) return balance.toInt();
    return 0;
  }

  // Get coin balance (earned currency)
  static int getCoinBalance(UserModel user) {
    final balance = user.wallet['coin_balance'];
    if (balance is int) return balance;
    if (balance is double) return balance.toInt();
    return 0;
  }

  // Get total earnings (coins)
  static double getTotalEarnings(UserModel user) {
    final earnings = user.wallet['coin_balance']/100;
    if (earnings is double) return earnings;
    if (earnings is int) return earnings.toDouble();
    return 0.0;
  }

  // Check if user has enough diamonds
  static bool hasEnoughDiamonds(UserModel user, int amount) {
    return getDiamondBalance(user) >= amount;
  }

  // Check if user has enough coins
  static bool hasEnoughCoins(UserModel user, int amount) {
    return getCoinBalance(user) >= amount;
  }
}