// lib/chat_screen.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_zimkit/zego_zimkit.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../constants/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPlayingVoiceNote = false;
  String? _currentPlayingVoiceNote;
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markMessagesAsRead();
    // Initialize ZIMKit conversation
    _initializeZIMKitConversation();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _textController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Initialize ZIMKit conversation
  void _initializeZIMKitConversation() async {
    try {
      // ZIMKit automatically handles conversation management
      // No need to manually create conversations
      print('ZIMKit conversation initialized for user: ${widget.otherUserId}');
    } catch (e) {
      print('Error initializing ZIMKit conversation: $e');
    }
  }

  // Load messages from Firestore
  void _loadMessages() {
    final user = _auth.currentUser;
    if (user == null) return;

    _messagesSubscription = _firestore
        .collection('chat_conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _messages = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'senderId': data['senderId'],
              'text': data['text'] ?? '',
              'type': data['type'] ?? 'text',
              'mediaUrl': data['mediaUrl'] ?? '',
              'timestamp': data['timestamp'],
              'duration': data['duration'] ?? 0,
              'isOther': data['senderId'] != user.uid,
            };
          }).toList();
        });
      }
    });
  }

  // Mark messages as read
  void _markMessagesAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('chat_conversations')
          .doc(widget.conversationId)
          .update({
        'unreadCount.${user.uid}': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Send text message - Using ZIMKit's built-in functionality
  void _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Use ZIMKit's built-in method to send message
      // ZIMKit automatically handles the conversation
      await ZIMKit().sendTextMessage(
        text,
        widget.otherUserId as ZIMConversationType,
        ZIMConversationType.peer as String,
      );

      // Also save to Firestore for backup
      await _saveMessageToFirestore(
        type: 'text',
        text: text,
        senderId: user.uid,
      );

      _textController.clear();
    } catch (e) {
      print('Error sending text message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  // Send image message - Using ZIMKit's built-in functionality
  void _sendImageMessage(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // In a real app, you would upload the image to your storage first
      final imageUrl = 'https://via.placeholder.com/400x300.png?text=Image';

      // Use ZIMKit's built-in method to send image
      await ZIMKit().sendMediaMessage(
        widget.otherUserId,
        ZIMConversationType.peer,
        imageFile.path as List<ZIMKitPlatformFile>,
      );

      // Save to Firestore
      await _saveMessageToFirestore(
        type: 'image',
        text: 'Sent an image',
        mediaUrl: imageUrl,
        senderId: user.uid,
      );
    } catch (e) {
      print('Error sending image message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: $e')),
      );
    }
  }

  // Send voice message - Using ZIMKit's built-in functionality
  void _sendVoiceMessage(String audioPath, int duration) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // In a real app, you would upload the audio file to your storage first
      final audioUrl = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Use ZIMKit's built-in method to send audio
      await ZIMKit().sendMediaMessage(
        widget.otherUserId,
        ZIMConversationType.peer,
        audioPath as List<ZIMKitPlatformFile>,
      );

      // Save to Firestore
      await _saveMessageToFirestore(
        type: 'voice',
        text: _formatDuration(duration),
        mediaUrl: audioUrl,
        senderId: user.uid,
        duration: duration,
      );
    } catch (e) {
      print('Error sending voice message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send voice message: $e')),
      );
    }
  }

  // Save message to Firestore
  Future<void> _saveMessageToFirestore({
    required String type,
    required String text,
    required String senderId,
    String mediaUrl = '',
    int duration = 0,
  }) async {
    try {
      await _firestore
          .collection('chat_conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .add({
        'senderId': senderId,
        'text': text,
        'type': type,
        'mediaUrl': mediaUrl,
        'duration': duration,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update conversation last message
      await _firestore
          .collection('chat_conversations')
          .doc(widget.conversationId)
          .update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageType': type,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving message to Firestore: $e');
    }
  }

  // Pick image from gallery
  void _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (image != null) {
        _sendImageMessage(File(image.path));
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  // Take photo with camera
  void _takePhotoWithCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );

      if (image != null) {
        _sendImageMessage(File(image.path));
      }
    } catch (e) {
      print('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take photo: $e')),
      );
    }
  }

  // Start voice recording
  void _startVoiceRecording() {
    setState(() {
      _isRecording = true;
    });
    // In a real app, you would start recording using a package like audiorecorder
    print('Voice recording started...');
  }

  // Stop voice recording and send
  void _stopVoiceRecording() async {
    setState(() {
      _isRecording = false;
    });

    // Mock: Simulate recording and sending
    // In a real app, you would get the actual audio file and duration
    final mockDuration = 5; // seconds
    final mockAudioPath = 'temp_audio.m4a';

    _sendVoiceMessage(mockAudioPath, mockDuration);
  }

  // Play voice note
  void _playVoiceNote(String messageId, String mediaUrl, int duration) async {
    try {
      if (_isPlayingVoiceNote && _currentPlayingVoiceNote == messageId) {
        // Stop if already playing
        await _audioPlayer.stop();
        setState(() {
          _isPlayingVoiceNote = false;
          _currentPlayingVoiceNote = null;
        });
      } else {
        // Start playing
        if (_currentPlayingVoiceNote != null) {
          await _audioPlayer.stop();
        }

        // In a real app, you would play from the actual URL
        // For now, we'll just simulate playback
        setState(() {
          _isPlayingVoiceNote = true;
          _currentPlayingVoiceNote = messageId;
        });

        // Simulate playback completion after duration
        Timer(Duration(seconds: duration), () {
          if (mounted) {
            setState(() {
              _isPlayingVoiceNote = false;
              _currentPlayingVoiceNote = null;
            });
          }
        });
      }
    } catch (e) {
      print('Error playing voice note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play voice note: $e')),
      );
    }
  }

  // Start voice call
  void _startVoiceCall() {
    final user = _auth.currentUser;
    if (user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZegoUIKitPrebuiltCall(
          appID: 51745598, // Your Zego app ID
          appSign: '5bfa67bea457bf8b27014d411711518683ef0465f4a09f64832ea8d56e92e7a4', // Your app sign
          callID: 'voice_call_${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}',
          userID: user.uid,
          userName: user.displayName ?? 'User',
          config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
            ..avatarBuilder = (BuildContext context, Size size, ZegoUIKitUser? user, Map extraInfo) {
              return CircleAvatar(
                backgroundImage: NetworkImage(widget.otherUserAvatar),
                radius: size.width / 2,
              );
            },
        ),
      ),
    );

    // Save call history
    _saveCallHistory('voice');
  }

  // Start video call
  void _startVideoCall() {
    final user = _auth.currentUser;
    if (user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZegoUIKitPrebuiltCall(
          appID: 51745598, // Your Zego app ID
          appSign: '5bfa67bea457bf8b27014d411711518683ef0465f4a09f64832ea8d56e92e7a4', // Your app sign
          callID: 'video_call_${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}',
          userID: user.uid,
          userName: user.displayName ?? 'User',
          config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
            ..avatarBuilder = (BuildContext context, Size size, ZegoUIKitUser? user, Map extraInfo) {
              return CircleAvatar(
                backgroundImage: NetworkImage(widget.otherUserAvatar),
                radius: size.width / 2,
              );
            },
        ),
      ),
    );

    // Save call history
    _saveCallHistory('video');
  }

  // Save call history to Firestore
  Future<void> _saveCallHistory(String callType) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('call_history').add({
        'UID': user.uid,
        'call_with': {
          'friendUID': widget.otherUserId,
          'start_date_time': FieldValue.serverTimestamp(),
          'end_date_time': null, // Will be updated when call ends
          'call_type': callType,
        },
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving call history: $e');
    }
  }

  // Show media options
  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(CupertinoIcons.camera_fill, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhotoWithCamera();
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.photo_fill, color: AppColors.primary),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Format duration for voice notes
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Build message content based on type
  Widget _buildMessageContent(Map<String, dynamic> message, bool isOther) {
    final contentColor = isOther ? Colors.black87 : Colors.white;

    switch (message['type']) {
      case 'image':
        return GestureDetector(
          onTap: () {
            // Show image in full screen
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: InteractiveViewer(
                  child: Image.network(
                    message['mediaUrl'] ?? 'https://via.placeholder.com/400x300.png?text=Image',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              message['mediaUrl'] ?? 'https://via.placeholder.com/200x150.png?text=Image',
              width: 200,
              height: 150,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey[300],
                  child: const Icon(CupertinoIcons.photo, size: 40),
                );
              },
            ),
          ),
        );

      case 'voice':
        final isPlaying = _isPlayingVoiceNote && _currentPlayingVoiceNote == message['id'];
        return GestureDetector(
          onTap: () => _playVoiceNote(
            message['id'],
            message['mediaUrl'],
            message['duration'] ?? 0,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isOther ? Colors.grey[100] : AppColors.primary.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                  color: contentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  message['text'] ?? '0:00',
                  style: TextStyle(
                    color: contentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                // Waveform visualization
                Container(
                  width: 80,
                  height: 20,
                  margin: const EdgeInsets.only(left: 8),
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      isPlaying: isPlaying,
                      color: contentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case 'text':
      default:
        return Text(
          message['text'] ?? '',
          style: TextStyle(
            color: contentColor,
            fontSize: 16,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.otherUserAvatar),
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "Online",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _startVoiceCall,
            icon: const Icon(CupertinoIcons.phone_fill, color: AppColors.primary),
          ),
          IconButton(
            onPressed: _startVideoCall,
            icon: const Icon(CupertinoIcons.video_camera, color: AppColors.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.chat_bubble, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Start the conversation!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: false,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isOther = message['isOther'] as bool;

                return Align(
                  alignment: isOther ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isOther ? Colors.grey[100] : AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _buildMessageContent(message, isOther),
                  ),
                );
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Media Button
                IconButton(
                  onPressed: _showMediaOptions,
                  icon: const Icon(CupertinoIcons.plus_circle_fill, color: AppColors.primary),
                ),

                // Text Input
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: _isRecording ? "Recording..." : "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendTextMessage(),
                  ),
                ),

                const SizedBox(width: 8),

                // Send/Voice Record Button
                GestureDetector(
                  onLongPress: _startVoiceRecording,
                  onLongPressUp: _stopVoiceRecording,
                  onTap: _textController.text.isNotEmpty ? _sendTextMessage : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording
                          ? CupertinoIcons.mic_fill
                          : (_textController.text.isNotEmpty
                          ? CupertinoIcons.arrow_up_circle_fill
                          : CupertinoIcons.mic_fill),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for voice note waveform
class _WaveformPainter extends CustomPainter {
  final bool isPlaying;
  final Color color;

  _WaveformPainter({required this.isPlaying, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final waveCount = 20;
    final waveWidth = size.width / waveCount;
    final maxHeight = size.height;

    for (var i = 0; i < waveCount; i++) {
      final height = isPlaying
          ? maxHeight * (0.3 + 0.7 * ((i + 1) / waveCount))
          : maxHeight * (0.2 + 0.3 * ((i % 3 + 1) / 3));

      final x = i * waveWidth;
      final rect = Rect.fromLTWH(x, (maxHeight - height) / 2, waveWidth - 2, height);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}