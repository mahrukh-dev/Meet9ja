import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class MatchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ UNIFIED LIKE PROFILE FUNCTION
  static Future<void> likeProfile({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      // Get both users' data
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      final targetUserDoc = await _firestore
          .collection('users')
          .doc(targetUserId)
          .get();

      if (!currentUserDoc.exists || !targetUserDoc.exists) {
        throw 'User not found';
      }

      final currentUserData = currentUserDoc.data()!;
      final targetUserData = targetUserDoc.data()!;

      // Check if target has already liked current user
      final targetLikedProfiles = List<String>.from(
          targetUserData['liked_profiles'] ?? []);
      final isMutualMatch = targetLikedProfiles.contains(currentUserId);

      // Update current user's liked_profiles
      await _firestore.collection('users').doc(currentUserId).update({
        'liked_profiles': FieldValue.arrayUnion([targetUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Get user names for notifications
      final currentUserName = currentUserData['name'] ?? 'User';
      final targetUserName = targetUserData['name'] ?? 'User';

      if (isMutualMatch) {
        // Create mutual match
        await _createMutualMatch(
          user1Id: currentUserId,
          user1Name: currentUserName,
          user2Id: targetUserId,
          user2Name: targetUserName,
        );

        // Send mutual match notifications
        await NotificationTriggers.onMutualMatch(
          user1Id: currentUserId,
          user1Name: currentUserName,
          user1Photo: _getFirstPhotoUrl(currentUserData['first_photos']),
          user2Id: targetUserId,
          user2Name: targetUserName,
          user2Photo: _getFirstPhotoUrl(targetUserData['first_photos']),
          matchId: '${currentUserId}_$targetUserId',
        );
      } else {
        // Create regular like record
        await _createMatchRecord(
          user1Id: currentUserId,
          user2Id: targetUserId,
          status: 'like',
        );

        // Send like notification
        await NotificationService.createNotification(
          type: 'profile_like',
          targetUserId: targetUserId,
          fromUserId: currentUserId,
          fromUserName: currentUserName,
          fromUserPhoto: _getFirstPhotoUrl(currentUserData['first_photos']) ?? '',
        );
      }

      print('✅ Profile liked: $targetUserId');
    } catch (e) {
      print('❌ Error liking profile: $e');
      throw 'Failed to like profile: $e';
    }
  }

  // ✅ UNIFIED UNLIKE/UNMATCH FUNCTION
  static Future<void> unlikeProfile({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      // Remove from current user's liked_profiles
      await _firestore.collection('users').doc(currentUserId).update({
        'liked_profiles': FieldValue.arrayRemove([targetUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Remove from target user's liked_by (if exists)
      await _firestore.collection('users').doc(targetUserId).update({
        'liked_by': FieldValue.arrayRemove([currentUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update match record status to 'unmatched'
      await _createMatchRecord(
        user1Id: currentUserId,
        user2Id: targetUserId,
        status: 'unmatched',
      );

      // Delete mutual match if exists
      final mutualMatchId = 'mutual_${currentUserId}_$targetUserId';
      await _firestore.collection('matches').doc(mutualMatchId).delete();

      print('✅ Profile unliked/unmatched: $targetUserId');
    } catch (e) {
      print('❌ Error unliking profile: $e');
      throw 'Failed to unlike profile: $e';
    }
  }

  // ✅ UNIFIED PASS PROFILE FUNCTION
  static Future<void> passProfile({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      // Add to current user's passed_profiles
      await _firestore.collection('users').doc(currentUserId).update({
        'passed_profiles': FieldValue.arrayUnion([targetUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Create pass record
      await _createMatchRecord(
        user1Id: currentUserId,
        user2Id: targetUserId,
        status: 'pass',
      );

      print('✅ Profile passed: $targetUserId');
    } catch (e) {
      print('❌ Error passing profile: $e');
      throw 'Failed to pass profile: $e';
    }
  }

  // ✅ CHECK IF LIKED
  static Future<bool> checkIfLiked({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final likedProfiles = List<String>.from(
            userData['liked_profiles'] ?? []);
        return likedProfiles.contains(targetUserId);
      }
      return false;
    } catch (e) {
      print('❌ Error checking like status: $e');
      return false;
    }
  }

  // ✅ CHECK FOR MATCH
  static Future<bool> checkForMatch({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      final matchSnapshot = await _firestore
          .collection('matches')
          .where('UID', isEqualTo: currentUserId)
          .where('matched_user_ID', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'match')
          .limit(1)
          .get();

      return matchSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking for match: $e');
      return false;
    }
  }

  // ✅ GET USER MATCHES
  static Future<List<Map<String, dynamic>>> getUserMatches(
      String userId) async {
    try {
      // Get matches from matches collection
      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('UID', isEqualTo: userId)
          .where('status', isEqualTo: 'match')
          .orderBy('time_stamp', descending: true)
          .get();

      final matches = matchesSnapshot.docs
          .map((doc) => doc.data())
          .toList();

      // Get detailed user info for each match
      final detailedMatches = await Future.wait(
        matches.map((match) async {
          final matchedUserId = match['matched_user_ID'] as String;
          final userDoc = await _firestore
              .collection('users')
              .doc(matchedUserId)
              .get();

          return {
            ...match,
            'matched_user': userDoc.data(),
          };
        }),
      );

      return detailedMatches;
    } catch (e) {
      print('❌ Error getting user matches: $e');
      return [];
    }
  }

  // ============ PRIVATE HELPER METHODS ============

  static Future<void> _createMutualMatch({
    required String user1Id,
    required String user1Name,
    required String user2Id,
    required String user2Name,
  }) async {
    try {
      final matchId = '${user1Id}_$user2Id';
      final mutualMatchId = 'mutual_$matchId';

      // Get user photos
      final user1Doc = await _firestore.collection('users').doc(user1Id).get();
      final user2Doc = await _firestore.collection('users').doc(user2Id).get();
      final user1Data = user1Doc.data()!;
      final user2Data = user2Doc.data()!;

      // Create mutual match document
      await _firestore.collection('matches').doc(mutualMatchId).set({
        'matchId': mutualMatchId,
        'user1Id': user1Id,
        'user1Name': user1Name,
        'user2Id': user2Id,
        'user2Name': user2Name,
        'user1Photo': _getFirstPhotoUrl(user1Data['first_photos']),
        'user2Photo': _getFirstPhotoUrl(user2Data['first_photos']),
        'status': 'match',
        'time_stamp': FieldValue.serverTimestamp(),
        'is_mutual': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update both users' matches array
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(user1Id), {
        'matches': FieldValue.arrayUnion([mutualMatchId]),
        'updated_at': FieldValue.serverTimestamp(),
      });
      batch.update(_firestore.collection('users').doc(user2Id), {
        'matches': FieldValue.arrayUnion([mutualMatchId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print('🎉 Mutual match created between $user1Name and $user2Name');
    } catch (e) {
      print('❌ Error creating mutual match: $e');
      throw 'Failed to create mutual match: $e';
    }
  }

  static Future<void> _createMatchRecord({
    required String user1Id,
    required String user2Id,
    required String status,
  }) async {
    try {
      final matchId = '${user1Id}_$user2Id';
      await _firestore.collection('matches').doc(matchId).set({
        'matchId': matchId,
        'UID': user1Id,
        'matched_user_ID': user2Id,
        'status': status,
        'time_stamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Created match record: $matchId with status: $status');
    } catch (e) {
      print('❌ Error creating match record: $e');
      throw 'Failed to create match record: $e';
    }
  }

  static String? _getFirstPhotoUrl(Map<String, dynamic>? photos) {
    if (photos == null) return null;
    for (var i = 1; i <= 4; i++) {
      final photoUrl = photos['photo${i}url']?.toString();
      if (photoUrl != null && photoUrl.isNotEmpty && photoUrl != 'null') {
        return photoUrl;
      }
    }
    return null;
  }

  // ✅ GET MATCHED PROFILES
  static Future<List<Map<String, dynamic>>> getMatchedProfiles() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'User not authenticated';
      }

      final currentUserId = currentUser.uid;

      // Query for mutual matches where current user is either user1 or user2
      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('status', isEqualTo: 'match')
          .where('is_mutual', isEqualTo: true)
          .orderBy('time_stamp', descending: true)
          .get();

      // Filter matches where current user is involved
      final userMatches = matchesSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['user1Id'] == currentUserId || data['user2Id'] == currentUserId;
      }).toList();

      // Extract matched user IDs and get their full profiles
      final matchedProfiles = await Future.wait(
        userMatches.map((matchDoc) async {
          final matchData = matchDoc.data() as Map<String, dynamic>;

          // Determine which user is the matched partner
          final isUser1 = matchData['user1Id'] == currentUserId;
          final matchedUserId = isUser1
              ? matchData['user2Id'] as String
              : matchData['user1Id'] as String;

          final matchedUserName = isUser1
              ? matchData['user2Name'] as String
              : matchData['user1Name'] as String;

          final matchedUserPhoto = isUser1
              ? matchData['user2Photo'] as String?
              : matchData['user1Photo'] as String?;

          // Get full user profile
          final userDoc = await _firestore
              .collection('users')
              .doc(matchedUserId)
              .get();

          if (!userDoc.exists) {
            return null;
          }

          final userData = userDoc.data()!;

          return {
            'matchId': matchData['matchId'],
            'matchedUserId': matchedUserId,
            'matchedUserName': matchedUserName,
            'matchedUserPhoto': matchedUserPhoto,
            'matchTimestamp': matchData['time_stamp'],
            'isMutual': matchData['is_mutual'] ?? true,

            // Full user profile data
            'user': {
              'id': matchedUserId,
              'name': userData['name'],
              'age': userData['age'],
              'gender': userData['gender'],
              'bio': userData['bio'],
              'interests': userData['interests'] ?? [],
              'location': userData['location'],
              'distance': userData['distance'],
              'first_photos': userData['first_photos'],
              'liked_profiles': userData['liked_profiles'] ?? [],
              'passed_profiles': userData['passed_profiles'] ?? [],
              'created_at': userData['created_at'],
              'updated_at': userData['updated_at'],
            },
          };
        }),
      );

      // Filter out any null values
      return matchedProfiles.whereType<Map<String, dynamic>>().toList();

    } catch (e) {
      print('❌ Error getting matched profiles: $e');
      throw 'Failed to get matched profiles: $e';
    }
  }

// ✅ GET MATCHED PROFILES WITH PAGINATION (Optional - for large lists)
  static Future<Map<String, dynamic>> getMatchedProfilesPaginated({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'User not authenticated';
      }

      final currentUserId = currentUser.uid;

      Query query = _firestore
          .collection('matches')
          .where('status', isEqualTo: 'match')
          .where('is_mutual', isEqualTo: true)
          .orderBy('time_stamp', descending: true)
          .limit(limit);

      // Apply startAfter for pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final matchesSnapshot = await query.get();

      if (matchesSnapshot.docs.isEmpty) {
        return {
          'profiles': [],
          'lastDocument': null,
          'hasMore': false,
        };
      }

      // Filter and process matches
      final userMatches = matchesSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['user1Id'] == currentUserId || data['user2Id'] == currentUserId;
      }).toList();

      // Extract matched user IDs and get their full profiles
      final matchedProfiles = await Future.wait(
        userMatches.map((matchDoc) async {
          final matchData = matchDoc.data() as Map<String, dynamic>;

          final isUser1 = matchData['user1Id'] == currentUserId;
          final matchedUserId = isUser1
              ? matchData['user2Id'] as String
              : matchData['user1Id'] as String;

          final matchedUserName = isUser1
              ? matchData['user2Name'] as String
              : matchData['user1Name'] as String;

          // Get full user profile
          final userDoc = await _firestore
              .collection('users')
              .doc(matchedUserId)
              .get();

          if (!userDoc.exists) {
            return null;
          }

          final userData = userDoc.data()!;

          return {
            'matchId': matchData['matchId'],
            'matchedUserId': matchedUserId,
            'matchedUserName': matchedUserName,
            'matchedUserPhoto': isUser1
                ? matchData['user2Photo'] as String?
                : matchData['user1Photo'] as String?,
            'matchTimestamp': matchData['time_stamp'],

            // Essential user info (you can customize this)
            'user': {
              'id': matchedUserId,
              'name': userData['name'],
              'age': userData['age'],
              'bio': userData['bio'],
              'first_photos': userData['first_photos'],
              'interests': userData['interests'] ?? [],
            },
          };
        }),
      );

      final validProfiles = matchedProfiles.whereType<Map<String, dynamic>>().toList();
      final newLastDocument = matchesSnapshot.docs.last;

      return {
        'profiles': validProfiles,
        'lastDocument': newLastDocument,
        'hasMore': matchesSnapshot.docs.length == limit,
      };

    } catch (e) {
      print('❌ Error getting paginated matched profiles: $e');
      throw 'Failed to get matched profiles: $e';
    }
  }

// ✅ GET RECENT MATCHES (Last 24 hours)
  static Future<List<Map<String, dynamic>>> getRecentMatches({int hours = 24}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'User not authenticated';
      }

      final currentUserId = currentUser.uid;
      final cutoffTime = DateTime.now().subtract(Duration(hours: hours));

      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('status', isEqualTo: 'match')
          .where('is_mutual', isEqualTo: true)
          .where('time_stamp', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .orderBy('time_stamp', descending: true)
          .get();

      final userMatches = matchesSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['user1Id'] == currentUserId || data['user2Id'] == currentUserId;
      }).toList();

      // Process matches (simplified version without full user profiles)
      final recentMatches = userMatches.map((matchDoc) {
        final matchData = matchDoc.data() as Map<String, dynamic>;

        final isUser1 = matchData['user1Id'] == currentUserId;
        final matchedUserId = isUser1
            ? matchData['user2Id'] as String
            : matchData['user1Id'] as String;

        return {
          'matchId': matchData['matchId'],
          'matchedUserId': matchedUserId,
          'matchedUserName': isUser1
              ? matchData['user2Name'] as String
              : matchData['user1Name'] as String,
          'matchedUserPhoto': isUser1
              ? matchData['user2Photo'] as String?
              : matchData['user1Photo'] as String?,
          'matchTimestamp': matchData['time_stamp'],
          'isNew': true, // Flag for UI to show as new match
        };
      }).toList();

      return recentMatches;

    } catch (e) {
      print('❌ Error getting recent matches: $e');
      return [];
    }
  }

// ✅ GET MATCH COUNT
  static Future<int> getMatchCount() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return 0;
      }

      final currentUserId = currentUser.uid;

      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('status', isEqualTo: 'match')
          .where('is_mutual', isEqualTo: true)
          .get();

      final count = matchesSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['user1Id'] == currentUserId || data['user2Id'] == currentUserId;
      }).length;

      return count;

    } catch (e) {
      print('❌ Error getting match count: $e');
      return 0;
    }
  }
}