import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutterwave_standard/core/flutterwave.dart';
import 'package:flutterwave_standard/models/requests/customer.dart';
import 'package:flutterwave_standard/models/requests/customizations.dart';
import 'package:flutterwave_standard/models/responses/charge_response.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:meet9ja/screens/home_screen.dart';
import 'package:meet9ja/screens/messages_screen.dart' hide StoryModel;
import 'package:meet9ja/screens/post_detail_screen.dart';
import 'package:meet9ja/screens/signin_screen.dart';
import 'package:meet9ja/screens/story_view_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../db_functions/firebase_service.dart';
import '../db_functions/user_service.dart';
import '../models/live_history_model.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import 'MatchedUserScreen.dart';
import 'create_post_screen.dart';
import 'create_story_screen.dart';
import 'edit_profile_screen.dart';
import 'package:intl/intl.dart';
import 'livestream_screen.dart';
import 'create_schedule_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isMyProfile;
  final String? userId;

  const ProfileScreen({
    super.key,
    this.isMyProfile = true,
    this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late StreamSubscription<UserModel?>? _profileSubscription;

  UserModel? _userProfile;
  bool _isLoading = true;
  String? _error;
  Map<String, int> _userStats = {
    'followers': 0,
    'following': 0,
    'matches': 0,
  };
  bool _isFollowing = false;
  bool _isMatched = false;

  List<String> get _tabLabels {
    if (widget.isMyProfile) {
      return ["Home", "Clips", "Wallet", "Schedules", "About"];
    } else {
      return ["Home", "Clips", "Schedules", "About"];
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _loadUserData() async {
    final String userId = widget.userId ?? UserService.currentUserId ?? '';

    if (userId.isEmpty) {
      setState(() {
        _error = 'No user ID available';
        _isLoading = false;
      });
      return;
    }

    try {
      final stats = await UserService.getUserStats(userId);
      setState(() {
        _userStats = stats;
      });

      if (!widget.isMyProfile && UserService.currentUserId != null) {
        final following = await UserService.isFollowing(userId);
        setState(() {
          _isFollowing = following;
        });
      }

      if (!widget.isMyProfile && UserService.currentUserId != null) {
        final matched = await _checkForMatch(userId);
        setState(() {
          _isMatched = matched;
        });
      }

      _profileSubscription = UserService.getUserProfileStream(userId).listen(
            (profile) {
          setState(() {
            _userProfile = profile;
            _isLoading = false;
            _error = null;
          });
        },
        onError: (error) {
          setState(() {
            _error = 'Error loading profile: $error';
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to load user data: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkForMatch(String targetUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final matchSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('UID', isEqualTo: currentUser.uid)
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

  Future<void> _toggleFollow() async {
    if (_userProfile == null || widget.isMyProfile) return;

    try {
      if (_isFollowing) {
        await UserService.unfollowUser(_userProfile!.uid);
      } else {
        await UserService.followUser(_userProfile!.uid);
      }

      setState(() {
        _isFollowing = !_isFollowing;
        _userStats['followers'] =
            _userStats['followers']! + (_isFollowing ? 1 : -1);
      });

      _showSnackBar(
        _isFollowing ? 'You are now following ${_userProfile!.name}' : 'You unfollowed ${_userProfile!.name}',
        color: _isFollowing ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _showSnackBar(
        'Failed to ${_isFollowing ? 'unfollow' : 'follow'}: $e',
        color: Colors.red,
      );
    }
  }

  Future<void> _toggleMatch() async {
    if (_userProfile == null || widget.isMyProfile) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'User not logged in';

      final targetUserId = _userProfile!.uid;

      if (_isMatched) {
        await _unmatchProfile(targetUserId);
      } else {
        await _likeProfile(targetUserId);
      }

      setState(() {
        _isMatched = !_isMatched;
      });

      _showSnackBar(
        _isMatched ? 'You matched with ${_userProfile!.name}! 🎉' : 'You unmatched ${_userProfile!.name}',
        color: _isMatched ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _showSnackBar(
        'Failed to ${_isMatched ? 'unmatch' : 'match'}: $e',
        color: Colors.red,
      );
    }
  }

  Future<void> _likeProfile(String targetUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'User not logged in';

      final batch = FirebaseFirestore.instance.batch();

      final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'liked_profiles': FieldValue.arrayUnion([targetUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _createMatchRecord(currentUser.uid, targetUserId, 'like');

      final targetUserDoc = await FirebaseFirestore.instance.collection('users').doc(targetUserId).get();
      final targetUserLikes = List.from(targetUserDoc.data()?['liked_profiles'] ?? []);

      if (targetUserLikes.contains(currentUser.uid)) {
        await _createMutualMatch(currentUser.uid, targetUserId);
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

      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'liked_profiles': FieldValue.arrayRemove([targetUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _createMatchRecord(currentUser.uid, targetUserId, 'pass');

      print('✅ Unmatched profile: $targetUserId');
    } catch (e) {
      print('❌ Error unmatching profile: $e');
      throw 'Failed to unmatch profile: $e';
    }
  }

  Future<void> _createMatchRecord(String user1Id, String user2Id, String status) async {
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

  Future<void> _createMutualMatch(String user1Id, String user2Id) async {
    try {
      final matchId = '${user1Id}_$user2Id';
      final mutualMatchId = 'mutual_$matchId';

      final matchRef = FirebaseFirestore.instance.collection('matches').doc(mutualMatchId);

      await matchRef.set({
        'matchId': mutualMatchId,
        'UID': user1Id,
        'matched_user_ID': user2Id,
        'status': 'match',
        'time_stamp': FieldValue.serverTimestamp(),
        'is_mutual': true,
      });

      final batch = FirebaseFirestore.instance.batch();

      final user1Ref = FirebaseFirestore.instance.collection('users').doc(user1Id);
      batch.update(user1Ref, {
        'matches': FieldValue.arrayUnion([mutualMatchId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final user2Ref = FirebaseFirestore.instance.collection('users').doc(user2Id);
      batch.update(user2Ref, {
        'matches': FieldValue.arrayUnion([mutualMatchId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      print('🎉 Mutual match created between $user1Id and $user2Id');

    } catch (e) {
      print('❌ Error creating mutual match: $e');
    }
  }

  Future<void> _navigateToEditProfile() async {
    if (_userProfile == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userProfile: _userProfile!),
      ),
    );

    if (result == true && mounted) {
      _loadUserData();
    }
  }

  void _navigateToMatchedUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchedUsersScreen(userId: _userProfile!.uid),
      ),
    );
  }

  // Report functionality
  void _showReportDialog(BuildContext context, UserModel userProfile) {
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
                  userProfile,
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

      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      print('✅ Report submitted for user: ${reportedUser.uid}');
    } catch (e) {
      print('❌ Error submitting report: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchURL(String url) async {
    if (url.isEmpty) {
      _showSnackBar('No URL available');
      return;
    }

    try {
      final Uri uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
        );
      }

    } catch (e) {
      print('Error launching URL: $e');
      _showSnackBar('Error opening link. Please make sure you have a browser installed.');
    }
  }

  Future<void> _launchInstagram() async {
    if (_userProfile?.instagram?.isEmpty ?? true) {
      _showSnackBar('No Instagram username available');
      return;
    }

    final username = _userProfile!.instagram!.replaceAll('@', '');
    final url = "https://instagram.com/$username";

    await _launchURL(url);
  }

  Future<void> _launchTwitter() async {
    if (_userProfile?.twitter?.isEmpty ?? true) {
      _showSnackBar('No Twitter username available');
      return;
    }

    final username = _userProfile!.twitter!.replaceAll('@', '');
    final url = "https://twitter.com/$username";

    await _launchURL(url);
  }

  Future<void> _launchFacebook() async {
    if (_userProfile?.facebook?.isEmpty ?? true) {
      _showSnackBar('No Facebook username available');
      return;
    }

    final username = _userProfile!.facebook!.replaceAll('@', '');
    final url = "https://facebook.com/$username";

    await _launchURL(url);
  }

  Future<void> _launchTikTok() async {
    if (_userProfile?.tiktok?.isEmpty ?? true) {
      _showSnackBar('No TikTok username available');
      return;
    }

    final username = _userProfile!.tiktok!.replaceAll('@', '');
    final url = "https://tiktok.com/@$username";

    await _launchURL(url);
  }

  Future<void> _launchYouTube() async {
    if (_userProfile?.youtube?.isEmpty ?? true) {
      _showSnackBar('No YouTube channel available');
      return;
    }

    final channel = _userProfile!.youtube!.replaceAll('@', '');
    final url = "https://youtube.com/c/$channel";

    await _launchURL(url);
  }

  Future<void> _launchEmail() async {
    final email = _userProfile?.email;
    if (email == null || email.isEmpty) {
      _showSnackBar('No email available');
      return;
    }

    try {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          'subject': 'Hello from Meet9ja!',
          'body': 'I found you on Meet9ja and wanted to connect!',
        },
      );

      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(
          emailLaunchUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showSnackBar('No email app found. Please install an email app.');
      }
    } catch (e) {
      print('Error launching email: $e');
      _showSnackBar('Error opening email app. Please install an email app.');
    }
  }

  Future<void> _launchWebsite() async {
    final website = _userProfile?.website;
    if (website == null || website.isEmpty) {
      _showSnackBar('No website available');
      return;
    }

    try {
      String websiteUrl = website;
      if (!websiteUrl.startsWith('http://') && !websiteUrl.startsWith('https://')) {
        websiteUrl = 'https://$websiteUrl';
      }

      final Uri uri = Uri.parse(websiteUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showSnackBar('Could not open website. Please check your connection.');
      }
    } catch (e) {
      print('Error launching website: $e');
      _showSnackBar('Error opening website. Please check the URL and try again.');
    }
  }

  void _showSnackBar(String message, {Color color = Colors.orange}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    if (_userProfile == null) {
      return _buildErrorScreen(message: 'User profile not found');
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _SliverHeader(
              isMyProfile: widget.isMyProfile,
              userProfile: _userProfile!,
              userStats: _userStats,
              isFollowing: _isFollowing,
              isMatched: _isMatched,
              isSmallScreen: isSmallScreen,
              onFollowTap: _toggleFollow,
              onMatchTap: _toggleMatch,
              onEditTap: _navigateToEditProfile,
              onManageMatchesTap: _navigateToMatchedUsers,
              onReportTap: () => _showReportDialog(context, _userProfile!),
              onInstagramTap: _launchInstagram,
              onTwitterTap: _launchTwitter,
              onFacebookTap: _launchFacebook,
              onTikTokTap: _launchTikTok,
              onYouTubeTap: _launchYouTube,
            ),

            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppColors.primary,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black54,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                  tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _getTabContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen({String? message}) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft, color: Colors.black),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HomeScreen()),
            );
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.exclamationTriangle,
              size: 60,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                message ?? _error ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getTabContent() {
    final tabs = [
      _HomeTab(userId: _userProfile!.uid, isMyProfile: widget.isMyProfile),
      _ClipsTab(userId: _userProfile!.uid, isMyProfile: widget.isMyProfile),
    ];

    if (widget.isMyProfile) {
      tabs.add(_WalletTab(userProfile: _userProfile!));
    }

    tabs.addAll([
      _SchedulesTab(
        userId: _userProfile!.uid,
        isMyProfile: widget.isMyProfile,
        userName: _userProfile!.name,
      ),
      _AboutTab(
        userProfile: _userProfile!,
        isMyProfile: widget.isMyProfile,
        onEmailTap: _launchEmail,
        onWebsiteTap: _launchWebsite,
        onInstagramTap: _launchInstagram,
        onTwitterTap: _launchTwitter,
        onFacebookTap: _launchFacebook,
        onTikTokTap: _launchTikTok,
        onYouTubeTap: _launchYouTube,
      ),
    ]);

    return tabs;
  }
}

// Header Widget
class _SliverHeader extends StatelessWidget {
  const _SliverHeader({
    required this.isMyProfile,
    required this.userProfile,
    required this.userStats,
    required this.isFollowing,
    required this.isMatched,
    required this.isSmallScreen,
    required this.onFollowTap,
    required this.onMatchTap,
    required this.onEditTap,
    required this.onManageMatchesTap,
    required this.onReportTap,
    required this.onInstagramTap,
    required this.onTwitterTap,
    required this.onFacebookTap,
    required this.onTikTokTap,
    required this.onYouTubeTap,
  });

  final bool isMyProfile;
  final UserModel userProfile;
  final Map<String, int> userStats;
  final bool isFollowing;
  final bool isMatched;
  final bool isSmallScreen;
  final VoidCallback onFollowTap;
  final VoidCallback onMatchTap;
  final VoidCallback onEditTap;
  final VoidCallback onManageMatchesTap;
  final VoidCallback onReportTap;
  final VoidCallback onInstagramTap;
  final VoidCallback onTwitterTap;
  final VoidCallback onFacebookTap;
  final VoidCallback onTikTokTap;
  final VoidCallback onYouTubeTap;

  bool get _hasSocialMedia {
    return userProfile.instagram?.isNotEmpty == true ||
        userProfile.twitter?.isNotEmpty == true ||
        userProfile.facebook?.isNotEmpty == true ||
        userProfile.tiktok?.isNotEmpty == true ||
        userProfile.youtube?.isNotEmpty == true;
  }

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = UserService.getProfilePhotoUrl(userProfile);
    final displayUsername = UserService.getDisplayUsername(userProfile);

    return SliverAppBar(
      expandedHeight: isSmallScreen ? 270.0 : 290.0,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
      shadowColor: Colors.black12,

      leading: IconButton(
        icon: const Icon(FontAwesomeIcons.arrowLeft, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(),
      ),

      actions: [
        if (isMyProfile)
          IconButton(
            icon: const Icon(FontAwesomeIcons.gear, size: 20),
            onPressed: () {
              FirebaseService.signOut();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => Signinscreen()),
              );
            },
          )
        else
          PopupMenuButton<String>(
            icon: const Icon(FontAwesomeIcons.ellipsisVertical, size: 20),
            onSelected: (value) {
              if (value == 'report') {
                onReportTap();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(FontAwesomeIcons.flag, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Report Profile'),
                  ],
                ),
              ),
            ],
          ),
      ],

      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 40),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: isSmallScreen ? 28 : 34,
                            backgroundImage: profilePhotoUrl != null
                                ? NetworkImage(profilePhotoUrl)
                                : const NetworkImage(
                              "https://i.pravatar.cc/160?img=8",
                            )
                            as ImageProvider,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProfile.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    fontSize: isSmallScreen ? 18 : 20,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayUsername,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    color: Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isMyProfile)
                            Container(
                              padding: const EdgeInsets.only(top: 24),
                              child: SizedBox(
                                width: isSmallScreen ? 65 : 75,
                                child: OutlinedButton(
                                  onPressed: onEditTap,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.black12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        FontAwesomeIcons.pencil,
                                        size: isSmallScreen ? 11 : 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Edit",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: isSmallScreen ? 11 : 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Stats Row
                SizedBox(
                  height: 55,
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: "Followers",
                          value: userStats['followers'] ?? 0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _StatTile(
                          label: "Following",
                          value: userStats['following'] ?? 0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _StatTile(
                          label: "Matches",
                          value: userStats['matches'] ?? 0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                const SizedBox(height: 4),
                if (isMyProfile)
                  _buildMyProfileActions()
                else
                  _buildOtherProfileActions(),

                // Social Media Handles
                if (_hasSocialMedia) _buildSocialMediaHandles(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyProfileActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onManageMatchesTap,
            icon: const Icon(FontAwesomeIcons.heart, size: 13),
            label: const Text(
              "Manage Matches",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: const BorderSide(color: Colors.black12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherProfileActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: isFollowing ? "Following" : "Follow",
            icon: isFollowing
                ? FontAwesomeIcons.userCheck
                : FontAwesomeIcons.userPlus,
            color: isFollowing ? Colors.grey : AppColors.primary,
            textColor: isFollowing ? Colors.black87 : Colors.white,
            onPressed: onFollowTap,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ActionButton(
            label: isMatched ? "Matched" : "Match",
            icon: isMatched
                ? FontAwesomeIcons.heartCircleCheck
                : FontAwesomeIcons.heart,
            color: isMatched ? Colors.green : AppColors.primary,
            textColor: Colors.white,
            onPressed: onMatchTap,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialMediaHandles() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Follow me on:",
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (userProfile.instagram?.isNotEmpty == true)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.instagram,
                  color: const Color(0xFFE4405F),
                  onTap: onInstagramTap,
                  isEnabled: true,
                ),
              if (userProfile.twitter?.isNotEmpty == true) const SizedBox(width: 12),
              if (userProfile.twitter?.isNotEmpty == true)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.xTwitter,
                  color: Colors.black,
                  onTap: onTwitterTap,
                  isEnabled: true,
                ),
              if (userProfile.facebook?.isNotEmpty == true) const SizedBox(width: 12),
              if (userProfile.facebook?.isNotEmpty == true)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.facebook,
                  color: const Color(0xFF1877F2),
                  onTap: onFacebookTap,
                  isEnabled: true,
                ),
              if (userProfile.tiktok?.isNotEmpty == true) const SizedBox(width: 12),
              if (userProfile.tiktok?.isNotEmpty == true)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.tiktok,
                  color: Colors.black,
                  onTap: onTikTokTap,
                  isEnabled: true,
                ),
              if (userProfile.youtube?.isNotEmpty == true) const SizedBox(width: 12),
              if (userProfile.youtube?.isNotEmpty == true)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.youtube,
                  color: const Color(0xFFFF0000),
                  onTap: onYouTubeTap,
                  isEnabled: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// UI Components
class _StatTile extends StatelessWidget {
  final String label;
  final int value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _shortNumber(value),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

String _shortNumber(int n) {
  if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
  if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
  return n.toString();
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFFF0F0F0),
    this.textColor = Colors.black87,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 13),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: textColor,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _SocialMediaIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isEnabled;

  const _SocialMediaIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled
              ? color.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isEnabled
                ? color.withOpacity(0.3)
                : Colors.grey.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isEnabled ? color : Colors.grey,
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}

// Report Reason Tile Widget
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

// Home Tab with Live Streams
class _HomeTab extends StatefulWidget {
  final String userId;
  final bool isMyProfile;
  const _HomeTab({required this.userId, required this.isMyProfile});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<LiveHistory> _liveHistory = [];
  bool _isLoading = true;
  String? _error;
  Map<String, bool> _currentLiveStatus = {};

  @override
  void initState() {
    super.initState();
    _loadLiveHistory();
    _subscribeToLiveStatus();
  }

  Future<void> _loadLiveHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final history = await UserService.getUserLiveHistory(widget.userId);

      setState(() {
        _liveHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load live history: $e';
        _isLoading = false;
      });
    }
  }

  void _subscribeToLiveStatus() {
    FirebaseFirestore.instance
        .collection('liveStreams')
        .where('UID', isEqualTo: widget.userId)
        .where('isLive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final liveStatus = <String, bool>{};
      for (final doc in snapshot.docs) {
        liveStatus[doc.id] = true;
      }

      if (mounted) {
        setState(() {
          _currentLiveStatus = liveStatus;
        });
      }
    }, onError: (error) {
      print('Error listening to live status: $error');
    });
  }

  bool _isUserCurrentlyLive() {
    return _currentLiveStatus.isNotEmpty;
  }

  String _getCurrentLiveId() {
    return _currentLiveStatus.keys.firstOrNull ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final isCurrentlyLive = _isUserCurrentlyLive();
    final currentLiveId = _getCurrentLiveId();

    return RefreshIndicator(
      onRefresh: _loadLiveHistory,
      child: CustomScrollView(
        slivers: [
          if (isCurrentlyLive)
            _buildCurrentLiveBanner(currentLiveId),

          _buildLiveHistoryHeader(),

          if (_liveHistory.isEmpty)
            _buildEmptyState()
          else
            _buildLiveHistoryList(),

          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading live history...',
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
            Icons.error_outline,
            size: 60,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading content',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadLiveHistory,
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

  Widget _buildCurrentLiveBanner(String liveId) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red, Colors.orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE NOW',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'User is currently live!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => _joinLiveStream(liveId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'JOIN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveHistoryHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            const Text(
              'Live History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_liveHistory.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.live_tv_rounded,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No live history yet',
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
              'When this user goes live, their streams will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveHistoryList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final live = _liveHistory[index];
          return _LiveHistoryCard(
            liveHistory: live,
            onTap: () => _viewLiveReplay(live),
          );
        },
        childCount: _liveHistory.length,
      ),
    );
  }

  void _joinLiveStream(String liveId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to join live stream')),
        );
        return;
      }

      final userProfile = await UserService.getUserProfile(currentUser.uid);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveStreamScreen(
            liveId: liveId,
            userId: currentUser.uid,
            isHost: false,
            userName: userProfile?.name ?? 'User',
            hostId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining live: $e')),
      );
    }
  }

  void _viewLiveReplay(LiveHistory live) {
    if (live.liveReplayMediaUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No replay available for this stream')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(live.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Duration', '${live.durationSeconds} seconds'),
              _buildInfoRow('Viewers', '${live.viewerCount}'),
              _buildInfoRow('Gifts', '${live.totalGiftValue} coins'),
              _buildInfoRow('Status', live.uploadStatus),
              _buildInfoRow('Recording', live.recordingType),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Replay URL:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      live.liveReplayMediaUrl,
                      style: const TextStyle(fontSize: 10, color: Colors.blue),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (live.liveReplayMediaUrl.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _launchReplayUrl(live.liveReplayMediaUrl),
                    child: const Text('Watch Replay'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _copyToClipboard(live.liveReplayMediaUrl),
                    child: const Text('Copy URL'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _launchReplayUrl(String url) async {
    try {
      print('🔗 Attempting to play video: $url');

      String cleanedUrl = url.trim();

      if (cleanedUrl.endsWith('.mp4')) {
        print('🎥 MP4 file detected, opening video player');
        _openVideoPlayer(cleanedUrl);
      } else if (cleanedUrl.contains('youtube.com') || cleanedUrl.contains('youtu.be')) {
        print('📺 YouTube URL detected');
        _openYouTubeVideo(cleanedUrl);
      } else {
        print('🌐 Generic URL, attempting to open in browser');
        _openInBrowser(cleanedUrl);
      }
    } catch (e) {
      print('❌ Error handling replay URL: $e');
      _showReplayFallbackOptions(url, error: e.toString());
    }
  }

  void _openVideoPlayer(String videoUrl) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading video...'),
            ],
          ),
        ),
      );

      final videoPlayerController = VideoPlayerController.network(videoUrl);
      await videoPlayerController.initialize();

      if (mounted) Navigator.of(context).pop();

      final chewieController = ChewieController(
        videoPlayerController: videoPlayerController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 300,
                  child: Chewie(controller: chewieController),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  chewieController.pause();
                  videoPlayerController.dispose();
                  chewieController.dispose();
                  Navigator.of(context).pop();
                },
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      print('❌ Error playing video: $e');
      _showVideoError(videoUrl, e.toString());
    }
  }

  void _openYouTubeVideo(String url) async {
    try {
      String videoId = '';

      if (url.contains('youtube.com/watch?v=')) {
        videoId = url.split('v=')[1].split('&')[0];
      } else if (url.contains('youtu.be/')) {
        videoId = url.split('youtu.be/')[1].split('?')[0];
      } else if (url.contains('youtube.com/embed/')) {
        videoId = url.split('embed/')[1].split('?')[0];
      }

      if (videoId.isNotEmpty) {
        final youtubeAppUrl = 'vnd.youtube:$videoId';
        final youtubeWebUrl = 'https://www.youtube.com/watch?v=$videoId';

        final Uri appUri = Uri.parse(youtubeAppUrl);
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri);
          return;
        }

        final Uri webUri = Uri.parse(youtubeWebUrl);
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open YouTube URL');
      }
    } catch (e) {
      print('❌ Error opening YouTube: $e');
      _showReplayFallbackOptions(url, error: 'Cannot open YouTube: $e');
    }
  }

  void _openInBrowser(String url) async {
    try {
      String cleanedUrl = url;
      if (!cleanedUrl.startsWith('http://') && !cleanedUrl.startsWith('https://')) {
        cleanedUrl = 'https://$cleanedUrl';
      }

      final Uri uri = Uri.parse(cleanedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open URL in browser');
      }
    } catch (e) {
      print('❌ Error opening in browser: $e');
      _showReplayFallbackOptions(url, error: 'Cannot open in browser: $e');
    }
  }

  void _showVideoError(String url, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Playback Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unable to play the video: $error'),
            const SizedBox(height: 12),
            const Text('This could be because:'),
            const SizedBox(height: 8),
            const Text('• The video file is corrupted'),
            const Text('• The URL is not accessible'),
            const Text('• Network connectivity issues'),
            const Text('• File format not supported'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showReplayFallbackOptions(url, error: error);
            },
            child: const Text('Try Other Options'),
          ),
        ],
      ),
    );
  }

  void _showReplayFallbackOptions(String url, {String? error}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replay Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              Text('Error: $error', style: TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 12),
            const Text('Choose how you want to access the replay:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _copyToClipboard(url);
            },
            child: const Text('Copy URL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openInBrowser(url);
            },
            child: const Text('Open in Browser'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL copied to clipboard')),
    );
  }
}

class _LiveHistoryCard extends StatelessWidget {
  final LiveHistory liveHistory;
  final VoidCallback onTap;

  const _LiveHistoryCard({
    required this.liveHistory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValidUrl = liveHistory.liveReplayMediaUrl.isNotEmpty &&
        (liveHistory.liveReplayMediaUrl.contains('http') ||
            liveHistory.liveReplayMediaUrl.contains('.mp4') ||
            liveHistory.liveReplayMediaUrl.contains('youtube') ||
            liveHistory.liveReplayMediaUrl.contains('vimeo'));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      liveHistory.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusIndicator(liveHistory.uploadStatus),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  _buildStatItem(
                    Icons.people,
                    '${liveHistory.viewerCount}',
                  ),
                  const SizedBox(width: 16),
                  _buildStatItem(
                    Icons.card_giftcard,
                    '${liveHistory.totalGiftValue}',
                  ),
                  const SizedBox(width: 16),
                  _buildStatItem(
                    Icons.timer,
                    '${liveHistory.durationSeconds}s',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                _formatDateTime(liveHistory.endTime),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),

              if (hasValidUrl)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Replay Available',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    String text;

    switch (status) {
      case 'success':
        color = Colors.green;
        text = 'Completed';
        break;
      case 'partial_success':
        color = Colors.orange;
        text = 'Partial';
        break;
      case 'failed':
        color = Colors.red;
        text = 'Failed';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
    }

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        )
    );
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y • h:mm a').format(date);
    }
  }
}

// Add this to your UserService class
extension UserServiceExtensions on UserService {
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
}

// Clips Tab
class _ClipsTab extends StatefulWidget {
  final String userId;
  final bool isMyProfile;
  const _ClipsTab({required this.userId, required this.isMyProfile});

  @override
  State<_ClipsTab> createState() => _ClipsTabState();
}

class _ClipsTabState extends State<_ClipsTab> {
  late Stream<List<StoryModel>> _storiesStream;
  late UniqueKey _storiesKey;

  @override
  void initState() {
    super.initState();
    _storiesKey = UniqueKey();
    _storiesStream = UserService.getUserStoriesStream(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stories Section - Fixed height
        _buildStoriesSection(),
        const SizedBox(height: 20),
        // Add Post Button (only for my profile)
        if (widget.isMyProfile) _buildAddPostButton(),

        const SizedBox(height: 16),
        // Posts Grid - Takes remaining space
        Expanded(
          child: _buildPostsGrid(),
        ),
      ],
    );
  }

  Widget _buildAddPostButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _createNewPost,
          icon: const Icon(FontAwesomeIcons.plus, size: 16),
          label: const Text(
            'Create New Post',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  void _createNewPost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(userId: widget.userId),
      ),
    );

    if (result == true && mounted) {
      // Refresh the posts grid
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildStoriesSection() {
    return StreamBuilder<List<StoryModel>>(
      stream: _storiesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildStoriesLoading();
        }

        if (snapshot.hasError) {
          return _buildStoriesError(snapshot.error.toString());
        }

        final stories = snapshot.data ?? [];

        // If no stories and not my profile, don't show stories section
        if (stories.isEmpty && !widget.isMyProfile) {
          return const SizedBox.shrink();
        }

        return Container(
          key: _storiesKey,
          height: 140,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Stories',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    // Add Story Button (only for my profile)
                    if (widget.isMyProfile) _buildAddStoryButton(),

                    // User's Stories with unique keys
                    ...stories.map((story) => _buildStoryCircle(
                      story,
                      key: ValueKey('story_${story.id}_${story.createdAt.millisecondsSinceEpoch}'),
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoriesLoading() {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Stories',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                if (widget.isMyProfile)
                  _buildAddStoryButtonSkeleton(),
                _buildStoryCircleSkeleton(),
                _buildStoryCircleSkeleton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesError(String error) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Stories',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Text(
                'Error loading stories',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddStoryButtonSkeleton() {
    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: Icon(Icons.add, size: 30, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Story',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCircleSkeleton() {
    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 12,
            color: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildAddStoryButton() {
    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          GestureDetector(
            onTap: _createNewStory,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: Icon(Icons.add, size: 30, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your Story',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _createNewStory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateStoryScreen(userId: widget.userId),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _storiesKey = UniqueKey();
      });

      await Future.delayed(Duration(milliseconds: 500));

      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildStoryCircle(StoryModel story, {Key? key}) {
    return Container(
      key: key,
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoryViewScreen(
                    stories: [story],
                    initialIndex: 0,
                  ),
                ),
              );
            },
            child: Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, Colors.pink, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  image: DecorationImage(
                    image: NetworkImage(story.mediaUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatStoryTime(story),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatStoryTime(StoryModel story) {
    final remaining = story.timeRemaining;
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m';
    } else {
      return 'Ending';
    }
  }

  Widget _buildPostsGrid() {
    return StreamBuilder<List<PostModel>>(
      stream: UserService.getUserPostsStream(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FontAwesomeIcons.video, size: 60, color: Colors.black26),
                const SizedBox(height: 16),
                Text(
                  "No posts yet.",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                if (widget.isMyProfile) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Create posts to share with your followers!",
                    style: TextStyle(fontSize: 14, color: Colors.black45),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.8,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(postId: post.id),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(post.mediaUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    if (post.likes.isNotEmpty)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                FontAwesomeIcons.solidHeart,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                post.likes.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Complete Wallet Tab with Google Pay & Apple Pay Integration
class _WalletTab extends StatefulWidget {
  final UserModel userProfile;
  const _WalletTab({required this.userProfile});

  @override
  State<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<_WalletTab> {
  bool _isLoading = false;
  bool _isWithdrawing = false;
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _banks = [];
  String? _selectedCountryCode;

  // Flutterwave credentials
  final bool _isTestMode = true; // Set to false for production
  late final String _publicKey = _isTestMode
      ? "FLWPUBK_TEST-befed163ca7c7e9909b525da24b1332d-X"
      : "YOUR_LIVE_PUBLIC_KEY";
  late final String _secretKey = _isTestMode
      ? "FLWSECK_TEST-40e21085dd94e60bb65a13d7987295af-X"
      : "YOUR_LIVE_SECRET_KEY";
  final String _baseUrl = "https://api.flutterwave.com/v3";

  // Diamond packages in USD
  final List<Map<String, dynamic>> _diamondPackages = [
    {'diamonds': 10, 'price': 1.0, 'label': '10 Diamonds'},
    {'diamonds': 50, 'price': 5.0, 'label': '50 Diamonds'},
    {'diamonds': 100, 'price': 10.0, 'label': '100 Diamonds'},
    {'diamonds': 500, 'price': 45.0, 'label': '500 Diamonds\n(10% OFF)'},
    {'diamonds': 1000, 'price': 80.0, 'label': '1000 Diamonds\n(20% OFF)'},
    {'diamonds': 2000, 'price': 150.0, 'label': '2000 Diamonds\n(25% OFF)'},
  ];

  // Payment methods
  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'card',
      'name': 'Credit/Debit Card',
      'icon': FontAwesomeIcons.creditCard,
      'color': Colors.blue,
      'description': 'Pay with Visa, Mastercard, etc.'
    },
    {
      'id': 'googlepay',
      'name': 'Google Pay',
      'icon': FontAwesomeIcons.google,
      'color': Colors.red,
      'description': 'Fast and secure Google Pay'
    },
    {
      'id': 'applepay',
      'name': 'Apple Pay',
      'icon': FontAwesomeIcons.apple,
      'color': Colors.black,
      'description': 'Secure Apple Pay payment'
    },
    {
      'id': 'banktransfer',
      'name': 'Bank Transfer',
      'icon': FontAwesomeIcons.buildingColumns,
      'color': Colors.green,
      'description': 'Direct bank transfer'
    },
  ];

  String? _selectedPaymentMethod = 'card';

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _checkMobileWalletSupport();
  }

  // Check if Google Pay/Apple Pay are supported
  void _checkMobileWalletSupport() {
    print('🔍 Checking mobile wallet support...');

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      print('📱 iOS device detected - Apple Pay should be available');
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      print('📱 Android device detected - Google Pay should be available');
    }
  }

  // Enhanced diamond purchase with multiple payment methods
  Future<void> _purchaseDiamonds(int diamonds, double price) async {
    if (_isLoading) return;

    // Show payment method selection
    final selectedMethod = await _showPaymentMethodDialog(diamonds, price);
    if (selectedMethod == null) return;

    setState(() {
      _isLoading = true;
      _selectedPaymentMethod = selectedMethod;
    });

    try {
      final Customer customer = Customer(
          email: widget.userProfile.email,
          phoneNumber: _getDefaultPhoneNumber(),
          name: widget.userProfile.name
      );

      // Configure payment options based on selected method
      String paymentOptions = "googlepay";

      if (selectedMethod == 'googlepay') {
        paymentOptions = "googlepay";
      } else if (selectedMethod == 'applepay') {
        paymentOptions = "applepay";
      }

      final Flutterwave flutterwave = Flutterwave(
        publicKey: _publicKey,
        currency: "USD",
        amount: price.toStringAsFixed(2),
        customer: customer,
        txRef: Uuid().v4(),
        paymentOptions: paymentOptions,
        customization: Customization(
          title: "Purchase Diamonds",
          description: "Get ${diamonds} diamonds for \$$price",
          logo: "https://your-app-logo.com/logo.png",
        ),
        redirectUrl: "https://www.google.com",
        isTestMode: _isTestMode,
      );

      print('💎 Initiating diamond purchase: $diamonds diamonds for \$$price');
      print('💳 Selected payment method: $selectedMethod');

      final ChargeResponse response = await flutterwave.charge(context);

      print('💰 Payment response: ${response.toJson()}');

      if (mounted) {
        if (response.status == 'successful') {
          await _addDiamondsToWallet(diamonds);
          await _sendPaymentNotification(
              diamonds,
              price,
              selectedMethod,
              response.txRef!
          );

          _showSuccessDialog(
              'Purchase Successful!',
              'You have successfully purchased $diamonds diamonds using ${_getPaymentMethodName(selectedMethod)}! 🎉\n\n'
                  'Transaction ID: ${response.txRef}'
          );
        } else {
          _showErrorDialog('Payment failed: ${response.status ?? "Please try again."}');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Payment error: $e');
      print('📝 Stack trace: $stackTrace');

      if (mounted) {
        _showErrorDialog('Payment error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show payment method selection dialog
  Future<String?> _showPaymentMethodDialog(int diamonds, double price) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(FontAwesomeIcons.creditCard, size: 24),
            SizedBox(width: 8),
            Text('Select Payment Method'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Purchase $diamonds diamonds for \$$price',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              ..._paymentMethods.map((method) => _PaymentMethodTile(
                method: method,
                isSelected: _selectedPaymentMethod == method['id'],
                onTap: () {
                  Navigator.of(context).pop(method['id']);
                },
              )).toList(),

              const SizedBox(height: 16),

              // Security info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All payments are secure and encrypted',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodName(String methodId) {
    switch (methodId) {
      case 'googlepay':
        return 'Google Pay';
      case 'applepay':
        return 'Apple Pay';
      case 'card':
        return 'Credit/Debit Card';
      case 'banktransfer':
        return 'Bank Transfer';
      default:
        return 'Payment';
    }
  }

  // Enhanced payment notification
  Future<void> _sendPaymentNotification(
      int diamonds,
      double price,
      String method,
      String transactionId
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final notificationId = 'payment_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('notifications').doc(notificationId).set({
        'notification_id': notificationId,
        'UID': user.uid,
        'title': 'Payment Successful! 💎',
        'message': 'You purchased $diamonds diamonds for \$$price using ${_getPaymentMethodName(method)}',
        'type': 'payment_success',
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
        'data': {
          'diamonds': diamonds,
          'amount': price,
          'payment_method': method,
          'transaction_id': transactionId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      });

      print('✅ Payment notification sent for $diamonds diamonds');
    } catch (e) {
      print('❌ Error sending payment notification: $e');
    }
  }

  // Quick purchase method for one-tap payments
  Future<void> _quickPurchaseWithMobileWallet(int diamonds, double price, String method) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _selectedPaymentMethod = method;
    });

    try {
      final Customer customer = Customer(
          email: widget.userProfile.email,
          phoneNumber: _getDefaultPhoneNumber(),
          name: widget.userProfile.name
      );

      final Flutterwave flutterwave = Flutterwave(
        publicKey: _publicKey,
        currency: "USD",
        amount: price.toStringAsFixed(2),
        customer: customer,
        txRef: Uuid().v4(),
        paymentOptions: method,
        customization: Customization(
          title: "Quick Diamond Purchase",
          description: "Get ${diamonds} diamonds instantly",
          logo: "https://your-app-logo.com/logo.png",
        ),
        redirectUrl: "https://www.google.com",
        isTestMode: _isTestMode,
      );

      print('⚡ Quick purchase: $diamonds diamonds with $method');

      final ChargeResponse response = await flutterwave.charge(context);

      if (mounted) {
        if (response.status == 'successful') {
          await _addDiamondsToWallet(diamonds);

          _showSuccessDialog(
              'Quick Purchase Complete!',
              '$diamonds diamonds added to your wallet! ⚡\n\n'
                  'Paid with ${_getPaymentMethodName(method)}'
          );
        } else {
          _showErrorDialog('Quick purchase failed. Please try again.');
        }
      }
    } catch (e) {
      print('❌ Quick purchase error: $e');
      if (mounted) {
        _showErrorDialog('Quick purchase failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Mobile wallet quick action buttons
  Widget _buildMobileWalletQuickActions() {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final quickPackages = _diamondPackages.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Purchase",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isIOS
              ? "One-tap purchase with Apple Pay"
              : "Fast checkout with Google Pay",
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),

        // Quick purchase buttons
        Row(
          children: quickPackages.map((package) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: _QuickPurchaseCard(
                  diamonds: package['diamonds'],
                  price: package['price'],
                  isIOS: isIOS,
                  onTap: () => _quickPurchaseWithMobileWallet(
                      package['diamonds'],
                      package['price'],
                      isIOS ? 'applepay' : 'googlepay'
                  ),
                  isLoading: _isLoading,
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // Add diamonds to wallet
  Future<void> _addDiamondsToWallet(int diamonds) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final currentWallet = userData['wallet'] ?? {};

        // Handle type conversion safely
        final currentDiamonds = (currentWallet['diamond_balance'] ?? 0).toInt();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'wallet.diamond_balance': currentDiamonds + diamonds,
          'updated_at': FieldValue.serverTimestamp(),
        });

        print('✅ Added $diamonds diamonds to wallet');
      }
    } catch (e) {
      print('❌ Error adding diamonds to wallet: $e');
      throw 'Failed to update wallet: $e';
    }
  }

  // Exchange rate: 100 coins = $1
  double _convertCoinsToUSD(int coins) {
    return coins / 100.0;
  }

  int _convertUSDToCoins(double usdAmount) {
    return (usdAmount * 100).round();
  }

  // Flutterwave API Headers
  Map<String, String> _getHeaders() {
    return {
      'Authorization': 'Bearer $_secretKey',
      'Content-Type': 'application/json',
    };
  }

  // Load supported countries from Flutterwave API
  Future<void> _loadCountries() async {
    try {
      // For testing, use mock data
      if (_isTestMode) {
        _countries = [
          {'code': 'NG', 'name': 'Nigeria', 'currency': 'NGN', 'flag': '🇳🇬', 'is_rtp': true},
          {'code': 'GH', 'name': 'Ghana', 'currency': 'GHS', 'flag': '🇬🇭', 'is_rtp': true},
          {'code': 'KE', 'name': 'Kenya', 'currency': 'KES', 'flag': '🇰🇪', 'is_rtp': true},
          {'code': 'UG', 'name': 'Uganda', 'currency': 'UGX', 'flag': '🇺🇬', 'is_rtp': true},
          {'code': 'TZ', 'name': 'Tanzania', 'currency': 'TZS', 'flag': '🇹🇿', 'is_rtp': true},
          {'code': 'ZA', 'name': 'South Africa', 'currency': 'ZAR', 'flag': '🇿🇦', 'is_rtp': true},
          {'code': 'US', 'name': 'United States', 'currency': 'USD', 'flag': '🇺🇸', 'is_rtp': false},
          {'code': 'UK', 'name': 'United Kingdom', 'currency': 'GBP', 'flag': '🇬🇧', 'is_rtp': false},
        ];
      } else {
        // Production: Call Flutterwave countries API
        final response = await http.get(
          Uri.parse('$_baseUrl/countries'),
          headers: _getHeaders(),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success') {
            _countries = List<Map<String, dynamic>>.from(data['data']
                .where((country) => country['is_rtp'] == true)
                .map((country) => {
              'code': country['code'],
              'name': country['name'],
              'currency': country['currency'],
              'flag': _getFlagEmoji(country['code']),
              'is_rtp': country['is_rtp'],
            }));
          }
        }
      }

      setState(() {
        _selectedCountryCode = 'NG';
      });

      await _loadBanksForCountry('NG');
    } catch (e) {
      print('❌ Error loading countries: $e');
      // Fallback to test data
      _countries = [
        {'code': 'NG', 'name': 'Nigeria', 'currency': 'NGN', 'flag': '🇳🇬', 'is_rtp': true},
        {'code': 'GH', 'name': 'Ghana', 'currency': 'GHS', 'flag': '🇬🇭', 'is_rtp': true},
      ];
      setState(() {});
    }
  }

  // Load banks for a country using Flutterwave API
  Future<void> _loadBanksForCountry(String countryCode) async {
    try {
      setState(() {
        _banks = [];
      });

      if (_isTestMode) {
        // Test data
        await Future.delayed(const Duration(milliseconds: 500));
        _banks = _getTestBanksForCountry(countryCode);
      } else {
        // Production: Call Flutterwave banks API
        final response = await http.get(
          Uri.parse('$_baseUrl/banks/$countryCode'),
          headers: _getHeaders(),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success') {
            _banks = List<Map<String, dynamic>>.from(data['data']
                .where((bank) => bank['active'] == true)
                .map((bank) => {
              'code': bank['code'].toString(),
              'name': bank['name'],
              'id': bank['id'],
            }));
          }
        }
      }

      setState(() {});
    } catch (e) {
      print('❌ Error loading banks: $e');
      _banks = _getTestBanksForCountry(countryCode);
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _getTestBanksForCountry(String countryCode) {
    switch (countryCode) {
      case 'NG':
        return [
          {'code': '044', 'name': 'Access Bank'},
          {'code': '063', 'name': 'Diamond Bank'},
          {'code': '058', 'name': 'Guaranty Trust Bank'},
          {'code': '033', 'name': 'United Bank For Africa'},
          {'code': '032', 'name': 'Union Bank of Nigeria'},
          {'code': '035', 'name': 'Wema Bank'},
          {'code': '057', 'name': 'Zenith Bank'},
        ];
      case 'GH':
        return [
          {'code': '030100', 'name': 'Absa Bank Ghana'},
          {'code': '280100', 'name': 'GCB Bank'},
          {'code': '130100', 'name': 'Ecobank Ghana'},
        ];
      case 'KE':
        return [
          {'code': '01000', 'name': 'KCB Bank Kenya'},
          {'code': '02000', 'name': 'Standard Chartered Kenya'},
          {'code': '03000', 'name': 'Absa Bank Kenya'},
        ];
      default:
        return [
          {'code': '00100', 'name': 'Default Bank 1'},
          {'code': '00200', 'name': 'Default Bank 2'},
        ];
    }
  }

  String _getFlagEmoji(String countryCode) {
    final flags = {
      'NG': '🇳🇬', 'GH': '🇬🇭', 'KE': '🇰🇪', 'UG': '🇺🇬',
      'TZ': '🇹🇿', 'ZA': '🇿🇦', 'US': '🇺🇸', 'UK': '🇬🇧',
    };
    return flags[countryCode] ?? '🇺🇳';
  }

  String _getDefaultPhoneNumber() {
    return "2348100000000";
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Flexible(child: Text(title)),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Continue', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final diamondBalance = UserService.getDiamondBalance(widget.userProfile);
    final coinBalance = UserService.getCoinBalance(widget.userProfile);
    final availableUSD = _convertCoinsToUSD(coinBalance);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Overview Section
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    _isTestMode ? 'Test Wallet' : 'Global Wallet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Balances
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BalanceItem(
                        label: 'Diamonds',
                        value: '$diamondBalance 💎',
                        subtitle: 'Purchased',
                        color: Colors.white,
                      ),
                      _BalanceItem(
                        label: 'Coins',
                        value: '$coinBalance 🪙',
                        subtitle: 'Earned',
                        color: Colors.white,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Available USD
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(FontAwesomeIcons.dollarSign,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Available: \$${availableUSD.toStringAsFixed(2)} USD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(FontAwesomeIcons.globe, color: Colors.white, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Purchase Section with Mobile Wallets
          _buildMobileWalletQuickActions(),

          // Buy Diamonds Section
          const Text(
            "Buy Diamonds",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Get diamonds to send gifts, unlock premium features, and support creators",
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),

          // Diamond Packages Grid
          SizedBox(
            height: 200,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _diamondPackages.map((package) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _diamondPackageCard(package),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Payment Methods Info
          _buildPaymentMethodsInfo(),

          // Wallet Actions
          const Text(
            "Wallet Actions",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),

          _walletTile(
            title: "Diamonds Balance",
            value: "$diamondBalance 💎",
            subtitle: "Purchased currency for sending gifts",
            icon: FontAwesomeIcons.diamond,
            iconColor: Colors.blue,
          ),

          _walletTile(
            title: "Coins Balance",
            value: "$coinBalance 🪙",
            subtitle: "Earned from gifts received",
            icon: FontAwesomeIcons.coins,
            iconColor: Colors.amber,
          ),

          _walletTile(
            title: "Available USD",
            value: "\$${availableUSD.toStringAsFixed(2)}",
            subtitle: "Withdrawable amount",
            icon: FontAwesomeIcons.dollarSign,
            iconColor: Colors.green,
          ),

          // Global Info Section
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(FontAwesomeIcons.globe, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Global Payment Support',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _InfoBullet(
                  icon: '💎',
                  text: 'Buy diamonds with Credit Cards, Google Pay & Apple Pay',
                ),
                _InfoBullet(
                  icon: '🌍',
                  text: 'Available in multiple countries worldwide',
                ),
                _InfoBullet(
                  icon: '🔒',
                  text: 'All payments are secure and encrypted',
                ),
                _InfoBullet(
                  icon: '⚡',
                  text: 'Instant diamond delivery after payment',
                ),
                if (_isTestMode) ...[
                  const SizedBox(height: 8),
                  _InfoBullet(
                    icon: '🧪',
                    text: 'TEST MODE - No real money transactions',
                  ),
                ],
              ],
            ),
          ),

          // Test Mode Indicator
          if (_isTestMode)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isTestMode
                          ? 'Test Mode - Use test card/bank details. No real money involved.'
                          : 'Live Mode - Real transactions enabled',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Supported Payment Methods',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentMethods.map((method) => Chip(
              label: Text(method['name']),
              avatar: Icon(method['icon'], size: 16, color: method['color']),
              backgroundColor: Colors.white,
            )).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _isTestMode
                ? 'Test Mode: Use test cards for testing'
                : 'All payments are secure and encrypted',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    Color iconColor = Colors.black87,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: isLoading ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: isLoading
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Icon(icon, color: iconColor, size: 24),
        title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isLoading ? Colors.grey : Colors.black87,
            )
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
              fontSize: 12,
              color: isLoading ? Colors.grey : Colors.black54
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: isLoading ? Colors.grey : Colors.black87,
              ),
            ),
            if (onTap != null && !isLoading) const SizedBox(width: 8),
            if (onTap != null && !isLoading)
              const Icon(
                FontAwesomeIcons.chevronRight,
                size: 14,
                color: Colors.black54,
              ),
          ],
        ),
      ),
    );
  }

  Widget _diamondPackageCard(Map<String, dynamic> package) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${package['diamonds']}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Icon(FontAwesomeIcons.diamond,
                color: Colors.blue, size: 20),
            const SizedBox(height: 8),
            Text(
              '\$${package['price']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              package['label'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _purchaseDiamonds(package['diamonds'], package['price']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'BUY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Payment Method Tile Widget
class _PaymentMethodTile extends StatelessWidget {
  final Map<String, dynamic> method;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? method['color'] : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          method['icon'],
          color: method['color'],
          size: 24,
        ),
        title: Text(
          method['name'],
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? method['color'] : Colors.black87,
          ),
        ),
        subtitle: Text(
          method['description'],
          style: const TextStyle(fontSize: 12),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: method['color'])
            : null,
      ),
    );
  }
}

// Quick Purchase Card Widget
class _QuickPurchaseCard extends StatelessWidget {
  final int diamonds;
  final double price;
  final bool isIOS;
  final VoidCallback onTap;
  final bool isLoading;

  const _QuickPurchaseCard({
    required this.diamonds,
    required this.price,
    required this.isIOS,
    required this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isIOS
                  ? [Colors.black, Colors.grey[800]!]
                  : [Colors.red, Colors.redAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$diamonds 💎',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$$price',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isIOS ? FontAwesomeIcons.apple : FontAwesomeIcons.google,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Supporting UI Components
class _BalanceItem extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _BalanceItem({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _InfoBullet extends StatelessWidget {
  final String icon;
  final String text;

  const _InfoBullet({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

// Schedules Tab
class _SchedulesTab extends StatefulWidget {
  final String userId;
  final bool isMyProfile;
  final String userName;
  const _SchedulesTab({
    required this.userId,
    required this.isMyProfile,
    required this.userName,
  });

  @override
  State<_SchedulesTab> createState() => _SchedulesTabState();
}

class _SchedulesTabState extends State<_SchedulesTab> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final schedules = await UserService.getUserSchedules(widget.userId);

      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load schedules: $e';
        _isLoading = false;
      });
    }
  }

  void _createNewSchedule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateScheduleScreen(userId: widget.userId),
      ),
    );

    if (result == true && mounted) {
      _loadSchedules();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _deleteSchedule(String scheduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await UserService.deleteSchedule(scheduleId);
        if (mounted) {
          _loadSchedules();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Schedule deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete schedule: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        // Create Schedule Button (only for my profile)
        if (widget.isMyProfile) _buildCreateScheduleButton(),

        const SizedBox(height: 16),

        // Schedules List
        Expanded(
          child: _schedules.isEmpty
              ? _buildEmptyState()
              : _buildSchedulesList(),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading schedules...',
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
            Icons.error_outline,
            size: 60,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading schedules',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black45,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadSchedules,
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

  Widget _buildCreateScheduleButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _createNewSchedule,
          icon: const Icon(FontAwesomeIcons.calendarPlus, size: 16),
          label: const Text(
            'Create New Schedule',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.calendar,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            widget.isMyProfile ? "No schedules yet." : "No scheduled streams.",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isMyProfile
                ? "Create schedules to let your followers know when you'll be live!"
                : "Check back later for upcoming streams.",
            style: TextStyle(fontSize: 14, color: Colors.black45),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesList() {
    return RefreshIndicator(
      onRefresh: _loadSchedules,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _schedules.length,
        itemBuilder: (context, index) {
          final schedule = _schedules[index];
          return _ScheduleCard(
            schedule: schedule,
            isMyProfile: widget.isMyProfile,
            onDelete: () => _deleteSchedule(schedule['id']),
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final bool isMyProfile;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.schedule,
    required this.isMyProfile,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = schedule['title'] ?? 'Untitled Schedule';
    final description = schedule['description'] ?? '';
    final scheduledTime = (schedule['scheduled_time'] as Timestamp).toDate();
    final now = DateTime.now();
    final timeUntil = scheduledTime.difference(now);
    final isUpcoming = timeUntil > Duration.zero;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMyProfile)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, y • h:mm a').format(scheduledTime),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isUpcoming ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isUpcoming
                    ? _getTimeUntilString(timeUntil)
                    : 'Completed',
                style: TextStyle(
                  fontSize: 12,
                  color: isUpcoming ? AppColors.primary : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeUntilString(Duration duration) {
    if (duration.inDays > 0) {
      return 'In ${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return 'In ${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return 'In ${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Starting soon';
    }
  }
}

// About Tab
class _AboutTab extends StatefulWidget {
  final UserModel userProfile;
  final bool isMyProfile;
  final VoidCallback onEmailTap;
  final VoidCallback onWebsiteTap;
  final VoidCallback onInstagramTap;
  final VoidCallback onTwitterTap;
  final VoidCallback onFacebookTap;
  final VoidCallback onTikTokTap;
  final VoidCallback onYouTubeTap;

  const _AboutTab({
    required this.userProfile,
    required this.isMyProfile,
    required this.onEmailTap,
    required this.onWebsiteTap,
    required this.onInstagramTap,
    required this.onTwitterTap,
    required this.onFacebookTap,
    required this.onTikTokTap,
    required this.onYouTubeTap,
  });

  @override
  State<_AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<_AboutTab> {
  @override
  Widget build(BuildContext context) {
    final joinDate = UserService.getFormattedJoinDate(widget.userProfile);
    final primaryMode = UserService.getPrimaryMode(widget.userProfile);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio Section
          _SectionCard(
            title: "Bio",
            child: Text(
              widget.userProfile.bio?.isNotEmpty == true
                  ? widget.userProfile.bio!
                  : 'No bio yet. ${widget.isMyProfile ? 'Add a bio to tell people about yourself!' : ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.4,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info Section
          _SectionCard(
            title: "Info",
            child: Column(
              children: [
                _InfoTile(
                  icon: FontAwesomeIcons.locationDot,
                  label: "Location",
                  value: widget.userProfile.location?.isNotEmpty == true
                      ? widget.userProfile.location!
                      : 'Not set',
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: FontAwesomeIcons.calendar,
                  label: "Joined",
                  value: joinDate,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: FontAwesomeIcons.user,
                  label: "Primary Mode",
                  value: primaryMode,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: FontAwesomeIcons.venusMars,
                  label: "Preferences",
                  value: widget.userProfile.preferences.isNotEmpty
                      ? widget.userProfile.preferences
                      : 'Not set',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Links Section
          if (widget.userProfile.email.isNotEmpty ||
              widget.userProfile.website?.isNotEmpty == true ||
              widget.userProfile.instagram?.isNotEmpty == true ||
              widget.userProfile.twitter?.isNotEmpty == true ||
              widget.userProfile.facebook?.isNotEmpty == true ||
              widget.userProfile.tiktok?.isNotEmpty == true ||
              widget.userProfile.youtube?.isNotEmpty == true)
            _SectionCard(
              title: "Links",
              child: Column(
                children: [
                  if (widget.userProfile.email.isNotEmpty)
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.solidEnvelope,
                      label: "Email",
                      value: widget.userProfile.email,
                      onTap: widget.onEmailTap,
                    ),
                  if (widget.userProfile.website?.isNotEmpty == true) ...[
                    if (widget.userProfile.email.isNotEmpty)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.globe,
                      label: "Website",
                      value: widget.userProfile.website!,
                      onTap: widget.onWebsiteTap,
                    ),
                  ],
                  if (widget.userProfile.instagram?.isNotEmpty == true) ...[
                    if (widget.userProfile.email.isNotEmpty ||
                        widget.userProfile.website?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.instagram,
                      label: "Instagram",
                      value: widget.userProfile.instagram!,
                      onTap: widget.onInstagramTap,
                    ),
                  ],
                  if (widget.userProfile.twitter?.isNotEmpty == true) ...[
                    if (widget.userProfile.email.isNotEmpty ||
                        widget.userProfile.website?.isNotEmpty == true ||
                        widget.userProfile.instagram?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.xTwitter,
                      label: "Twitter",
                      value: widget.userProfile.twitter!,
                      onTap: widget.onTwitterTap,
                    ),
                  ],
                  if (widget.userProfile.facebook?.isNotEmpty == true) ...[
                    if (widget.userProfile.email.isNotEmpty ||
                        widget.userProfile.website?.isNotEmpty == true ||
                        widget.userProfile.instagram?.isNotEmpty == true ||
                        widget.userProfile.twitter?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.facebook,
                      label: "Facebook",
                      value: widget.userProfile.facebook!,
                      onTap: widget.onFacebookTap,
                    ),
                  ],
                  if (widget.userProfile.tiktok?.isNotEmpty == true) ...[
                    if (widget.userProfile.email.isNotEmpty ||
                        widget.userProfile.website?.isNotEmpty == true ||
                        widget.userProfile.instagram?.isNotEmpty == true ||
                        widget.userProfile.twitter?.isNotEmpty == true ||
                        widget.userProfile.facebook?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.tiktok,
                      label: "TikTok",
                      value: widget.userProfile.tiktok!,
                      onTap: widget.onTikTokTap,
                    ),
                  ],
                  if (widget.userProfile.youtube?.isNotEmpty == true) ...[
                    if (widget.userProfile.email.isNotEmpty ||
                        widget.userProfile.website?.isNotEmpty == true ||
                        widget.userProfile.instagram?.isNotEmpty == true ||
                        widget.userProfile.twitter?.isNotEmpty == true ||
                        widget.userProfile.facebook?.isNotEmpty == true ||
                        widget.userProfile.tiktok?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.youtube,
                      label: "YouTube",
                      value: widget.userProfile.youtube!,
                      onTap: widget.onYouTubeTap,
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// UI Components for About Tab
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.black87, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClickableInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ClickableInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.black87, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              FontAwesomeIcons.arrowUpRightFromSquare,
              size: 14,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}