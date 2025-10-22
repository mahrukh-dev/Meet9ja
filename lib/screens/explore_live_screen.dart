import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meet9ja/screens/profile_screen.dart';

import '../constants/app_colors.dart';
import 'discover_screen.dart';
import 'home_screen.dart';
import 'livestream_screen.dart';
import 'messages_screen.dart';

class ExploreLiveScreen extends StatefulWidget {
  const ExploreLiveScreen({super.key});
  @override
  State<ExploreLiveScreen> createState() => _ExploreLiveScreenState();
}

class _ExploreLiveScreenState extends State<ExploreLiveScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final List<String> _liveFilters = const [
    "All",
    "Drops & Loot",
    "Fortnite",
    "Call of Duty: Warzone",
  ];
  int _liveFilterIndex = 0;

  List<_ReelItem> _followingReels = [];
  List<_ReelItem> _clipsReels = [];
  List<_LiveCard> _liveRooms = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _liveStreamSubscription;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadLiveData();
    _setupLiveStreamListener();
  }

  @override
  void dispose() {
    _liveStreamSubscription?.cancel();
    _tab.dispose();
    super.dispose();
  }

  // Load real live stream data from Firebase
  Future<void> _loadLiveData() async {
    try {
      setState(() => _isLoading = true);

      // Load active live streams
      final liveStreams = await _getActiveLiveStreams();

      // Load ALL stories from ALL users except current user
      final followingReels = await _getAllStories();

      // Load ALL posts from ALL users except current user
      final clipsReels = await _getAllPosts();

      if (mounted) {
        setState(() {
          _liveRooms = liveStreams;
          _followingReels = followingReels;
          _clipsReels = clipsReels;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading live data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Get active live streams from Firebase
  Future<List<_LiveCard>> _getActiveLiveStreams() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('liveStreams')
          .where('isLive', isEqualTo: true)
          .orderBy('startedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _LiveCard(
          title: data['title'] ?? 'Live Stream',
          user: data['hostName'] ?? 'Unknown Host',
          viewers: (data['viewers'] ?? 0).toInt(),
          thumb: data['thumbnailUrl'] ?? 'https://images.unsplash.com/photo-1517705008128-361805f42e86?q=80&w=1080&auto=format&fit=crop',
          game: data['category'] ?? 'Just Chatting',
          liveId: doc.id,
          hostId: data['hostId'] ?? '',
        );
      }).toList();
    } catch (e) {
      print('Error getting live streams: $e');
      return [];
    }
  }

  // Get ALL stories from ALL users except current user
  Future<List<_ReelItem>> _getAllStories() async {
    try {
      print('🔍 Fetching stories from Firebase...');

      // Get ALL active stories from ALL users from the 'stories' collection
      final snapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('expires_at', isGreaterThan: Timestamp.now())
          .orderBy('expires_at', descending: true)
          .limit(50) // Limit to 50 most recent stories
          .get();

      print('📱 Found ${snapshot.docs.length} stories in database');

      if (snapshot.docs.isEmpty) {
        print('❌ No stories found in database');
        return [];
      }

      // Get user details for each story and filter out current user's stories
      final reels = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          final userId = data['UID'] as String?;

          print('👤 Processing story from user: $userId, Current user: $_currentUserId');

          // Filter out current user's stories
          if (userId == null || userId == _currentUserId) {
            print('🚫 Filtered out current user\'s story');
            return null;
          }

          try {
            // Get user details
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

            if (!userDoc.exists) {
              print('❌ User document not found for userId: $userId');
              return null;
            }

            final userData = userDoc.data() as Map<String, dynamic>?;
            final username = userData?['username'] ?? 'User';
            final userPhoto = userData?['photo_url'] ?? '';

            print('✅ Loaded user data: $username');

            return _ReelItem(
              user: username,
              title: 'New Story', // Default title for stories
              viewers: (data['viewers']?.length ?? 0),
              thumb: data['media_url'] ?? 'https://images.unsplash.com/photo-1535223289827-42f1e9919769?q=80&w=1080&auto=format&fit=crop',
              type: 'story',
              postId: doc.id,
              userId: userId,
              userPhoto: userPhoto,
              timestamp: data['created_at'] as Timestamp?,
              likes: [],
              comments: [],
              mediaType: data['media_type'] ?? 'image',
            );
          } catch (e) {
            print('❌ Error loading user data for $userId: $e');
            return null;
          }
        }),
      );

      final filteredReels = reels.whereType<_ReelItem>().toList();
      print('🎯 Final stories count after filtering: ${filteredReels.length}');

      return filteredReels;
    } catch (e) {
      print('❌ Error getting all stories: $e');
      return [];
    }
  }

  // Get ALL posts from ALL users except current user
  Future<List<_ReelItem>> _getAllPosts() async {
    try {
      // Get ALL posts from ALL users
      final snapshot = await FirebaseFirestore.instance
          .collection('user_feed')
          .orderBy('date_time', descending: true)
          .limit(50) // Limit to 50 most recent posts
          .get();

      if (snapshot.docs.isEmpty) return [];

      // Get user details for each post and filter out current user's posts
      final reels = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          final userId = data['UID'] as String?;

          // Filter out current user's posts
          if (userId == null || userId == _currentUserId) return null;

          // Get user details
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (!userDoc.exists) return null;

          final userData = userDoc.data() as Map<String, dynamic>?;

          return _ReelItem(
            user: userData?['username'] ?? 'User',
            title: data['caption'] ?? 'New Post',
            viewers: (data['likes']?.length ?? 0) + (data['comments']?.length ?? 0),
            thumb: data['media_url'] ?? 'https://images.unsplash.com/photo-1517705008128-361805f42e86?q=80&w=1080&auto=format&fit=crop',
            type: data['type'] ?? 'post',
            postId: doc.id,
            userId: userId,
            userPhoto: userData?['photo_url'] ?? '',
            timestamp: data['date_time'] as Timestamp?,
            likes: List<Map<String, dynamic>>.from(data['likes'] ?? []),
            comments: List<Map<String, dynamic>>.from(data['comments'] ?? []),
            mediaType: data['type'] == 'video' ? 'video' : 'image',
          );
        }),
      );

      return reels.whereType<_ReelItem>().toList();
    } catch (e) {
      print('Error getting all posts: $e');
      return [];
    }
  }

  // Real-time listener for live streams
  void _setupLiveStreamListener() {
    _liveStreamSubscription = FirebaseFirestore.instance
        .collection('liveStreams')
        .where('isLive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _liveRooms = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _LiveCard(
              title: data['title'] ?? 'Live Stream',
              user: data['hostName'] ?? 'Unknown Host',
              viewers: (data['viewers'] ?? 0).toInt(),
              thumb: data['thumbnailUrl'] ?? 'https://images.unsplash.com/photo-1517705008128-361805f42e86?q=80&w=1080&auto=format&fit=crop',
              game: data['category'] ?? 'Just Chatting',
              liveId: doc.id,
              hostId: data['hostId'] ?? '',
            );
          }).toList();
        });
      }
    });
  }

  // Check if user is premium before going live
  Future<void> _checkPremiumAndGoLive(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to go live')),
        );
        return;
      }

      // Check if user is premium
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>?;
      final isPremium = userData?['type'] == 'premium';

      if (!isPremium) {
        _showPremiumRequiredDialog(context);
        return;
      }

      // User is premium, proceed to live stream
      _startLiveStream(context);
    } catch (e) {
      print('Error checking premium status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showPremiumRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Feature'),
        content: const Text('Live streaming is available for premium users only. Upgrade to premium to start broadcasting.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to premium subscription screen
              // Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionScreen()));
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Future<void> _startLiveStream(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Create a new live stream document
      final liveId = DateTime.now().millisecondsSinceEpoch.toString();
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>?;

      await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(liveId)
          .set({
        'liveId': liveId,
        'hostId': user.uid,
        'hostName': userData?['name'] ?? 'Anonymous',
        'title': 'My Live Stream',
        'category': 'Just Chatting',
        'isLive': true,
        'viewers': 0,
        'startedAt': FieldValue.serverTimestamp(),
        'thumbnailUrl': userData?['photo_url'] ?? '',
      });

      // Navigate to live stream screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveStreamScreen(
            liveId: liveId,
            userId: user.uid,
            userName: userData?['name'] ?? 'Host',
            isHost: true,
            hostId: '',
          ),
        ),
      );
    } catch (e) {
      print('Error starting live stream: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start live stream: $e')),
      );
    }
  }

  void _joinLiveStream(BuildContext context, _LiveCard room) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to join live streams')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveStreamScreen(
          liveId: room.liveId,
          userId: user.uid,
          userName: user.displayName ?? 'Viewer',
          isHost: false,
          hostId: room.hostId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The dark background color used in the images
    const Color darkBackground = Color(0xFF333333);

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌸 Custom Tabs (Stories, Live, Clips)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: darkBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.transparent),
              ),
              child: TabBar(
                controller: _tab,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(
                    width: 3.0,
                    color: Colors.white,
                  ),
                  insets: EdgeInsets.symmetric(horizontal: 20.0),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                indicatorSize: TabBarIndicatorSize.label,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                padding: const EdgeInsets.all(6),
                labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                tabs: const [
                  Tab(text: "Stories"),
                  Tab(text: "Live"),
                  Tab(text: "Posts"),
                ],
              ),
            ),
          ],
        ),
      ),

      // Body content with floating button
      body: Stack(
        children: [
          Container(
            color: darkBackground,
            child: _isLoading
                ? _buildLoadingState()
                : TabBarView(
              controller: _tab,
              children: [
                // Stories Tab - Shows ALL stories from other users
                _ReelsFeed(items: _followingReels, showStories: true),

                // Live Tab - Shows live streams
                Column(
                  children: [
                    const SizedBox(height: 8),
                    // Live Filters Bar
                    _LiveFiltersBar(
                      filters: _liveFilters,
                      selected: _liveFilterIndex,
                      onTap: (i) => setState(() => _liveFilterIndex = i),
                      backgroundColor: darkBackground,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _liveRooms.isEmpty
                          ? _buildEmptyLiveState()
                          : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                    (context, i) => _LiveTile(
                                  room: _liveRooms[i],
                                  onTap: () => _joinLiveStream(context, _liveRooms[i]),
                                ),
                                childCount: _liveRooms.length,
                              ),
                              gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 9 / 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Posts Tab - Shows ALL posts from other users
                _ReelsFeed(items: _clipsReels, showStories: false),
              ],
            ),
          ),

          // Floating Live Button - Positioned on screen
          Positioned(
            right: 20,
            bottom: 20, // Position above the bottom nav
            child: _FloatingLiveButton(
              onTap: () => _checkPremiumAndGoLive(context),
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar (without floating button)
      bottomNavigationBar: Container(
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile
            _BottomNavItem(
              icon: CupertinoIcons.person,
              label: "Profile",
              selected: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen()),
                );
              },
            ),

            // Discover
            _BottomNavItem(
              icon: FontAwesomeIcons.compass,
              label: "Discover",
              selected: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const DiscoverScreen()),
                );
              },
            ),

            // People (Home)
            _BottomNavItem(
              icon: FontAwesomeIcons.userGroup,
              label: "People",
              selected: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
            ),

            // Live (Current)
            _BottomNavItem(
              icon: FontAwesomeIcons.video,
              label: "Live",
              selected: true,
              onTap: () {}, // Already on live screen
            ),

            // Chats
            _BottomNavItem(
              icon: FontAwesomeIcons.comment,
              label: "Chats",
              selected: false,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MessagesScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading content...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }



  Widget _buildEmptyLiveState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.tv, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'No live streams at the moment',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to go live!',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _checkPremiumAndGoLive(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go Live Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyContentState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.film, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Content from other users will appear here',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  String timeOfDayText() {
    final now = TimeOfDay.now();
    final h = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final m = now.minute.toString().padLeft(2, '0');
    final suffix = now.period == DayPeriod.am ? "AM" : "PM";
    return "$h:$m $suffix";
  }
}

