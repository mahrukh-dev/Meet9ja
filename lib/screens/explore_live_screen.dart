import 'dart:async';
import 'dart:ui';
import 'package:chewie/chewie.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meet9ja/db_functions/user_service.dart';
import 'package:meet9ja/screens/MatchedUserScreen.dart';
import 'package:meet9ja/screens/activity_screen.dart' hide AppColors;
import 'package:meet9ja/screens/profile_screen.dart';
import 'package:meet9ja/screens/post_detail_screen.dart';
import 'package:video_player/video_player.dart';

import '../constants/app_colors.dart';
import '../models/user_model.dart';
import 'browse_live_screen.dart';
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
    "Comedy",
    "Relationships",
    "Music",
    "Lifestyle/Entertainment",
  ];
  int _liveFilterIndex = 0;

  List<_ReelItem> _followingReels = [];
  List<_ReelItem> _clipsReels = [];
  List<_LiveCard> _liveRooms = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _liveStreamSubscription;
  String? _currentUserId;
  List<UserModel> _matchedUsers = [];

  // Bottom navigation state
  int _currentBottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadLiveData();
    _setupLiveStreamListener();
    _loadMatchedUsers();
  }

  @override
  void dispose() {
    _liveStreamSubscription?.cancel();
    _tab.dispose();
    super.dispose();
  }

  // Load matched users for sharing
  Future<void> _loadMatchedUsers() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get mutual matches where both users have liked each other
      final matchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('UID', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'match')
          .where('is_mutual', isEqualTo: true)
          .get();

      final matchedUserIds = matchesSnapshot.docs
          .map((doc) => doc.data()['matched_user_ID'] as String)
          .toList();

      final users = await Future.wait(
        matchedUserIds.map((userId) => UserService.getUserProfile(userId)),
      );

      setState(() {
        _matchedUsers = users.whereType<UserModel>().toList();
      });
    } catch (e) {
      print('Error loading matched users: $e');
    }
  }

  // Load matched users for sharing (same as in PostDetailScreen)
  Future<List<UserModel>> _loadMatchedUsersForSharing() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      // Get mutual matches where both users have liked each other
      final matchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('UID', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'match')
          .where('is_mutual', isEqualTo: true)
          .get();

      final matchedUserIds = matchesSnapshot.docs
          .map((doc) => doc.data()['matched_user_ID'] as String)
          .toList();

      final users = await Future.wait(
        matchedUserIds.map((userId) => UserService.getUserProfile(userId)),
      );

      return users.whereType<UserModel>().toList();
    } catch (e) {
      print('Error loading matched users for sharing: $e');
      return [];
    }
  }

  // Generate consistent conversation ID (same as in PostDetailScreen)
  String _getConversationId(String user1, String user2) {
    final sortedIds = [user1, user2]..sort();
    return 'conversation_${sortedIds[0]}_${sortedIds[1]}';
  }

  // Ensure conversation exists (same as in PostDetailScreen)
  Future<void> _ensureConversationExists(String conversationId, String currentUserId, UserModel otherUser) async {
    try {
      final conversationDoc = await FirebaseFirestore.instance
          .collection('chat_conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        // Get current user data from Firestore
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;

        final currentUserName = currentUserData?['name'] ?? 'You';
        final currentUserAvatar = _getFirstPhotoUrl(currentUserData?['first_photos']) ?? 'https://i.pravatar.cc/200';

        final otherUserAvatar = UserService.getProfilePhotoUrl(otherUser) ?? 'https://i.pravatar.cc/200';

        await FirebaseFirestore.instance
            .collection('chat_conversations')
            .doc(conversationId)
            .set({
          'participants': [currentUserId, otherUser.uid],
          'participantNames': {
            currentUserId: currentUserName,
            otherUser.uid: otherUser.name,
          },
          'participantAvatars': {
            currentUserId: currentUserAvatar,
            otherUser.uid: otherUserAvatar,
          },
          'lastMessage': 'Shared a post',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageType': 'post_share',
          'unreadCount': {
            currentUserId: 0,
            otherUser.uid: 0,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Created new conversation for sharing: $conversationId');
      }
    } catch (e) {
      print('❌ Error ensuring conversation exists: $e');
      rethrow;
    }
  }

  // Helper method to get first photo URL (same as in PostDetailScreen)
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

  // Save shared post to chat (same as in PostDetailScreen)
  Future<void> _saveSharedPostToChat({
    required String conversationId,
    required String message,
    required _ReelItem item,
    required String senderId,
  }) async {
    try {
      // Save message to messages subcollection
      await FirebaseFirestore.instance
          .collection('chat_conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'senderId': senderId,
        'text': message,
        'type': 'post_share',
        'sharedPost': {
          'postId': item.postId,
          'mediaUrl': item.thumb,
          'caption': item.title,
          'ownerId': item.userId,
          'postType': item.type, // Add post type for context
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update conversation with shared post info
      await FirebaseFirestore.instance
          .collection('chat_conversations')
          .doc(conversationId)
          .update({
        'lastMessage': 'Shared ${item.type == 'story' ? 'a story' : 'a post'} 📸',
        'lastMessageType': 'post_share',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount.$senderId': 0,
      });

      print('✅ Shared ${item.type} saved to chat: $conversationId');
    } catch (e) {
      print('❌ Error saving shared ${item.type} to chat: $e');
      rethrow;
    }
  }

  // Share post with specific user (same as in PostDetailScreen)
  Future<void> _shareWithUser(UserModel user, _ReelItem item) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Generate conversation ID
      final conversationId = _getConversationId(currentUser.uid, user.uid);

      // Ensure conversation exists
      await _ensureConversationExists(conversationId, currentUser.uid, user);

      // Create share message based on content type
      final contentType = item.type == 'story' ? 'story' : 'post';
      final shareMessage = "Check out this $contentType! 📸\n\n${item.title}\n\n[Shared ${contentType}: ${item.thumb}]";

      // Save shared post message to Firestore
      await _saveSharedPostToChat(
        conversationId: conversationId,
        message: shareMessage,
        item: item,
        senderId: currentUser.uid,
      );

      // Close the share sheet
      if (mounted) {
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contentType} shared with ${user.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }


    } catch (e) {
      print('❌ Error sharing ${item.type}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share ${item.type}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              likes: List<Map<String, dynamic>>.from(data['likes'] ?? []),
              comments: List<Map<String, dynamic>>.from(data['comments'] ?? []),
              mediaType: data['media_type'] ?? 'image', // 'image' or 'video' for stories
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
          final postType = data['type'] ?? 'post';
          final mediaType = postType == 'video' ? 'video' : 'image';

          return _ReelItem(
            user: userData?['username'] ?? 'User',
            title: data['caption'] ?? 'New Post',
            viewers: (data['likes']?.length ?? 0) + (data['comments']?.length ?? 0),
            thumb: data['media_url'] ?? 'https://images.unsplash.com/photo-1517705008128-361805f42e86?q=80&w=1080&auto=format&fit=crop',
            type: postType,
            postId: doc.id,
            userId: userId,
            userPhoto: userData?['photo_url'] ?? '',
            timestamp: data['date_time'] as Timestamp?,
            likes: List<Map<String, dynamic>>.from(data['likes'] ?? []),
            comments: List<Map<String, dynamic>>.from(data['comments'] ?? []),
            mediaType: mediaType,
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

  // Like functionality - simplified without progress indicators
  Future<void> _likePost(_ReelItem item) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to like posts')),
        );
        return;
      }

      // Check if already liked
      final isLiked = item.likes.any((like) => like['likerUID'] == currentUserId);

      if (isLiked) {
        // Unlike
        await UserService.unlikePost(item.postId, currentUserId);
      } else {
        // Like
        await UserService.likePost(item.postId, currentUserId);
      }

      // Update UI immediately without showing loading state
        _loadLiveData(); // This will refresh the data in background
    } catch (e) {
      print('Error liking post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like: $e')),
      );
    }
  }

  // Comment functionality
  void _showComments(BuildContext context, _ReelItem item) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to comment')),
      );
      return;
    }

    // Navigate to post detail screen for comments
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: item.postId),
      ),
    );
  }

  // Share functionality - only to matched users
  void _sharePost(_ReelItem item) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to share posts')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.share, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Share ${item.type == 'story' ? 'Story' : 'Post'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              FutureBuilder<List<UserModel>>(
                future: _loadMatchedUsersForSharing(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          const Text(
                            'No matches yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Match with users to share posts',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  final matchedUsers = snapshot.data!;
                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: matchedUsers.length,
                      itemBuilder: (context, index) {
                        final user = matchedUsers[index];
                        final profilePhotoUrl = UserService.getProfilePhotoUrl(user);

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundImage: profilePhotoUrl != null
                                ? NetworkImage(profilePhotoUrl)
                                : const NetworkImage("https://i.pravatar.cc/100?img=8") as ImageProvider,
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            UserService.getDisplayUsername(user),
                            style: const TextStyle(
                              color: Colors.black54,
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
                              'Share',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          onTap: () => _shareWithUser(user, item),
                        );
                      },
                    ),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Send share message to matched user
  Future<void> _sendShareMessage(UserModel user, _ReelItem item) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      // Create a share message
      final message = {
        'senderId': currentUserId,
        'receiverId': user.uid,
        'message': 'Check out this ${item.type}! ${item.title}',
        'sharedPostId': item.postId,
        'sharedPostType': item.type,
        'sharedPostImage': item.thumb,
        'sharedPostUser': item.user,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'share',
        'isRead': false,
      };

      // Save to messages collection
      await FirebaseFirestore.instance
          .collection('messages')
          .add(message);

      // Update user's recent activity
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('recent_activity')
          .add({
        'type': 'shared_post',
        'postId': item.postId,
        'sharedWith': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // Close the bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shared with ${user.username}')),
      );
    } catch (e) {
      print('Error sharing post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }

  // Navigate to user profile
  void _navigateToUserProfile(String userId) async {
    try {
      // Check if it's the current user's profile
      final currentUserId = _currentUserId;
      if (currentUserId == userId) {
        // Navigate to own profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(isMyProfile: true),
          ),
        );
      } else {
        // Navigate to other user's profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              isMyProfile: false,
              userId: userId,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open profile: $e')),
      );
    }
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

  // Handle bottom navigation
  void _onBottomNavTapped(int index) {
    setState(() {
      _currentBottomNavIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BrowseLiveScreen()),
        );
        break;
      case 2:
        _checkPremiumAndGoLive(context);
        break;
      case 3:
        Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ActivityScreen()));
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The dark background color used in the images
    const Color darkBackground = Color(0xFF333333);

    return Scaffold(
      backgroundColor: darkBackground,
      extendBodyBehindAppBar: true, // Important for TikTok-style overlay
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // TikTok-style transparent tabs
        title: Container(
          height: kToolbarHeight,
          alignment: Alignment.center,
          child: _TikTokTabBar(
            tabController: _tab,
          ),
        ),
      ),

      // Body content with floating button
      body: Stack(
        children: [
          Container(
            color: darkBackground,
            child: TabBarView(
              controller: _tab,
              children: [
                // Stories Tab - Shows ALL stories from other users
                _ReelsFeed(
                  items: _followingReels,
                  showStories: true,
                  onLike: _likePost,
                  onComment: _showComments,
                  onShare: _sharePost,
                  onProfileTap: _navigateToUserProfile,
                  autoPlayVideos: true,
                ),

                // Live Tab - Shows live streams
                Column(
                  children: [
                    const SizedBox(height: kToolbarHeight + 40), // Space for overlay tabs
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
                _ReelsFeed(
                  items: _clipsReels,
                  showStories: false,
                  onLike: _likePost,
                  onComment: _showComments,
                  onShare: _sharePost,
                  onProfileTap: _navigateToUserProfile,
                  autoPlayVideos: true,
                ),
              ],
            ),
          ),
        ],
      ),

      // Bottom nav like screenshot (Home, Browse, Create, Activity, Profile)
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
            _BottomNavItem(
              icon: Icons.home_filled,
              label: "Home",
              selected: _currentBottomNavIndex == 0,
              onTap: () => _onBottomNavTapped(0),
            ),
            _BottomNavItem(
              icon: Icons.search,
              label: "Browse",
              selected: _currentBottomNavIndex == 1,
              onTap: () => _onBottomNavTapped(1),
            ),
            _BottomCreateButton(
              onTap: () => _onBottomNavTapped(2),
            ),
            _BottomNavItem(
              icon: Icons.notifications_none,
              label: "Activity",
              selected: _currentBottomNavIndex == 3,
              onTap: () => _onBottomNavTapped(3),
            ),
            _BottomNavItem(
              icon: Icons.person_outline,
              label: "Profile",
              selected: _currentBottomNavIndex == 4,
              onTap: () => _onBottomNavTapped(4),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildLoadingState() {
  //   return const Center(
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         CircularProgressIndicator(color: Colors.white),
  //         SizedBox(height: 16),
  //         Text(
  //           'Loading content...',
  //           style: TextStyle(color: Colors.white),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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

/* ----------------------- TIKTOK STYLE TAB BAR ----------------------- */
class _TikTokTabBar extends StatelessWidget {
  final TabController tabController;

  const _TikTokTabBar({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 40,

      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.transparent,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        padding: const EdgeInsets.all(2),
        tabs: const [
          Tab(text: "Following"),
          Tab(text: "Live"),
          Tab(text: "Clips"),
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

class _ReelsFeed extends StatelessWidget {
  const _ReelsFeed({
    required this.items,
    this.showStories = false,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onProfileTap,
    this.autoPlayVideos = false, // NEW: Add this parameter
  });

  final List<_ReelItem> items;
  final bool showStories;
  final Function(_ReelItem) onLike;
  final Function(BuildContext, _ReelItem) onComment;
  final Function(_ReelItem) onShare;
  final Function(String) onProfileTap;
  final bool autoPlayVideos; // NEW: Auto-play parameter

  @override
  Widget build(BuildContext context) {
    return items.isEmpty
        ? _buildEmptyState()
        : PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return _ReelContent(
          item: it,
          showStories: showStories,
          onLike: onLike,
          onComment: onComment,
          onShare: onShare,
          onProfileTap: onProfileTap,
          autoPlayVideos: autoPlayVideos, // NEW: Pass the parameter
        );
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
class _ReelContent extends StatefulWidget {
  final _ReelItem item;
  final bool showStories;
  final Function(_ReelItem) onLike;
  final Function(BuildContext, _ReelItem) onComment;
  final Function(_ReelItem) onShare;
  final Function(String) onProfileTap;
  final bool autoPlayVideos; // NEW: Add this parameter

  const _ReelContent({
    required this.item,
    this.showStories = false,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onProfileTap,
    this.autoPlayVideos = false, // NEW: Default to false
  });

  @override
  State<_ReelContent> createState() => _ReelContentState();
}
class _ReelContentState extends State<_ReelContent> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;
  bool _isMuted = false; // NEW: Track mute state

  @override
  void initState() {
    super.initState();
    if (widget.item.mediaType == 'video') {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.network(widget.item.thumb)
        ..setLooping(true)
        ..setVolume(1.0); // CHANGED: Set volume to 1.0 (full volume) instead of 0.0

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: widget.autoPlayVideos,
        looping: true,
        allowFullScreen: true,
        allowMuting: true,
        showControls: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
      );

      // Set initial mute state
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoPlaying = widget.autoPlayVideos;
        });
      }
    } catch (e) {
      print('❌ Error initializing video: $e');
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController == null) return;

    if (_isVideoPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }

    setState(() {
      _isVideoPlaying = !_isVideoPlaying;
    });
  }

  // NEW: Toggle mute/unmute
  void _toggleMute() {
    if (_videoController == null) return;

    setState(() {
      _isMuted = !_isMuted;
    });

    _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
  }

  Widget _buildMediaContent() {
    if (widget.item.mediaType == 'video') {
      if (!_isVideoInitialized) {
        return Stack(
          children: [
            Image.network(
              widget.item.thumb,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        );
      }

      return Stack(
        children: [
          Chewie(controller: _chewieController!),

          // Custom play/pause button overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleVideoPlayback,
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: (!widget.autoPlayVideos || !_isVideoPlaying) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // NEW: Mute/Unmute button in top right corner
          // Positioned(
          //   top: 12,
          //   right: 12,
          //   child: GestureDetector(
          //     onTap: _toggleMute,
          //     child: Container(
          //       padding: const EdgeInsets.all(8),
          //       decoration: BoxDecoration(
          //         color: Colors.black.withOpacity(0.7),
          //         shape: BoxShape.circle,
          //       ),
          //       child: Icon(
          //         _isMuted ? Icons.volume_off : Icons.volume_up,
          //         color: Colors.white,
          //         size: 20,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      );
    } else {
      // Image content
      return Image.network(
        widget.item.thumb,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isLiked = widget.item.likes.any((like) => like['likerUID'] == currentUserId);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Media (Image/Video)
        _buildMediaContent(),

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


        // Story Time Remaining (only for stories)
        if (widget.showStories && widget.item.type == 'story')
          Positioned(
            top: 40,
            right: 12,
            child: _StoryTimeBadge(timestamp: widget.item.timestamp),
          ),

        // Video Play Indicator (only for videos)
        if (widget.item.mediaType == 'video')
          Positioned(
            top: 40,
            right: widget.showStories && widget.item.type == 'story' ? 70 : 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'VIDEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Right Action Buttons
        Positioned(
          right: 12,
          bottom: 110,
          child: Column(
            children: [
              _CircleIcon(
                icon: isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                onTap: () => widget.onLike(widget.item),
                count: widget.item.likes.length,
                isLiked: isLiked,
              ),
              const SizedBox(height: 16),
              _CircleIcon(
                icon: FontAwesomeIcons.comment,
                onTap: () => widget.onComment(context, widget.item),
                count: widget.item.comments.length,
              ),
              const SizedBox(height: 16),
              _CircleIcon(
                icon: FontAwesomeIcons.share,
                onTap: () => widget.onShare(widget.item),
              ),
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
              // User Info Row - Make tappable
              GestureDetector(
                onTap: () => widget.onProfileTap(widget.item.userId),
                child: Row(
                  children: [
                    // User Avatar - Make tappable
                    GestureDetector(
                      onTap: () => widget.onProfileTap(widget.item.userId),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: DecorationImage(
                            image: NetworkImage(widget.item.userPhoto.isNotEmpty
                                ? widget.item.userPhoto
                                : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=100&auto=format&fit=crop'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${widget.item.user}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          if (widget.item.timestamp != null)
                            Text(
                              _formatTimestamp(widget.item.timestamp!),
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
              ),
              const SizedBox(height: 12),

              // Content Title
              Text(
                widget.item.title,
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
                    _formatViewers(widget.item.viewers),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.item.likes.length}',
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
                    '${widget.item.comments.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),

                  // Video Duration (for videos)
                  if (widget.item.mediaType == 'video' && _videoController != null && _isVideoInitialized)
                    Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.timer_outlined,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(_videoController!.value.duration),
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

  String _formatViewers(int v) {
    if (v >= 1000000) return "${(v / 1000000).toStringAsFixed(1)}M";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(1)}K";
    return "$v";
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      final hours = twoDigits(duration.inHours);
      return "$hours:$minutes:$seconds";
    } else {
      return "$minutes:$seconds";
    }
  }
}
/* ----------------------- SHARE BOTTOM SHEET ----------------------- */
class _ShareBottomSheet extends StatelessWidget {
  final _ReelItem item;
  final List<UserModel> matchedUsers;
  final Function(UserModel, _ReelItem) onShare;

  const _ShareBottomSheet({
    required this.item,
    required this.matchedUsers,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                  'Share with Matched Users',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${matchedUsers.length})',
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

          // Matched Users List
          Expanded(
            child: matchedUsers.isEmpty
                ? const Center(
              child: Text(
                'No matched users found',
                style: TextStyle(color: Colors.white54),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: matchedUsers.length,
              itemBuilder: (context, index) {
                final user = matchedUsers[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(
                      user.photoUrl![0].isNotEmpty
                          ? user.photoUrl![0]
                          : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=100&auto=format&fit=crop',
                    ),
                  ),
                  title: Text(
                    user.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  trailing: IconButton(
                    icon: const Icon(FontAwesomeIcons.paperPlane, color: AppColors.primary),
                    onPressed: () => onShare(user, item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
// Updated Circle Icon with Count
class _CircleIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int count;
  final bool isLiked;

  const _CircleIcon({
    required this.icon,
    required this.onTap,
    this.count = 0,
    this.isLiked = false,
  });

  @override
  State<_CircleIcon> createState() => _CircleIconState();
}

class _CircleIconState extends State<_CircleIcon> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkResponse(
          onTap: () {
            setState(() {
              _isTapped = true;
            });
            widget.onTap();
            // Reset the tap state after a short delay
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                setState(() {
                  _isTapped = false;
                });
              }
            });
          },
          radius: 28,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(_isTapped ? 0.5 : 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(
                widget.icon,
                color: widget.isLiked ? Colors.red : Colors.white,
                size: 20
            ),
          ),
        ),
        if (widget.count > 0) ...[
          const SizedBox(height: 4),
          Text(
            _formatCount(widget.count),
            style: TextStyle(
              color: widget.isLiked ? Colors.red : Colors.white,
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
  final String mediaType; // 'image' or 'video' - THIS IS IMPORTANT

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
    this.mediaType = 'image', // Default to image
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
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
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