import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meet9ja/db_functions/user_service.dart';
import 'package:meet9ja/screens/MatchedUserScreen.dart';
import 'package:meet9ja/screens/dating_profile.dart';
import 'package:meet9ja/screens/profile_screen.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_zimkit/zego_zimkit.dart';
import 'package:meet9ja/constants/app_colors.dart';
import 'package:meet9ja/screens/story_view_screen.dart';
import 'package:meet9ja/screens/create_story_screen.dart';
import 'package:meet9ja/models/story_model.dart';
import '../models/user_model.dart';
import 'discover_screen.dart';
import 'chat_screen.dart';
import 'explore_live_screen.dart';
import 'home_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // --- Search State ---
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // --- Real Data State ---
  List<_Conversation> _chats = [];
  List<_Conversation> _filteredChats = [];
  List<_StoryDisplay> _stories = [];
  List<_User> _allUsers = [];
  bool _isLoading = true;
  bool _showNewChatOptions = false;
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _storiesSubscription;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_performSearch);
    _loadChatsAndStories();
    _loadAllUsers();
    _initializeZegoCloud();
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _usersSubscription?.cancel();
    _storiesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Initialize ZegoCloud ZIMKit
  Future<void> _initializeZegoCloud() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await ZIMKit().init(
        appID: 51745598,
        appSign: '5bfa67bea457bf8b27014d411711518683ef0465f4a09f64832ea8d56e92e7a4',
      );

      await ZIMKit().connectUser(
        id: user.uid,
        name: user.displayName ?? 'User',
      );

      print('✅ ZegoCloud ZIMKit initialized and user connected');
    } catch (e) {
      print('❌ ZegoCloud ZIMKit initialization error: $e');
    }
  }

  // Load all users for messaging
  Future<void> _loadAllUsers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      _usersSubscription = _firestore
          .collection('users')
          .where('UID', isNotEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _allUsers = snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _User(
                id: data['UID'] ?? doc.id,
                name: data['name'] ?? 'User',
                avatar: _getFirstPhotoUrl(data['first_photos']) ?? 'https://i.pravatar.cc/200',
                isOnline: data['is_online'] ?? false,
              );
            }).toList();
          });
          print('✅ Loaded ${_allUsers.length} users for messaging');
        }
      });
    } catch (e) {
      print('❌ Error loading users: $e');
    }
  }

  String? _getFirstPhotoUrl(Map<String, dynamic>? firstPhotos) {
    if (firstPhotos == null) return null;
    for (var i = 1; i <= 4; i++) {
      final photoUrl = firstPhotos['photo${i}url']?.toString();
      if (photoUrl != null && photoUrl.isNotEmpty && photoUrl != 'null') {
        return photoUrl;
      }
    }
    return null;
  }

  // Load real chat data from Firestore
  Future<void> _loadChatsAndStories() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      print('🔄 Loading chats for user: ${user.uid}');

      _chatSubscription = _firestore
          .collection('chat_conversations')
          .where('participants', arrayContains: user.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .listen((snapshot) async {
        if (mounted) {
          // Process conversations to get correct user data
          List<_Conversation> conversations = [];

          for (var doc in snapshot.docs) {
            try {
              final conversation = await _Conversation.fromFirestoreWithUserData(doc.id, doc.data() as Map<String, dynamic>);
              conversations.add(conversation);
            } catch (e) {
              print('❌ Error processing conversation ${doc.id}: $e');
            }
          }

          setState(() {
            _chats = conversations;
            _filteredChats = List.from(_chats);
            _isLoading = false;
          });
          print('✅ Loaded ${_chats.length} conversations');
        }
      }, onError: (e) {
        print('❌ Chat subscription error: $e');
        setState(() => _isLoading = false);
      });

      await _loadStories();
    } catch (e) {
      print('❌ Error loading chats: $e');
      setState(() => _isLoading = false);
    }
  }

  // Load stories from followed users and current user
  Future<void> _loadStories() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get current user's following list
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final following = List<String>.from(userData?['following'] ?? []);

      // Add current user to the list to show "Your Story"
      final allUserIds = {user.uid, ...following};

      print('🔄 Loading stories for users: $allUserIds');

      _storiesSubscription = _firestore
          .collection('stories')
          .where('UID', whereIn: allUserIds.toList())
          .where('expires_at', isGreaterThan: Timestamp.now())
          .orderBy('expires_at', descending: true)
          .snapshots()
          .listen((snapshot) async {
        if (mounted) {
          final stories = <_StoryDisplay>[];

          // Group stories by user
          final storiesByUser = <String, List<StoryModel>>{};

          for (var doc in snapshot.docs) {
            try {
              final story = StoryModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);

              if (!storiesByUser.containsKey(story.uid)) {
                storiesByUser[story.uid] = [];
              }
              storiesByUser[story.uid]!.add(story);
            } catch (e) {
              print('❌ Error processing story ${doc.id}: $e');
            }
          }

          // Fetch user data for each story user and create story display items
          for (final userId in storiesByUser.keys) {
            try {
              final userStories = storiesByUser[userId]!;
              final userDoc = await _firestore.collection('users').doc(userId).get();

              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>?;
                final userName = userId == user.uid ? 'You' : userData?['name'] ?? 'User';
                final userAvatar = _getFirstPhotoUrl(userData?['first_photos']) ?? 'https://i.pravatar.cc/150?img=1';

                // Use the first story for the circle display
                final firstStory = userStories.first;

                // Create a story display item
                stories.add(_StoryDisplay(
                  userId: userId,
                  userName: userName,
                  userAvatar: userAvatar,
                  story: firstStory,
                  isCurrentUser: userId == user.uid,
                ));
              }
            } catch (e) {
              print('❌ Error fetching user data for story: $e');
            }
          }

          // Sort stories: current user first, then others
          stories.sort((a, b) {
            if (a.isCurrentUser) return -1;
            if (b.isCurrentUser) return 1;
            return 0;
          });

          setState(() {
            _stories = stories;
          });
          print('✅ Loaded ${_stories.length} user stories');
        }
      }, onError: (e) {
        print('❌ Stories subscription error: $e');
      });
    } catch (e) {
      print('❌ Error loading stories: $e');
    }
  }

  // Search functionality
  void _performSearch() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _filteredChats = List.from(_chats);
      });
    } else {
      setState(() {
        _filteredChats = _chats.where((chat) =>
            chat.name.toLowerCase().contains(query)
        ).toList();
      });
    }
  }

  // Toggle between existing chats and new chat options
  void _toggleNewChatOptions() {
    setState(() {
      _showNewChatOptions = !_showNewChatOptions;
      if (_showNewChatOptions) {
        _searchController.clear();
      }
    });
  }

  // Start chat with a user
  void _startChatWithUser(_User user) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final conversationId = _getConversationId(currentUser.uid, user.id);
      await _ensureConversationExists(conversationId, currentUser.uid, user);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            otherUserId: user.id,
            otherUserName: user.name,
            otherUserAvatar: user.avatar,
          ),
        ),
      );

      setState(() {
        _showNewChatOptions = false;
      });

    } catch (e) {
      print('❌ Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $e')),
      );
    }
  }

  // Generate consistent conversation ID
  String _getConversationId(String user1, String user2) {
    final sortedIds = [user1, user2]..sort();
    return 'conversation_${sortedIds[0]}_${sortedIds[1]}';
  }

  // Ensure conversation exists in Firestore
  Future<void> _ensureConversationExists(String conversationId, String currentUserId, _User otherUser) async {
    try {
      final conversationDoc = await _firestore.collection('chat_conversations').doc(conversationId).get();

      if (!conversationDoc.exists) {
        // Get current user data from Firestore
        final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
        final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;

        final currentUserName = currentUserData?['name'] ?? 'You';
        final currentUserAvatar = _getFirstPhotoUrl(currentUserData?['first_photos']) ?? 'https://i.pravatar.cc/200';

        await _firestore.collection('chat_conversations').doc(conversationId).set({
          'participants': [currentUserId, otherUser.id],
          'participantNames': {
            currentUserId: currentUserName,
            otherUser.id: otherUser.name,
          },
          'participantAvatars': {
            currentUserId: currentUserAvatar,
            otherUser.id: otherUser.avatar,
          },
          'lastMessage': 'Start a conversation',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageType': 'text',
          'unreadCount': {
            currentUserId: 0,
            otherUser.id: 0,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Created new conversation: $conversationId');
      } else {
        print('✅ Conversation already exists: $conversationId');
      }
    } catch (e) {
      print('❌ Error ensuring conversation exists: $e');
      rethrow;
    }
  }

  // Open existing chat
  void _openExistingChat(_Conversation chat) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _markConversationAsRead(chat.id);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: chat.id,
            otherUserId: chat.otherUserId,
            otherUserName: chat.name,
            otherUserAvatar: chat.avatar,
          ),
        ),
      );

    } catch (e) {
      print('❌ Error opening chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open chat: $e')),
      );
    }
  }

  // Mark conversation as read
  Future<void> _markConversationAsRead(String conversationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('chat_conversations').doc(conversationId).update({
        'unreadCount.${user.uid}': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error marking conversation as read: $e');
    }
  }

  // Create new story
  void _createNewStory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateStoryScreen(userId: user.uid),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // View user stories
  void _viewUserStory(_StoryDisplay storyDisplay) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get all stories for this user
      final storiesSnapshot = await _firestore
          .collection('stories')
          .where('UID', isEqualTo: storyDisplay.userId)
          .where('expires_at', isGreaterThan: Timestamp.now())
          .orderBy('created_at', descending: false)
          .get();

      final userStories = storiesSnapshot.docs
          .map((doc) => StoryModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (userStories.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewScreen(
              stories: userStories,
              initialIndex: 0,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error viewing story: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to view story: $e')),
      );
    }
  }

  Widget _buildTitleBar(BuildContext context) {
    if (_isSearching) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Search chats...",
              hintStyle: const TextStyle(color: Colors.black54),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(FontAwesomeIcons.multiply, color: AppColors.primary),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _isSearching = false);
                },
              ),
            ),
          ),
        ),
      );
    } else {
      return const Expanded(
        child: Center(
          child: Text(
            "Chats",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  children: [
                    if (_isSearching)
                      IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.arrowLeft,
                          color: Colors.black87,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchController.clear();
                          });
                        },
                      )
                    else
                      const SizedBox(width: 48),

                    _buildTitleBar(context),

                    if (!_isSearching)
                      Row(
                        children: [
                          IconButton(
                            icon: FaIcon(
                              _showNewChatOptions ? FontAwesomeIcons.comments : FontAwesomeIcons.plus,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            onPressed: _toggleNewChatOptions,
                          ),
                          IconButton(
                            icon: const FaIcon(
                              FontAwesomeIcons.magnifyingGlass,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSearching = true;
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _showNewChatOptions
                    ? _buildNewChatView()
                    : _buildExistingChatsView(),
              ),

              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: _BottomNav(current: 4),
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
            'Loading conversations...',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingChatsView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      children: [
        const _SectionHeader("Stories"),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: _stories.isEmpty
              ? _buildEmptyStoriesState()
              : ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _stories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _StoryCircle(
              storyDisplay: _stories[i],
              onCreateStory: _createNewStory,
              onViewStory: _viewUserStory,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            const _SectionHeader("Conversations"),
            const Spacer(),
            if (_chats.isNotEmpty)
              TextButton(
                onPressed: _toggleNewChatOptions,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'New Chat',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_filteredChats.isEmpty) _buildEmptyChatsState(),
        if (_filteredChats.isNotEmpty) ..._buildChatList(),
      ],
    );
  }

  Widget _buildEmptyStoriesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.circlePlay, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          const Text(
            'No stories yet',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: _toggleNewChatOptions,
              ),
              const SizedBox(width: 8),
              const Text(
                'New Chat',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search users...",
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (value) {
              // Implement user search here
            },
          ),
        ),

        Expanded(
          child: _allUsers.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _allUsers.length,
            itemBuilder: (context, index) {
              final user = _allUsers[index];
              return _UserTile(
                user: user,
                onTap: () => _startChatWithUser(user),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChatsState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.comments, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No conversations yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new conversation with someone',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _toggleNewChatOptions,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start New Chat'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChatList() {
    return _filteredChats.map((chat) => Column(
      children: [
        _ChatTile(
          chat: chat,
          onTap: () => _openExistingChat(chat),
        ),
        const Divider(height: 0),
      ],
    )).toList();
  }
}

// ---------- Story Display Model (for UI) ----------
class _StoryDisplay {
  final String userId;
  final String userName;
  final String userAvatar;
  final StoryModel story;
  final bool isCurrentUser;

  const _StoryDisplay({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.story,
    required this.isCurrentUser,
  });
}

// ---------- Updated Conversation Model ----------
class _Conversation {
  final String id;
  final String name;
  final String avatar;
  final String lastMessage;
  final String time;
  final int unread;
  final String otherUserId;
  final List<String> participants;

  const _Conversation({
    required this.id,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.otherUserId,
    required this.participants,
  });

  // Factory method that fetches user data from Firestore
  static Future<_Conversation> fromFirestoreWithUserData(String id, Map<String, dynamic> data) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final participants = List<String>.from(data['participants'] ?? []);
    final otherUserId = participants.firstWhere(
          (uid) => uid != currentUser.uid,
      orElse: () => '',
    );

    // If we have the other user's data in conversation, use it
    String otherUserName = data['otherUserName'] ?? 'User';
    String otherUserAvatar = data['otherUserAvatar'] ?? 'https://i.pravatar.cc/200';

    // If data is missing or we need to refresh, fetch from users collection
    if (otherUserId.isNotEmpty && (otherUserName == 'User' || otherUserAvatar.contains('pravatar'))) {
      try {
        final otherUserDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
        if (otherUserDoc.exists) {
          final otherUserData = otherUserDoc.data() as Map<String, dynamic>?;
          otherUserName = otherUserData?['name'] ?? 'User';
          otherUserAvatar = _getFirstPhotoUrl(otherUserData?['first_photos']) ?? 'https://i.pravatar.cc/200';
        }
      } catch (e) {
        print('❌ Error fetching user data for $otherUserId: $e');
      }
    }

    // Get unread count for current user
    final unreadCount = (data['unreadCount'] as Map<String, dynamic>?)?[currentUser.uid] ?? 0;

    return _Conversation(
      id: id,
      name: otherUserName,
      avatar: otherUserAvatar,
      lastMessage: data['lastMessage'] ?? 'Start a conversation',
      time: _formatTime(data['lastMessageTime']),
      unread: (unreadCount is int) ? unreadCount : 0,
      otherUserId: otherUserId,
      participants: participants,
    );
  }

  static String? _getFirstPhotoUrl(Map<String, dynamic>? firstPhotos) {
    if (firstPhotos == null) return null;
    for (var i = 1; i <= 4; i++) {
      final photoUrl = firstPhotos['photo${i}url']?.toString();
      if (photoUrl != null && photoUrl.isNotEmpty && photoUrl != 'null') {
        return photoUrl;
      }
    }
    return null;
  }

  static String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Now';

    try {
      final messageTime = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(messageTime);

      if (difference.inMinutes < 1) return 'Now';
      if (difference.inHours < 1) return '${difference.inMinutes}m';
      if (difference.inDays < 1) return '${difference.inHours}h';
      if (difference.inDays < 7) return '${difference.inDays}d';

      return '${messageTime.month}/${messageTime.day}';
    } catch (e) {
      return 'Now';
    }
  }
}

// ---------- New User Tile Component ----------
class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});
  final _User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      onTap: onTap,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(user.avatar),
          ),
          if (user.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        user.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        user.isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          color: user.isOnline ? Colors.green : Colors.grey,
          fontSize: 12,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Text(
          'Message',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

// ---------- Stories Circle ----------
class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.storyDisplay,
    required this.onCreateStory,
    required this.onViewStory,
  });

  final _StoryDisplay storyDisplay;
  final VoidCallback onCreateStory;
  final Function(_StoryDisplay) onViewStory;

  @override
  Widget build(BuildContext context) {
    final isYou = storyDisplay.isCurrentUser;

    return GestureDetector(
      onTap: () {
        if (isYou) {
          onCreateStory();
        } else {
          onViewStory(storyDisplay);
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: (!isYou)
                  ? const LinearGradient(
                colors: [AppColors.primary, Color(0xFFFFC107)],
              )
                  : LinearGradient(
                colors: [AppColors.primary.withOpacity(0.35), Colors.white],
              ),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(storyDisplay.userAvatar),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              storyDisplay.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Chat List Tile ----------
class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});
  final _Conversation chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(radius: 26, backgroundImage: NetworkImage(chat.avatar)),
          if (chat.unread > 0)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "${chat.unread}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            chat.time,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.black.withOpacity(0.7),
          fontWeight: chat.unread > 0 ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      trailing: const FaIcon(
        FontAwesomeIcons.chevronRight,
        color: Colors.black26,
        size: 16,
      ),
    );
  }
}
// ---------- Bottom Nav ----------
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, this.onTap});
  final int current;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final icons = const [
      FontAwesomeIcons.solidUser,
      FontAwesomeIcons.compass,
      FontAwesomeIcons.solidCircleUser,
      FontAwesomeIcons.heart, // Changed from solidHeart to video
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
                if (i == 0 && current != 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => DatingProfileScreen()),
                  );
                  return;
                }
                if (i == 1 && current != 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DiscoverScreen()),
                  );
                  return;
                }
                if (i == 2 && current != 2) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                  return;
                }
                if (i == -3 && current != 3) { // Added navigation for Live tab

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => MatchedUsersScreen(userId: UserService.currentUserId!,)),
                  );
                  return;
                }
                if (i == 4 && current != 4) { // Current screen (Chats), do nothing
                  // Already on Messages screen, do nothing
                  return;
                }
              },
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
                    FaIcon(
                      icons[i],
                      size: selected ? 26 : 24,
                      color: selected ? AppColors.primary : Colors.black54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
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
        }),
      ),
    );
  }
}

// ---------- Shared Components ----------
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

// ---------- User Model ----------
class _User {
  final String id;
  final String name;
  final String avatar;
  final bool isOnline;

  const _User({
    required this.id,
    required this.name,
    required this.avatar,
    required this.isOnline,
  });
}