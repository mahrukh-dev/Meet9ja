import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meet9ja/db_functions/user_service.dart';
import 'package:meet9ja/models/post_model.dart';
import 'package:meet9ja/models/user_model.dart';
import 'package:meet9ja/screens/dating_profile.dart';
import 'package:meet9ja/screens/profile_screen.dart';
import '../constants/app_colors.dart';
import 'MatchedUserScreen.dart';
import 'explore_live_screen.dart';
import 'home_screen_filters.dart';
import 'home_screen.dart';
import 'messages_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final Set<String> liked = {};
  bool _travelAlertsOn = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Firebase streams
  late Stream<List<UserModel>> _recommendedUsersStream;
  late Stream<List<UserModel>> _popularUsersStream;
  late Stream<List<PostModel>> _trendingPostsStream;
  late Stream<List<UserModel>> _similarInterestsStream;
  late Stream<List<UserModel>> _sameGoalsStream;

  @override
  void initState() {
    super.initState();
    _loadFirebaseData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadFirebaseData() {
    _recommendedUsersStream = UserService.getRecommendedUsers();
    _popularUsersStream = UserService.getPopularUsers();
    _trendingPostsStream = UserService.getTrendingPosts();
    _similarInterestsStream = UserService.getSimilarInterestsUsers();
    _sameGoalsStream = UserService.getSameGoalsUsers();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar (centered title + filter)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    const Expanded(
                      child: Text(
                        "Discover",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    // IconButton(
                    //   icon: const Icon(
                    //     FontAwesomeIcons.sliders,
                    //     color: AppColors.primary,
                    //   ),
                    //   onPressed: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(builder: (_) => const HomeScreenFilters()),
                    //     );
                    //   },
                    // ),
                  ],
                ),
              ),

              // Feed
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  children: [
                    // Search Bar
                    _SearchBar(controller: _searchController),
                    const SizedBox(height: 18),

                    // Show search results if query exists, otherwise show normal content
                    if (_searchQuery.isNotEmpty)
                      _SearchResults(searchQuery: _searchQuery)
                    else
                      _DiscoverContent(
                        travelAlertsOn: _travelAlertsOn,
                        onTravelAlertsChanged: (value) {
                          setState(() {
                            _travelAlertsOn = value;
                          });
                        },
                        liked: liked,
                        onLikeToggle: _toggleLike,
                      ),
                  ],
                ),
              ),

              // Bottom nav — Discover selected
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: _BottomNav(current: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleLike(String id) {
    setState(() {
      if (liked.contains(id)) {
        liked.remove(id);
      } else {
        liked.add(id);
      }
    });
  }
}

// Search Results Widget
class _SearchResults extends StatelessWidget {
  final String searchQuery;

  const _SearchResults({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.searchUsers(searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return const Column(
            children: [
              Icon(FontAwesomeIcons.search, size: 60, color: Colors.black26),
              SizedBox(height: 16),
              Text(
                'No users found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Results (${users.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserCard(user: user);
              },
            ),
          ],
        );
      },
    );
  }
}

// Main Discover Content (when no search)
class _DiscoverContent extends StatelessWidget {
  final bool travelAlertsOn;
  final ValueChanged<bool> onTravelAlertsChanged;
  final Set<String> liked;
  final void Function(String id) onLikeToggle;

  const _DiscoverContent({
    required this.travelAlertsOn,
    required this.onTravelAlertsChanged,
    required this.liked,
    required this.onLikeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Trending Clips
        const _SectionHeader("Trending Clips 🎬"),
        const SizedBox(height: 10),
        _TrendingClipsStrip(),
        const SizedBox(height: 22),

        // Popular Profiles
        const _SectionHeader("Popular Profiles ⭐"),
        const SizedBox(height: 10),
        _PopularProfilesStrip(),
        const SizedBox(height: 24),

        // Timer pill + subtext
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 212, 45, 137),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              "See new people in 6 hours",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Connect over common ground with people who match your vibe, refreshed every day.",
          style: TextStyle(fontSize: 14.5, color: Colors.black87),
        ),
        const SizedBox(height: 18),