/* ----------------------- LIVE FILTER BAR ----------------------- */
class _LiveFiltersBar extends StatelessWidget {
  const _LiveFiltersBar({
    required this.filters,
    required this.selected,
    required this.onTap,
    required this.backgroundColor,
  });

  final List<String> filters;
  final int selected;
  final ValueChanged<int> onTap;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    const Color selectedBgColor = Colors.white;
    const Color unselectedBgColor = Color(0xFF333333);
    const Color selectedTextColor = Colors.black87;
    const Color unselectedTextColor = Colors.white;

    return Container(
      color: backgroundColor,
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final sel = i == selected;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? selectedBgColor : unselectedBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? selectedBgColor : unselectedBgColor,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  filters[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: sel ? selectedTextColor : unselectedTextColor,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }
}

/* ----------------------- LIVE TILE ----------------------- */
class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.room, required this.onTap});
  final _LiveCard room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(room.thumb, fit: BoxFit.cover),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(.65), Colors.transparent],
                    stops: const [0, .55],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _pill(
                icon: FontAwesomeIcons.eye,
                text: _formatViewers(room.viewers),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(FontAwesomeIcons.solidCircleCheck,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room.user,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room.game,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatViewers(int v) {
    if (v >= 1000000) return "${(v / 1000000).toStringAsFixed(1)}M";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(1)}K";
    return "$v";
  }
}

