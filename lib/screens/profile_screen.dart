import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:meet9ja/screens/post_detail_screen.dart';
import 'package:meet9ja/screens/signin_screen.dart';
import 'package:meet9ja/screens/story_view_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../db_functions/firebase_service.dart';
import '../db_functions/user_service.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import 'create_post_screen.dart';
import 'create_story_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isMyProfile;
  final String? userId;
  const ProfileScreen({super.key, this.isMyProfile = true, this.userId});

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
    'subscribers': 0,
  };
  bool _isFollowing = false;

  List<String> get _tabLabels {
    final baseTabs = ["Home", "Clips", "About", "Schedules"];
    if (widget.isMyProfile) {
      return ["Home", "Clips", "Wallet", "About", "Schedules"];
    }
    return baseTabs;
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
      // Load user stats
      final stats = await UserService.getUserStats(userId);
      setState(() {
        _userStats = stats;
      });

      // Load follow status if viewing other profile
      if (!widget.isMyProfile && UserService.currentUserId != null) {
        final following = await UserService.isFollowing(userId);
        setState(() {
          _isFollowing = following;
        });
      }

      // Subscribe to profile updates
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

  Future<void> _toggleFollow() async {
    if (_userProfile == null || widget.isMyProfile) return;

    try {
      if (_isFollowing) {
        await UserService.unfollowUser(_userProfile!.uid);
      } else {
        await UserService.followUser(_userProfile!.uid);
      }

      // Update local state
      setState(() {
        _isFollowing = !_isFollowing;
        _userStats['followers'] =
            _userStats['followers']! + (_isFollowing ? 1 : -1);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to ${_isFollowing ? 'unfollow' : 'follow'}: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
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

    // Refresh profile data if changes were made
    if (result == true && mounted) {
      _loadUserData(); // Reload the user data
    }
  }

  // Social media URLs
  String get _instagramUrl =>
      "https://instagram.com/${_userProfile?.instagram ?? _userProfile?.username}";
  String get _twitterUrl =>
      "https://twitter.com/${_userProfile?.twitter ?? _userProfile?.username}";
  String get _facebookUrl =>
      "https://facebook.com/${_userProfile?.facebook ?? _userProfile?.username}";
  String get _tiktokUrl =>
      "https://tiktok.com/@${_userProfile?.tiktok ?? _userProfile?.username}";
  String get _youtubeUrl =>
      "https://youtube.com/c/${_userProfile?.youtube ?? _userProfile?.username}";

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail() async {
    final email = _userProfile?.email;
    if (email == null || email.isEmpty) return;

    final Uri emailLaunchUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  Future<void> _launchWebsite() async {
    final website = _userProfile?.website;
    if (website == null || website.isEmpty) return;
    await _launchURL(website);
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
              isSmallScreen: isSmallScreen,
              onFollowTap: _toggleFollow,
              onEditTap: _navigateToEditProfile,
              onInstagramTap: () => _launchURL(_instagramUrl),
              onTwitterTap: () => _launchURL(_twitterUrl),
              onFacebookTap: () => _launchURL(_facebookUrl),
              onTikTokTap: () => _launchURL(_tiktokUrl),
              onYouTubeTap: () => _launchURL(_youtubeUrl),
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
          onPressed: () => Navigator.of(context).pop(),
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
      _HomeTab(userId: _userProfile!.uid),
      _ClipsTab(userId: _userProfile!.uid, isMyProfile: widget.isMyProfile),
    ];

    if (widget.isMyProfile) {
      tabs.add(_WalletTab(userProfile: _userProfile!));
    }

    tabs.addAll([
      _AboutTab(
        userProfile: _userProfile!,
        isMyProfile: widget.isMyProfile,
        onEmailTap: _launchEmail,
        onWebsiteTap: _launchWebsite,
        onInstagramTap: () => _launchURL(_instagramUrl),
        onTwitterTap: () => _launchURL(_twitterUrl),
        onFacebookTap: () => _launchURL(_facebookUrl),
        onTikTokTap: () => _launchURL(_tiktokUrl),
        onYouTubeTap: () => _launchURL(_youtubeUrl),
      ),
      _SchedulesTab(isMyProfile: widget.isMyProfile),
    ]);

    return tabs;
  }
}

// Updated _SliverHeader to include edit functionality
class _SliverHeader extends StatelessWidget {
  const _SliverHeader({
    required this.isMyProfile,
    required this.userProfile,
    required this.userStats,
    required this.isFollowing,
    required this.isSmallScreen,
    required this.onFollowTap,
    required this.onEditTap,
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
  final bool isSmallScreen;
  final VoidCallback onFollowTap;
  final VoidCallback onEditTap;
  final VoidCallback onInstagramTap;
  final VoidCallback onTwitterTap;
  final VoidCallback onFacebookTap;
  final VoidCallback onTikTokTap;
  final VoidCallback onYouTubeTap;

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
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => Signinscreen()),
              );
              },
          )
        else
          IconButton(
            icon: const Icon(FontAwesomeIcons.ellipsisVertical, size: 20),
            onPressed: () {},
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
                          label: "Subs",
                          value: userStats['subscribers'] ?? 0,
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

                // Social Media Handles - Only show if user has social media
                if (_hasSocialMedia()) _buildSocialMediaHandles(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasSocialMedia() {
    return userProfile.instagram != null ||
        userProfile.twitter != null ||
        userProfile.facebook != null ||
        userProfile.tiktok != null ||
        userProfile.youtube != null;
  }

  Widget _buildMyProfileActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(FontAwesomeIcons.userGroup, size: 13),
            label: const Text(
              "Manage Subs",
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
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(FontAwesomeIcons.shareFromSquare, size: 13),
            label: const Text(
              "Share",
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
            label: "Message",
            icon: FontAwesomeIcons.solidCommentDots,
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 75,
          child: _ActionButton(
            label: "Gift",
            icon: FontAwesomeIcons.solidGem,
            onPressed: () {},
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
              if (userProfile.instagram != null)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.instagram,
                  color: const Color(0xFFE4405F),
                  onTap: onInstagramTap,
                ),
              if (userProfile.twitter != null) const SizedBox(width: 12),
              if (userProfile.twitter != null)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.xTwitter,
                  color: Colors.black,
                  onTap: onTwitterTap,
                ),
              if (userProfile.facebook != null) const SizedBox(width: 12),
              if (userProfile.facebook != null)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.facebook,
                  color: const Color(0xFF1877F2),
                  onTap: onFacebookTap,
                ),
              if (userProfile.tiktok != null) const SizedBox(width: 12),
              if (userProfile.tiktok != null)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.tiktok,
                  color: Colors.black,
                  onTap: onTikTokTap,
                ),
              if (userProfile.youtube != null) const SizedBox(width: 12),
              if (userProfile.youtube != null)
                _SocialMediaIcon(
                  icon: FontAwesomeIcons.youtube,
                  color: const Color(0xFFFF0000),
                  onTap: onYouTubeTap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Tab Content Widgets
class _HomeTab extends StatelessWidget {
  final String userId;
  const _HomeTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: UserService.getUserFeed(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data?.docs ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FontAwesomeIcons.video, size: 60, color: Colors.black26),
                SizedBox(height: 16),
                Text(
                  "No posts yet.",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(post['caption'] ?? ''),
              // Add more post content
            );
          },
        );
      },
    );
  }
}

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

  // Add this new method for the Add Post button
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

  // Add this method to handle post creation
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
        // Debug logging
        print('Stories StreamBuilder - Connection: ${snapshot.connectionState}');
        print('Stories StreamBuilder - Has data: ${snapshot.hasData}');
        if (snapshot.hasData) {
          print('Stories count: ${snapshot.data!.length}');
        }
        if (snapshot.hasError) {
          print('Stories error: ${snapshot.error}');
        }

        // Handle different states
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
                // Add skeleton loading for stories
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

  // Separate function for better state management
  void _createNewStory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateStoryScreen(userId: widget.userId),
      ),
    );

    if (result == true && mounted) {
      // Force complete rebuild of stories section
      setState(() {
        _storiesKey = UniqueKey(); // Change the key to force rebuild
      });

      // Optional: Add a small delay to ensure Firestore updates
      await Future.delayed(Duration(milliseconds: 500));

      // Force another rebuild to get fresh data
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildStoryCircle(StoryModel story, {Key? key}) {
    return Container(
      key: key, // Use the provided key
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

class _WalletTab extends StatelessWidget {
  final UserModel userProfile;
  const _WalletTab({required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _WalletTabContent(userProfile: userProfile),
    );
  }
}

class _AboutTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _AboutTabContent(
        userProfile: userProfile,
        isMyProfile: isMyProfile,
        onEmailTap: onEmailTap,
        onWebsiteTap: onWebsiteTap,
        onInstagramTap: onInstagramTap,
        onTwitterTap: onTwitterTap,
        onFacebookTap: onFacebookTap,
        onTikTokTap: onTikTokTap,
        onYouTubeTap: onYouTubeTap,
      ),
    );
  }
}

