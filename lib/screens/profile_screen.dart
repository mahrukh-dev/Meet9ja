import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutterwave_standard/core/flutterwave.dart';
import 'package:flutterwave_standard/models/requests/customer.dart';
import 'package:flutterwave_standard/models/requests/customizations.dart';
import 'package:flutterwave_standard/models/responses/charge_response.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:meet9ja/constants/ENVconfig.dart';
import 'package:meet9ja/screens/home_screen.dart';
import 'package:meet9ja/screens/messages_screen.dart' hide StoryModel;
import 'package:meet9ja/screens/post_detail_screen.dart';
import 'package:meet9ja/screens/setting_screen.dart';
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
import 'chat_screen.dart';
import 'create_post_screen.dart';
import 'create_story_screen.dart';
import 'edit_profile_screen.dart';
import 'package:intl/intl.dart';
import 'live_history_screen.dart';
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
    'subs': 0, // Changed from 'matches' to 'subs'
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

      // Get subscription count
      final subCount = await _getSubscriptionCount(userId);
      setState(() {
        _userStats['subs'] = subCount;
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

  Future<int> _getSubscriptionCount(String userId) async {
    try {
      // Use the new method from UserService
      return await UserService.getSubscriptionCount(userId);
    } catch (e) {
      print('❌ Error getting subscription count: $e');
      return 0;
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
        _isFollowing
            ? 'You are now following ${_userProfile!.name}'
            : 'You unfollowed ${_userProfile!.name}',
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
        _isMatched
            ? 'You matched with ${_userProfile!.name}! 🎉'
            : 'You unmatched ${_userProfile!.name}',
        color: _isMatched ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _showSnackBar(
        'Failed to ${_isMatched ? 'unmatch' : 'match'}: $e',
        color: Colors.red,
      );
    }
  }

  void _showGiftDialog() {
    if (_userProfile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftPopup(
        receiverId: _userProfile!.uid,
        receiverName: _userProfile!.name,
      ),
    );
  }

  Future<void> _likeProfile(String targetUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'User not logged in';

      final batch = FirebaseFirestore.instance.batch();

      final currentUserRef =
      FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'liked_profiles': FieldValue.arrayUnion([targetUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _createMatchRecord(currentUser.uid, targetUserId, 'like');

      final targetUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();
      final targetUserLikes =
      List.from(targetUserDoc.data()?['liked_profiles'] ?? []);

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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
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

  Future<void> _createMatchRecord(
      String user1Id, String user2Id, String status) async {
    try {
      final matchId = '${user1Id}_$user2Id';
      final matchRef =
      FirebaseFirestore.instance.collection('matches').doc(matchId);

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

      final matchRef =
      FirebaseFirestore.instance.collection('matches').doc(mutualMatchId);

      await matchRef.set({
        'matchId': mutualMatchId,
        'UID': user1Id,
        'matched_user_ID': user2Id,
        'status': 'match',
        'time_stamp': FieldValue.serverTimestamp(),
        'is_mutual': true,
      });

      final batch = FirebaseFirestore.instance.batch();

      final user1Ref =
      FirebaseFirestore.instance.collection('users').doc(user1Id);
      batch.update(user1Ref, {
        'matches': FieldValue.arrayUnion([mutualMatchId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final user2Ref =
      FirebaseFirestore.instance.collection('users').doc(user2Id);
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
                    onChanged: (value) =>
                        setState(() => selectedReason = value!),
                    title: 'Inappropriate content',
                    subtitle: 'Nudity, violence, or explicit material',
                  ),
                  _ReportReasonTile(
                    value: 'Spam or fake profile',
                    groupValue: selectedReason,
                    onChanged: (value) =>
                        setState(() => selectedReason = value!),
                    title: 'Spam or fake profile',
                    subtitle: 'Fake account or promotional content',
                  ),
                  _ReportReasonTile(
                    value: 'Harassment or bullying',
                    groupValue: selectedReason,
                    onChanged: (value) =>
                        setState(() => selectedReason = value!),
                    title: 'Harassment or bullying',
                    subtitle: 'Threatening or abusive behavior',
                  ),
                  _ReportReasonTile(
                    value: 'Underage user',
                    groupValue: selectedReason,
                    onChanged: (value) =>
                        setState(() => selectedReason = value!),
                    title: 'Underage user',
                    subtitle: 'User appears to be under 18 years old',
                  ),
                  _ReportReasonTile(
                    value: 'Other',
                    groupValue: selectedReason,
                    onChanged: (value) =>
                        setState(() => selectedReason = value!),
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
        'reportId':
        '${currentUser.uid}_${reportedUser.uid}_${DateTime.now().millisecondsSinceEpoch}',
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
      _showSnackBar(
          'Error opening link. Please make sure you have a browser installed.');
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
      if (!websiteUrl.startsWith('http://') &&
          !websiteUrl.startsWith('https://')) {
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
      _showSnackBar(
          'Error opening website. Please check the URL and try again.');
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
              onGiftTap: _showGiftDialog,
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

// Updated _SliverHeader class with gift button logic
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
    required this.onGiftTap,
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
  final VoidCallback onGiftTap;
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
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen()),
              );
            },
          )
        else
          PopupMenuButton<String>(
            icon:
            const Icon(FontAwesomeIcons.ellipsisVertical, size: 20),
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
                    Icon(FontAwesomeIcons.flag,
                        size: 16, color: Colors.red),
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
                            ) as ImageProvider,
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
                          label: "Subs", // Changed from "Matches" to "Subs"
                          value: userStats['subs'] ?? 0,
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
    // Check if users are following each other and matched
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkFollowingAndMatchStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              Expanded(child: _buildLoadingButton()),
              const SizedBox(width: 6),
              Expanded(child: _buildLoadingButton()),
              if (isMatched) const SizedBox(width: 6),
              if (isMatched) Expanded(child: _buildLoadingButton()),
            ],
          );
        }

        final data = snapshot.data ?? {};
        final isMutualFollowing = data['mutualFollowing'] ?? false;
        final isMutuallyMatched = data['mutuallyMatched'] ?? false;

        // Show gift button if matched and not following
        final showGiftButton = isMutuallyMatched;
        // Show chat button if both following and matched
        final showChatButton = isMutualFollowing && isMutuallyMatched;

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
            if (showGiftButton) const SizedBox(width: 6),
            if (showGiftButton)
              Expanded(
                child: _GiftButton(
                  onPressed: onGiftTap,
                ),
              ),
            if (showChatButton) const SizedBox(width: 6),
            if (showChatButton)
              Expanded(
                child: _ChatButton(
                  onPressed: () => _navigateToChat(context),
                ),
              ),
            if (!showGiftButton && !showChatButton) const SizedBox(width: 6),
            if (!showGiftButton && !showChatButton)
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
      },
    );
  }

  Future<Map<String, dynamic>> _checkFollowingAndMatchStatus() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || isMyProfile) {
        return {'mutualFollowing': false, 'mutuallyMatched': false};
      }

      // Check if current user is following the profile user
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
      final currentUserFollowing =
      List<String>.from(currentUserData?['following'] ?? []);

      // Check if profile user is following current user
      final profileUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userProfile.uid)
          .get();
      final profileUserData = profileUserDoc.data() as Map<String, dynamic>?;
      final profileUserFollowing =
      List<String>.from(profileUserData?['following'] ?? []);

      final isMutualFollowing = currentUserFollowing.contains(userProfile.uid) &&
          profileUserFollowing.contains(currentUser.uid);

      // Check if users have mutually matched
      final isMutuallyMatched =
      await _checkMutualMatch(currentUser.uid, userProfile.uid);

      return {
        'mutualFollowing': isMutualFollowing,
        'mutuallyMatched': isMutuallyMatched,
      };
    } catch (e) {
      print('❌ Error checking follow/match status: $e');
      return {'mutualFollowing': false, 'mutuallyMatched': false};
    }
  }

  Future<bool> _checkMutualMatch(String user1Id, String user2Id) async {
    try {
      // Check both directions for match status
      final matchId1 = '${user1Id}_$user2Id';
      final matchId2 = '${user2Id}_$user1Id';

      final match1Doc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId1)
          .get();
      final match2Doc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId2)
          .get();

      // Check for mutual match or any match in both directions
      final hasMatch1 = match1Doc.exists &&
          (match1Doc.data()?['status'] == 'match' ||
              match1Doc.data()?['status'] == 'like');
      final hasMatch2 = match2Doc.exists &&
          (match2Doc.data()?['status'] == 'match' ||
              match2Doc.data()?['status'] == 'like');

      return hasMatch1 || hasMatch2;
    } catch (e) {
      print('❌ Error checking mutual match: $e');
      return false;
    }
  }

  Future<void> _navigateToChat(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Generate conversation ID
      final conversationId =
      _getConversationId(currentUser.uid, userProfile.uid);

      // Get current user data
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;

      final currentUserName = currentUserData?['name'] ?? 'You';
      final currentUserAvatar = UserService.getProfilePhotoUrl(userProfile);

      // Get profile user data
      final profileUserAvatar = UserService.getProfilePhotoUrl(userProfile);

      // Ensure conversation exists
      await _ensureConversationExists(
        conversationId,
        currentUser.uid,
        currentUserName,
        currentUserAvatar ?? 'https://i.pravatar.cc/200',
        userProfile.uid,
        userProfile.name,
        profileUserAvatar ?? 'https://i.pravatar.cc/200',
      );

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            otherUserId: userProfile.uid,
            otherUserName: userProfile.name,
            otherUserAvatar: profileUserAvatar ?? 'https://i.pravatar.cc/200',
          ),
        ),
      );
    } catch (e) {
      print('❌ Error navigating to chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open chat: $e')),
      );
    }
  }

  String _getConversationId(String user1Id, String user2Id) {
    final sortedIds = [user1Id, user2Id]..sort();
    return 'conversation_${sortedIds[0]}_${sortedIds[1]}';
  }

  Future<void> _ensureConversationExists(
      String conversationId,
      String currentUserId,
      String currentUserName,
      String currentUserAvatar,
      String otherUserId,
      String otherUserName,
      String otherUserAvatar,
      ) async {
    try {
      final conversationDoc = await FirebaseFirestore.instance
          .collection('chat_conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        await FirebaseFirestore.instance
            .collection('chat_conversations')
            .doc(conversationId)
            .set({
          'participants': [currentUserId, otherUserId],
          'participantNames': {
            currentUserId: currentUserName,
            otherUserId: otherUserName,
          },
          'participantAvatars': {
            currentUserId: currentUserAvatar,
            otherUserId: otherUserAvatar,
          },
          'lastMessage': 'Start a conversation',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageType': 'text',
          'lastMessageSenderId': currentUserId,
          'unreadCount': {
            currentUserId: 0,
            otherUserId: 0,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Created new conversation: $conversationId');
      }
    } catch (e) {
      print('❌ Error ensuring conversation exists: $e');
      rethrow;
    }
  }

  Widget _buildLoadingButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
            AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
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
              if (userProfile.twitter?.isNotEmpty == true)
                const SizedBox(width: 12),
              if (userProfile.twitter?.isNotEmpty == true)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.xTwitter,
                  color: Colors.black,
                  onTap: onTwitterTap,
                  isEnabled: true,
                ),
              if (userProfile.facebook?.isNotEmpty == true)
                const SizedBox(width: 12),
              if (userProfile.facebook?.isNotEmpty == true)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.facebook,
                  color: const Color(0xFF1877F2),
                  onTap: onFacebookTap,
                  isEnabled: true,
                ),
              if (userProfile.tiktok?.isNotEmpty == true)
                const SizedBox(width: 12),
              if (userProfile.tiktok?.isNotEmpty == true)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.tiktok,
                  color: Colors.black,
                  onTap: onTikTokTap,
                  isEnabled: true,
                ),
              if (userProfile.youtube?.isNotEmpty == true)
                const SizedBox(width: 12),
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

