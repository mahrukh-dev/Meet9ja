import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../db_functions/user_service.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  PostModel? _post;
  UserModel? _postUser;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _commentController = TextEditingController();
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    try {
      final post = await UserService.getPostById(widget.postId);
      if (post != null && mounted) {
        setState(() {
          _post = post;
          _isLoading = false;
        });
        await _loadPostUser(post.uid);
        _checkIfLiked();
      } else {
        setState(() {
          _error = 'Post not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load post: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPostUser(String userId) async {
    try {
      final user = await UserService.getUserProfile(userId);
      if (mounted) {
        setState(() {
          _postUser = user;
        });
      }
    } catch (e) {
      print('Error loading post user: $e');
    }
  }

  void _checkIfLiked() {
    final currentUserId = UserService.currentUserId;
    if (_post != null && currentUserId != null) {
      setState(() {
        _isLiked = _post!.likes.any((like) => like.likerUID == currentUserId);
      });
    }
  }

  Future<void> _toggleLike() async {
    final currentUserId = UserService.currentUserId;
    if (_post == null || currentUserId == null) return;

    try {
      if (_isLiked) {
        await UserService.unlikePost(_post!.id, currentUserId);
      } else {
        await UserService.likePost(_post!.id, currentUserId);
      }

      // Reload post to get updated likes
      await _loadPost();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${_isLiked ? 'unlike' : 'like'} post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addComment() async {
    final currentUserId = UserService.currentUserId;
    if (_post == null || currentUserId == null) return;

    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    try {
      await UserService.addComment(
        postId: _post!.id,
        userId: currentUserId,
        text: commentText,
      );

      _commentController.clear();
      // Reload post to get updated comments
      await _loadPost();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Share post with matched users
  void _sharePost() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
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
                      const Text(
                        'Share Post',
                        style: TextStyle(
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
                            onTap: () => _shareWithUser(user),
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
        );
      },
    );
  }

  // Load matched users for sharing
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

  // Share post with specific user
  Future<void> _shareWithUser(UserModel user) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || _post == null) return;

      // Generate conversation ID (same as in your MessagesScreen)
      final conversationId = _getConversationId(currentUser.uid, user.uid);

      // Ensure conversation exists
      await _ensureConversationExists(conversationId, currentUser.uid, user);

      // Create share message
      final shareMessage = "Check out this post! 📸\n\n${_post!.caption}\n\n[Shared Post: ${_post!.mediaUrl}]";

      // Save shared post message to Firestore
      await _saveSharedPostToChat(
        conversationId: conversationId,
        message: shareMessage,
        post: _post!,
        senderId: currentUser.uid,
      );

      // Close the share sheet
      if (mounted) {
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post shared with ${user.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('✅ Post shared with ${user.name}');
    } catch (e) {
      print('❌ Error sharing post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Generate consistent conversation ID (same as in MessagesScreen)
  String _getConversationId(String user1, String user2) {
    final sortedIds = [user1, user2]..sort();
    return 'conversation_${sortedIds[0]}_${sortedIds[1]}';
  }

  // Ensure conversation exists (similar to MessagesScreen)
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

  // Helper method to get first photo URL
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

  // Save shared post to chat
  Future<void> _saveSharedPostToChat({
    required String conversationId,
    required String message,
    required PostModel post,
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
          'postId': post.id,
          'mediaUrl': post.mediaUrl,
          'caption': post.caption,
          'ownerId': post.uid,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update conversation with shared post info
      await FirebaseFirestore.instance
          .collection('chat_conversations')
          .doc(conversationId)
          .update({
        'lastMessage': 'Shared a post 📸',
        'lastMessageType': 'post_share',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount.$senderId': 0,
      });

      print('✅ Shared post saved to chat: $conversationId');
    } catch (e) {
      print('❌ Error saving shared post to chat: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null || _post == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(FontAwesomeIcons.arrowLeft),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(_error ?? 'Post not found'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Post',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Post Image
                  Container(
                    width: double.infinity,
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                    ),
                    child: Image.network(
                      _post!.mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error);
                      },
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _toggleLike,
                          icon: Icon(
                            _isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                            color: _isLiked ? Colors.red : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(FontAwesomeIcons.comment),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: _sharePost,
                          icon: const Icon(FontAwesomeIcons.share),
                        ),
                        const Spacer(),
                        Text(
                          '${_post!.likes.length} likes',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Caption
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _postUser?.username ?? 'User',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_post!.caption),
                        ),
                      ],
                    ),
                  ),

                  // Comments
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Comments',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  if (_post!.comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._post!.comments.map((comment) => ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.grey,
                      ),
                      title: Text(
                        'User ${comment.commenterUID.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(comment.text),
                      trailing: Text(
                        _formatTime(comment.dateTime),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    )),
                ],
              ),
            ),
          ),

          // Add Comment - FIXED BORDER SYNTAX
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all( // FIXED: Changed from Border.top to Border.all
                color: Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(FontAwesomeIcons.paperPlane),
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w';
    return '${(difference.inDays / 30).floor()}mo';
  }
}