class _SchedulesTab extends StatelessWidget {
  final bool isMyProfile;
  const _SchedulesTab({required this.isMyProfile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _SchedulesTabContent(isMyProfile: isMyProfile),
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

  const _SocialMediaIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
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

// Wallet Tab Content
class _WalletTabContent extends StatelessWidget {
  final UserModel userProfile;
  const _WalletTabContent({required this.userProfile});

  Widget _walletTile({
    required String title,
    required String value,
    required IconData icon,
    Color iconColor = Colors.black87,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            if (onTap != null) const SizedBox(width: 8),
            if (onTap != null)
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

  @override
  Widget build(BuildContext context) {
    final coinBalance = UserService.getCoinBalance(userProfile);
    final totalEarnings = UserService.getTotalEarnings(userProfile);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current Balance",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          _walletTile(
            title: "My Coin Balance",
            value: "$coinBalance 💎",
            icon: FontAwesomeIcons.solidGem,
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 24),

          Text(
            "Actions",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          _walletTile(
            title: "Top-up Coins",
            value: "Buy",
            icon: FontAwesomeIcons.creditCard,
            onTap: () {},
          ),
          _walletTile(
            title: "Earnings",
            value: "\$$totalEarnings",
            icon: FontAwesomeIcons.sackDollar,
          ),
          _walletTile(
            title: "Withdraw",
            value: "Cash Out",
            icon: FontAwesomeIcons.moneyBillTransfer,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// About Tab Content
class _AboutTabContent extends StatelessWidget {
  final UserModel userProfile;
  final bool isMyProfile;
  final VoidCallback onEmailTap;
  final VoidCallback onWebsiteTap;
  final VoidCallback onInstagramTap;
  final VoidCallback onTwitterTap;
  final VoidCallback onFacebookTap;
  final VoidCallback onTikTokTap;
  final VoidCallback onYouTubeTap;

  const _AboutTabContent({
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
  Widget build(BuildContext context) {
    final joinDate = UserService.getFormattedJoinDate(userProfile);
    final primaryMode = UserService.getPrimaryMode(userProfile);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio Section
          _SectionCard(
            title: "Bio",
            child: Text(
              userProfile.bio?.isNotEmpty == true
                  ? userProfile.bio!
                  : 'No bio yet. ${isMyProfile ? 'Add a bio to tell people about yourself!' : ''}',
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
                  value: userProfile.location?.isNotEmpty == true
                      ? userProfile.location!
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
                  value: userProfile.preferences.isNotEmpty
                      ? userProfile.preferences
                      : 'Not set',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Links Section
          if (userProfile.email.isNotEmpty ||
              userProfile.website?.isNotEmpty == true ||
              userProfile.instagram?.isNotEmpty == true ||
              userProfile.twitter?.isNotEmpty == true ||
              userProfile.facebook?.isNotEmpty == true ||
              userProfile.tiktok?.isNotEmpty == true ||
              userProfile.youtube?.isNotEmpty == true)
            _SectionCard(
              title: "Links",
              child: Column(
                children: [
                  if (userProfile.email.isNotEmpty)
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.solidEnvelope,
                      label: "Email",
                      value: userProfile.email,
                      onTap: onEmailTap,
                    ),
                  if (userProfile.website?.isNotEmpty == true) ...[
                    if (userProfile.email.isNotEmpty)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.globe,
                      label: "Website",
                      value: userProfile.website!,
                      onTap: onWebsiteTap,
                    ),
                  ],
                  if (userProfile.instagram?.isNotEmpty == true) ...[
                    if (userProfile.email.isNotEmpty ||
                        userProfile.website?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.instagram,
                      label: "Instagram",
                      value: userProfile.instagram!,
                      onTap: onInstagramTap,
                    ),
                  ],
                  if (userProfile.twitter?.isNotEmpty == true) ...[
                    if (userProfile.email.isNotEmpty ||
                        userProfile.website?.isNotEmpty == true ||
                        userProfile.instagram?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.xTwitter,
                      label: "Twitter",
                      value: userProfile.twitter!,
                      onTap: onTwitterTap,
                    ),
                  ],
                  if (userProfile.facebook?.isNotEmpty == true) ...[
                    if (userProfile.email.isNotEmpty ||
                        userProfile.website?.isNotEmpty == true ||
                        userProfile.instagram?.isNotEmpty == true ||
                        userProfile.twitter?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.facebook,
                      label: "Facebook",
                      value: userProfile.facebook!,
                      onTap: onFacebookTap,
                    ),
                  ],
                  if (userProfile.tiktok?.isNotEmpty == true) ...[
                    if (userProfile.email.isNotEmpty ||
                        userProfile.website?.isNotEmpty == true ||
                        userProfile.instagram?.isNotEmpty == true ||
                        userProfile.twitter?.isNotEmpty == true ||
                        userProfile.facebook?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.tiktok,
                      label: "TikTok",
                      value: userProfile.tiktok!,
                      onTap: onTikTokTap,
                    ),
                  ],
                  if (userProfile.youtube?.isNotEmpty == true) ...[
                    if (userProfile.email.isNotEmpty ||
                        userProfile.website?.isNotEmpty == true ||
                        userProfile.instagram?.isNotEmpty == true ||
                        userProfile.twitter?.isNotEmpty == true ||
                        userProfile.facebook?.isNotEmpty == true ||
                        userProfile.tiktok?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ClickableInfoTile(
                      icon: FontAwesomeIcons.youtube,
                      label: "YouTube",
                      value: userProfile.youtube!,
                      onTap: onYouTubeTap,
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

// Schedules Tab Content
class _SchedulesTabContent extends StatelessWidget {
  final bool isMyProfile;
  const _SchedulesTabContent({required this.isMyProfile});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.calendar, size: 60, color: Colors.black26),
          SizedBox(height: 16),
          Text(
            "No schedules yet.",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Check back later for upcoming streams.",
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
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
