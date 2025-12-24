// lib/home_screen.dart
import 'dart:ui';
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

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.92);
    _currentPage = _pageCtrl.initialPage.toDouble();
    _loadProfiles();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // Load profiles from Firebase
  Future<void> _loadProfiles() async {
    try {
      print('🔄 Starting to load profiles...');
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final profiles = await getDiscoveryProfiles();
      print('📥 Loaded ${profiles.length} profiles from Firebase');

      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
        });

        // Auto-refresh if no profiles found
        if (profiles.isEmpty) {
          print('🔄 No profiles found, scheduling refresh...');
          Future.delayed(const Duration(seconds: 3), _loadProfiles);
        }

        print('✅ Profiles state updated: ${_profiles.length} profiles');
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

  // Dummy data fallback
  void _loadDummyData() {
    setState(() {
      _isLoading = false;
      _errorMessage = '';
      _profiles = [
        {
          'uid': 'demo_1',
          'name': 'Sarah Johnson',
          'age': 26,
          'bio': 'Passionate traveler and foodie. Love exploring new cultures!',
          'first_photos': {'photo1url': 'https://i.pravatar.cc/300?img=1'},
          'type': 'premium',
          'location': 'New York',
          'interests': ['Travel', 'Food', 'Photography'],
        },
        {
          'uid': 'demo_2',
          'name': 'Mike Chen',
          'age': 29,
          'bio': 'Digital nomad and adventure seeker. Always planning my next trip!',
          'first_photos': {'photo1url': 'https://i.pravatar.cc/300?img=5'},
          'type': 'nonpremium',
          'location': 'San Francisco',
          'interests': ['Technology', 'Travel', 'Coffee'],
        },
      ];
    });
  }

  void _goNext() {
    if (_profiles.isEmpty) {
      // No profiles, try to load more
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
      // Reached end, reload more profiles
      _loadProfiles();
    }
  }
// In lib/home_screen.dart, update the _likeProfile and _passProfile methods

// Like profile function - only triggered by ❤️ icon
  Future<void> _likeProfile(Map<String, dynamic> profile) async {
    try {
      final String uid = profile['uid'] ?? profile['UID'];
      final String name = getUserName(profile);
      print('❤️ Liking profile: $uid');

      await likeProfile(uid);

      // Immediately remove the profile from the list
      if (mounted) {
        setState(() {
          _profiles.removeWhere((p) =>
          (p['uid'] == uid) || (p['UID'] == uid)
          );

          // Reset index if needed
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

// Pass profile function - only triggered by ❌ icon
  Future<void> _passProfile(Map<String, dynamic> profile) async {
    try {
      final String uid = profile['uid'] ?? profile['UID'];
      final String name = getUserName(profile);
      print('👎 Passing on profile: $uid');

      await passProfile(uid);

      // Immediately remove the profile from the list
      if (mounted) {
        setState(() {
          _profiles.removeWhere((p) =>
          (p['uid'] == uid) || (p['UID'] == uid)
          );

          // Reset index if needed
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
  // Navigate to profile details - only triggered by share icon or card tap
  void _navigateToProfileDetails(Map<String, dynamic> profile) {
    final String userId = profile['uid'] ?? profile['UID'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherDatingProfileScreen(
          conversationId: '',// This is someone else's profile
          userId: userId, // Pass the user ID to load their profile
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🏠 Building HomeScreen - Loading: $_isLoading, Profiles: ${_profiles.length}');
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Reduced app bar height
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0), // Reduced vertical padding
                child: Row(
                  children: [
                    // Updated: Direct navigation to ExploreLiveScreen
                    _LivePill(onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ExploreLiveScreen()),
                      );
                    }),
                    const Expanded(child: Center(child: _Meet9jaLogo())),
                    IconButton(
                      icon: const Icon(
                        Icons.logout,
                        color: AppColors.primary,
                        size: 20, // Smaller icon
                      ),
                      onPressed: () {
                        FirebaseService.signOut();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => Signinscreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Progress indicator - moved closer to cards
              if (!_isLoading && _profiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6), // Reduced vertical padding
                  child: Row(
                    children: List.generate(_profiles.length, (i) {
                      final active = i <= _index;
                      return Expanded(
                        child: Container(
                          height: 3, // Thinner progress bar
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

              // Content Area - Expanded to take more space
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
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10), // Reduced padding
                child: _BottomNav(current: 2),
              ),
            ],
          ),
        ),
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadProfiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Try Again'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _loadDummyData,
                  child: const Text('Use Demo Data'),
                ),
              ],
            ),
          ],
        ),
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
            const Text(
              'Check back later for new people in your area',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadProfiles,
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

  Widget _buildProfilesList() {
    return RefreshIndicator(
      onRefresh: _loadProfiles,
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

// ===== Updated Widgets for Real Data =====

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

            // Share icon - triggers navigation
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
                    // Bio row - removed job and education
                    if (bio.isNotEmpty && bio != 'No bio yet')
                      _InfoRow(icon: CupertinoIcons.text_bubble, text: bio),
                    const SizedBox(height: 10),
                    // Action buttons - use GestureDetector to stop propagation
                    Row(
                      children: [
                        // Cross icon - Pass profile only (no navigation)
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
                        // Heart icon - Like profile only (no navigation)
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
        fontSize: 22, // Slightly smaller logo
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Smaller padding
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6, // Smaller dot
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.tv,
              size: 16, // Smaller icon
              color: AppColors.primary,
            ),
            const SizedBox(width: 3),
            const Text(
              "LIVE",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 12, // Smaller font
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
        Icon(icon, size: 16, color: Colors.white), // Smaller icon
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14, // Slightly smaller font
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), // Smaller padding
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_icon != null) ...[
            Icon(_icon, size: 12, color: Colors.black87), // Smaller icon
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11, // Smaller font
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // Smaller padding
            child: Icon(icon, color: fg, size: 20), // Smaller icon
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
        padding: const EdgeInsets.all(8), // Smaller padding
        child: Icon(icon, size: 16, color: Colors.black87), // Smaller icon
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
      FontAwesomeIcons.heart, // Changed from heart to video
      FontAwesomeIcons.comment,
    ];
    final labels = const [
      "Profile",
      "Discover",
      "People",
      "Liked You", // Changed from "Liked You" to "Live"
      "Chats",
    ];

    return Container(
      height: 80, // Smaller bottom nav
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
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
                if (i == 3 && current != 3) { // Changed from 4 to 3 for Live tab

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
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4), // Smaller padding
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
                      size: selected ? 26 : 24, // Smaller icons
                      color: selected ? AppColors.primary : Colors.black54,
                    ),
                    const SizedBox(height: 2), // Reduced spacing
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.0,
                        fontSize: 10, // Smaller font
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