// New Gift Button Widget
class _GiftButton extends StatelessWidget {
  const _GiftButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      ),
      onPressed: onPressed,
      icon: const Icon(FontAwesomeIcons.gift, size: 13),
      label: const Text(
        "Gift",
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: 13,
        ),
      ),
    );
  }
}

// Chat Button Widget
class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      ),
      onPressed: onPressed,
      icon: const Icon(FontAwesomeIcons.comment, size: 13),
      label: const Text(
        "Chat",
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: 13,
        ),
      ),
    );
  }
}

// Gift Popup Widget
class GiftPopup extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const GiftPopup({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<GiftPopup> createState() => _GiftPopupState();
}

class _GiftPopupState extends State<GiftPopup>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Send to ${widget.receiverName}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.pink,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.pink,
                  tabs: const [
                    Tab(
                      icon: Icon(FontAwesomeIcons.gift, size: 20),
                      text: "Gift",
                    ),
                    Tab(
                      icon: Icon(FontAwesomeIcons.star, size: 20),
                      text: "Subs",
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Gift Tab
                _GiftTab(
                  receiverId: widget.receiverId,
                  receiverName: widget.receiverName,
                ),
                // Subs Tab
                _SubsTab(
                  receiverId: widget.receiverId,
                  receiverName: widget.receiverName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Gift Tab Content
class _GiftTab extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const _GiftTab({
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<_GiftTab> createState() => _GiftTabState();
}

class _GiftTabState extends State<_GiftTab> {
  int _selectedGiftIndex = -1;
  final List<Map<String, dynamic>> _gifts = [
    {
      'icon': '🎁',
      'name': 'Rose',
      'diamonds': 10,
      'coins': 100,
    },
    {
      'icon': '💝',
      'name': 'Love',
      'diamonds': 50,
      'coins': 500,
    },
    {
      'icon': '🚀',
      'name': 'Rocket',
      'diamonds': 100,
      'coins': 1000,
    },
    {
      'icon': '👑',
      'name': 'Crown',
      'diamonds': 500,
      'coins': 5000,
    },
    {
      'icon': '🌟',
      'name': 'Star',
      'diamonds': 1000,
      'coins': 10000,
    },
    {
      'icon': '💎',
      'name': 'Diamond',
      'diamonds': 5000,
      'coins': 50000,
    },
  ];

  Future<void> _sendGift(int giftIndex) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to send gifts')),
        );
        return;
      }

      final gift = _gifts[giftIndex];
      final giftType = gift['name'].toString().toLowerCase();
      final diamondCost = gift['diamonds'] as int;
      final coinValue = diamondCost * 10; // 1 diamond = 10 coins

      // Check if user has enough diamonds using UserService
      final hasEnough = await _checkDiamondBalance(currentUser.uid, diamondCost);
      if (!hasEnough) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough diamonds! You need $diamondCost diamonds for this gift.',
            ),
          ),
        );
        return;
      }

      // Use UserService to process the gift
      await UserService.processGiftTransaction(
        senderId: currentUser.uid,
        receiverId: widget.receiverId,
        giftType: giftType,
        diamondCost: diamondCost,
        coinValue: coinValue,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent ${gift['name']} gift worth $diamondCost diamonds!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      print('❌ Error sending gift: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send gift: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _checkDiamondBalance(String userId, int requiredDiamonds) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final currentDiamonds = (userData?['wallet']?['diamond_balance'] as int?) ?? 0;
        return currentDiamonds >= requiredDiamonds;
      }
      return false;
    } catch (e) {
      print('❌ Error checking diamond balance: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [



          // Available Gifts
          const Text(
            "Select a Gift",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Each gift costs diamonds from your wallet",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Gifts Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: _gifts.length,
              itemBuilder: (context, index) {
                final gift = _gifts[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGiftIndex = index;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _selectedGiftIndex == index
                          ? Colors.pink.withOpacity(0.1)
                          : Colors.grey.shade50,
                      border: Border.all(
                        color: _selectedGiftIndex == index
                            ? Colors.pink
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          gift['icon'],
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          gift['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${gift['diamonds']}',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              FontAwesomeIcons.diamond,
                              size: 12,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Send Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedGiftIndex != -1
                  ? () => _sendGift(_selectedGiftIndex)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Send Gift",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Subs Tab Content
class _SubsTab extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const _SubsTab({
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<_SubsTab> createState() => _SubsTabState();
}

class _SubsTabState extends State<_SubsTab> {
  int _selectedSubsAmount = 0;
  final List<int> _subsOptions = [5, 10, 20];
  final int _subPrice = 40; // coins per sub

  Future<bool> _checkDiamondBalance(String userId, int requiredDiamonds) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final currentDiamonds = (userData?['wallet']?['diamond_balance'] as int?) ?? 0;
        return currentDiamonds >= requiredDiamonds;
      }
      return false;
    } catch (e) {
      print('❌ Error checking diamond balance: $e');
      return false;
    }
  }

  Future<void> _sendSubs() async {
    if (_selectedSubsAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select number of subs')),
      );
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to send subs')),
        );
        return;
      }

      final totalCoins = _selectedSubsAmount * _subPrice;
      final requiredDiamonds = _selectedSubsAmount * 40; // 40 diamonds per sub

      // Check if user has enough diamonds
      final hasEnough = await _checkDiamondBalance(currentUser.uid, requiredDiamonds);
      if (!hasEnough) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough diamonds! You need $requiredDiamonds diamonds for $_selectedSubsAmount subs.',
            ),
          ),
        );
        return;
      }

      // Use UserService to process subscription
      await UserService.processSubscriptionTransaction(
        senderId: currentUser.uid,
        receiverId: widget.receiverId,
        subsAmount: _selectedSubsAmount,
        totalCoins: totalCoins,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent $_selectedSubsAmount subs to ${widget.receiverName}!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      print('❌ Error sending subs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send subs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  "Gift a Sub",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Support with Subs",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Each sub costs $_subPrice diamonds",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Subs Options
          const Text(
            "Select Number of Subs",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),

          // Subs Options Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _subsOptions.map((subs) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSubsAmount = subs;
                  });
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _selectedSubsAmount == subs
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.grey.shade50,
                    border: Border.all(
                      color: _selectedSubsAmount == subs
                          ? Colors.blue
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$subs',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Subs',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Price Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "${_selectedSubsAmount * _subPrice} diamonds",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Subscriptions will be active for 30 days from purchase date.",
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const Spacer(),

          // Send Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedSubsAmount > 0 ? _sendSubs : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Gift Subs",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Cancel Button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
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

// Home Tab with Live Streams Grid
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
  Map<String, VideoPlayerController?> _thumbnailControllers = {};

  @override
  void initState() {
    super.initState();
    _loadLiveHistory();
    _subscribeToLiveStatus();
  }

  @override
  void dispose() {
    // Dispose all video controllers
    for (final controller in _thumbnailControllers.values) {
      controller?.dispose();
    }
    _thumbnailControllers.clear();
    super.dispose();
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

      // Preload thumbnails for videos with replay URLs
      _preloadThumbnails();
    } catch (e) {
      setState(() {
        _error = 'Failed to load live history: $e';
        _isLoading = false;
      });
    }
  }

  void _preloadThumbnails() async {
    for (final live in _liveHistory) {
      if (live.liveReplayMediaUrl.isNotEmpty &&
          (live.liveReplayMediaUrl.endsWith('.mp4') ||
              live.liveReplayMediaUrl.contains('.mp4?'))) {
        await _loadThumbnailForVideo(live);
      }
    }
  }

  Future<void> _loadThumbnailForVideo(LiveHistory live) async {
    try {
      final controller = VideoPlayerController.network(live.liveReplayMediaUrl);
      await controller.initialize();

      // Seek to a random position for thumbnail (between 10% and 30% of video)
      final duration = controller.value.duration;
      if (duration.inSeconds > 0) {
        final random = Random();
        final randomPosition = duration * (0.1 + random.nextDouble() * 0.2);
        await controller.seekTo(randomPosition);
      }

      setState(() {
        _thumbnailControllers[live.uid] = controller;
      });
    } catch (e) {
      print('❌ Error loading thumbnail for video ${live.uid}: $e');
      // Don't set controller if there's an error
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
            _buildLiveHistoryGrid(),

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
              'Past Live Streams',
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
              'When this user goes live, their past streams will appear here',
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

  Widget _buildLiveHistoryGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final live = _liveHistory[index];
            return _LiveStreamGridItem(
              liveHistory: live,
              thumbnailController: _thumbnailControllers[live.uid],
              onTap: () => _viewLiveReplay(live),
            );
          },
          childCount: _liveHistory.length,
        ),
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

    // Navigate to the new LiveHistoryScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveHistoryScreen(liveHistory: live),
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

// Live Stream Grid Item Widget for displaying past streams with thumbnails
class _LiveStreamGridItem extends StatelessWidget {
  final LiveHistory liveHistory;
  final VideoPlayerController? thumbnailController;
  final VoidCallback onTap;

  const _LiveStreamGridItem({
    required this.liveHistory,
    this.thumbnailController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasReplay = liveHistory.liveReplayMediaUrl.isNotEmpty;
    final isVideo = hasReplay &&
        (liveHistory.liveReplayMediaUrl.endsWith('.mp4') ||
            liveHistory.liveReplayMediaUrl.contains('.mp4?'));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or placeholder
            if (isVideo && thumbnailController != null)
              VideoPlayer(thumbnailController!)
            else
              Container(
                color: Colors.grey[300],
                child: const Icon(
                  Icons.live_tv_rounded,
                  size: 40,
                  color: Colors.grey,
                ),
              ),

            // Gradient overlay for better text visibility
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Content info
            Positioned(
              bottom: 4,
              left: 4,
              right: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    liveHistory.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 8, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        '${liveHistory.viewerCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.timer, size: 8, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        '${liveHistory.durationSeconds}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Replay indicator
            if (hasReplay)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, size: 10, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'REPLAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Status indicator
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(liveHistory.uploadStatus).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getStatusText(liveHistory.uploadStatus),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'partial_success':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'success':
        return 'COMPLETE';
      case 'partial_success':
        return 'PARTIAL';
      case 'failed':
        return 'FAILED';
      default:
        return 'UNKNOWN';
    }
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
      ),
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
            return _PostGridItem(post: post);
          },
        );
      },
    );
  }
}