        // Recommended for you
        const _SectionHeader("Recommended for you"),
        const SizedBox(height: 10),
        _RecommendedStrip(liked: liked, onLikeToggle: onLikeToggle),
        const SizedBox(height: 24),

        // Similar interests section
        _SurfaceBlock(
          title: "Similar interests",
          child: _SimilarInterestsGrid(liked: liked, onLikeToggle: onLikeToggle),
        ),
        const SizedBox(height: 18),

        // Same dating goals section
        _SurfaceBlock(
          title: "Same dating goals",
          child: _SameGoalsGrid(liked: liked, onLikeToggle: onLikeToggle),
        ),
      ],
    );
  }
}

// Updated Widgets with Firebase Data

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(FontAwesomeIcons.magnifyingGlass, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "Search by name, tags, or location...",
                hintStyle: TextStyle(color: Colors.black54),
                border: InputBorder.none,
              ),
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(FontAwesomeIcons.times, size: 16),
              onPressed: () => controller.clear(),
            ),
        ],
      ),
    );
  }
}

class _TrendingClipsStrip extends StatelessWidget {
  const _TrendingClipsStrip();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PostModel>>(
      stream: UserService.getTrendingPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox(
            height: 180,
            child: Center(child: Text('Error loading trending clips')),
          );
        }

        final posts = snapshot.data!;

        if (posts.isEmpty) {
          return SizedBox(
            height: 180,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.video, size: 40, color: Colors.black26),
                  const SizedBox(height: 8),
                  Text(
                    'No trending clips',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final post = posts[i];
              return _TrendingClipCard(post: post, index: i);
            },
          ),
        );
      },
    );
  }
}

class _TrendingClipCard extends StatelessWidget {
  final PostModel post;
  final int index;

  const _TrendingClipCard({required this.post, required this.index});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Clip Thumbnail
          Container(
            width: 120,
            height: 180,
            color: Colors.grey.shade200,
            child: Image.network(
              post.mediaUrl,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.35),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(FontAwesomeIcons.video, color: Colors.black38),
              ),
            ),
          ),
          // Play Icon
          const Positioned.fill(
            child: Center(
              child: Icon(
                FontAwesomeIcons.solidCirclePlay,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          // Trending Text
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "#${index + 1} Trending",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularProfilesStrip extends StatelessWidget {
  const _PopularProfilesStrip();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.getPopularUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) => const _UserCircleSkeleton(),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return SizedBox(
            height: 120,
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final users = snapshot.data!;

        if (users.isEmpty) {
          return SizedBox(
            height: 120,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.users, size: 40, color: Colors.black26),
                  const SizedBox(height: 8),
                  Text(
                    'No popular profiles',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final user = users[i];
              return _UserCircle(user: user);
            },
          ),
        );
      },
    );
  }
}

class _UserCircle extends StatelessWidget {
  final UserModel user;

  const _UserCircle({required this.user});

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = UserService.getProfilePhotoUrl(user);

    return Column(
      children: [
        // Circular Profile Image
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
            image: DecorationImage(
              image: profilePhotoUrl != null
                  ? NetworkImage(profilePhotoUrl)
                  : const NetworkImage("https://i.pravatar.cc/300") as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Name
        Text(
          user.name.split(' ').first, // Show only first name
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _UserCircleSkeleton extends StatelessWidget {
  const _UserCircleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 12,
          color: Colors.grey.shade300,
        ),
      ],
    );
  }
}

class _TravelStrip extends StatelessWidget {
  const _TravelStrip();

