import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

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
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
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

      await _firestore
          .collection('users')
          .doc(userId)
          .update(updates);
    } catch (e) {
      print('❌ Error updating user profile: $e');
      throw 'Failed to update profile: $e';
    }
  }

  // Follow/Unfollow user
  static Future<void> followUser(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw 'User not logged in';

      final batch = _firestore.batch();

      // Add to current user's following
      batch.update(
        _firestore.collection('users').doc(currentUserId),
        {
          'following': FieldValue.arrayUnion([targetUserId]),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Add to target user's followers
      batch.update(
        _firestore.collection('users').doc(targetUserId),
        {
          'followers': FieldValue.arrayUnion([currentUserId]),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

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
      batch.update(
        _firestore.collection('users').doc(currentUserId),
        {
          'following': FieldValue.arrayRemove([targetUserId]),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Remove from target user's followers
      batch.update(
        _firestore.collection('users').doc(targetUserId),
        {
          'followers': FieldValue.arrayRemove([currentUserId]),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

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

  // Get user's live history
  static Stream<QuerySnapshot> getUserLiveHistory(String userId) {
    return _firestore
        .collection('live_history')
        .where('UID', isEqualTo: userId)
        .orderBy('start_time', descending: true)
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

  // Search users by username
  static Stream<QuerySnapshot> searchUsers(String query) {
    return _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThan: query + 'z')
        .snapshots();
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
          .map((doc) => UserModel.fromFirestore(doc.data() as Map<String, dynamic>))
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

  static int getCoinBalance(UserModel user) {
    return user.wallet['coin_balance'] ?? 0;
  }

  static int getTotalEarnings(UserModel user) {
    return user.wallet['total_earning'] ?? 0;
  }

  static bool isPremium(UserModel user) {
    return user.type == 'premium';
  }
}