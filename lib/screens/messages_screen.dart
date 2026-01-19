import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meet9ja/constants/ENVconfig.dart';
import 'package:meet9ja/db_functions/user_service.dart';
import 'package:meet9ja/screens/activity_screen.dart';
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
  Set<String> _matchedUserIds = {}; // Track currently matched user IDs
  bool _isLoading = true;
  bool _showNewChatOptions = false;
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _storiesSubscription;
  StreamSubscription<QuerySnapshot>? _matchesSubscription; // Track matches changes
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_performSearch);
    _loadAllChats();
    _loadMatchedUsers();
    _listenToMatches(); // Listen for match changes
    _initializeZegoCloud();
    _debugChatData(); // Debug helper
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _usersSubscription?.cancel();
    _storiesSubscription?.cancel();
    _matchesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Listen to matches in real-time
  void _listenToMatches() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _matchesSubscription = _firestore
        .collection('matches')
        .where('UID', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'match')
        .where('is_mutual', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final matchedIds = snapshot.docs
            .map((doc) => doc.data()['matched_user_ID'] as String)
            .toSet();
        setState(() {
          _matchedUserIds = matchedIds;
        });
        print('✅ Updated matched users: ${matchedIds.length} users');
      }
    }, onError: (e) {
      print('❌ Error listening to matches: $e');
    });
  }

  // Debug method to check chat data
  void _debugChatData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('🔍 DEBUG: Checking chat data for user: ${user.uid}');
      print('✅ Currently matched users: $_matchedUserIds');

      // Check all conversations
      final snapshot = await _firestore
          .collection('chat_conversations')
          .get();

      print('📊 Total conversations in DB: ${snapshot.docs.length}');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('\n📄 Conversation ID: ${doc.id}');
        print('   Participants: ${data['participants']}');
        print('   Last message: ${data['lastMessage']}');
        print('   Last time: ${data['lastMessageTime']}');
      }
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  // Initialize ZegoCloud ZIMKit
  Future<void> _initializeZegoCloud() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await ZIMKit().init(
        appID: Env.zegoAppID,
        appSign: Env.zegoAppSign,
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

  // Load matched users for messaging
  Future<void> _loadMatchedUsers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get mutual matches
      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('UID', isEqualTo: user.uid)
          .where('status', isEqualTo: 'match')
          .where('is_mutual', isEqualTo: true)
          .get();

      final matchedUserIds = matchesSnapshot.docs
          .map((doc) => doc.data()['matched_user_ID'] as String)
          .toSet();

      setState(() {
        _matchedUserIds = matchedUserIds;
      });

      if (matchedUserIds.isEmpty) {
        setState(() {
          _allUsers = [];
        });
        return;
      }

      // Load user data for matched users
      final usersQuery = await _firestore
          .collection('users')
          .where('UID', whereIn: matchedUserIds.toList())
          .get();

      if (mounted) {
        setState(() {
          _allUsers = usersQuery.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _User(
              id: data['UID'] ?? doc.id,
              name: data['name'] ?? 'User',
              avatar: _getFirstPhotoUrl(data['first_photos']) ?? 'https://i.pravatar.cc/200',
              isOnline: data['is_online'] ?? false,
            );
          }).toList();
        });
        print('✅ Loaded ${_allUsers.length} matched users for messaging');
      }
    } catch (e) {
      print('❌ Error loading matched users: $e');
    }
  }

  // Load ALL chat conversations
  Future<void> _loadAllChats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      print('🔄 Loading ALL chats for user: ${user.uid}');

      _chatSubscription = _firestore
          .collection('chat_conversations')
          .snapshots()
          .listen((snapshot) async {
        if (mounted) {
          List<_Conversation> conversations = [];

          for (var doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;

              // Check if user is a participant in this conversation
              final participants = data['participants'] as Map<String, dynamic>?;

              if (participants != null && participants.containsKey(user.uid)) {
                final conversation = await _Conversation.fromFirestoreWithUserData(doc.id, data);
                conversations.add(conversation);
              }
            } catch (e) {
              print('❌ Error processing conversation ${doc.id}: $e');
            }
          }

          // Sort by last message time (newest first)
          conversations.sort((a, b) {
            if (a.time == "Now" && b.time != "Now") return -1;
            if (b.time == "Now" && a.time != "Now") return 1;

            try {
              final aTime = _parseTimeString(a.time);
              final bTime = _parseTimeString(b.time);
              return bTime.compareTo(aTime);
            } catch (e) {
              return 0;
            }
          });

          setState(() {
            _chats = conversations;
            _filteredChats = List.from(_chats);
            _isLoading = false;
          });

          print('✅ Successfully loaded ${_chats.length} conversations');
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

  int _parseTimeString(String time) {
    if (time == "Now") return 0;

    if (time.endsWith('m')) {
      final minutes = int.tryParse(time.replaceAll('m', '')) ?? 0;
      return minutes;
    } else if (time.endsWith('h')) {
      final hours = int.tryParse(time.replaceAll('h', '')) ?? 0;
      return hours * 60;
    } else if (time.endsWith('d')) {
      final days = int.tryParse(time.replaceAll('d', '')) ?? 0;
      return days * 60 * 24;
    } else if (time.contains('/')) {
      return 999999;
    }

    return 0;
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

  // Start chat with any user (only matched users)
  void _startChatWithUser(_User user) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Check if user is matched
      if (!_matchedUserIds.contains(user.id)) {
        _showUnmatchedPopup(user.name);
        return;
      }

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

        // Create participants map (consistent with ChatScreen format)
        final participantsMap = {
          currentUserId: {
            'userId': currentUserId,
            'userName': currentUserName,
            'userAvatar': currentUserAvatar,
            'lastRead': FieldValue.serverTimestamp(),
          },
          otherUser.id: {
            'userId': otherUser.id,
            'userName': otherUser.name,
            'userAvatar': otherUser.avatar,
            'lastRead': FieldValue.serverTimestamp(),
          }
        };

        await _firestore.collection('chat_conversations').doc(conversationId).set({
          'conversationId': conversationId,
          'participants': participantsMap,
          'lastMessage': 'Start a conversation',
          'lastMessageType': 'text',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': currentUserId,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'unreadCount': {
            currentUserId: 0,
            otherUser.id: 0,
          }
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

  // Open existing chat - CHECK IF USER IS STILL MATCHED
  void _openExistingChat(_Conversation chat) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if the other user is still matched
      if (!_matchedUserIds.contains(chat.otherUserId)) {
        _showUnmatchedPopup(chat.name);
        return;
      }

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

  // Show popup for unmatched users
  void _showUnmatchedPopup(String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.heart_broken, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Unmatched',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$userName has been unmatched',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can only message users you are currently matched with.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Optionally navigate to MatchedUsersScreen
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => MatchedUsersScreen(userId: _auth.currentUser!.uid),
              //   ),
              // );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Matches'),
          ),
        ],
      ),
    );
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
      } else {
        // If no stories exist for current user, allow them to create one
        if (storyDisplay.isCurrentUser) {
          _createNewStory();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No stories available')),
          );
        }
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
            controller: TextEditingController(),
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
              ? _buildNoUsersState()
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

  Widget _buildNoUsersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.heart,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No matches yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'You need to match with users before you can message them',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DiscoverScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discover People'),
          ),
        ],
      ),
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
          isMatched: _matchedUserIds.contains(chat.otherUserId),
          onUnmatchedTap: () => _showUnmatchedDetails(chat), // New callback
        ),
        const Divider(height: 0),
      ],
    )).toList();
  }

  // Show detailed information about unmatched chat
  void _showUnmatchedDetails(_Conversation chat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Icon(Icons.heart_broken, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Unmatched Chat',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chat Info
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage(chat.avatar),
              ),
              title: Text(
                chat.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Last active: ${chat.time}'),
            ),

            const SizedBox(height: 16),

            // Information
            const Text(
              'Chat Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'You are no longer matched with ${chat.name}.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),

            Text(
              '• You cannot send new messages\n• Chat history is preserved\n• Match again to resume chatting',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Option 1: Navigate to user's profile
                      // _viewUserProfile(chat.otherUserId);

                      // Option 2: Navigate to discover to find them again
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DiscoverScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppColors.primary),
                    ),
                    child: Text(
                      'Find New Matches',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
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

    // Handle participants - could be Map or List
    dynamic participantsData = data['participants'];
    String otherUserId = '';
    String otherUserName = 'User';
    String otherUserAvatar = 'https://i.pravatar.cc/200';

    if (participantsData is Map<String, dynamic>) {
      // New format: participants is a Map
      final participantsMap = participantsData;
      final participantIds = participantsMap.keys.toList();

      // Find the other user ID
      for (var userId in participantIds) {
        if (userId != currentUser.uid) {
          otherUserId = userId;

          // Get user info from participants map
          final userData = participantsMap[userId] as Map<String, dynamic>?;
          if (userData != null) {
            otherUserName = userData['userName'] ?? 'User';
            otherUserAvatar = userData['userAvatar'] ?? 'https://i.pravatar.cc/200';
          }
          break;
        }
      }
    } else if (participantsData is List) {
      // Old format: participants is a List
      final participantsList = participantsData as List<dynamic>;
      for (var participant in participantsList) {
        if (participant != currentUser.uid) {
          otherUserId = participant.toString();
          break;
        }
      }
    }

    // If we couldn't find other user from participants, try alternative methods
    if (otherUserId.isEmpty) {
      // Try to get from participantNames or participantAvatars
      final participantNames = data['participantNames'] as Map<String, dynamic>?;
      if (participantNames != null) {
        for (var userId in participantNames.keys) {
          if (userId != currentUser.uid) {
            otherUserId = userId;
            otherUserName = participantNames[userId]?.toString() ?? 'User';
            break;
          }
        }
      }

      final participantAvatars = data['participantAvatars'] as Map<String, dynamic>?;
      if (participantAvatars != null && participantAvatars.containsKey(otherUserId)) {
        otherUserAvatar = participantAvatars[otherUserId]?.toString() ?? 'https://i.pravatar.cc/200';
      }
    }

    // If still no user ID, fetch from users collection
    if (otherUserId.isEmpty) {
      // This shouldn't happen, but as a fallback
      print('⚠ Could not determine other user ID from conversation data');
    } else if (otherUserName == 'User' || otherUserAvatar.contains('pravatar')) {
      // Fetch user data from users collection
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
      lastMessage: data['lastMessage']?.toString() ?? 'Start a conversation',
      time: _formatTime(data['lastMessageTime']),
      unread: (unreadCount is int) ? unreadCount : 0,
      otherUserId: otherUserId,
      participants: [currentUser.uid, otherUserId],
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
      if (timestamp is Timestamp) {
        final messageTime = timestamp.toDate();
        final now = DateTime.now();
        final difference = now.difference(messageTime);

        if (difference.inMinutes < 1) return 'Now';
        if (difference.inHours < 1) return '${difference.inMinutes}m';
        if (difference.inDays < 1) return '${difference.inHours}h';
        if (difference.inDays < 7) return '${difference.inDays}d';

        return '${messageTime.month}/${messageTime.day}';
      } else if (timestamp is DateTime) {
        final messageTime = timestamp;
        final now = DateTime.now();
        final difference = now.difference(messageTime);

        if (difference.inMinutes < 1) return 'Now';
        if (difference.inHours < 1) return '${difference.inMinutes}m';
        if (difference.inDays < 1) return '${difference.inHours}h';
        if (difference.inDays < 7) return '${difference.inDays}d';

        return '${messageTime.month}/${messageTime.day}';
      } else {
        return 'Now';
      }
    } catch (e) {
      print('❌ Error formatting time: $e');
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

// ---------- Updated Chat Tile with unmatched indicator ----------
// ---------- Updated Chat Tile with proper unmatched handling ----------
class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.onTap,
    required this.isMatched,
    required this.onUnmatchedTap, // New callback for unmatched chats
  });

  final _Conversation chat;
  final VoidCallback onTap;
  final bool isMatched;
  final VoidCallback onUnmatchedTap; // Callback for unmatched chats

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      onTap: isMatched ? onTap : onUnmatchedTap, // Use different callback
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: NetworkImage(chat.avatar),
            onBackgroundImageError: (exception, stackTrace) {
              print('❌ Error loading avatar: $exception');
            },
          ),
          if (!isMatched)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.heart_broken,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          if (isMatched && chat.unread > 0)
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
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isMatched ? Colors.black : Colors.grey,
                decoration: !isMatched ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            chat.time,
            style: TextStyle(
              fontSize: 12,
              color: isMatched ? Colors.black54 : Colors.grey,
            ),
          ),
        ],
      ),
      subtitle: Text(
        isMatched ? chat.lastMessage : 'Unmatched',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isMatched ? Colors.black.withOpacity(0.7) : Colors.red,
          fontWeight: isMatched && chat.unread > 0 ? FontWeight.w800 : FontWeight.w500,
          fontStyle: !isMatched ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      trailing: isMatched
          ? const FaIcon(
        FontAwesomeIcons.chevronRight,
        color: Colors.black26,
        size: 16,
      )
          : IconButton(
        icon: const Icon(
          Icons.info_outline,
          color: Colors.red,
          size: 18,
        ),
        onPressed: onUnmatchedTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
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
    return GestureDetector(
      onTap: () {
        onViewStory(storyDisplay);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: (!storyDisplay.isCurrentUser && storyDisplay.story != null)
                  ? const LinearGradient(
                colors: [AppColors.primary, Color(0xFFFFC107)],
              )
                  : storyDisplay.isCurrentUser
                  ? LinearGradient(
                colors: [AppColors.primary.withOpacity(0.35), Colors.white],
              )
                  : null,
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(storyDisplay.userAvatar),
                  ),
                  if (storyDisplay.isCurrentUser)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          storyDisplay.story != null
                              ? Icons.check
                              : Icons.add,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
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
      FontAwesomeIcons.heart,
      FontAwesomeIcons.solidCommentDots,
    ];
    final labels = const [
      "Profile",
      "Discover",
      "People",
      "Liked You",
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
                if (i == 2 && current != 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
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
                        fontSize: 11,
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