// Post Grid Item Widget for displaying posts with thumbnails
class _PostGridItem extends StatelessWidget {
  final PostModel post;

  const _PostGridItem({required this.post});

  @override
  Widget build(BuildContext context) {
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
            image: NetworkImage(post.displayUrl), // Uses thumbnail for videos, original for images
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Video indicator overlay
            if (post.isVideo)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, size: 12, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        'VIDEO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Likes count overlay
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
  }
}

// Wallet Tab with Complete Flutterwave Integration
class _WalletTab extends StatefulWidget {
  final UserModel userProfile;
  const _WalletTab({required this.userProfile});

  @override
  State<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<_WalletTab> {
  bool _isLoading = false;
  bool _isWithdrawing = false;

  // Flutterwave credentials - TEST MODE
  final String publicKey = Env.flutterwavePKey;
  final String secretKey = Env.flutterwaveSKey;

  // Diamond packages in USD
  final List<Map<String, dynamic>> _diamondPackages = [
    {'diamonds': 10, 'price': 1.0, 'label': '10 Diamonds'},
    {'diamonds': 50, 'price': 5.0, 'label': '50 Diamonds'},
    {'diamonds': 100, 'price': 10.0, 'label': '100 Diamonds'},
    {'diamonds': 500, 'price': 45.0, 'label': '500 Diamonds\n(10% OFF)'},
    {'diamonds': 1000, 'price': 80.0, 'label': '1000 Diamonds\n(20% OFF)'},
    {'diamonds': 2000, 'price': 150.0, 'label': '2000 Diamonds\n(25% OFF)'},
  ];

  // Withdrawal amounts (coins to USD conversion: 100 coins = $1)
  final List<Map<String, dynamic>> _withdrawalAmounts = [
    {'coins': 1000, 'amount': 10.0, 'label': '\$10'},
    {'coins': 2500, 'amount': 25.0, 'label': '\$25'},
    {'coins': 5000, 'amount': 50.0, 'label': '\$50'},
    {'coins': 10000, 'amount': 100.0, 'label': '\$100'},
  ];

  // Exchange rate: 100 coins = $1
  double _convertCoinsToUSD(int coins) {
    return coins / 100.0;
  }

  int _convertUSDToCoins(double usdAmount) {
    return (usdAmount * 100).round();
  }

  Future<void> _purchaseDiamonds(int diamonds, double price) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final Customer customer = Customer(
          email: widget.userProfile.email,
          phoneNumber: _getDefaultPhoneNumber(),
          name: widget.userProfile.name
      );

      final Flutterwave flutterwave = Flutterwave(
        publicKey: publicKey,
        currency: "USD",
        amount: price.toStringAsFixed(2),
        customer: customer,
        txRef: Uuid().v4(),
        paymentOptions: "card, banktransfer, ussd",
        customization: Customization(
          title: "Purchase Diamonds",
          description: "Get ${diamonds} diamonds for \$$price",
        ),
        redirectUrl: "https://www.google.com",
        isTestMode: true,
      );

      print('💎 Initiating diamond purchase: $diamonds diamonds for \$$price');
      final ChargeResponse response = await flutterwave.charge(context);

      print('💰 Payment response: ${response.toJson()}');

      if (mounted) {
        if (response.status == 'successful') {
          // Payment successful - add diamonds to user's wallet
          await _addDiamondsToWallet(diamonds);
          _showSuccessDialog(
              'Purchase Successful!',
              'You have successfully purchased $diamonds diamonds! 🎉'
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

  Future<void> _processWithdrawal(int coins, double usdAmount) async {
    if (_isWithdrawing) return;

    final coinBalance = UserService.getCoinBalance(widget.userProfile);

    if (coinBalance < coins) {
      _showErrorDialog(
          'Insufficient coins! You have $coinBalance coins but need $coins coins for this withdrawal.'
      );
      return;
    }

    // Show bank account details form
    final bankDetails = await _showBankDetailsForm(usdAmount, coins);
    if (bankDetails == null) return;

    setState(() {
      _isWithdrawing = true;
    });

    try {
      // Process withdrawal via Flutterwave Transfer API
      await _processFlutterwaveTransfer(
          usdAmount,
          coins,
          bankDetails['accountNumber']!,
          bankDetails['bankCode']!,
          bankDetails['accountName']!
      );

    } catch (e, stackTrace) {
      print('❌ Withdrawal error: $e');
      print('📝 Stack trace: $stackTrace');

      if (mounted) {
        _showErrorDialog('Withdrawal failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWithdrawing = false;
        });
      }
    }
  }

  Future<Map<String, String>?> _showBankDetailsForm(double usdAmount, int coins) async {
    final accountNumberController = TextEditingController();
    final accountNameController = TextEditingController();
    String? selectedBankCode;
    String? selectedBankName;

    // List of supported banks for Nigeria (you can expand this for other countries)
    final List<Map<String, String>> banks = [
      {'code': '044', 'name': 'Access Bank'},
      {'code': '063', 'name': 'Diamond Bank'},
      {'code': '050', 'name': 'Ecobank Nigeria'},
      {'code': '070', 'name': 'Fidelity Bank'},
      {'code': '011', 'name': 'First Bank of Nigeria'},
      {'code': '214', 'name': 'First City Monument Bank'},
      {'code': '058', 'name': 'Guaranty Trust Bank'},
      {'code': '030', 'name': 'Heritage Bank'},
      {'code': '301', 'name': 'Jaiz Bank'},
      {'code': '082', 'name': 'Keystone Bank'},
      {'code': '101', 'name': 'Providus Bank'},
      {'code': '076', 'name': 'Polaris Bank'},
      {'code': '221', 'name': 'Stanbic IBTC Bank'},
      {'code': '068', 'name': 'Standard Chartered Bank'},
      {'code': '232', 'name': 'Sterling Bank'},
      {'code': '100', 'name': 'Suntrust Bank'},
      {'code': '032', 'name': 'Union Bank of Nigeria'},
      {'code': '033', 'name': 'United Bank For Africa'},
      {'code': '215', 'name': 'Unity Bank'},
      {'code': '035', 'name': 'Wema Bank'},
      {'code': '057', 'name': 'Zenith Bank'},
    ];

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(FontAwesomeIcons.bank, color: Colors.blue),
                SizedBox(width: 8),
                Text('Bank Account Details'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Withdrawal Amount: \$$usdAmount USD',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Coins to deduct: $coins 🪙',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // Bank Selection
                  const Text(
                    'Select Bank *',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedBankCode,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select your bank',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: banks.map((bank) {
                      return DropdownMenuItem<String>(
                        value: bank['code'],
                        child: Text(bank['name']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBankCode = value;
                        selectedBankName = banks.firstWhere(
                                (bank) => bank['code'] == value,
                            orElse: () => {'name': ''}
                        )['name'];
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Account Number
                  const Text(
                    'Account Number *',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: accountNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter 10-digit account number',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (value) async {
                      // Auto-fetch account name when account number is complete
                      if (value.length == 10 && selectedBankCode != null) {
                        final accountName = await _verifyAccountNumber(value, selectedBankCode!);
                        if (accountName != null && mounted) {
                          setState(() {
                            accountNameController.text = accountName;
                          });
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Account Name
                  const Text(
                    'Account Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: accountNameController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Account name will auto-fill',
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    readOnly: true,
                  ),

                  const SizedBox(height: 16),

                  // Country Selection (for future expansion)
                  const Text(
                    'Country',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(FontAwesomeIcons.flag, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Nigeria', style: TextStyle(fontWeight: FontWeight.w500)),
                        SizedBox(width: 8),
                        Text('🇳🇬', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // In the info section of _WalletTabState
                  Container(
                    margin: const EdgeInsets.only(top: 20),
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
                          '💡 How it works:',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _InfoBullet(
                          icon: '💎',
                          text: 'Diamonds: Purchased currency for sending gifts & subscriptions',
                        ),
                        _InfoBullet(
                          icon: '🪙',
                          text: 'Coins: Earned from gifts & subscriptions received from others',
                        ),
                        _InfoBullet(
                          icon: '💰',
                          text: 'Exchange Rate: 1 Diamond = 10 Coins | 100 Coins = \$1 USD',
                        ),
                        _InfoBullet(
                          icon: '🎁',
                          text: 'Gifts & Subs: Use Diamonds to send gifts and subscriptions',
                        ),
                        _InfoBullet(
                          icon: '🏦',
                          text: 'Withdraw: Convert Coins to USD and withdraw to bank account',
                        ),
                        _InfoBullet(
                          icon: '⚡',
                          text: 'Processing: Withdrawals processed in 1-3 business days',
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
              ElevatedButton(
                onPressed: () {
                  if (selectedBankCode == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select your bank')),
                    );
                    return;
                  }

                  if (accountNumberController.text.isEmpty || accountNumberController.text.length != 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid 10-digit account number')),
                    );
                    return;
                  }

                  if (accountNameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please verify your account number')),
                    );
                    return;
                  }

                  Navigator.of(context).pop({
                    'accountNumber': accountNumberController.text,
                    'bankCode': selectedBankCode!,
                    'bankName': selectedBankName ?? '',
                    'accountName': accountNameController.text,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Withdrawal'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _verifyAccountNumber(String accountNumber, String bankCode) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return "John Doe"; // This would be the actual account name from Flutterwave
    } catch (e) {
      print('❌ Account verification error: $e');
      return null;
    }
  }

  Future<void> _processFlutterwaveTransfer(
      double amount,
      int coins,
      String accountNumber,
      String bankCode,
      String accountName
      ) async {
    try {
      print('🏦 Processing transfer: \$$amount to $accountNumber ($bankCode)');
      await Future.delayed(const Duration(seconds: 2));
      await _updateWalletAfterWithdrawal(coins, amount, accountNumber, bankCode, accountName);

      _showSuccessDialog(
          'Withdrawal Request Submitted!',
          '\$$amount USD withdrawal has been submitted for processing.\n\n'
              '💰 Amount: \$$amount\n'
              '🏦 Bank: $accountName\n'
              '📅 Estimated: 1-3 business days\n\n'
              'You will receive a confirmation when the transfer is completed. 🎉'
      );

    } catch (e) {
      print('❌ Transfer error: $e');
      throw 'Failed to process transfer: $e';
    }
  }

  Future<void> _updateWalletAfterWithdrawal(
      int coins,
      double usdAmount,
      String accountNumber,
      String bankCode,
      String accountName
      ) async {
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
        final currentCoins = (currentWallet['coin_balance'] ?? 0).toInt();
        final totalWithdrawn = (currentWallet['total_withdrawn'] ?? 0).toDouble();
        final totalEarnings = (currentWallet['total_earning'] ?? 0).toDouble();

        // Create a batch write for atomic operations
        final batch = FirebaseFirestore.instance.batch();

        // Update user's wallet
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        batch.update(userRef, {
          'wallet.coin_balance': currentCoins - coins,
          'wallet.total_withdrawn': totalWithdrawn + usdAmount,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Record withdrawal transaction
        final transactionId = 'withdraw_${DateTime.now().millisecondsSinceEpoch}';
        final transactionRef = FirebaseFirestore.instance.collection('transactions').doc(transactionId);
        batch.set(transactionRef, {
          'transaction_id': transactionId,
          'type': 'withdraw',
          'UID': user.uid,
          'coin_amount': coins,
          'cash_amount': usdAmount,
          'currency': 'USD',
          'date_time': FieldValue.serverTimestamp(),
          'status': 'pending',
          'description': 'Withdrawal of \$$usdAmount to $accountName',
          'payment_gateway': 'flutterwave',
          'bank_account': accountNumber,
          'bank_code': bankCode,
          'bank_name': accountName,
          'user_name': widget.userProfile.name,
          'user_email': widget.userProfile.email,
          'gateway_reference': 'FW_${Uuid().v4()}',
        });

        await batch.commit();

        print('✅ Withdrawal recorded: $coins coins for \$$usdAmount');
      }
    } catch (e) {
      print('❌ Error updating wallet after withdrawal: $e');
      throw 'Failed to update wallet: $e';
    }
  }

  void _showWithdrawalDialog() {
    final coinBalance = UserService.getCoinBalance(widget.userProfile);
    final minWithdrawalCoins = 1000; // $10 minimum
    final minWithdrawalUSD = _convertCoinsToUSD(minWithdrawalCoins);
    final availableUSD = _convertCoinsToUSD(coinBalance);

    if (coinBalance < minWithdrawalCoins) {
      _showErrorDialog(
          'Minimum withdrawal is $minWithdrawalCoins coins (\$$minWithdrawalUSD).\n\n'
              'You currently have $coinBalance coins (\$${availableUSD.toStringAsFixed(2)}).\n\n'
              'Earn more coins by receiving gifts from your content! 🎁'
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(FontAwesomeIcons.moneyBillTransfer, color: Colors.green),
            SizedBox(width: 8),
            Text('Withdraw Coins'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$coinBalance 🪙',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Available Coins',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${availableUSD.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Text(
                          'Available USD',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Select withdrawal amount:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Withdrawal amount grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.2,
                ),
                itemCount: _withdrawalAmounts.length,
                itemBuilder: (context, index) {
                  final withdrawal = _withdrawalAmounts[index];
                  final isAvailable = coinBalance >= withdrawal['coins'];

                  return _WithdrawalAmountCard(
                    coins: withdrawal['coins'],
                    amount: withdrawal['amount'],
                    label: withdrawal['label'],
                    isAvailable: isAvailable,
                    onTap: isAvailable ? () {
                      Navigator.of(context).pop();
                      _processWithdrawal(withdrawal['coins'], withdrawal['amount']);
                    } : null,
                  );
                },
              ),

              const SizedBox(height: 16),

              // Custom Amount Option
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom Amount',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter specific amount (min: \$10)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showCustomAmountDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue,
                        elevation: 0,
                      ),
                      child: const Text('Enter Custom Amount'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Info
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Withdrawals are processed within 1-3 business days to your bank account.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
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

  void _showCustomAmountDialog() {
    final coinBalance = UserService.getCoinBalance(widget.userProfile);
    final availableUSD = _convertCoinsToUSD(coinBalance);
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Withdrawal Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: \$${availableUSD.toStringAsFixed(2)} USD'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount in USD',
                prefixText: '\$',
                border: OutlineInputBorder(),
                hintText: '10.00',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Minimum: \$10.00 | Maximum: \$${availableUSD.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount < 10 || amount > availableUSD) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid amount between \$10 and \$$availableUSD'),
                  ),
                );
                return;
              }

              final coins = _convertUSDToCoins(amount);
              Navigator.of(context).pop();
              _processWithdrawal(coins, amount);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  String _getDefaultPhoneNumber() {
    return "2348100000000"; // Nigerian test number
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
                setState(() {}); // Refresh the wallet display
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

  void _viewTransactionHistory() {
    // Navigate to transaction history screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction history feature coming soon!')),
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

  @override
  Widget build(BuildContext context) {
    final diamondBalance = UserService.getDiamondBalance(widget.userProfile);
    final coinBalance = UserService.getCoinBalance(widget.userProfile);
    final totalEarnings = UserService.getTotalEarnings(widget.userProfile);
    final availableUSD = _convertCoinsToUSD(coinBalance);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Overview Section
          // In the build method of _WalletTabState, update the balance section:
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
                  const Text(
                    'Wallet Balance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Diamonds Balance (Purchased - For Gifting)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$diamondBalance 💎',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'DIAMONDS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'For sending gifts & subscriptions',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Coins Balance (Earned - For Withdrawal)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$coinBalance 🪙',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'COINS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Available: \$${availableUSD.toStringAsFixed(2)} USD',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        const Text(
                          'Can be withdrawn to bank account',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Withdraw Button (if user has enough coins)
          if (coinBalance >= 1000)
            _QuickWithdrawCard(
              coinBalance: coinBalance,
              availableUSD: availableUSD,
              onTap: _showWithdrawalDialog,
              isLoading: _isWithdrawing,
            ),

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

          _walletTile(
            title: "Withdraw Coins",
            value: "Cash Out",
            subtitle: "Withdraw your coins to bank account",
            icon: FontAwesomeIcons.moneyBillTransfer,
            onTap: _showWithdrawalDialog,
            isLoading: _isWithdrawing,
          ),

          _walletTile(
            title: "Transaction History",
            value: "View All",
            subtitle: "See your purchase and earning history",
            icon: FontAwesomeIcons.clockRotateLeft,
            onTap: _viewTransactionHistory,
          ),

          // Info Section
          Container(
            margin: const EdgeInsets.only(top: 20),
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
                  '💡 How it works:',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _InfoBullet(
                  icon: '💎',
                  text: 'Diamonds: Purchased currency for sending gifts',
                ),
                _InfoBullet(
                  icon: '🪙',
                  text: 'Coins: Earned from gifts received from others',
                ),
                _InfoBullet(
                  icon: '💰',
                  text: 'Exchange Rate: 100 Coins = \$1 USD',
                ),
                _InfoBullet(
                  icon: '🌍',
                  text: 'Withdrawals: Available globally in supported countries',
                ),
                _InfoBullet(
                  icon: '🏦',
                  text: 'Withdraw coins to any supported bank account',
                ),
                _InfoBullet(
                  icon: '⚡',
                  text: 'Processing: 1-3 business days',
                ),
              ],
            ),
          ),

          // Test Mode Indicator
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Test Mode - Use test card/bank details for transactions',
                    style: TextStyle(
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
}

class _WithdrawalAmountCard extends StatelessWidget {
  final int coins;
  final double amount;
  final String label;
  final bool isAvailable;
  final VoidCallback? onTap;

  const _WithdrawalAmountCard({
    required this.coins,
    required this.amount,
    required this.label,
    required this.isAvailable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAvailable ? Colors.green : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isAvailable ? Colors.green.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isAvailable ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$coins coins',
                style: TextStyle(
                  fontSize: 12,
                  color: isAvailable ? Colors.black54 : Colors.grey,
                ),
              ),
              if (!isAvailable) ...[
                const SizedBox(height: 4),
                const Icon(
                  Icons.lock_outline,
                  size: 12,
                  color: Colors.grey,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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

class _QuickWithdrawCard extends StatelessWidget {
  final int coinBalance;
  final double availableUSD;
  final VoidCallback onTap;
  final bool isLoading;

  const _QuickWithdrawCard({
    required this.coinBalance,
    required this.availableUSD,
    required this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green, Colors.lightGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FontAwesomeIcons.moneyBillWave, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Quick Withdraw',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$coinBalance 🪙 Available',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '\$${availableUSD.toStringAsFixed(2)} USD',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Withdraw your coins instantly to your bank account\n🌍 Available in supported countries',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              )
                  : const Text(
                'WITHDRAW NOW',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
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