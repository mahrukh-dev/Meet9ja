import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/ENVconfig.dart';
import '../constants/app_colors.dart';
import '../db_functions/firebaseStorageService.dart';
import '../models/post_model.dart';
import '../screens/post_detail_screen.dart';

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

  // Audio recording
  late FlutterSoundRecorder _audioRecorder;
  bool _isRecorderReady = false;

  bool _isRecording = false;
  bool _isPlayingVoiceNote = false;
  String? _currentPlayingVoiceNote;
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = FlutterSoundRecorder();
    _initRecorder();
    _loadMessages();
    _markMessagesAsRead();

    // Listen for text changes to update send button
    _textController.addListener(() {
      if (mounted) {
        setState(() {}); // Rebuild to update send button state
      }
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _textController.dispose();
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    _stopRecording();
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  // Initialize audio recorder
  Future<void> _initRecorder() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print('❌ Microphone permission denied');
        return;
      }

      // Open the recorder
      await _audioRecorder.openRecorder();

      // Set recorder to ready state
      setState(() {
        _isRecorderReady = true;
      });

      print('✅ Audio recorder initialized successfully');
    } catch (e) {
      print('❌ Error initializing audio recorder: $e');
      setState(() {
        _isRecorderReady = false;
      });
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
            final data = doc.data();
            return {
              'id': doc.id,
              'senderId': data['senderId'] ?? '',
              'text': data['text'] ?? '',
              'type': data['type'] ?? 'text',
              'mediaUrl': data['mediaUrl'] ?? '',
              'timestamp': data['timestamp'],
              'duration': data['duration'] ?? 0,
              'isOther': data['senderId'] != user.uid,
              'sharedPost': data['sharedPost'], // Add shared post data
            };
          }).toList();
        });
        print('✅ Loaded ${_messages.length} messages');
      }
    }, onError: (e) {
      print('❌ Error loading messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load messages: $e')),
      );
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

  // Send text message - IMPROVED VERSION
  void _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send messages')),
      );
      return;
    }

    try {
      // Show sending indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sending message...')),
      );

      await _saveMessageToFirestore(
        type: 'text',
        text: text,
        senderId: user.uid,
      );

      _textController.clear();

      // Hide sending indicator and show success
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent!')),
      );

      print('✅ Text message sent: $text');

    } catch (e) {
      print('❌ Error sending text message: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  // Send image message
  void _sendImageMessage(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading image...')),
      );

      final imageUrl = await FirebaseStorageService.uploadImage(
          imageFile,
          user.uid,
          widget.conversationId
      );

      await _saveMessageToFirestore(
        type: 'image',
        text: '📷 Photo',
        mediaUrl: imageUrl,
        senderId: user.uid,
      );

      print('✅ Image message sent: $imageUrl');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image sent!')),
      );
    } catch (e) {
      print('❌ Error sending image message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: $e')),
      );
    }
  }

  // Send voice message
  void _sendVoiceMessage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (_recordingPath == null || _recordingDuration == 0) {
      print('❌ No recording to send');
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading voice message...')),
      );

      // Upload actual audio file to Firebase Storage
      final audioFile = File(_recordingPath!);
      final audioUrl = await FirebaseStorageService.uploadVoiceNote(
          audioFile,
          user.uid,
          widget.conversationId
      );

      await _saveMessageToFirestore(
        type: 'voice',
        text: _formatDuration(_recordingDuration),
        mediaUrl: audioUrl,
        senderId: user.uid,
        duration: _recordingDuration,
      );

      print('✅ Voice message sent: $audioUrl, duration: $_recordingDuration seconds');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice message sent!')),
      );

    } catch (e) {
      print('❌ Error sending voice message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send voice message: $e')),
      );
    } finally {
      // Clean up temporary file
      if (_recordingPath != null) {
        try {
          final file = File(_recordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('⚠ Could not delete temp audio file: $e');
        }
      }
    }
  }

  // Save message to Firestore - FIXED VERSION
  Future<void> _saveMessageToFirestore({
    required String type,
    required String text,
    required String senderId,
    String mediaUrl = '',
    int duration = 0,
    Map<String, dynamic>? sharedPost,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create message data
      final messageData = {
        'senderId': senderId,
        'text': text,
        'type': type,
        'mediaUrl': mediaUrl,
        'duration': duration,
        'timestamp': FieldValue.serverTimestamp(),
        if (sharedPost != null) 'sharedPost': sharedPost,
      };

      // Save message to messages subcollection
      await _firestore
          .collection('chat_conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .add(messageData);

      print('✅ Message saved to messages subcollection: $text');

      // Update or create conversation document with ALL required fields
      final conversationData = {
        'conversationId': widget.conversationId,
        'participants': {
          user.uid: {
            'userId': user.uid,
            'userName': user.displayName ?? 'User',
            'userAvatar': user.photoURL ?? '',
            'lastRead': FieldValue.serverTimestamp(),
          },
          widget.otherUserId: {
            'userId': widget.otherUserId,
            'userName': widget.otherUserName,
            'userAvatar': widget.otherUserAvatar,
            'lastRead': FieldValue.serverTimestamp(),
          }
        },
        'lastMessage': text,
        'lastMessageType': type,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': {
          user.uid: 0, // Reset for current user
          widget.otherUserId: FieldValue.increment(1), // Increment for other user
        }
      };

      // Use set with merge: true to create or update the conversation
      await _firestore
          .collection('chat_conversations')
          .doc(widget.conversationId)
          .set(conversationData, SetOptions(merge: true));

      print('✅ Conversation updated successfully');

    } catch (e) {
      print('❌ Error saving message to Firestore: $e');
      throw e;
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
      print('❌ Error picking image: $e');
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
      print('❌ Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take photo: $e')),
      );
    }
  }

  // Start voice recording - FIXED VERSION
  void _startVoiceRecording() async {
    try {
      // Check if recorder is ready
      if (!_isRecorderReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio recorder not ready. Please wait...')),
        );
        return;
      }

      // Check microphone permission again
      if (!await Permission.microphone.isGranted) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required for voice recording')),
          );
          return;
        }
      }

      // Create temporary file path
      final tempDir = await getTemporaryDirectory();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${tempDir.path}/$fileName';

      // Start recording with simpler configuration
      await _audioRecorder.startRecorder(
        toFile: _recordingPath!,
        codec: Codec.aacMP4,
        sampleRate: 44100,
        numChannels: 1,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start timer to track recording duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration = timer.tick;
        });
      });

      print('🎤 Voice recording started: $_recordingPath');

    } catch (e) {
      print('❌ Error starting voice recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  // Stop voice recording
  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    if (_isRecording && _isRecorderReady) {
      try {
        await _audioRecorder.stopRecorder();
        setState(() {
          _isRecording = false;
        });
        print('⏹ Recording stopped');
      } catch (e) {
        print('❌ Error stopping recording: $e');
      }
    }
  }

  // Stop voice recording and send
  void _stopVoiceRecording() async {
    await _stopRecording();

    if (_recordingDuration > 1) { // Minimum 1 second recording
      _sendVoiceMessage();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording too short')),
      );
      // Clean up short recording
      if (_recordingPath != null) {
        try {
          final file = File(_recordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('⚠ Could not delete temp audio file: $e');
        }
      }
    }

    setState(() {
      _recordingDuration = 0;
      _recordingPath = null;
    });
  }

  // Cancel voice recording
  void _cancelVoiceRecording() async {
    await _stopRecording();

    // Delete the recording file
    if (_recordingPath != null) {
      try {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('⚠ Could not delete temp audio file: $e');
      }
    }

    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
      _recordingPath = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording cancelled')),
    );
  }

  // Play voice note - Using AudioPlayer for simplicity
  void _playVoiceNote(String messageId, String mediaUrl, int duration) async {
    try {
      if (_isPlayingVoiceNote && _currentPlayingVoiceNote == messageId) {
        // Stop playing
        await _audioPlayer.stop();
        setState(() {
          _isPlayingVoiceNote = false;
          _currentPlayingVoiceNote = null;
        });
      } else {
        // Stop any currently playing audio
        if (_currentPlayingVoiceNote != null) {
          await _audioPlayer.stop();
        }

        setState(() {
          _isPlayingVoiceNote = true;
          _currentPlayingVoiceNote = messageId;
        });

        // Play the actual audio from Firebase Storage using AudioPlayer
        await _audioPlayer.play(UrlSource(mediaUrl));

        // Listen for completion
        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _isPlayingVoiceNote = false;
              _currentPlayingVoiceNote = null;
            });
          }
        });

        print('▶ Playing voice note: $mediaUrl');
      }
    } catch (e) {
      print('❌ Error playing voice note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play voice note: $e')),
      );
      setState(() {
        _isPlayingVoiceNote = false;
        _currentPlayingVoiceNote = null;
      });
    }
  }

  // Start voice call
  void _startVoiceCall() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to make calls')),
      );
      return;
    }

    try {
      await ZegoUIKit().init(
        appID: Env.zegoAppID,
        appSign: Env.zegoAppSign,
      );

      final callID = 'voice_call_${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ZegoUIKitPrebuiltCall(
              appID: Env.zegoAppID,
              appSign: Env.zegoAppSign,
              callID: callID,
              userID: user.uid,
              userName: user.displayName ?? 'User',
              config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
          ),
        ),
      );

      await _saveCallHistory('voice');
      print('✅ Voice call started');
    } catch (e) {
      print('❌ Error starting voice call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start call: $e')),
      );
    }
  }

  // Start video call
  void _startVideoCall() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to make calls')),
      );
      return;
    }

    try {
      await ZegoUIKit().init(
        appID: Env.zegoAppID,
        appSign: Env.zegoAppSign,
      );

      final callID = 'video_call_${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ZegoUIKitPrebuiltCall(
              appID: Env.zegoAppID,
              appSign: Env.zegoAppSign,
              callID: callID,
              userID: user.uid,
              userName: user.displayName ?? 'User',
              config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
          ),
        ),
      );

      await _saveCallHistory('video');
      print('✅ Video call started');
    } catch (e) {
      print('❌ Error starting video call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start call: $e')),
      );
    }
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
          'end_date_time': null,
          'call_type': callType,
        },
        'created_at': FieldValue.serverTimestamp(),
      });
      print('✅ Call history saved: $callType');
    } catch (e) {
      print('❌ Error saving call history: $e');
    }
  }

  // Navigate to post detail screen
  void _navigateToPostDetail(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: postId),
      ),
    );
  }

  // Show media options
  void _showMediaOptions() {
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
                      Icon(Icons.attach_file, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Send Media',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.photo_library, color: AppColors.primary),
                  ),
                  title: const Text('Photo Library'),
                  subtitle: const Text('Choose from your gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),

                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.camera_alt, color: AppColors.primary),
                  ),
                  title: const Text('Take Photo'),
                  subtitle: const Text('Use your camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhotoWithCamera();
                  },
                ),

                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.mic, color: AppColors.primary),
                  ),
                  title: const Text('Voice Message'),
                  subtitle: const Text('Hold to record'),
                  onTap: () {
                    Navigator.pop(context);
                    _startVoiceRecording();
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

  // Format duration for voice notes
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Build shared post widget
  Widget _buildSharedPost(Map<String, dynamic> sharedPost, bool isOther) {
    final postId = sharedPost['postId'] ?? '';
    final mediaUrl = sharedPost['mediaUrl'] ?? '';
    final caption = sharedPost['caption'] ?? '';
    final ownerId = sharedPost['ownerId'] ?? '';

    return GestureDetector(
      onTap: () => _navigateToPostDetail(postId),
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: isOther ? Colors.grey[50] : AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOther ? Colors.grey[300]! : AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Post Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.network(
                mediaUrl,
                height: 150,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.grey, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'Failed to load post',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Post Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shared Label
                  Row(
                    children: [
                      Icon(
                        Icons.share,
                        color: isOther ? Colors.grey : AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Shared Post',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOther ? Colors.grey : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Caption Preview
                  Text(
                    caption.isNotEmpty
                        ? (caption.length > 100 ? '${caption.substring(0, 100)}...' : caption)
                        : 'No caption',
                    style: TextStyle(
                      fontSize: 14,
                      color: isOther ? Colors.black87 : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Tap to view hint
                  const SizedBox(height: 8),
                  Text(
                    'Tap to view post',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOther ? Colors.grey : AppColors.primary,
                      fontStyle: FontStyle.italic,
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

  // Build message content based on type
  Widget _buildMessageContent(Map<String, dynamic> message, bool isOther) {
    final contentColor = isOther ? Colors.black87 : Colors.white;

    switch (message['type']) {
      case 'post_share':
        final sharedPost = message['sharedPost'];
        if (sharedPost != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shared post preview
              _buildSharedPost(sharedPost, isOther),
              const SizedBox(height: 8),
              // Optional text message along with the share
              if (message['text'] != null && message['text'].toString().isNotEmpty)
                Text(
                  message['text'],
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 16,
                  ),
                ),
            ],
          );
        } else {
          // Fallback for old format
          return Text(
            message['text'] ?? 'Shared a post',
            style: TextStyle(
              color: contentColor,
              fontSize: 16,
            ),
          );
        }

      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          child: Image.network(
                            message['mediaUrl'],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 300,
                                height: 300,
                                color: Colors.grey[300],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error, color: Colors.grey, size: 40),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Failed to load image',
                                      style: TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  message['mediaUrl'],
                  width: 200,
                  height: 150,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey[300],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.grey, size: 40),
                          const SizedBox(height: 8),
                          const Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '📷 Photo',
              style: TextStyle(
                color: contentColor,
                fontSize: 12,
              ),
            ),
          ],
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
                  isPlaying ? Icons.stop : Icons.play_arrow,
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
                const SizedBox(width: 8),
                Container(
                  width: 60,
                  height: 20,
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

  // Build the bottom input bar - UPDATED TO REMOVE RED RECORDING UI
  Widget _buildInputBar() {
    return Container(
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
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _showMediaOptions,
              icon: Icon(Icons.add, color: AppColors.primary, size: 24),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: "Type message...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      maxLines: 5,
                      minLines: 1,
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _sendTextMessage();
                        }
                      },
                    ),
                  ),

                  // Voice recording button - now shows recording status in a snackbar instead of red UI
                  GestureDetector(
                    onLongPressStart: (_) {
                      _startVoiceRecording();
                      // Show recording started snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.mic, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Recording... Release to send'),
                            ],
                          ),
                          backgroundColor: Colors.black87,
                          duration: Duration(hours: 1), // Long duration until released
                        ),
                      );
                    },
                    onLongPressEnd: (_) {
                      _stopVoiceRecording();
                      // Hide the recording snackbar
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Send button
          Container(
            decoration: BoxDecoration(
              color: _textController.text.trim().isNotEmpty
                  ? AppColors.primary
                  : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _textController.text.trim().isNotEmpty
                  ? _sendTextMessage
                  : null,
              icon: Icon(
                Icons.send,
                color: _textController.text.trim().isNotEmpty
                    ? Colors.white
                    : Colors.grey,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
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

          _buildInputBar(),
        ],
      ),
    );
  }
}

// Custom painter for voice note waveform
class _WaveformPainter extends CustomPainter {
  final bool isPlaying;
  final Color color;

  const _WaveformPainter({required this.isPlaying, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final waveCount = 8;
    final waveWidth = size.width / waveCount;
    final maxHeight = size.height;

    for (var i = 0; i < waveCount; i++) {
      final height = isPlaying
          ? maxHeight * (0.3 + 0.7 * ((i + 1) / waveCount))
          : maxHeight * (0.2 + 0.3 * ((i % 3 + 1) / 3));

      final x = i * waveWidth;
      final rect = Rect.fromLTWH(x, (maxHeight - height) / 2, waveWidth - 1, height);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}