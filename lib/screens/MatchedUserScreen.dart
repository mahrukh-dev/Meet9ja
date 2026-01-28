import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/user_model.dart';
import '../db_functions/user_service.dart';
import '../constants/app_colors.dart';

class MatchedUsersScreen extends StatefulWidget {
  final String userId;

  const MatchedUsersScreen({super.key, required this.userId});

  @override
  State<MatchedUsersScreen> createState() => _MatchedUsersScreenState();
}

class _MatchedUsersScreenState extends State<MatchedUsersScreen> {
  List<UserModel> _matchedUsers = [];
  Map<String, bool> _isUserMatched = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatchedUsers();
  }

  Future<void> _loadMatchedUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      print('🔄 Loading matches for user: ${currentUser.uid}');

      // OPTION 1: Check matches collection for any match records
      final matchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('UID', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'match')
          .get();

      print('📊 Found ${matchesSnapshot.docs.length} match documents');

      // Extract matched user IDs
      final matchedUserIds = matchesSnapshot.docs
          .map((doc) {
        final data = doc.data();
        print('Match document data: $data');
        return data['matched_user_ID'] as String?;
      })
          .where((id) => id != null)
          .toSet()
          .toList();

      print('🎯 Matched user IDs: $matchedUserIds');

      // OPTION 2: Check user's liked_profiles and see who also liked back
      if (matchedUserIds.isEmpty) {
        print('⚠ No matches in matches collection, checking user data...');

        // Get current user's liked profiles
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (currentUserDoc.exists) {
          final currentUserData = currentUserDoc.data()!;
          final myLikedProfiles = List<String>.from(
              currentUserData['liked_profiles'] ?? []);

          print('❤️ My liked profiles: $myLikedProfiles');

          // Check each liked profile to see if they also liked me
          for (final likedUserId in myLikedProfiles) {
            try {
              final likedUserDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(likedUserId)
                  .get();

              if (likedUserDoc.exists) {
                final likedUserData = likedUserDoc.data()!;
                final theirLikedProfiles = List<String>.from(
                    likedUserData['liked_profiles'] ?? []);

                if (theirLikedProfiles.contains(currentUser.uid)) {
                  // It's a mutual match!
                  matchedUserIds.add(likedUserId);
                }
              }
            } catch (e) {
              print('⚠ Error checking user $likedUserId: $e');
            }
          }
        }
      }

      // OPTION 3: Check matches by conversation ID pattern
      if (matchedUserIds.isEmpty) {
        print('⚠ Checking for matches using ID pattern...');

        // Look for documents where current user is user1Id or user2Id
        final user1Matches = await FirebaseFirestore.instance
            .collection('matches')
            .where('user1Id', isEqualTo: currentUser.uid)
            .get();

        final user2Matches = await FirebaseFirestore.instance
            .collection('matches')
            .where('user2Id', isEqualTo: currentUser.uid)
            .get();

        for (var doc in user1Matches.docs) {
          final data = doc.data();
          final user2Id = data['user2Id'] as String?;
          if (user2Id != null && !matchedUserIds.contains(user2Id)) {
            matchedUserIds.add(user2Id);
          }
        }

        for (var doc in user2Matches.docs) {
          final data = doc.data();
          final user1Id = data['user1Id'] as String?;
          if (user1Id != null && !matchedUserIds.contains(user1Id)) {
            matchedUserIds.add(user1Id);
          }
        }
      }

      print('✅ Final matched user IDs: $matchedUserIds');

      // Fetch user profiles
      if (matchedUserIds.isNotEmpty) {
        final users = await Future.wait(
          matchedUserIds.map((userId) => UserService.getUserProfile(userId!)),
        );

        final validUsers = users.whereType<UserModel>().toList();
        final matchStatusMap = <String, bool>{};

        for (var user in validUsers) {
          matchStatusMap[user.uid] = true;
        }

        setState(() {
          _matchedUsers = validUsers;
          _isUserMatched = matchStatusMap;
          _isLoading = false;
        });

        print('🎉 Loaded ${_matchedUsers.length} matched users');
      } else {
        setState(() {
          _matchedUsers = [];
          _isLoading = false;
        });
        print('📭 No matches found');
      }

    } catch (e) {
      print('❌ Error loading matched users: $e');
      setState(() {
        _error = 'Failed to load matches: $e';
        _isLoading = false;
      });
    }
  }

  // Add this debug function to check your database structure
  Future<void> _debugDatabaseStructure() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    print('\n=== DATABASE STRUCTURE DEBUG ===');

    // Check user document
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      print('📋 User document fields:');
      data.forEach((key, value) {
        print('  $key: $value');
      });
    }

    // Check all matches
    final allMatches = await FirebaseFirestore.instance
        .collection('matches')
        .where('UID', isEqualTo: currentUser.uid)
        .get();

    print('\n🎯 All matches for current user:');
    for (var doc in allMatches.docs) {
      print('  Document ID: ${doc.id}');
      print('  Data: ${doc.data()}');
    }

    // Check if there are any documents with current user as user1Id or user2Id
    final asUser1 = await FirebaseFirestore.instance
        .collection('matches')
        .where('user1Id', isEqualTo: currentUser.uid)
        .get();

    final asUser2 = await FirebaseFirestore.instance
        .collection('matches')
        .where('user2Id', isEqualTo: currentUser.uid)
        .get();

    print('\n👤 Matches as user1Id: ${asUser1.docs.length}');
    print('👤 Matches as user2Id: ${asUser2.docs.length}');

    print('=== END DEBUG ===\n');
  }

  Future<void> _toggleMatch(UserModel user) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final isCurrentlyMatched = _isUserMatched[user.uid] ?? false;

      if (isCurrentlyMatched) {
        // Unmatch the user
        await _unmatchProfile(user.uid);

        // Remove from local list
        setState(() {
          _matchedUsers.removeWhere((u) => u.uid == user.uid);
          _isUserMatched.remove(user.uid);
        });
      } else {
        // Match the user (like profile)
        await _likeProfile(user.uid);

        // Add to matched list
        setState(() {
          if (!_matchedUsers.any((u) => u.uid == user.uid)) {
            _matchedUsers.add(user);
          }
          _isUserMatched[user.uid] = true;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCurrentlyMatched
                ? 'Unmatched with ${user.name}'
                : 'Matched with ${user.name}! 🎉',
          ),
          backgroundColor: isCurrentlyMatched ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error toggling match: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${_isUserMatched[user.uid] ?? false ? 'unmatch' : 'match'}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _likeProfile(String targetUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'User not logged in';

      final batch = FirebaseFirestore.instance.batch();

      // Add to current user's liked profiles
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
        {
          'liked_profiles': FieldValue.arrayUnion([targetUserId]),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Add to target user's liked by
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(targetUserId),
        {
          'liked_by': FieldValue.arrayUnion([currentUser.uid]),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Check if it's a mutual match
      final targetUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();

      if (targetUserDoc.exists) {
        final targetData = targetUserDoc.data() as Map<String, dynamic>;
        final targetLikedProfiles = List<String>.from(targetData['liked_profiles'] ?? []);

        if (targetLikedProfiles.contains(currentUser.uid)) {
          // It's a mutual match! Create match document
          await _createMutualMatch(currentUser.uid, targetUserId);
        } else {
          // Just a regular like
          await _createMatchRecord(currentUser.uid, targetUserId, 'like');
        }
      }

      await batch.commit();
      print('✅ Liked profile: $targetUserId');
    } catch (e) {
      print('❌ Error liking profile: $e');
      throw 'Failed to like profile: $e';
    }
  }

  Future<void> _unmatchProfile(String targetUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'User not logged in';

      final batch = FirebaseFirestore.instance.batch();

      // Remove from current user's liked profiles
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
        {
          'liked_profiles': FieldValue.arrayRemove([targetUserId]),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Remove from target user's liked by
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(targetUserId),
        {
          'liked_by': FieldValue.arrayRemove([currentUser.uid]),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Delete match records
      final matchId = '${currentUser.uid}_$targetUserId';
      final mutualMatchId = 'mutual_$matchId';

      // Delete mutual match if exists
      await FirebaseFirestore.instance.collection('matches').doc(mutualMatchId).delete();

      // Update regular match status to 'unmatched'
      await _createMatchRecord(currentUser.uid, targetUserId, 'unmatched');

      await batch.commit();
      print('✅ Unmatched profile: $targetUserId');
    } catch (e) {
      print('❌ Error unmatching profile: $e');
      throw 'Failed to unmatch profile: $e';
    }
  }

  Future<void> _createMutualMatch(String user1Id, String user2Id) async {
    try {
      final matchId = '${user1Id}_$user2Id';
      final mutualMatchId = 'mutual_$matchId';

      // Get user data
      final user1Doc = await FirebaseFirestore.instance.collection('users').doc(user1Id).get();
      final user2Doc = await FirebaseFirestore.instance.collection('users').doc(user2Id).get();

      final user1Data = user1Doc.data() ?? {};
      final user2Data = user2Doc.data() ?? {};

      await FirebaseFirestore.instance.collection('matches').doc(mutualMatchId).set({
        'matchId': mutualMatchId,
        'user1Id': user1Id,
        'user1Name': user1Data['name'] ?? 'User',
        'user2Id': user2Id,
        'user2Name': user2Data['name'] ?? 'User',
        'matchedAt': FieldValue.serverTimestamp(),
        'status': 'match',
        'is_mutual': true,
      });

      print('✅ Created mutual match between $user1Id and $user2Id');
    } catch (e) {
      print('❌ Error creating mutual match: $e');
    }
  }

  Future<void> _createMatchRecord(String user1Id, String user2Id, String status) async {
    try {
      final matchId = '${user1Id}_$user2Id';

      await FirebaseFirestore.instance.collection('matches').doc(matchId).set({
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

  void _showReportDialog(UserModel user) {
    String selectedReason = 'Inappropriate content';
    final TextEditingController detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              'Report Profile',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why are you reporting this profile?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Report reason options
                  _ReportReasonTile(
                    value: 'Inappropriate content',
                    groupValue: selectedReason,
                    onChanged: (value) => setState(() => selectedReason = value!),
                    title: 'Inappropriate content',
                    subtitle: 'Nudity, violence, or explicit material',
                  ),
                  _ReportReasonTile(
                    value: 'Spam or fake profile',
                    groupValue: selectedReason,
                    onChanged: (value) => setState(() => selectedReason = value!),
                    title: 'Spam or fake profile',
                    subtitle: 'Fake account or promotional content',
                  ),
                  _ReportReasonTile(
                    value: 'Harassment or bullying',
                    groupValue: selectedReason,
                    onChanged: (value) => setState(() => selectedReason = value!),
                    title: 'Harassment or bullying',
                    subtitle: 'Threatening or abusive behavior',
                  ),
                  _ReportReasonTile(
                    value: 'Underage user',
                    groupValue: selectedReason,
                    onChanged: (value) => setState(() => selectedReason = value!),
                    title: 'Underage user',
                    subtitle: 'User appears to be under 18 years old',
                  ),
                  _ReportReasonTile(
                    value: 'Other',
                    groupValue: selectedReason,
                    onChanged: (value) => setState(() => selectedReason = value!),
                    title: 'Other',
                    subtitle: 'Something else',
                  ),

                  if (selectedReason == 'Other') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Please provide more details:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: detailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Describe the issue...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _submitReport(
                  context,
                  user,
                  selectedReason,
                  detailsController.text,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit Report'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitReport(
      BuildContext context,
      UserModel reportedUser,
      String reason,
      String details,
      ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to report profiles')),
        );
        return;
      }

      final reportData = {
        'reportId': '${currentUser.uid}_${reportedUser.uid}_${DateTime.now().millisecondsSinceEpoch}',
        'reporterId': currentUser.uid,
        'reporterName': currentUser.displayName ?? 'Anonymous',
        'reportedUserId': reportedUser.uid,
        'reportedUserName': reportedUser.name,
        'reason': reason,
        'details': details.isNotEmpty ? details : null,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportData['reportId'] as String?)
          .set(reportData);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      print('✅ Report submitted for user: ${reportedUser.uid}');
    } catch (e) {
      print('❌ Error submitting report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserActionsBottomSheet(UserModel user) {
    final isMatched = _isUserMatched[user.uid] ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(
                UserService.getProfilePhotoUrl(user) ?? 'https://i.pravatar.cc/100?img=8',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              UserService.getDisplayUsername(user),
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),

            // Match/Unmatch Button
            ListTile(
              leading: Icon(
                isMatched ? FontAwesomeIcons.heartCircleXmark : FontAwesomeIcons.heart,
                color: isMatched ? Colors.red : AppColors.primary,
              ),
              title: Text(
                isMatched ? 'Unmatch' : 'Match',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isMatched ? Colors.red : AppColors.primary,
                ),
              ),
              subtitle: Text(
                isMatched
                    ? 'Remove this user from your matches'
                    : 'Like this user\'s profile',
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleMatch(user);
              },
            ),

            const Divider(),

            // Report Button
            ListTile(
              leading: const Icon(
                FontAwesomeIcons.flag,
                color: Colors.red,
              ),
              title: const Text(
                'Report Profile',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              subtitle: const Text('Report inappropriate behavior or content'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(user);
              },
            ),

            // Cancel Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Matches',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.arrowRotateRight),
            onPressed: _loadMatchedUsers,
            tooltip: 'Refresh',
          ),
          // Debug button - remove in production

        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : _matchedUsers.isEmpty
          ? _buildEmptyState()
          : _buildMatchedUsersList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading matches...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.exclamationTriangle,
            size: 60,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Matches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black45),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadMatchedUsers,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.heart,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'No matches yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'When you match with someone, they will appear here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black45,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadMatchedUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchedUsersList() {
    return RefreshIndicator(
      onRefresh: _loadMatchedUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _matchedUsers.length,
        itemBuilder: (context, index) {
          final user = _matchedUsers[index];
          final isMatched = _isUserMatched[user.uid] ?? false;
          final profilePhotoUrl = UserService.getProfilePhotoUrl(user);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Profile Image
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: profilePhotoUrl != null
                        ? NetworkImage(profilePhotoUrl)
                        : const NetworkImage("https://i.pravatar.cc/100?img=8")
                    as ImageProvider,
                  ),

                  const SizedBox(width: 12),

                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          UserService.getDisplayUsername(user),
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${user.age} years',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (user.gender.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user.gender,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Match Status and Action Button
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMatched ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FontAwesomeIcons.heart,
                              size: 12,
                              color: isMatched ? AppColors.primary : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isMatched ? 'Matched' : 'Match',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isMatched ? AppColors.primary : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Action Button
                      ElevatedButton.icon(
                        onPressed: () => _toggleMatch(user),
                        icon: Icon(
                          isMatched ? FontAwesomeIcons.heartCrack : FontAwesomeIcons.heart,
                          size: 14,
                        ),
                        label: Text(
                          isMatched ? 'Unmatch' : 'Match',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMatched ? Colors.grey.shade100 : AppColors.primary,
                          foregroundColor: isMatched ? Colors.red : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // More Options Button
                  IconButton(
                    icon: const Icon(
                      FontAwesomeIcons.ellipsisVertical,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onPressed: () => _showUserActionsBottomSheet(user),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportReasonTile extends StatelessWidget {
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;
  final String title;
  final String subtitle;

  const _ReportReasonTile({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }
}