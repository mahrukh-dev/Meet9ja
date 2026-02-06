import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/ENVconfig.dart';
import '../constants/app_colors.dart';
import '../db_functions/firebaseStorageService.dart';
import '../db_functions/user_service.dart';
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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final AudioPlayer _ringtonePlayer = AudioPlayer();

  // Audio recording
  late FlutterSoundRecorder _audioRecorder;
  bool _isRecorderReady = false;

  bool _isRecording = false;
  bool _isPlayingVoiceNote = false;
  String? _currentPlayingVoiceNote;
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<QuerySnapshot>? _callSubscription;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String? _recordingPath;

  // Call states
  String? _activeCallId;
  String? _callType;
  bool _isReceivingCall = false;
  Map<String, dynamic>? _incomingCallData;
  Timer? _callRingTimer;
  int _callRingDuration = 0;
  static const int _maxCallRingDuration = 30; // 30 seconds

  // Navigation
  bool _isNavigatingToCall = false;
  StreamSubscription<DocumentSnapshot>? _callAnswerSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioRecorder = FlutterSoundRecorder();
    _initRecorder();
    _loadMessages();
    _markMessagesAsRead();
    _initNotifications();
    _listenForIncomingCalls();

    // Initialize ZegoUIKit
    _initZegoUIKit();

    // Listen for text changes to update send button
    _textController.addListener(() {
      if (mounted) {
        setState(() {}); // Rebuild to update send button state
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, check for pending calls
      _checkForPendingCalls();
    } else if (state == AppLifecycleState.paused) {
      // App went to background
      _stopRingtone();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagesSubscription?.cancel();
    _callSubscription?.cancel();
    _callAnswerSubscription?.cancel();
    _textController.dispose();
    _audioPlayer.dispose();
    _ringtonePlayer.dispose();
    _recordingTimer?.cancel();
    _callRingTimer?.cancel();
    _stopRecording();
    _stopRingtone();
    _audioRecorder.closeRecorder();
    _cleanupStaleCallInvitations();
    super.dispose();
  }

  // Initialize notifications with proper setup
  void _initNotifications() async {
    // Create notification channel for incoming calls (required for Android 8.0+)
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'incoming_call_channel', // channel id
      'Incoming Calls', // channel name
      description: 'Notifications for incoming calls',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('ringtone'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const [0, 1000, 500, 1000]),
    );

    // Initialize Android plugin
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Create the channel
    await androidPlugin?.createNotificationChannel(channel);

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (response.payload?.startsWith('call_') ?? false) {
          // Handle call notification tap
          print('Call notification tapped: ${response.payload}');
        }
      },
    );
  }

  // Show notification for incoming call
  void _showIncomingCallNotification(Map<String, dynamic> callData) async {
    final String callerName = callData['callerName'] ?? 'Unknown';
    final String callType = callData['callType'] ?? 'voice';

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'incoming_call_channel', // Must match channel id
      'Incoming Calls',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Incoming call',
      sound: const RawResourceAndroidNotificationSound('ringtone'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      autoCancel: false,
      ongoing: true,
      colorized: true,
      color: Colors.blue,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accept',
          'Accept',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'decline',
          'Decline',
          showsUserInterface: true,
        ),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      id: 0,
      title: 'Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call',
      body: 'From $callerName',
      notificationDetails: platformChannelSpecifics,
      payload: 'call_${callData['callID']}',
    );
  }

  // Stop/cancel the call notification
  void _stopCallNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(id: 0);
  }

  // Listen for incoming calls
  void _listenForIncomingCalls() {
    final user = _auth.currentUser;
    if (user == null) return;

    _callSubscription = _firestore
        .collection('call_invitations')
        .where('receiverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final callData = doc.data() as Map<String, dynamic>;
          _handleIncomingCall(callData, doc.id);
        }
      }
    }, onError: (error) {
      print('Error listening for calls: $error');
    });
  }

  // Handle incoming call
  void _handleIncomingCall(Map<String, dynamic> callData, String docId) async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    // If we already have an active call or are receiving a call, ignore
    if (_activeCallId != null || _isReceivingCall || _isNavigatingToCall) {
      return;
    }

    // Validate call data
    if (callData['callID'] == null || callData['callerId'] == null) {
      print('Invalid call data received');
      return;
    }

    // Store incoming call data with null checks
    setState(() {
      _isReceivingCall = true;
      _incomingCallData = callData;
      _callType = callData['callType'] ?? 'voice';
      _activeCallId = callData['callID'];
    });

    // Show incoming call screen overlay
    _showIncomingCallOverlay(callData);

    // Start ringtone
    await _playRingtone();

    // Start ring timer
    _startCallRingTimer(docId);
  }

  // Show incoming call overlay
  void _showIncomingCallOverlay(Map<String, dynamic> callData) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) {
        return IncomingCallScreen(
          callData: callData,
          onAccept: () => _acceptIncomingCall(callData),
          onReject: () => _rejectIncomingCall(),
        );
      },
    ).then((value) {
      // Dialog was dismissed
      if (mounted) {
        _cleanupCall();
      }
    });
  }

  // Play ringtone
  Future<void> _playRingtone() async {
    try {
      // For web, you might need to handle ringtone differently
      // For mobile, you can use a local asset
      await _ringtonePlayer.setSource(AssetSource('audio/ringtone.mp3'));
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.resume();
    } catch (e) {
      print('Error playing ringtone: $e');
    }
  }

  // Stop ringtone
  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
    } catch (e) {
      print('Error stopping ringtone: $e');
    }
  }

  // Start call ring timer
  void _startCallRingTimer(String docId) {
    _callRingDuration = 0;
    _callRingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _callRingDuration++;

      if (_callRingDuration >= _maxCallRingDuration) {
        // Call timed out
        timer.cancel();
        await _handleCallTimeout(docId);
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  // Handle call timeout
  Future<void> _handleCallTimeout(String docId) async {
    if (!_isReceivingCall || !mounted) return;

    // Update call status to missed
    await _firestore.collection('call_invitations').doc(docId).update({
      'status': 'missed',
      'endedAt': FieldValue.serverTimestamp(),
    });

    // Clean up
    _cleanupCall();

    // Show missed call notification
    final callerName = _incomingCallData?['callerName'] ?? 'Unknown';
    final callType = _callType ?? 'voice';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text('Missed ${callType == 'video' ? 'video' : 'voice'} call from $callerName'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Accept incoming call - OPTIMIZED VERSION
  Future<void> _acceptIncomingCall(Map<String, dynamic> callData) async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    // Prevent multiple navigation attempts
    if (_isNavigatingToCall) return;
    _isNavigatingToCall = true;

    // Stop ringtone and timer immediately
    await _stopRingtone();
    _callRingTimer?.cancel();

    // Validate call data
    final String? callID = callData['callID'];
    final String? callerId = callData['callerId'];
    final String? callerName = callData['callerName'] ?? 'Unknown';
    final String callType = callData['callType'] ?? 'voice';

    if (callID == null || callerId == null) {
      print('Invalid call data when accepting call');
      _cleanupCall();
      Navigator.pop(context);
      return;
    }

    // Update call status to accepted in background (non-blocking)
    _firestore.collection('call_invitations').doc(callID).update({
      'status': 'accepted',
      'answeredAt': FieldValue.serverTimestamp(),
    }).catchError((e) {
      print('Error updating call status: $e');
    });

    // Close incoming call overlay immediately
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Navigate directly to call screen without any delay
    if (mounted) {
      // Use a post-frame callback to ensure navigation happens after UI updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => CallScreen(
              callID: callID,
              callType: callType,
              userID: user.uid,
              userName: 'User ${user.uid.substring(0, 6)}',
              otherUserID: callerId,
              otherUserName: callerName.toString(),
              isInitiator: false,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        ).then((_) {
          // Reset navigation flag when returning from call screen
          if (mounted) {
            _isNavigatingToCall = false;
            _cleanupCall();
          }
        });
      });
    } else {
      _cleanupCall();
    }
  }

  // Reject incoming call
  void _rejectIncomingCall() async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    // Stop ringtone and timer
    await _stopRingtone();
    _callRingTimer?.cancel();

    // Update call status to rejected
    if (_incomingCallData != null && _incomingCallData!['callID'] != null) {
      try {
        await _firestore.collection('call_invitations')
            .doc(_incomingCallData!['callID']!).update({
          'status': 'rejected',
          'endedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error updating call status: $e');
      }
    }

    // Clean up
    _cleanupCall();
    if (mounted) {
      Navigator.pop(context); // Close incoming call overlay
    }
  }

  // Clean up call state
  void _cleanupCall() {
    if (mounted) {
      setState(() {
        _isReceivingCall = false;
        _incomingCallData = null;
        _activeCallId = null;
        _callType = null;
        _callRingDuration = 0;
      });
    }
    _callRingTimer?.cancel();
    _isNavigatingToCall = false;
  }

  // Clean up stale call invitations
  void _cleanupStaleCallInvitations() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

    // Delete old ringing calls
    try {
      final staleCalls = await _firestore
          .collection('call_invitations')
          .where('receiverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'ringing')
          .where('createdAt', isLessThan: oneHourAgo)
          .get();

      for (var doc in staleCalls.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error cleaning up stale calls: $e');
    }
  }

  // Check for pending calls when app resumes
  void _checkForPendingCalls() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final pendingCalls = await _firestore
          .collection('call_invitations')
          .where('receiverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'ringing')
          .limit(1)
          .get();

      if (pendingCalls.docs.isNotEmpty && mounted) {
        final callData = pendingCalls.docs.first.data();
        _handleIncomingCall(callData, pendingCalls.docs.first.id);
      }
    } catch (e) {
      print('Error checking pending calls: $e');
    }
  }

  // Initialize ZegoUIKit
  void _initZegoUIKit() async {
    try {
      // Check if already initialized
      if (true) {
        await ZegoUIKit().init(
          appID: Env.zegoAppID,
          appSign: Env.zegoAppSign,
        );
        print('✅ ZegoUIKit initialized successfully');
      } else {
        print('✅ ZegoUIKit already initialized');
      }
    } catch (e) {
      print('❌ Error initializing ZegoUIKit: $e');
    }
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
      if (mounted) {
        setState(() {
          _isRecorderReady = true;
        });
      }

      print('✅ Audio recorder initialized successfully');
    } catch (e) {
      print('❌ Error initializing audio recorder: $e');
      if (mounted) {
        setState(() {
          _isRecorderReady = false;
        });
      }
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
              'sharedPost': data['sharedPost'],
            };
          }).toList();
        });
      }
    }, onError: (e) {
      print('❌ Error loading messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
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

  // Start voice call
  Future<void> _startVoiceCall() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to make calls')),
        );
      }
      return;
    }

    // Check if already in a call
    if (_activeCallId != null || _isNavigatingToCall) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already in a call')),
        );
      }
      return;
    }

    try {
      // Generate call ID
      final callID = 'call_${DateTime.now().millisecondsSinceEpoch}_${widget.conversationId}';

      // Save call invitation
      await _saveCallInvitation(callID, 'voice');

      // Set active call
      if (mounted) {
        setState(() {
          _activeCallId = callID;
          _callType = 'voice';
        });
      }

      // Show calling screen
      if (mounted) {
        _showCallingScreen(callID, 'voice');
      }

      // Start waiting for receiver to answer
      _waitForCallAnswer(callID);

      print('✅ Voice call initiated: $callID');
    } catch (e) {
      print('❌ Error starting voice call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }

  // Start video call
  Future<void> _startVideoCall() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to make calls')),
        );
      }
      return;
    }

    // Check if already in a call
    if (_activeCallId != null || _isNavigatingToCall) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already in a call')),
        );
      }
      return;
    }

    try {
      // Generate call ID
      final callID = 'call_${DateTime.now().millisecondsSinceEpoch}_${widget.conversationId}';

      // Save call invitation
      await _saveCallInvitation(callID, 'video');

      // Set active call
      if (mounted) {
        setState(() {
          _activeCallId = callID;
          _callType = 'video';
        });
      }

      // Show calling screen
      if (mounted) {
        _showCallingScreen(callID, 'video');
      }

      // Start waiting for receiver to answer
      _waitForCallAnswer(callID);

      print('✅ Video call initiated: $callID');
    } catch (e) {
      print('❌ Error starting video call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }

  // Show calling screen (waiting for answer)
  void _showCallingScreen(String callID, String callType) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) {
        return CallingScreen(
          otherUserName: widget.otherUserName,
          otherUserAvatar: widget.otherUserAvatar,
          callType: callType,
          onCancel: () => _cancelOutgoingCall(callID),
        );
      },
    ).then((value) {
      // Dialog was dismissed
      if (mounted) {
        _cleanupCall();
      }
    });
  }

  // Wait for call answer - OPTIMIZED VERSION
  void _waitForCallAnswer(String callID) {
    // Cancel any existing subscription
    _callAnswerSubscription?.cancel();

    final callDoc = _firestore.collection('call_invitations').doc(callID);

    _callAnswerSubscription = callDoc.snapshots().listen((DocumentSnapshot snapshot) async {
      if (!mounted) return;

      if (!snapshot.exists) {
        print('Call document no longer exists');
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        print('Call data is null');
        return;
      }

      final status = data['status'] as String?;
      print('Call status updated: $status');

      if (status == 'accepted') {
        // Receiver accepted the call
        print('Call accepted, navigating to call screen...');

        // Cancel subscription first to prevent multiple triggers
        _callAnswerSubscription?.cancel();

        // Close calling screen immediately
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context); // Close calling screen
        }

        // Navigate directly to call screen without any delay
        final user = _auth.currentUser;
        if (user != null && mounted) {
          final callType = data['callType'] as String? ?? 'voice';
          final otherUserID = data['receiverId'] as String? ?? widget.otherUserId;
          final otherUserName = data['receiverName'] as String? ?? widget.otherUserName;

          // Use a post-frame callback to ensure navigation happens after UI updates
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation1, animation2) => CallScreen(
                  callID: callID,
                  callType: callType,
                  userID: user.uid,
                  userName: user.displayName ?? 'User ${user.uid.substring(0, 6)}',
                  otherUserID: otherUserID,
                  otherUserName: otherUserName,
                  isInitiator: true,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 200),
              ),
            ).then((_) {
              // Reset navigation flag when returning from call screen
              if (mounted) {
                _isNavigatingToCall = false;
                _activeCallId = null;
                _callType = null;
              }
            });
          });
        }

      } else if (status == 'rejected' || status == 'missed' || status == 'cancelled') {
        // Call was rejected, missed or cancelled
        print('Call $status');

        // Cancel subscription
        _callAnswerSubscription?.cancel();

        // Close calling screen
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context); // Close calling screen
        }

        if (mounted && (status == 'rejected' || status == 'missed')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call ${status == 'rejected' ? 'rejected' : 'missed'}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Clean up
        if (mounted) {
          setState(() {
            _activeCallId = null;
            _callType = null;
            _isNavigatingToCall = false;
          });
        }
      }
    }, onError: (error) {
      print('Error in call answer listener: $error');
      _callAnswerSubscription?.cancel();
    });
  }

  // Cancel outgoing call
  void _cancelOutgoingCall(String callID) async {
    try {
      await _firestore.collection('call_invitations').doc(callID).update({
        'status': 'cancelled',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error cancelling call: $e');
    }

    // Cancel subscription
    _callAnswerSubscription?.cancel();

    if (mounted) {
      setState(() {
        _activeCallId = null;
        _callType = null;
        _isNavigatingToCall = false;
      });
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Close calling screen
      }
    }
  }

  // Save call invitation to Firestore
  Future<void> _saveCallInvitation(String callID, String callType) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userName = user.displayName ?? 'User';
      final userAvatar = user.photoURL ?? '';

      await _firestore.collection('call_invitations').doc(callID).set({
        'callID': callID,
        'callType': callType,
        'conversationId': widget.conversationId,
        'callerId': user.uid,
        'callerName': userName,
        'callerAvatar': userAvatar,
        'receiverId': widget.otherUserId,
        'receiverName': widget.otherUserName,
        'receiverAvatar': widget.otherUserAvatar,
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
        'answeredAt': '',
        'endedAt':'',
      }, SetOptions(merge: true));

      print('✅ Call invitation saved: $callID');
    } catch (e) {
      print('❌ Error saving call invitation: $e');
      throw e;
    }
  }

  // Send text message
  void _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to send messages')),
        );
      }
      return;
    }

    try {
      await _saveMessageToFirestore(
        type: 'text',
        text: text,
        senderId: user.uid,
      );

      _textController.clear();

      print('✅ Text message sent: $text');

    } catch (e) {
      print('❌ Error sending text message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  // Send image message
  void _sendImageMessage(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading image...')),
        );
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image sent!')),
        );
      }
    } catch (e) {
      print('❌ Error sending image message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading voice message...')),
        );
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice message sent!')),
        );
      }

    } catch (e) {
      print('❌ Error sending voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
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

  // Save message to Firestore
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

      // Update conversation
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
          user.uid: 0,
          widget.otherUserId: FieldValue.increment(1),
        }
      };

      await _firestore
          .collection('chat_conversations')
          .doc(widget.conversationId)
          .set(conversationData, SetOptions(merge: true));

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  // Start voice recording
  void _startVoiceRecording() async {
    try {
      if (!_isRecorderReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio recorder not ready. Please wait...')),
          );
        }
        return;
      }

      if (!await Permission.microphone.isGranted) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission is required for voice recording')),
            );
          }
          return;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${tempDir.path}/$fileName';

      await _audioRecorder.startRecorder(
        toFile: _recordingPath!,
        codec: Codec.aacMP4,
        sampleRate: 44100,
        numChannels: 1,
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });
      }

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = timer.tick;
          });
        }
      });

      print('🎤 Voice recording started: $_recordingPath');

    } catch (e) {
      print('❌ Error starting voice recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  // Stop voice recording
  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    if (_isRecording && _isRecorderReady) {
      try {
        await _audioRecorder.stopRecorder();
        if (mounted) {
          setState(() {
            _isRecording = false;
          });
        }
        print('⏹ Recording stopped');
      } catch (e) {
        print('❌ Error stopping recording: $e');
      }
    }
  }

  // Stop voice recording and send
  void _stopVoiceRecording() async {
    await _stopRecording();

    if (_recordingDuration > 1) {
      _sendVoiceMessage();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording too short')),
        );
      }
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

    if (mounted) {
      setState(() {
        _recordingDuration = 0;
        _recordingPath = null;
      });
    }
  }

  // Cancel voice recording
  void _cancelVoiceRecording() async {
    await _stopRecording();

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

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
        _recordingPath = null;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording cancelled')),
      );
    }
  }

  // Play voice note
  void _playVoiceNote(String messageId, String mediaUrl, int duration) async {
    try {
      if (_isPlayingVoiceNote && _currentPlayingVoiceNote == messageId) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _isPlayingVoiceNote = false;
            _currentPlayingVoiceNote = null;
          });
        }
      } else {
        if (_currentPlayingVoiceNote != null) {
          await _audioPlayer.stop();
        }

        if (mounted) {
          setState(() {
            _isPlayingVoiceNote = true;
            _currentPlayingVoiceNote = messageId;
          });
        }

        await _audioPlayer.play(UrlSource(mediaUrl));

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play voice note: $e')),
        );
        setState(() {
          _isPlayingVoiceNote = false;
          _currentPlayingVoiceNote = null;
        });
      }
    }
  }

  // Navigate to post detail screen
  void _navigateToPostDetail(String postId) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: postId),
      ),
    );
  }

  // Show media options
  void _showMediaOptions() {
    if (!mounted) return;

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

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              _buildSharedPost(sharedPost, isOther),
              const SizedBox(height: 8),
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
                if (!mounted) return;
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
                        )
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

  // Build the bottom input bar
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

                  GestureDetector(
                    onLongPressStart: (_) {
                      _startVoiceRecording();
                      if (mounted) {
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
                            duration: const Duration(hours: 1),
                          ),
                        );
                      }
                    },
                    onLongPressEnd: (_) {
                      _stopVoiceRecording();
                      if (mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      }
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
          if (_activeCallId == null && !_isReceivingCall && !_isNavigatingToCall) ...[
            IconButton(
              onPressed: _startVoiceCall,
              icon: const Icon(CupertinoIcons.phone_fill, color: AppColors.primary),
            ),
            IconButton(
              onPressed: _startVideoCall,
              icon: const Icon(CupertinoIcons.video_camera, color: AppColors.primary),
            ),
          ],
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

// Incoming Call Screen (Overlay)
class IncomingCallScreen extends StatelessWidget {
  final Map<String, dynamic> callData;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallScreen({
    super.key,
    required this.callData,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final String callerName = callData['callerName'] ?? 'Unknown';
    final String callerAvatar = callData['callerAvatar'] ?? 'callerAvatar';
    final String callType = callData['callType'] ?? 'voice';

    return Material(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Caller Info
            CircleAvatar(
              radius: 60,
              backgroundImage: callerAvatar.isNotEmpty
                  ? NetworkImage(callerAvatar)
                  : null,
              child: callerAvatar.isEmpty
                  ? Icon(
                Icons.person,
                size: 50,
                color: Colors.white,
              )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reject Button
                GestureDetector(
                  onTap: onReject,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 60),

                // Accept Button
                GestureDetector(
                  onTap: onAccept,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      callType == 'video' ? Icons.videocam : Icons.phone,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Calling Screen (Waiting for answer)
class CallingScreen extends StatelessWidget {
  final String otherUserName;
  final String otherUserAvatar;
  final String callType;
  final VoidCallback onCancel;

  const CallingScreen({
    super.key,
    required this.otherUserName,
    required this.otherUserAvatar,
    required this.callType,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Caller Info
            CircleAvatar(
              radius: 60,
              backgroundImage: otherUserAvatar.isNotEmpty
                  ? NetworkImage(otherUserAvatar)
                  : null,
              child: otherUserAvatar.isEmpty
                  ? Icon(
                Icons.person,
                size: 50,
                color: Colors.white,
              )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calling...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),

            // Pulsing Animation
            Container(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing circles
                  for (int i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeOut,
                      width: 100 + i * 30,
                      height: 100 + i * 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.3 - i * 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),

                  // Center icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      callType == 'video' ? Icons.videocam : Icons.phone,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Cancel Button
            GestureDetector(
              onTap: onCancel,
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Call Screen - Direct ZegoUIKit Integration
class CallScreen extends StatefulWidget {
  final String callID;
  final String callType;
  final String userID;
  final String userName;
  final String otherUserID;
  final String otherUserName;
  final bool isInitiator;

  const CallScreen({
    super.key,
    required this.callID,
    required this.callType,
    required this.userID,
    required this.userName,
    required this.otherUserID,
    required this.otherUserName,
    required this.isInitiator,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _callEnded = false;
  Timer? _callDurationTimer;
  int _callDuration = 0;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _updateCallStatus('ongoing');
    _startCallTimer();
    _loadUsername();

    // Ensure ZegoUIKit is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureZegoInitialization();
    });
  }

  void _loadUsername() async {
    try {


      // Otherwise, fetch from Firestore or use auth
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String username;

        // Try Firestore first
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          username = userData['username'] as String? ??
              user.displayName ??
              'User ${user.uid.substring(0, 6)}';
        } else {
          username = user.displayName ?? 'User ${user.uid.substring(0, 6)}';
        }

        setState(() {
          _username = username;
        });
      }
    } catch (e) {
      print('❌ Error loading username: $e');
      setState(() {
        _username = 'User';

      });
    }
  }


  @override
  void dispose() {
    _callDurationTimer?.cancel();
    if (!_callEnded) {
      _endCall();
    }
    super.dispose();
  }

  void _ensureZegoInitialization() async {
    try {
      // Check if ZegoUIKit is initialized
      if (true) {
        await ZegoUIKit().init(
          appID: Env.zegoAppID,
          appSign: Env.zegoAppSign,
        );
        print('✅ ZegoUIKit initialized successfully in CallScreen');
      }
    } catch (e) {
      print('⚠ Warning: ZegoUIKit initialization error in CallScreen: $e');
      // Even if initialization fails, the ZegoUIKitPrebuiltCall widget
      // will handle its own initialization
    }
  }

  void _startCallTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  void _updateCallStatus(String status) async {
    try {
      await _firestore.collection('call_invitations').doc(widget.callID).update({
        'status': status,
        if (status == 'ended') 'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating call status: $e');
    }
  }

  void _endCall() {
    if (_callEnded) return;

    _callEnded = true;
    _callDurationTimer?.cancel();
    _updateCallStatus('ended');

    // Save call history
    _saveCallHistory();
  }

  void _saveCallHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore.collection('call_history').add({
        'callID': widget.callID,
        'callType': widget.callType,
        'callerId': widget.isInitiator ? widget.userID : widget.otherUserID,
        'callerName': widget.isInitiator ? widget.userName : widget.otherUserName,
        'receiverId': widget.isInitiator ? widget.otherUserID : widget.userID,
        'receiverName': widget.isInitiator ? widget.otherUserName : widget.userName,
        'startTime': FieldValue.serverTimestamp(),
        'endTime': FieldValue.serverTimestamp(),
        'duration': _callDuration,
        'status': 'completed',
      });
    } catch (e) {
      print('Error saving call history: $e');
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Directly return ZegoUIKitPrebuiltCall without any loading screen
    return ZegoUIKitPrebuiltCall(
      appID: Env.zegoAppID,
      appSign: Env.zegoAppSign,
      callID: widget.callID,
      userID: widget.userID,
      userName: 'Me', // pass username properly
      config: widget.callType == 'video'
          ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
          : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
      onDispose: () {
        _endCall();
        Navigator.pop(context);
      },
    );
  }
}