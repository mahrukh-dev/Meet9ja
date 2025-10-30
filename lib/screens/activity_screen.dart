// lib/screens/activity_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:meet9ja/db_functions/notification_service.dart';
// import 'package:meet9ja/services/user_service.dart';
import 'package:meet9ja/screens/profile_screen.dart';
import 'package:meet9ja/screens/chat_screen.dart';
import 'package:meet9ja/screens/post_detail_screen.dart';

import 'livestream_screen.dart';

class AppColors {
  static const Color primary = Color(0xA1E43AA8);
  static const Color kGradA = Color(0xFFFDF2F8);
  static const Color kGradB = Color(0xFFF8EAFE);
  static const Color kGradC = Color(0xFFFFF7FB);
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _notificationsStream;
  late Stream<int> _unreadCountStream;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    if (_currentUser != null) {
      _notificationsStream = NotificationService.getUserNotificationsStream(_currentUser!.uid);
      _unreadCountStream = NotificationService.getUnreadNotificationsCount(_currentUser!.uid);
    } else {
      // Create empty streams if no user
      _notificationsStream = const Stream.empty();
      _unreadCountStream = Stream.value(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kGradC,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Activity',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          StreamBuilder<int>(
            stream: _unreadCountStream,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount == 0) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Badge(
                  label: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.mark_email_read, color: AppColors.primary),
                    onPressed: _markAllAsRead,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _currentUser == null
          ? _buildNotLoggedInView()
          : _buildNotificationsList(),
    );
  }

  Widget _buildNotLoggedInView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          const Text(
            'Please log in to view activity',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Navigate to login screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: const Text(
              'Log In',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingView();
        }

        final notifications = snapshot.data?.docs ?? [];

        if (notifications.isEmpty) {
          return _buildEmptyView();
        }

        return RefreshIndicator(
          onRefresh: _refreshNotifications,
          backgroundColor: AppColors.kGradC,
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              return _buildNotificationItem(notification, notifications[index].id);
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshNotifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Loading avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Loading content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your activity will appear here',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _refreshNotifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: const Text(
              'Refresh',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification, String notificationId) {
    final isRead = notification['isRead'] ?? false;
    final type = notification['type'] ?? '';
    final fromUserName = notification['fromUserName'] ?? 'Someone';
    final fromUserPhoto = notification['fromUserPhoto'] ?? '';
    final fromUserId = notification['fromUserId'] ?? '';
    final timestamp = notification['createdAt'] as Timestamp?;
    final timeAgo = _getTimeAgo(timestamp);

    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(notificationId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: isRead
              ? const LinearGradient(
            colors: [AppColors.kGradC, AppColors.kGradC],
          )
              : const LinearGradient(
            colors: [AppColors.kGradA, AppColors.kGradB],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (!isRead) {
                NotificationService.markNotificationAsRead(notificationId);
              }
              _handleNotificationTap(notification);
            },
            onLongPress: () {
              _showNotificationOptions(notificationId, fromUserName);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar with online indicator for live notifications
                  Stack(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: type == 'user_live'
                                ? Colors.red
                                : AppColors.primary.withOpacity(0.3),
                            width: type == 'user_live' ? 3 : 2,
                          ),
                        ),
                        child: ClipOval(
                          child: fromUserPhoto.isNotEmpty
                              ? CachedNetworkImage(
                            imageUrl: fromUserPhoto,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.person,
                                color: Colors.grey[400],
                                size: 24,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.person,
                                color: Colors.grey[400],
                                size: 24,
                              ),
                            ),
                          )
                              : Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.person,
                              color: Colors.grey[400],
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      if (type == 'user_live')
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Notification Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNotificationMessage(type, fromUserName, notification),
                        const SizedBox(height: 6),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Unread indicator and action button
                  Column(
                    children: [
                      if (!isRead) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildActionButton(type, notification),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationMessage(String type, String fromUserName, Map<String, dynamic> notification) {
    switch (type) {
      case 'profile_like':
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: fromUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' liked your profile '),
              const TextSpan(text: '❤'),
            ],
          ),
        );

      case 'mutual_match':
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: "It's a match! "),
              TextSpan(
                text: 'You and $fromUserName ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: 'liked each other '),
              const TextSpan(text: '🎉'),
            ],
          ),
        );

      case 'post_comment':
        final commentText = notification['commentText'] ?? '';
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: fromUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' commented: '),
              TextSpan(
                text: '"${commentText.length > 30 ? '${commentText.substring(0, 30)}...' : commentText}"',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        );

      case 'post_like':
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: fromUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' liked your post '),
              const TextSpan(text: '👍'),
            ],
          ),
        );

      case 'follow':
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: fromUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' started following you '),
              const TextSpan(text: '👤'),
            ],
          ),
        );

      case 'new_message':
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: fromUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' sent you a message '),
              const TextSpan(text: '💬'),
            ],
          ),
        );

      case 'user_live':
        final liveTitle = notification['commentText'] ?? 'is live';
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: fromUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' is live: '),
              TextSpan(
                text: liveTitle,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' 🔴'),
            ],
          ),
        );

      case 'live_ended':
        final summary = notification['commentText'] ?? 'Your live has ended';
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'Live ended: '),
              TextSpan(
                text: summary,
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        );

      case 'live_gift':
        final giftInfo = notification['commentText'] ?? 'sent you a gift';
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: fromUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: ' $giftInfo '),
              const TextSpan(text: '🎁'),
            ],
          ),
        );

      case 'gift_received':
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: fromUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' sent you a gift '),
              const TextSpan(text: '🎁'),
            ],
          ),
        );

      default:
        return Text(
          'New activity from $fromUserName',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            height: 1.4,
          ),
        );
    }
  }

  Widget _buildActionButton(String type, Map<String, dynamic> notification) {
    switch (type) {
      case 'user_live':
        return IconButton(
          icon: const Icon(Icons.play_arrow, color: Colors.red),
          onPressed: () => _handleNotificationTap(notification),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 20,
        );
      case 'new_message':
        return IconButton(
          icon: const Icon(Icons.reply, color: AppColors.primary),
          onPressed: () => _handleNotificationTap(notification),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 20,
        );
      case 'mutual_match':
        return IconButton(
          icon: const Icon(Icons.chat, color: AppColors.primary),
          onPressed: () => _handleNotificationTap(notification),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 20,
        );
      default:
        return const SizedBox();
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    final type = notification['type'] ?? '';
    final fromUserId = notification['fromUserId'];
    final postId = notification['postId'];
    final matchId = notification['matchId'];
    final relatedUserId = notification['relatedUserId'];
    final notificationId = notification['id'];

    // Mark as read if not already
    if (!(notification['isRead'] ?? false) && notificationId != null) {
      await NotificationService.markNotificationAsRead(notificationId);
    }

    switch (type) {
      case 'profile_like':
      case 'follow':
        if (fromUserId != null) {
          _navigateToUserProfile(fromUserId);
        }
        break;

      case 'mutual_match':
        final chatWithUserId = relatedUserId ?? fromUserId;
        if (chatWithUserId != null) {
          _navigateToChat(chatWithUserId);
        }
        break;

      case 'post_comment':
      case 'post_like':
        if (postId != null) {
          _navigateToPost(postId);
        }
        break;

      case 'new_message':
        if (relatedUserId != null) {
          _navigateToChat(relatedUserId);
        }
        break;

      case 'user_live':
        if (relatedUserId != null && matchId != null) {
          _navigateToLiveStream(relatedUserId, matchId, notification['commentText'] ?? 'Live Stream');
        }
        break;

      case 'live_ended':
        _showLiveEndedDialog(notification);
        break;

      case 'live_gift':
      case 'gift_received':
        _navigateToWallet();
        break;

      default:
        break;
    }
  }

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  void _navigateToPost(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: postId),
      ),
    );
  }

  void _navigateToChat(String otherUserId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: otherUserId,
          otherUserName: 'User',
          conversationId: '',
          otherUserAvatar: '', // You can fetch the actual name if needed
        ),
      ),
    );
  }

  void _navigateToLiveStream(String hostUserId, String liveId, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(
          hostId: hostUserId,
          liveId: liveId,
          isHost: false,
          userName: title,
          userId: hostUserId,
        ),
      ),
    );
  }

  void _navigateToWallet() {
    // Navigate to wallet screen - you can implement this based on your app structure
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigate to wallet screen'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showLiveEndedDialog(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Ended'),
        content: Text(notification['commentText'] ?? 'Your live stream has ended.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToWallet();
            },
            child: const Text('View Earnings'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(String notificationId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await NotificationService.deleteNotification(notificationId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          backgroundColor: AppColors.primary,
        ),
      );
    }

    return result ?? false;
  }

  void _showNotificationOptions(String notificationId, String fromUserName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Notification',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(notificationId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_email_read, color: AppColors.primary),
              title: const Text('Mark as Read'),
              onTap: () {
                Navigator.pop(context);
                NotificationService.markNotificationAsRead(notificationId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification marked as read'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.primary),
              title: Text('View $fromUserName\'s Profile'),
              onTap: () {
                Navigator.pop(context);
                // You would need to get the user ID from the notification
                // _navigateToUserProfile(userId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    if (_currentUser != null) {
      await NotificationService.markAllNotificationsAsRead(_currentUser!.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _initializeStreams();
    });
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(timestamp.toDate());

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp.toDate());
    }
  }

  @override
  void dispose() {
    // Clean up any controllers or listeners if needed
    super.dispose();
  }
}