  @override
  Widget build(BuildContext context) {
    // For now, using static travel data as in original
    // You can replace this with Firebase data later
    final recentTrips = const [
      _Trip(
        country: "UAE",
        state: "Dubai",
        city: "Dubai",
        image: "https://images.unsplash.com/photo-1504610926078-a1611febcad3",
      ),
      _Trip(
        country: "Turkey",
        state: "Istanbul",
        city: "Beyoğlu",
        image: "https://images.unsplash.com/photo-1524231757912-21f4fe3a7200",
      ),
      _Trip(
        country: "Pakistan",
        state: "Punjab",
        city: "Lahore",
        image: "https://images.unsplash.com/photo-1591604129939-1cb13857dc3a",
      ),
      _Trip(
        country: "Saudi Arabia",
        state: "Makkah",
        city: "Jeddah",
        image: "https://images.unsplash.com/photo-1602071792473-99137559e889",
      ),
    ];

    final w = MediaQuery.of(context).size.width;
    final cardW = w * 0.68;
    final cardH = cardW * 0.62;

    return SizedBox(
      height: cardH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recentTrips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _TravelCard(trip: recentTrips[i], width: cardW, height: cardH),
      ),
    );
  }
}

class _RecommendedStrip extends StatelessWidget {
  final Set<String> liked;
  final void Function(String id) onLikeToggle;

  const _RecommendedStrip({
    required this.liked,
    required this.onLikeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.getRecommendedUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          final w = MediaQuery.of(context).size.width;
          final cardW = w * 0.78;
          final cardH = cardW * 1.2;

          return SizedBox(
            height: cardH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => Container(
                width: cardW,
                height: cardH,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return SizedBox(
            height: 200,
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final users = snapshot.data!;

        if (users.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.users, size: 60, color: Colors.black26),
                  const SizedBox(height: 16),
                  Text(
                    "No recommendations yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final w = MediaQuery.of(context).size.width;
        final cardW = w * 0.78;
        final cardH = cardW * 1.2;

        return SizedBox(
          height: cardH,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _BigCard(
              user: users[i],
              width: cardW,
              height: cardH,
              liked: liked.contains(users[i].uid),
              onLike: () => onLikeToggle(users[i].uid),
            ),
          ),
        );
      },
    );
  }
}

class _SimilarInterestsGrid extends StatelessWidget {
  final Set<String> liked;
  final void Function(String id) onLikeToggle;

  const _SimilarInterestsGrid({
    required this.liked,
    required this.onLikeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.getSimilarInterestsUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _GridSkeleton();
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data!;

        if (users.isEmpty) {
          return const Center(
            child: Text('No users with similar interests'),
          );
        }

        return GridView.builder(
          itemCount: users.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (_, i) {
            final user = users[i];
            return _UserCard(
              user: user,
              liked: liked.contains(user.uid),
              onLikeToggle: () => onLikeToggle(user.uid),
            );
          },
        );
      },
    );
  }
}

class _SameGoalsGrid extends StatelessWidget {
  final Set<String> liked;
  final void Function(String id) onLikeToggle;

  const _SameGoalsGrid({
    required this.liked,
    required this.onLikeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.getSameGoalsUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _GridSkeleton();
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data!;

        if (users.isEmpty) {
          return const Center(
            child: Text('No users with same goals'),
          );
        }

        return GridView.builder(
          itemCount: users.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (_, i) {
            final user = users[i];
            return _UserCard(
              user: user,
              liked: liked.contains(user.uid),
              onLikeToggle: () => onLikeToggle(user.uid),
              showGoal: true,
            );
          },
        );
      },
    );
  }
}

// Individual User Card for Grid
class _UserCard extends StatelessWidget {
  final UserModel user;
  final bool liked;
  final VoidCallback? onLikeToggle;
  final bool showGoal;