/* ----------------------- REELS FEED ----------------------- */
class _ReelsFeed extends StatelessWidget {
  const _ReelsFeed({required this.items, this.showStories = false});
  final List<_ReelItem> items;
  final bool showStories;

  @override
  Widget build(BuildContext context) {
    return items.isEmpty
        ? _buildEmptyState()
        : PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return _ReelContent(item: it, showStories: showStories);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.film, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'No content from other users',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for new content from other users',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _ReelContent extends StatelessWidget {
  final _ReelItem item;
  final bool showStories;

  const _ReelContent({required this.item, this.showStories = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image/Video
        Image.network(item.thumb, fit: BoxFit.cover),

        // Gradient Overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Colors.black.withOpacity(.75), Colors.transparent],
              ),
            ),
          ),
        ),

        // Content Type Badge
        Positioned(
          top: 40,
          left: 12,
          child: _ContentTypeBadge(type: item.type),
        ),

        // Story Time Remaining (only for stories)
        if (showStories && item.type == 'story')
          Positioned(
            top: 40,
            right: 12,
            child: _StoryTimeBadge(timestamp: item.timestamp),
          ),

        // Right Action Buttons
        Positioned(
          right: 12,
          bottom: 110,
          child: Column(
            children: [
              _CircleIcon(
                icon: FontAwesomeIcons.heart,
                onTap: () => _likePost(item),
                count: item.likes.length,
              ),
              const SizedBox(height: 16),
              _CircleIcon(
                icon: FontAwesomeIcons.comment,
                onTap: () => _showComments(context, item),
                count: item.comments.length,
              ),
              const SizedBox(height: 16),
              _CircleIcon(icon: FontAwesomeIcons.share, onTap: () => _sharePost(item)),
              const SizedBox(height: 16),
              _CircleIcon(icon: FontAwesomeIcons.bookmark, onTap: () => _savePost(item)),
            ],
          ),
        ),

        // Bottom Content Info
        Positioned(
          left: 12,
          right: 80,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Row
              Row(
                children: [
                  // User Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      image: DecorationImage(
                        image: NetworkImage(item.userPhoto.isNotEmpty
                            ? item.userPhoto
                            : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=100&auto=format&fit=crop'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${item.user}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        if (item.timestamp != null)
                          Text(
                            _formatTimestamp(item.timestamp!),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content Title
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              // Engagement Stats
              Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.eye,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatViewers(item.viewers),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    FontAwesomeIcons.heart,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.likes.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    FontAwesomeIcons.comment,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.comments.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${postTime.day}/${postTime.month}/${postTime.year}';
  }

  void _likePost(_ReelItem item) {
    // Implement like functionality
    print('Liked post: ${item.postId}');
  }

  void _showComments(BuildContext context, _ReelItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CommentsBottomSheet(item: item),
    );
  }

  void _sharePost(_ReelItem item) {
    // Implement share functionality
    print('Shared post: ${item.postId}');
  }

  void _savePost(_ReelItem item) {
    // Implement save functionality
    print('Saved post: ${item.postId}');
  }

  String _formatViewers(int v) {
    if (v >= 1000000) return "${(v / 1000000).toStringAsFixed(1)}M";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(1)}K";
    return "$v";
  }
}

// Story Time Badge Widget
class _StoryTimeBadge extends StatelessWidget {
  final Timestamp? timestamp;

  const _StoryTimeBadge({this.timestamp});

  @override
  Widget build(BuildContext context) {
    if (timestamp == null) return const SizedBox();

    final storyTime = timestamp!.toDate();
    final expiresAt = storyTime.add(const Duration(hours: 24));
    final remaining = expiresAt.difference(DateTime.now());

    String timeText;
    Color badgeColor;

    if (remaining.inHours > 0) {
      timeText = '${remaining.inHours}h';
      badgeColor = Colors.green;
    } else if (remaining.inMinutes > 0) {
      timeText = '${remaining.inMinutes}m';
      badgeColor = Colors.orange;
    } else {
      timeText = 'Ending';
      badgeColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        timeText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

// Content Type Badge Widget
class _ContentTypeBadge extends StatelessWidget {
  final String type;

  const _ContentTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (type) {
      case 'story':
        badgeColor = Colors.purpleAccent;
        badgeText = 'STORY';
        badgeIcon = FontAwesomeIcons.circlePlay;
      case 'live_replay':
        badgeColor = Colors.redAccent;
        badgeText = 'REPLAY';
        badgeIcon = FontAwesomeIcons.video;
      case 'video':
        badgeColor = Colors.blueAccent;
        badgeText = 'VIDEO';
        badgeIcon = FontAwesomeIcons.video;
      default:
        badgeColor = Colors.blueAccent;
        badgeText = 'POST';
        badgeIcon = FontAwesomeIcons.image;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Updated Circle Icon with Count
class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int count;

  const _CircleIcon({
    required this.icon,
    required this.onTap,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkResponse(
          onTap: onTap,
          radius: 28,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
        if (count > 0) ...[
          const SizedBox(height: 4),
          Text(
            _formatCount(count),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return "${(count / 1000000).toStringAsFixed(1)}M";
    if (count >= 1000) return "${(count / 1000).toStringAsFixed(1)}K";
    return count.toString();
  }
}

// Comments Bottom Sheet
class _CommentsBottomSheet extends StatelessWidget {
  final _ReelItem item;

  const _CommentsBottomSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF333333),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${item.comments.length})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(FontAwesomeIcons.xmark, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: item.comments.isEmpty
                ? const Center(
              child: Text(
                'No comments yet',
                style: TextStyle(color: Colors.white54),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: item.comments.length,
              itemBuilder: (context, index) {
                final comment = item.comments[index];
                return _CommentTile(comment: comment);
              },
            ),
          ),

          // Add Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black.withOpacity(0.3),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(FontAwesomeIcons.paperPlane, color: AppColors.primary),
                  onPressed: () {
                    // Implement add comment
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(
              'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=100&auto=format&fit=crop',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment['commenterUID'] ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment['text'] ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCommentTime(comment['date_time']),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.heart, size: 16, color: Colors.white54),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  String _formatCommentTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final time = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    }
    return '';
  }
}

/* ----------------------- MODELS ----------------------- */
class _ReelItem {
  final String user;
  final String title;
  final int viewers;
  final String thumb;
  final String type; // 'post', 'story', 'live_replay', 'video'
  final String postId;
  final String userId;
  final String userPhoto;
  final Timestamp? timestamp;
  final List<Map<String, dynamic>> likes;
  final List<Map<String, dynamic>> comments;
  final String mediaType; // 'image' or 'video'

  const _ReelItem({
    required this.user,
    required this.title,
    required this.viewers,
    required this.thumb,
    required this.type,
    required this.postId,
    required this.userId,
    required this.userPhoto,
    this.timestamp,
    required this.likes,
    required this.comments,
    this.mediaType = 'image',
  });
}

class _LiveCard {
  final String title;
  final String user;
  final int viewers;
  final String thumb;
  final String game;
  final String liveId;
  final String hostId;

  const _LiveCard({
    required this.title,
    required this.user,
    required this.viewers,
    required this.thumb,
    required this.game,
    required this.liveId,
    required this.hostId,
  });
}

/* ----------------------- BOTTOM NAV ----------------------- */
class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon,
            color: selected ? AppColors.primary : Colors.black87, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: selected ? AppColors.primary : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _FloatingLiveButton extends StatelessWidget {
  const _FloatingLiveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.8),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: const Icon(
          FontAwesomeIcons.video,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _BottomCreateButton extends StatelessWidget {
  const _BottomCreateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(.35),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(FontAwesomeIcons.plus, color: Colors.white, size: 20),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
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
                icon,
                size: selected ? 30 : 28,
                color: selected ? AppColors.primary : Colors.black54,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
  }
}