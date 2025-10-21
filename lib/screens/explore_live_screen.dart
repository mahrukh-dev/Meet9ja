import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_colors.dart';
import 'livestream_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1);
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

      // Load following reels (stories from followed users)
      final followingReels = await _getFollowingReels();

      // Load clips (saved live replays)
      final clipsReels = await _getClipsReels();

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

  // Get following reels from Firebase
  Future<List<_ReelItem>> _getFollowingReels() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // Get user's following list
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final following = List<String>.from(userDoc.data()?['following'] ?? []);

      if (following.isEmpty) return [];

      // Get active stories from followed users
      final snapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('UID', whereIn: following)
          .where('expires_at', isGreaterThan: Timestamp.now())
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _ReelItem(
          user: data['hostName'] ?? 'User',
          title: data['title'] ?? 'Live Story',
          viewers: (data['viewers'] ?? 0).toInt(),
          thumb: data['media_url'] ?? 'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?q=80&w=1080&auto=format&fit=crop',
        );
      }).toList();
    } catch (e) {
      print('Error getting following reels: $e');
      return [];
    }
  }

  // Get clips reels from Firebase
  Future<List<_ReelItem>> _getClipsReels() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('live_history')
          .where('status', isEqualTo: 'ended')
          .orderBy('end_time', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _ReelItem(
          user: data['hostName'] ?? 'Streamer',
          title: data['title'] ?? 'Live Replay',
          viewers: (data['viewer_count'] ?? 0).toInt(),
          thumb: data['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1535223289827-42f1e9919769?q=80&w=1080&auto=format&fit=crop',
        );
      }).toList();
    } catch (e) {
      print('Error getting clips reels: $e');
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
            isHost: true, hostId: '',
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
            // 🌸 Custom Tabs (Following, Live, Clips)
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
                  Tab(text: "Following"),
                  Tab(text: "Live"),
                  Tab(text: "Clips"),
                ],
              ),
            ),
          ],
        ),
      ),

      // Body content
      body: Container(
        color: darkBackground,
        child: _isLoading
            ? _buildLoadingState()
            : TabBarView(
          controller: _tab,
          children: [
            _ReelsFeed(items: _followingReels),
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
            _ReelsFeed(items: _clipsReels),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.black12.withOpacity(.4)),
          ),
          color: Colors.white,
        ),
        height: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _BottomItem(
                icon: FontAwesomeIcons.house, label: "Home", selected: true),
            const _BottomItem(icon: FontAwesomeIcons.compass, label: "Browse"),
            _BottomCreateButton(
              onTap: () => _checkPremiumAndGoLive(context),
            ),
            const _BottomItem(icon: FontAwesomeIcons.bell, label: "Activity"),
            const _BottomItem(icon: FontAwesomeIcons.user, label: "Profile"),
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
            'Loading live streams...',
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
  const _ReelsFeed({required this.items});
  final List<_ReelItem> items;

  @override
  Widget build(BuildContext context) {
    return items.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.film, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'No content available',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Follow users to see their stories',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    )
        : PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(it.thumb, fit: BoxFit.cover),
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
            Positioned(
              right: 12,
              bottom: 110,
              child: Column(
                children: [
                  _CircleIcon(icon: FontAwesomeIcons.heart, onTap: () {}),
                  const SizedBox(height: 16),
                  _CircleIcon(icon: FontAwesomeIcons.comment, onTap: () {}),
                  const SizedBox(height: 16),
                  _CircleIcon(icon: FontAwesomeIcons.share, onTap: () {}),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 80,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(FontAwesomeIcons.solidCircleCheck,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        it.user,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "LIVE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    it.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        FontAwesomeIcons.eye,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatViewers(it.viewers),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatViewers(int v) {
    if (v >= 1000000) return "${(v / 1000000).toStringAsFixed(1)}M";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(1)}K";
    return "$v";
  }
}

/* ----------------------- MODELS ----------------------- */
class _ReelItem {
  final String user;
  final String title;
  final int viewers;
  final String thumb;
  const _ReelItem({
    required this.user,
    required this.title,
    required this.viewers,
    required this.thumb,
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

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
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
    );
  }
}