import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meet9ja/constants/app_colors.dart';
import 'package:meet9ja/screens/livestream_screen.dart';

class BrowseLiveScreen extends StatefulWidget {
  const BrowseLiveScreen({super.key});

  @override
  State<BrowseLiveScreen> createState() => _BrowseLiveScreenState();
}

class _BrowseLiveScreenState extends State<BrowseLiveScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<_LiveCard> _allLiveRooms = [];
  List<_LiveCard> _filteredLiveRooms = [];
  List<_UserCard> _searchUsers = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _currentUserId;
  Timer? _searchDebounce;

  final List<String> _liveFilters = const [
    "All",
    "Comedy",
    "Relationships",
    "Music",
    "Lifestyle/Entertainment",
    "Gaming",
    "Education",
    "Sports",
  ];
  int _liveFilterIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadLiveData();
    _setupSearchListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      // Debounce search to avoid too many requests
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        _performSearch(_searchController.text.trim());
      });
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchUsers.clear();
        _filteredLiveRooms = _allLiveRooms;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Filter live rooms by username
    final filteredRooms = _allLiveRooms.where((room) {
      return room.user.toLowerCase().contains(query.toLowerCase());
    }).toList();

    // Also search for users in the database
    _searchUsersInDatabase(query).then((users) {
      if (mounted) {
        setState(() {
          _filteredLiveRooms = filteredRooms;
          _searchUsers = users;
        });
      }
    });
  }

  Future<List<_UserCard>> _searchUsersInDatabase(String query) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: query + 'z')
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _UserCard(
          userId: doc.id,
          username: data['username'] ?? 'User',
          displayName: data['name'] ?? 'User',
          avatar: data['photo_url'] ?? '',
          isLive: data['isLive'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Future<void> _loadLiveData() async {
    try {
      setState(() => _isLoading = true);

      final liveStreams = await _getActiveLiveStreams();

      if (mounted) {
        setState(() {
          _allLiveRooms = liveStreams;
          _filteredLiveRooms = liveStreams;
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
          hostUsername: data['hostUsername'] ?? '',
        );
      }).toList();
    } catch (e) {
      print('Error getting live streams: $e');
      return [];
    }
  }

  void _joinLiveStream(_LiveCard room) {
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

  void _viewUserProfile(_UserCard user) {
    // Navigate to user profile
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing ${user.displayName}\'s profile')),
    );
    // You can implement navigation to user profile screen here
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchUsers.clear();
      _filteredLiveRooms = _allLiveRooms;
    });
  }

  void _applyCategoryFilter(int index) {
    setState(() {
      _liveFilterIndex = index;
    });

    if (_liveFilterIndex == 0) {
      // "All" filter
      _filteredLiveRooms = _allLiveRooms;
    } else {
      final category = _liveFilters[index];
      _filteredLiveRooms = _allLiveRooms.where((room) {
        return room.game.toLowerCase().contains(category.toLowerCase());
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF333333),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Browse Live Streams',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by username...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        prefixIcon: Icon(FontAwesomeIcons.search, color: Colors.white.withOpacity(0.6)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(FontAwesomeIcons.times, color: Colors.white.withOpacity(0.6)),
                          onPressed: _clearSearch,
                        )
                            : null,
                      ),
                      cursorColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Live Filters Bar
          _LiveFiltersBar(
            filters: _liveFilters,
            selected: _liveFilterIndex,
            onTap: _applyCategoryFilter,
            backgroundColor: const Color(0xFF333333),
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _isSearching && _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildLiveStreamsGrid(),
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

  Widget _buildSearchResults() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Live Stream Results
        if (_filteredLiveRooms.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Live Streams',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 9 / 14,
            ),
            itemCount: _filteredLiveRooms.length,
            itemBuilder: (context, index) {
              return _LiveTile(
                room: _filteredLiveRooms[index],
                onTap: () => _joinLiveStream(_filteredLiveRooms[index]),
              );
            },
          ),
          const SizedBox(height: 24),
        ],

        // User Results
        if (_searchUsers.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Users',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          ..._searchUsers.map((user) => _UserSearchTile(
            user: user,
            onTap: () => _viewUserProfile(user),
          )),
        ],

        // No Results
        if (_filteredLiveRooms.isEmpty && _searchUsers.isEmpty)
          _buildNoResults(),
      ],
    );
  }

  Widget _buildLiveStreamsGrid() {
    return _filteredLiveRooms.isEmpty
        ? _buildEmptyLiveState()
        : CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _LiveTile(
                room: _filteredLiveRooms[index],
                onTap: () => _joinLiveStream(_filteredLiveRooms[index]),
              ),
              childCount: _filteredLiveRooms.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 9 / 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.search, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'No results found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'No live streams or users found for "${_searchController.text}"',
            style: const TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
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
        ],
      ),
    );
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

/* ----------------------- USER SEARCH TILE ----------------------- */
class _UserSearchTile extends StatelessWidget {
  const _UserSearchTile({required this.user, required this.onTap});
  final _UserCard user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(user.avatar.isNotEmpty
                  ? user.avatar
                  : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=100&auto=format&fit=crop'),
            ),
            if (user.isLive)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.circle,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          user.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '@${user.username}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        trailing: user.isLive
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        )
            : null,
        onTap: onTap,
      ),
    );
  }
}

/* ----------------------- MODELS ----------------------- */
class _LiveCard {
  final String title;
  final String user;
  final int viewers;
  final String thumb;
  final String game;
  final String liveId;
  final String hostId;
  final String hostUsername;

  const _LiveCard({
    required this.title,
    required this.user,
    required this.viewers,
    required this.thumb,
    required this.game,
    required this.liveId,
    required this.hostId,
    required this.hostUsername,
  });
}

class _UserCard {
  final String userId;
  final String username;
  final String displayName;
  final String avatar;
  final bool isLive;

  const _UserCard({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.isLive,
  });
}