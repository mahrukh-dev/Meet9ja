import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:meet9ja/screens/activity_screen.dart';
import 'package:meet9ja/screens/dating_profile.dart';
import 'package:meet9ja/screens/explore_live_screen.dart';
import 'package:meet9ja/screens/other_dating_profile_screen.dart';
import 'package:meet9ja/screens/profile_screen.dart';
import 'package:meet9ja/screens/signin_screen.dart';
import '../constants/app_colors.dart';
import '../db_functions/firebase_service.dart';
import '../db_functions/getDiscoveryProfiles.dart';
import '../db_functions/getUserAge.dart';
import '../db_functions/getUserBio.dart';
import '../db_functions/getUserName.dart';
import '../db_functions/getUserPhotoUrl.dart';
import '../db_functions/isUserPremium.dart';
import '../db_functions/likeProfile.dart';
import '../db_functions/passProfile.dart';
import '../db_functions/user_service.dart';
import 'MatchedUserScreen.dart';
import 'home_screen_filters.dart';
import 'discover_screen.dart';
import 'messages_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageCtrl;
  int _index = 0;
  double _currentPage = 0.0;

  // Real profiles from Firebase
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Bottom navigation current index
  int _bottomNavIndex = 2; // Home is index 2 (People tab)

  // Store user preferences/filters
  Map<String, dynamic> _userPreferences = {};

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.92);
    _currentPage = _pageCtrl.initialPage.toDouble();
    _loadUserPreferences();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // Load user preferences from Firestore
  Future<void> _loadUserPreferences() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        await _loadProfiles();
        return;
      }

      // Get user preferences
      final prefDoc = await FirebaseFirestore.instance
          .collection('preferences')
          .doc(currentUser.uid)
          .get();

      if (prefDoc.exists) {
        setState(() {
          _userPreferences = prefDoc.data() ?? {};
          print('📋 Loaded user preferences: $_userPreferences');
        });
      } else {
        print('📋 No preferences found, using defaults');
      }

      await _loadProfiles();
    } catch (e) {
      print('❌ Error loading preferences: $e');
      await _loadProfiles();
    }
  }

  // Load profiles from Firebase with full filtering
  Future<void> _loadProfiles() async {
    try {
      print('🔄 Starting to load profiles...');
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Get current user's gender
      final currentUserGender = await _getCurrentUserGender();
      print('👤 Current user gender: $currentUserGender');

      // Get all discovery profiles
      final allProfiles = await getDiscoveryProfiles();
      print('📥 Total profiles found: ${allProfiles.length}');

      // Apply comprehensive filtering
      List<Map<String, dynamic>> filteredProfiles = [];

      if (_userPreferences.isNotEmpty) {
        // Apply all user filters if they exist
        filteredProfiles = _applyAllFilters(allProfiles, currentUserGender);
        print('🎯 Applied user filters, result: ${filteredProfiles.length} profiles');
      } else {
        // Default behavior: opposite gender only
        filteredProfiles = _applyDefaultGenderFilter(allProfiles, currentUserGender);
        print('🔧 Applied default filter, result: ${filteredProfiles.length} profiles');
      }

      if (mounted) {
        setState(() {
          _profiles = filteredProfiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error in _loadProfiles: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load profiles: $e';
        });
      }
    }
  }

  // Apply default gender filter (opposite gender)
  List<Map<String, dynamic>> _applyDefaultGenderFilter(
      List<Map<String, dynamic>> profiles, String currentUserGender) {
    return profiles.where((profile) {
      final profileGender = (profile['gender'] ?? 'male').toString().toLowerCase();

      // Default: males see females, females see males
      if (currentUserGender == 'male') {
        return profileGender == 'female';
      } else {
        return profileGender == 'male';
      }
    }).toList();
  }

  // Apply ALL user filters comprehensively
  List<Map<String, dynamic>> _applyAllFilters(
      List<Map<String, dynamic>> profiles, String currentUserGender) {
    return profiles.where((profile) {
      // 1. First check gender preference (highest priority)
      if (!_passesGenderFilter(profile, currentUserGender)) {
        return false;
      }

      // 2. Check age range
      if (!_passesAgeFilter(profile)) {
        return false;
      }

      // 3. Check interests (if any selected)
      if (!_passesInterestFilter(profile)) {
        return false;
      }

      // 4. Check verified status
      if (!_passesVerifiedFilter(profile)) {
        return false;
      }

      // 5. Check height range
      if (!_passesHeightFilter(profile)) {
        return false;
      }

      // 6. Check intentions (if any selected)
      if (!_passesIntentionsFilter(profile)) {
        return false;
      }

      // All filters passed
      return true;
    }).toList();
  }

  // Gender filter logic
  bool _passesGenderFilter(Map<String, dynamic> profile, String currentUserGender) {
    final profileGender = (profile['gender'] ?? 'male').toString().toLowerCase();
    final userPreference = _userPreferences['whoToDate']?.toString().toLowerCase();

    // If user has set a gender preference, use it
    if (userPreference != null) {
      if (userPreference == 'women') {
        return profileGender == 'female';
      } else if (userPreference == 'men') {
        return profileGender == 'male';
      } else if (userPreference == 'everyone') {
        return true; // Show all genders
      }
    }

    // Fallback to default opposite gender rule
    if (currentUserGender == 'male') {
      return profileGender == 'female';
    } else {
      return profileGender == 'male';
    }
  }

  // Age filter logic
  bool _passesAgeFilter(Map<String, dynamic> profile) {
    final minAge = _userPreferences['ageRangeStart'] ?? 18;
    final maxAge = _userPreferences['ageRangeEnd'] ?? 28;
    final flexAge = _userPreferences['flexAgeIfRunOut'] ?? true;

    final profileAge = getUserAge(profile);

    // Check if age is within range
    if (profileAge >= minAge && profileAge <= maxAge) {
      return true;
    }

    // If not in range but flex is enabled, allow 2 years outside range
    if (flexAge && (profileAge >= minAge - 2 && profileAge <= maxAge + 2)) {
      return true;
    }

    return false;
  }

  // Interest filter logic
  bool _passesInterestFilter(Map<String, dynamic> profile) {
    final selectedInterests = List<String>.from(_userPreferences['selectedInterests'] ?? []);
    final flexInterest = _userPreferences['flexInterestIfRunOut'] ?? true;

    // If no interests selected, pass the filter
    if (selectedInterests.isEmpty) {
      return true;
    }

    // Get profile interests
    final profileInterests = List<String>.from(profile['interests'] ?? []);

    // Check if profile has at least one matching interest
    final hasMatchingInterest = selectedInterests.any((interest) =>
        profileInterests.any((profileInterest) =>
        profileInterest.toLowerCase().contains(interest.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')) ||
            interest.toLowerCase().contains(profileInterest.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''))
        )
    );

    // If flex is enabled and no matching interests, still pass
    if (flexInterest && !hasMatchingInterest) {
      return true;
    }

    return hasMatchingInterest;
  }

  // Verified filter logic
  bool _passesVerifiedFilter(Map<String, dynamic> profile) {
    final verifiedOnly = _userPreferences['verifiedOnly'] ?? true;

    if (!verifiedOnly) {
      return true; // If not requiring verification, pass all
    }

    // Check if profile is verified
    final isVerified = profile['isVerified'] ?? profile['verified'] ?? false;
    return isVerified == true;
  }

  // Height filter logic
  bool _passesHeightFilter(Map<String, dynamic> profile) {
    final minHeight = _userPreferences['heightRangeStart'] ?? 140;
    final maxHeight = _userPreferences['heightRangeEnd'] ?? 200;
    final flexHeight = _userPreferences['flexHeightIfRunOut'] ?? true;

    // Get profile height (assuming it's stored in cm)
    final profileHeight = _getProfileHeight(profile);

    // If height is not available, pass the filter
    if (profileHeight == null) {
      return true;
    }

    // Check if height is within range
    if (profileHeight >= minHeight && profileHeight <= maxHeight) {
      return true;
    }

    // If flex is enabled and height is at extremes, allow
    if (flexHeight) {
      // Allow if at minimum or maximum range extremes
      if (minHeight <= 140 && maxHeight >= 200) {
        return true; // "Any height" setting
      }
    }

    return false;
  }

  // Helper to get profile height
  int? _getProfileHeight(Map<String, dynamic> profile) {
    // Try different possible height fields
    final height = profile['height'] ?? profile['height_cm'] ?? profile['heightCm'];

    if (height is int) return height;
    if (height is double) return height.toInt();
    if (height is String) {
      try {
        return int.parse(height.replaceAll('cm', '').trim());
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Intentions filter logic
  bool _passesIntentionsFilter(Map<String, dynamic> profile) {
    final selectedIntentions = List<String>.from(_userPreferences['intentions'] ?? []);
    final flexIntent = _userPreferences['flexIntentIfRunOut'] ?? false;

    // If no intentions selected, pass the filter
    if (selectedIntentions.isEmpty) {
      return true;
    }

    // Get profile intentions
    final profileIntentions = List<String>.from(profile['intentions'] ??
        profile['looking_for'] ??
        profile['goals'] ?? []);

    // Check if profile has at least one matching intention
    final hasMatchingIntention = selectedIntentions.any((intention) =>
        profileIntentions.any((profileIntention) =>
        profileIntention.toLowerCase().contains(intention.toLowerCase()) ||
            intention.toLowerCase().contains(profileIntention.toLowerCase())
        )
    );

    // If flex is enabled and no matching intentions, still pass
    if (flexIntent && !hasMatchingIntention) {
      return true;
    }

    return hasMatchingIntention;
  }

  // Helper method to get current user's gender
  Future<String> _getCurrentUserGender() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 'male';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final gender = (userDoc.data()?['gender'] ?? 'male').toString().toLowerCase();
        return gender;
      }
      return 'male';
    } catch (e) {
      print('❌ Error getting user gender: $e');
      return 'male';
    }
  }

  // Get active filter count for display
  int _getActiveFilterCount() {
    int count = 0;

    if (_userPreferences['whoToDate'] != null &&
        _userPreferences['whoToDate'] != 'Women') { // "Women" is default for males
      count++;
    }

    if (_userPreferences['ageRangeStart'] != 18 ||
        _userPreferences['ageRangeEnd'] != 28) {
      count++;
    }

    if ((_userPreferences['selectedInterests'] as List?)?.isNotEmpty == true) {
      count++;
    }

    if (_userPreferences['verifiedOnly'] == true) {
      count++;
    }

    if (_userPreferences['heightRangeStart'] != 140 ||
        _userPreferences['heightRangeEnd'] != 200) {
      count++;
    }

    if ((_userPreferences['intentions'] as List?)?.isNotEmpty == true) {
      count++;
    }

    return count;
  }

  // Refresh profiles when returning from filters screen
  void _refreshProfiles() {
    _loadUserPreferences();
  }

  // Navigate to filters screen
  void _openFilters() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HomeScreenFilters()),
    ).then((_) {
      // Refresh profiles when returning from filters
      _refreshProfiles();
    });
  }

  // Rest of your existing methods remain the same...
  void _goNext() {
    if (_profiles.isEmpty) {
      _loadProfiles();
      return;
    }

    if (_index < _profiles.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      print('🔄 Reached end of profiles, loading more...');
      _loadProfiles();
    }
  }

  Future<void> _likeProfile(Map<String, dynamic> profile) async {
    try {
      final String uid = profile['uid'] ?? profile['UID'];
      final String name = getUserName(profile);
      print('❤️ Liking profile: $uid');

      await likeProfile(uid);

      if (mounted) {
        setState(() {
          _profiles.removeWhere((p) =>
          (p['uid'] == uid) || (p['UID'] == uid)
          );

          if (_index >= _profiles.length && _profiles.isNotEmpty) {
            _index = _profiles.length - 1;
          } else if (_profiles.isEmpty) {
            _index = 0;
          }
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You liked $name"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 800),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error in _likeProfile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _passProfile(Map<String, dynamic> profile) async {
    try {
      final String uid = profile['uid'] ?? profile['UID'];
      final String name = getUserName(profile);
      print('👎 Passing on profile: $uid');

      await passProfile(uid);

      if (mounted) {
        setState(() {
          _profiles.removeWhere((p) =>
          (p['uid'] == uid) || (p['UID'] == uid)
          );

          if (_index >= _profiles.length && _profiles.isNotEmpty) {
            _index = _profiles.length - 1;
          } else if (_profiles.isEmpty) {
            _index = 0;
          }
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You passed on $name"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 700),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('❌ Error in _passProfile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToProfileDetails(Map<String, dynamic> profile) {
    final String userId = profile['uid'] ?? profile['UID'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherDatingProfileScreen(
          conversationId: '',
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilterCount = _getActiveFilterCount();

    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // App bar with filter button
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    // Live pill
                    _LivePill(onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ExploreLiveScreen()),
                      );
                    }),
                    const Expanded(child: Center(child: _Meet9jaLogo())),
                    // Filter button with badge
                    IconButton(
                      icon: Stack(
                        children: [
                          Icon(
                            Icons.filter_list_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          if (activeFilterCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 12,
                                  minHeight: 12,
                                ),
                                child: Text(
                                  '$activeFilterCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: _openFilters,
                    ),
                  ],
                ),
              ),

              // // Show active filters summary
              // if (activeFilterCount > 0)
              //   Padding(
              //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              //     child: Container(
              //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              //       decoration: BoxDecoration(
              //         color: AppColors.primary.withOpacity(0.1),
              //         borderRadius: BorderRadius.circular(12),
              //         border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              //       ),
              //       child: Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         children: [
              //           Text(
              //             '$activeFilterCount filter${activeFilterCount > 1 ? 's' : ''} active',
              //             style: const TextStyle(
              //               color: AppColors.primary,
              //               fontSize: 12,
              //               fontWeight: FontWeight.w600,
              //             ),
              //           ),
              //           TextButton(
              //             onPressed: _openFilters,
              //             style: TextButton.styleFrom(
              //               padding: EdgeInsets.zero,
              //               minimumSize: Size.zero,
              //               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              //             ),
              //             child: const Text(
              //               'View/Edit',
              //               style: TextStyle(
              //                 color: AppColors.primary,
              //                 fontSize: 12,
              //                 fontWeight: FontWeight.w700,
              //               ),
              //             ),
              //           ),
              //         ],
              //       ),
              //     ),
              //   ),

              // Progress indicator
              if (!_isLoading && _profiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                  child: Row(
                    children: List.generate(_profiles.length, (i) {
                      final active = i <= _index;
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: active ? AppColors.primary : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

              // Content Area
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage.isNotEmpty
                    ? _buildErrorState()
                    : _profiles.isEmpty
                    ? _buildEmptyState()
                    : _buildProfilesList(),
              ),

              // Bottom nav
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: _BottomNav(
                  current: _bottomNavIndex,
                  onTap: (index) {
                    setState(() {
                      _bottomNavIndex = index;
                    });
                    _handleBottomNavTap(index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DatingProfileScreen()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DiscoverScreen()),
        );
        break;
      case 2:
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ActivityScreen()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessagesScreen()),
        );
        break;
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading profiles...',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadProfiles,
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

  Widget _buildEmptyState() {
    final activeFilterCount = _getActiveFilterCount();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person,
              size: 64,
              color: Colors.black38,
            ),
            const SizedBox(height: 16),
            const Text(
              'No profiles found',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (activeFilterCount > 0)
              Text(
                'Your $activeFilterCount filter${activeFilterCount > 1 ? 's are' : ' is'} very specific',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 8),
            if (_userPreferences['whoToDate'] != null)
              Text(
                'Gender: ${_userPreferences['whoToDate']}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (_userPreferences['ageRangeStart'] != null && _userPreferences['ageRangeEnd'] != null)
              Text(
                'Age: ${_userPreferences['ageRangeStart']} - ${_userPreferences['ageRangeEnd']} years',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your filters or check back later',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadProfiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Refresh'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _openFilters,
                  child: const Text('Adjust Filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilesList() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadProfiles();
      },
      color: AppColors.primary,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics is PageMetrics) {
            final m = n.metrics as PageMetrics;
            setState(() {
              _currentPage = m.page ?? _index.toDouble();
            });
          }
          return false;
        },
        child: PageView.builder(
          controller: _pageCtrl,
          onPageChanged: (i) => setState(() => _index = i),
          itemCount: _profiles.length,
          itemBuilder: (context, i) {
            final profile = _profiles[i];
            final t = (_currentPage - i).abs().clamp(0.0, 1.0);
            final scale = lerpDouble(1.0, 0.94, t)!;
            final translateY = lerpDouble(0, 14, t)!;

            return Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scale: scale,
                child: _SwipeCard(
                  profile: profile,
                  onLike: () => _likeProfile(profile),
                  onPass: () => _passProfile(profile),
                  onViewDetails: () => _navigateToProfileDetails(profile),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ===== Rest of your widget classes remain exactly the same =====

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.profile,
    required this.onLike,
    required this.onPass,
    required this.onViewDetails,
  });

  final Map<String, dynamic> profile;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _ProfileCard(
        profile: profile,
        onLike: onLike,
        onPass: onPass,
        onViewDetails: onViewDetails,
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onLike,
    required this.onPass,
    required this.onViewDetails,
  });

  final Map<String, dynamic> profile;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final name = getUserName(profile);
    final age = getUserAge(profile);
    final photoUrl = getUserPhotoUrl(profile);
    final isPremium = isUserPremium(profile);
    final bio = getUserBio(profile);

    return GestureDetector(
      onTap: onViewDetails,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Profile Image
            Hero(
              tag: 'profile-img-${profile['uid']}',
              child: _ProfileImage(imageUrl: photoUrl),
            ),

            // Share icon
            Positioned(
              right: 10,
              top: 10,
              child: GestureDetector(
                onTap: onViewDetails,
                child: _CircleBtn(
                  icon: CupertinoIcons.share,
                  onTap: () {},
                ),
              ),
            ),

            // Bottom info section
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 60, 14, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black54,
                      Colors.black87,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (isPremium)
                          const _Chip.icon("Premium", CupertinoIcons.checkmark_seal_fill),
                        if (bio.isNotEmpty && bio != 'No bio yet')
                          _Chip("${bio.length > 20 ? '${bio.substring(0, 20)}...' : bio}"),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$name, $age",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (bio.isNotEmpty && bio != 'No bio yet')
                      _InfoRow(icon: CupertinoIcons.text_bubble, text: bio),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onPass,
                          child: _PillBtn(
                            icon: CupertinoIcons.multiply,
                            onTap: () {},
                            bg: Colors.white.withOpacity(0.85),
                            fg: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: onLike,
                          child: _PillBtn(
                            icon: CupertinoIcons.heart_fill,
                            onTap: () {},
                            bg: AppColors.primary,
                            fg: Colors.white,
                          ),
                        ),
                      ],
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

class _ProfileImage extends StatelessWidget {
  const _ProfileImage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: imageUrl.isNotEmpty
          ? Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              color: AppColors.primary,
            ),
          );
        },
      )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade300,
      child: const Icon(
        CupertinoIcons.person_crop_circle,
        size: 80,
        color: Colors.grey,
      ),
    );
  }
}

class _Meet9jaLogo extends StatelessWidget {
  const _Meet9jaLogo();

  @override
  Widget build(BuildContext context) {
    return Text(
      "Meet9ja",
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
        color: Colors.black87,
        shadows: [
          Shadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.primary.withOpacity(0.10),
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.tv,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 3),
            const Text(
              "LIVE",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {super.key}) : _icon = null;
  const _Chip.icon(this.text, this._icon, {super.key});

  final String text;
  final IconData? _icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_icon != null) ...[
            Icon(_icon, size: 12, color: Colors.black87),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBtn extends StatelessWidget {
  const _PillBtn({
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.fg,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          color: bg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Icon(icon, color: fg, size: 20),
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white70,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }
}

// --------- Bottom Nav ----------
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, this.onTap});
  final int current;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final icons = const [
      CupertinoIcons.person,
      FontAwesomeIcons.compass,
      FontAwesomeIcons.userGroup,
      FontAwesomeIcons.heart,
      FontAwesomeIcons.comment,
    ];
    final labels = const [
      "Profile",
      "Discover",
      "People",
      "Liked You",
      "Chats",
    ];

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(icons.length, (i) {
          final selected = i == current;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (onTap != null) {
                  onTap!(i);
                  return;
                }
                if (i == 0 && current != 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DatingProfileScreen()),
                  );
                  return;
                }
                if (i == 1 && current != 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiscoverScreen()),
                  );
                  return;
                }
                if (i == 3 && current != 3) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ActivityScreen()),
                  );
                  return;
                }
                if (i == 4 && current != 4) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()),
                  );
                  return;
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[i],
                      size: selected ? 26 : 24,
                      color: selected ? AppColors.primary : Colors.black54,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.0,
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}