  const _UserCard({
    required this.user,
    this.liked = false,
    this.onLikeToggle,
    this.showGoal = false,
  });

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = UserService.getProfilePhotoUrl(user);
    final tags = user.interests?.take(2).toList() ?? [];
    final goal = user.preferences.isNotEmpty ? user.preferences : 'Not specified';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // User Image
          Positioned.fill(
            child: Image.network(
              profilePhotoUrl ?? "https://i.pravatar.cc/300",
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(FontAwesomeIcons.user, color: Colors.black38),
              ),
            ),
          ),
          // Bottom overlay
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 48, 10, 10),
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
                  if (showGoal && goal.isNotEmpty) _darkPill(goal),
                  if (tags.isNotEmpty && !showGoal) _darkPill(tags.first),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${user.name.split(' ').first}, ${user.age}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (user.type == 'premium')
                        const Icon(
                          FontAwesomeIcons.certificate,
                          size: 14,
                          color: Colors.white,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Like button
          if (onLikeToggle != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: _circleBtn(
                icon: liked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                color: liked ? AppColors.primary : Colors.white,
                onTap: onLikeToggle!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _darkPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// Big Card for Recommended Users
class _BigCard extends StatelessWidget {
  final UserModel user;
  final double width;
  final double height;
  final bool liked;
  final VoidCallback onLike;

  const _BigCard({
    required this.user,
    required this.width,
    required this.height,
    required this.liked,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = UserService.getProfilePhotoUrl(user);
    final tags = user.interests?.take(2).toList() ?? [];
    final age = user.age;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.grey.shade200,
        image: DecorationImage(
          image: NetworkImage(profilePhotoUrl ?? "https://i.pravatar.cc/400"),
          fit: BoxFit.cover,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Stack(
        children: [
          // bottom info
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                "${user.name.split(' ').first}, $age",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (user.type == 'premium') ...[
                              const SizedBox(width: 6),
                              const Icon(
                                FontAwesomeIcons.certificate,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (tags.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tags.map((t) => _blackChip(t)).toList(),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onLike,
                    icon: Icon(
                      liked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                      color: liked ? AppColors.primary : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blackChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Skeleton Loaders
class _GridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// Keep all the existing helper classes (Trip, SectionHeader, SurfaceBlock, BottomNav) from your original code
// ... [Rest of the helper classes remain the same as in your original code]

class _Trip {
  final String country;
  final String state;
  final String city;
  final String image;

  const _Trip({
    required this.country,
    required this.state,
    required this.city,
    required this.image,
  });
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _SurfaceBlock extends StatelessWidget {
  const _SurfaceBlock({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TravelCard extends StatelessWidget {
  const _TravelCard({
    required this.trip,
    required this.width,
    required this.height,
  });
  final _Trip trip;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // image
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              image: DecorationImage(
                image: NetworkImage(trip.image),
                fit: BoxFit.cover,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 12),
              ],
            ),
          ),

          // overlay info
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(12, 48, 12, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      "Recent trip",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${trip.city}, ${trip.state}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    trip.country,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, this.onTap});
  final int current;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final icons = const [
      FontAwesomeIcons.user,
      FontAwesomeIcons.compass,
      FontAwesomeIcons.userGroup,
      FontAwesomeIcons.heart, // Changed from heart to video
      FontAwesomeIcons.solidCommentDots,
    ];
    final labels = const [
      "Profile",
      "Discover",
      "People",
      "Liked You", // Changed from "Liked You" to "Live"
      "Chats",
    ];

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: Row(
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

                // Handle navigation based on tab index
                switch (i) {
                  case 0: // Profile
                    if (current != 0) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => DatingProfileScreen()),
                      );
                    }
                    break;
                  case 1: // Discover (current screen)
                  // Already on Discover screen, do nothing
                    break;
                  case 2: // People (HomeScreen)
                    if (current != 2) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                    break;
                  case 3: // Live (ExploreLiveScreen)
                    if (current != 3) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => MatchedUsersScreen(userId: '',)),
                      );
                    }
                    break;
                  case 4: // Chats
                    if (current != 4) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MessagesScreen()),
                      );
                    }
                    break;
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6),
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
                      size: selected ? 24 : 22,
                      color: selected ? AppColors.primary : Colors.black54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: TextStyle(
                        height: 1.0,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? AppColors.primary : Colors.black54,
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