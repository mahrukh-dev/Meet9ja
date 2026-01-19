import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:meet9ja/constants/ENVconfig.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:meet9ja/db_functions/user_service.dart'; // Add this import

import '../aws/zego_recording_service.dart';

class LiveStreamScreen extends StatefulWidget {
  final String liveId;
  final String userId;
  final bool isHost;
  final String userName;
  final String? hostId;

  const LiveStreamScreen({
    super.key,
    required this.liveId,
    required this.userId,
    required this.isHost,
    required this.userName,
    this.hostId,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> with WidgetsBindingObserver, RouteAware {
  // Zego Configuration
  final int _zegoAppId = Env.zegoAppID;
  final String _zegoServerSecret = Env.zegoServerSecret;
  final String _zegoAppSign = Env.zegoAppSign;

  // AWS S3 Configuration
  final String _awsBucketName = Env.awsBucketName;
  final String _awsRegion = Env.awsRegion;
  final String _awsAccessKey = Env.awsAccessKey;
  final String _awsSecretKey = Env.awsSecretKey;

  // Recording state
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isLeaving = false;
  String? _recordingUrl;
  List<String> _recordingUrls = [];
  String? _recordingError;
  String? _recordingTaskId;
  bool _usingFallback = false;
  bool _zegoInitialized = false;
  Timer? _statusPollingTimer;
  Timer? _recordingCheckTimer;
  int _signatureAttempt = 0;
  int _recordingCheckAttempts = 0;
  static const int _maxRecordingCheckAttempts = 30; // 15 minutes total

  // Navigation control
  bool _canNavigate = false;
  Completer<void>? _recordingCompleter;

  // Route observer
  final RouteObserver<PageRoute> _routeObserver = RouteObserver<PageRoute>();
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeZego();
    _updateViewerCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Screen came back to foreground
    _isExiting = false;
  }

  @override
  void didPop() {
    // Screen was popped from navigation stack
    _handleScreenExit();
  }

  @override
  void didPushNext() {
    // Another screen was pushed on top
    _handleScreenExit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver.unsubscribe(this);
    _cleanupResources();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleScreenExit();
        break;
      case AppLifecycleState.resumed:
        _isExiting = false;
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _cleanupResources();
        break;
    }
  }

  void _cleanupResources() {
    print('🧹 Cleaning up resources...');

    // Cancel all timers
    _statusPollingTimer?.cancel();
    _recordingCheckTimer?.cancel();

    // Complete any pending completers
    _recordingCompleter?.complete();

    // Stop recording if still active
    if (_isRecording && widget.isHost) {
      _stopZegoRecording();
    }

    // Update viewer count if audience
    if (!widget.isHost) {
      _decrementViewerCount();
    }
  }

  void _handleScreenExit() {
    if (_isExiting) return;

    _isExiting = true;
    print('🚪 Screen exit detected, handling cleanup...');

    if (widget.isHost) {
      // Host: end the live stream
      _endLiveStream();
    } else {
      // Audience: just leave
      _leaveAsAudience();
    }
  }

  Future<void> _endLiveStream() async {
    if (_isLeaving) return;

    print('🛑 Host is ending live stream...');
    setState(() {
      _isLeaving = true;
    });

    // Stop recording if active
    if (_isRecording && !_usingFallback && _recordingTaskId != null) {
      await _stopZegoRecording();
    } else {
      // If recording wasn't started properly, just save what we have
      _completeRecordingProcess();
    }

    // Wait for recording process to complete if needed
    if (!_canNavigate) {
      _recordingCompleter = Completer<void>();
      await _recordingCompleter!.future;
    }

    // Update Firestore to end stream
    await _saveRecordingToFirestore();

    // Navigate back
    _navigateBack();
  }

  Future<void> _leaveAsAudience() async {
    print('👤 Audience leaving...');

    // Decrement viewer count
    await _decrementViewerCount();

    // Navigate back immediately
    _navigateBack();
  }

  Future<void> _decrementViewerCount() async {
    try {
      await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(widget.liveId)
          .update({'viewers': FieldValue.increment(-1)});
      print('✅ Viewer count decremented');
    } catch (e) {
      print('❌ Error decrementing viewer count: $e');
    }
  }

  void _navigateBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _initializeZego() {
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _zegoInitialized = true;
      });

      if (widget.isHost) {
        Future.delayed(const Duration(seconds: 3), () {
          _startZegoRecordingWithRetry();
        });
      }
    });
  }

  Future<void> _startZegoRecordingWithRetry() async {
    if (!widget.isHost || !_zegoInitialized) return;

    print('🎥 Attempting to start Zego Cloud Recording...');

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        setState(() {
          _signatureAttempt = attempt;
        });

        print('🔄 Attempt $attempt...');

        await _startZegoRecording();
        return;
      } catch (e) {
        _recordingError = e.toString();
        print('❌ Recording attempt $attempt failed: $e');

        if (attempt < 3) {
          final delay = Duration(seconds: attempt * 2);
          print('⏳ Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        } else {
          print('🚫 All recording attempts failed, using fallback');
          _handleRecordingFallback('All Zego recording attempts failed: $e');
        }
      }
    }
  }

  Future<void> _startZegoRecording() async {
    if (!widget.isHost) return;

    try {
      print('🎥 Starting Zego Cloud Recording...');
      print('🏠 Room ID: ${widget.liveId}');
      print('👤 User ID: ${widget.userId}');

      final result = await ZegoRecordingService.startRecording(
        appId: _zegoAppId,
        serverSecret: _zegoServerSecret,
        roomId: widget.liveId,
        userId: widget.userId,
        bucket: _awsBucketName,
        region: _awsRegion,
        accessKeyId: _awsAccessKey,
        accessKeySecret: _awsSecretKey,
      );

      if (result['Code'] == 0) {
        final taskId = result['Data']?['TaskId']?.toString();

        if (taskId == null || taskId.isEmpty) {
          throw Exception('No TaskId returned from Zego API');
        }

        setState(() {
          _isRecording = true;
          _recordingError = null;
          _usingFallback = false;
          _recordingTaskId = taskId;
        });

        print(
            '✅ Zego Cloud Recording started successfully. Task ID: $_recordingTaskId');
        _startRecordingStatusPolling();
      } else {
        throw Exception('Zego recording API error: ${result['Message']}');
      }
    } catch (e) {
      setState(() {
        _recordingError = e.toString();
      });
      rethrow;
    }
  }

  Future<void> _stopZegoRecording() async {
    if (!_isRecording || _usingFallback || _recordingTaskId == null) {
      print('⚠️ Cannot stop recording - not recording or no task ID');
      return;
    }

    try {
      print('🛑 Stopping Zego recording with Task ID: $_recordingTaskId');

      final result = await ZegoRecordingService.stopRecording(
        appId: _zegoAppId,
        serverSecret: _zegoServerSecret,
        taskId: _recordingTaskId!,
      );

      if (result['Code'] == 0) {
        setState(() {
          _isRecording = false;
        });
        print('✅ Zego recording stopped successfully');

        // Stop status polling
        _statusPollingTimer?.cancel();

        // Start checking for final recording files
        _startFinalRecordingCheck();
      } else {
        throw Exception('Stop recording failed: ${result['Message']}');
      }
    } catch (e) {
      print('❌ Error stopping Zego recording: $e');
      // Even if stop fails, try to get final URLs
      _startFinalRecordingCheck();
    }
  }

  void _startRecordingStatusPolling() {
    _statusPollingTimer?.cancel();

    _statusPollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isRecording || _usingFallback) {
        timer.cancel();
        return;
      }
      _queryRecordingStatus();
    });
  }

  Future<void> _queryRecordingStatus() async {
    if (!_isRecording || _usingFallback || _recordingTaskId == null) return;

    try {
      final status = await ZegoRecordingService.queryRecordingStatus(
        appId: _zegoAppId,
        serverSecret: _zegoServerSecret,
        taskId: _recordingTaskId!,
      );

      print('📊 Recording status query: ${status['Code']}');

      if (status['Code'] == 0 && status['Data'] != null) {
        final recordingData = status['Data'];
        final taskStatus = recordingData['Status']?.toString();
        // FIX: Changed from 'FileList' to 'RecordFiles'
        final files = recordingData['RecordFiles'] as List<dynamic>?;

        print('📊 Recording task status: $taskStatus');

        if (files != null && files.isNotEmpty) {
          final List<String> urls = [];
          for (final file in files) {
            final fileUrl = file['FileUrl'] as String?;
            if (fileUrl != null && fileUrl.isNotEmpty) {
              urls.add(fileUrl);
            }
          }

          if (urls.isNotEmpty) {
            setState(() {
              _recordingUrls = urls;
              _recordingUrl = urls.first;
            });
            print('🎯 Recording URLs found: ${urls.length}');

            // FIX: Stop polling immediately when URLs are found
            _statusPollingTimer?.cancel();
          }
        }
      } else if (status['Code'] != 0) {
        print('⚠️ Recording status query failed: ${status['Message']}');
      }
    } catch (e) {
      print('❌ Error querying recording status: $e');
    }
  }

  Future<void> _getFinalRecordingUrls() async {
    try {
      print('🔍 Querying for final recording URLs...');
      print('📋 Current Task ID: $_recordingTaskId');

      if (_recordingTaskId != null && _recordingTaskId!.isNotEmpty) {
        final status = await ZegoRecordingService.queryRecordingStatus(
          appId: _zegoAppId,
          serverSecret: _zegoServerSecret,
          taskId: _recordingTaskId!,
        );

        print('📊 Recording status query result: ${status['Code']}');

        if (status['Code'] == 0 && status['Data'] != null) {
          final recordingData = status['Data'];
          final taskStatus = recordingData['Status']?.toString();
          // FIX: Changed from 'FileList' to 'RecordFiles'
          final files = recordingData['RecordFiles'] as List<dynamic>?;

          print('📊 Recording task status: $taskStatus');
          print('📁 Files found: ${files?.length ?? 0}');

          if (files != null && files.isNotEmpty) {
            final List<String> urls = [];
            for (final file in files) {
              final fileUrl = file['FileUrl'] as String?;
              final fileName = file['FileId'] as String?; // FIX: Changed from 'FileName' to 'FileId'
              if (fileUrl != null && fileUrl.isNotEmpty) {
                urls.add(fileUrl);
                print('📹 Found recording file: $fileName -> $fileUrl');
              }
            }

            if (urls.isNotEmpty) {
              setState(() {
                _recordingUrls = urls;
                _recordingUrl = urls.first;
              });
              print('✅ Final recording URLs obtained: ${urls.length} files');
              _recordingCheckTimer?.cancel();
              return;
            }
          } else {
            print('📭 No recording files found yet');
          }
        } else {
          print('⚠️ Recording status query failed: ${status['Message']}');
        }
      } else {
        print('⚠️ No task ID available for query');
      }
    } catch (e) {
      print('❌ Error getting final recording URLs: $e');
    }
  }

  void _startFinalRecordingCheck() {
    _recordingCheckAttempts = 0;
    _recordingCheckTimer?.cancel();

    _recordingCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_recordingCheckAttempts >= 6) { // Reduced from 30 to 6 (1 minute total)
        timer.cancel();
        print('⏰ Max recording check attempts reached');
        if (_recordingUrls.isEmpty) {
          _handleRecordingFallback('Recording files not available after 1 minute of checking');
        }
        _completeRecordingProcess();
        return;
      }

      _recordingCheckAttempts++;
      print('🔍 Checking for recording files (attempt $_recordingCheckAttempts)...');

      await _getFinalRecordingUrls();

      // If we have URLs, stop checking and complete the process immediately
      if (_recordingUrls.isNotEmpty) {
        timer.cancel();
        print('✅ Recording URLs found, stopping checks');
        _completeRecordingProcess();
      } else if (_recordingCheckAttempts >= 6) {
        // If we reach max attempts without URLs, use fallback
        timer.cancel();
        _handleRecordingFallback('No recording URLs found after 6 attempts');
        _completeRecordingProcess();
      }
    });

    // Also do an immediate check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getFinalRecordingUrls();
    });
  }

  void _completeRecordingProcess() {
    print('🎊 Recording process completed!');
    print('📹 Recording URL: $_recordingUrl');
    print('📁 Total files: ${_recordingUrls.length}');
    print('🔄 Using fallback: $_usingFallback');

    setState(() {
      _canNavigate = true;
    });

    // Complete the completer if it exists
    _recordingCompleter?.complete();

    // Save to Firestore
    _saveRecordingToFirestore();
  }

  Future<void> _handleRecordingFallback(String error) async {
    print('🔄 Using fallback recording method: $error');

    try {
      final String recordingContent =
      '''
LIVE_STREAM_METADATA
Live ID: ${widget.liveId}
Host: ${widget.userName}
Host ID: ${widget.userId}
Start Time: ${DateTime.now().toIso8601String()}
Recording Type: FALLBACK_METADATA
Status: COMPLETED
Error: $error
Task ID: $_recordingTaskId
Recording URLs: ${_recordingUrls.join(', ')}
METADATA_END
''';

      final String fileName =
          'fallback_recordings/${widget.liveId}_${DateTime
          .now()
          .millisecondsSinceEpoch}.txt';

      final fallbackUrl = await uploadToS3Improved(
        content: recordingContent,
        accessKey: _awsAccessKey,
        secretKey: _awsSecretKey,
        bucket: _awsBucketName,
        region: _awsRegion,
        objectKey: fileName,
        contentType: 'text/plain',
      );

      setState(() {
        _recordingUrl = fallbackUrl;
        _usingFallback = true;
        _isRecording = false;
      });

      print('✅ Fallback recording created: $fallbackUrl');
    } catch (e) {
      print('❌ Fallback recording also failed: $e');
      setState(() {
        _recordingUrl =
        'https://$_awsBucketName.s3.$_awsRegion.amazonaws.com/error_${widget
            .liveId}.txt';
        _usingFallback = true;
        _isRecording = false;
      });
    }
  }

  void _updateViewerCount() async {
    if (!widget.isHost) {
      try {
        await FirebaseFirestore.instance
            .collection('liveStreams')
            .doc(widget.liveId)
            .update({'viewers': FieldValue.increment(1)});
      } catch (e) {
        print('Error updating viewer count: $e');
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_isLeaving || _canNavigate) {
      return true;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Leave Live Stream?'),
            content: const Text(
                'Recording is still being processed. Are you sure you want to leave?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () {
                  // Force leave and cleanup
                  _handleScreenExit();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Leave Anyway'),
              ),
            ],
          ),
    );

    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Stack(
          children: [
            // Zego UI Kit with proper configuration
            ZegoUIKitPrebuiltLiveStreaming(
              appID: _zegoAppId,
              appSign: _zegoAppSign,
              userID: widget.userId,
              userName: widget.userName,
              liveID: widget.liveId,
              config: widget.isHost
                  ? ZegoUIKitPrebuiltLiveStreamingConfig.host()
                  : ZegoUIKitPrebuiltLiveStreamingConfig.audience(),
              events: ZegoUIKitPrebuiltLiveStreamingEvents(
                onEnded: (ZegoLiveStreamingEndEvent event,
                    VoidCallback defaultHandle) {
                  print('🎬 Zego onEnded event triggered');
                  _handleScreenExit();
                },
              ),
            ),

            // Status indicators
            if (widget.isHost) _buildStatusIndicators(),

            // Gift overlay for audience
            if (!widget.isHost)
              _GiftOverlay(liveId: widget.liveId, userId: widget.userId),

            // Loading overlay when leaving and waiting for recording
            if (_isLeaving && !_canNavigate) _buildLeavingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicators() {
    return Positioned(
      top: 60,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File count
          if (_recordingUrls.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Files: ${_recordingUrls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),

          // Error message
          if (_recordingError != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Error: ${_recordingError!.split('\n').first}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Recording check progress
          if (_isLeaving && !_canNavigate)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Checking recording... $_recordingCheckAttempts/6',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeavingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Processing Recording...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please wait while we save your recording\nThis may take a few minutes...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            if (_recordingUrl != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✅ Recording URL obtained!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveRecordingToFirestore() async {
    if (!widget.isHost) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final liveDoc = await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(widget.liveId)
          .get();

      final liveData = liveDoc.data() as Map<String, dynamic>?;

      // Update live stream status
      await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(widget.liveId)
          .update({
        'isLive': false,
        'endedAt': FieldValue.serverTimestamp(),
        'status': 'ended',
      });

      // Calculate duration
      final startTime = liveData?['startedAt'] as Timestamp?;
      final durationSeconds = startTime != null
          ? DateTime
          .now()
          .difference(startTime.toDate())
          .inSeconds
          : 0;

      // Save to history
      final historyData = {
        'live_id': widget.liveId,
        'UID': widget.userId,
        'host_name': widget.userName,
        'start_time': startTime,
        'end_time': FieldValue.serverTimestamp(),
        'title': liveData?['title'] ?? 'Live Stream',
        'status': 'ended',
        'viewer_count': liveData?['viewers'] ?? 0,
        'total_gift_value': liveData?['total_gift_value'] ?? 0,
        'live_replay_media_url': _recordingUrl,
        'all_recording_urls': _recordingUrls,
        'storage_bucket': _awsBucketName,
        'storage_region': _awsRegion,
        'uploaded_at': FieldValue.serverTimestamp(),
        'upload_status': _recordingUrl != null ? 'success' : 'failed',
        'recording_type': _usingFallback
            ? 'fallback_metadata'
            : 'zego_cloud_recording',
        'zego_task_id': _recordingTaskId,
        'recording_error': _recordingError,
        'duration_seconds': durationSeconds,
        'file_count': _recordingUrls.length,
        'recording_checked_at': FieldValue.serverTimestamp(),
        'final_check_attempts': _recordingCheckAttempts,
      };

      await FirebaseFirestore.instance
          .collection('live_history')
          .doc(widget.liveId)
          .set(historyData);

      print('✅ Live ended and recording saved to Firestore');
      print('🎯 Recording URL: $_recordingUrl');
      print('📁 Total files: ${_recordingUrls.length}');
      print('⏱️ Duration: $durationSeconds seconds');
    } catch (e) {
      print('❌ Error saving recording to Firestore: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}

// AWS S3 Upload Function
Future<String> uploadToS3Improved({
  String? content,
  Uint8List? fileBytes,
  required String accessKey,
  required String secretKey,
  required String bucket,
  required String region,
  required String objectKey,
  required String contentType,
}) async {
  try {
    final host = '$bucket.s3.$region.amazonaws.com';
    final url = Uri.https(host, objectKey);

    final Uint8List payload =
        fileBytes ?? Uint8List.fromList(utf8.encode(content!));

    final date = DateTime.now().toUtc();
    final isoDate = _formatAmzDate(date);
    final dateStamp = isoDate.substring(0, 8);

    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final payloadHash = sha256.convert(payload).toString();

    final canonicalHeaders =
        'host:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$isoDate\n';
    final signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest =
    '''
PUT
/${_uriEncode(objectKey, encodeSlash: false)}

$canonicalHeaders
$signedHeaders
$payloadHash''';

    final canonicalRequestHash = sha256
        .convert(utf8.encode(canonicalRequest))
        .toString();

    final stringToSign =
    '''
AWS4-HMAC-SHA256
$isoDate
$credentialScope
$canonicalRequestHash''';

    List<int> kSecret = utf8.encode('AWS4$secretKey');
    List<int> kDate = Hmac(
      sha256,
      kSecret,
    ).convert(utf8.encode(dateStamp)).bytes;
    List<int> kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    List<int> kService = Hmac(sha256, kRegion).convert(utf8.encode('s3')).bytes;
    List<int> kSigning = Hmac(
      sha256,
      kService,
    ).convert(utf8.encode('aws4_request')).bytes;

    final signature = Hmac(
      sha256,
      kSigning,
    ).convert(utf8.encode(stringToSign)).toString();

    final authorization =
        'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    print('🌐 Uploading to S3...');
    print('📦 Bucket: $bucket');
    print('📍 Region: $region');
    print('📁 Object Key: $objectKey');
    print('📄 Content Type: $contentType');
    print('📏 Payload Size: ${payload.length} bytes');

    final response = await http.put(
      url,
      headers: {
        'x-amz-date': isoDate,
        'x-amz-content-sha256': payloadHash,
        'Authorization': authorization,
        'Content-Type': contentType,
      },
      body: payload,
    );

    print('📡 S3 Upload Response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final fileUrl = 'https://$host/$objectKey';
      print('✅ File uploaded successfully: $fileUrl');
      return fileUrl;
    } else {
      print('❌ S3 Upload failed: ${response.body}');
      throw Exception(
        'S3 Upload failed with status ${response.statusCode}: ${response.body}',
      );
    }
  } catch (e) {
    print('❌ S3 Upload error: $e');
    rethrow;
  }
}

String _formatAmzDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  final second = date.second.toString().padLeft(2, '0');
  return '${year}${month}${day}T${hour}${minute}${second}Z';
}

String _uriEncode(String input, {bool encodeSlash = true}) {
  final encoded = StringBuffer();
  for (final codeUnit in input.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    if (_isUnreserved(char)) {
      encoded.write(char);
    } else if (char == '/' && !encodeSlash) {
      encoded.write(char);
    } else {
      encoded.write(
        '%${codeUnit.toRadixString(16).padLeft(2, '0').toUpperCase()}',
      );
    }
  }
  return encoded.toString();
}

bool _isUnreserved(String char) {
  return (char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90) ||
      (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122) ||
      (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) ||
      char == '-' ||
      char == '.' ||
      char == '_' ||
      char == '~';
}

// Gift Overlay Widget - UPDATED WITH BALANCE CHECKS
class _GiftOverlay extends StatelessWidget {
  final String liveId;
  final String userId;

  const _GiftOverlay({required this.liveId, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      right: 20,
      child: FloatingActionButton(
        onPressed: () => _showGiftDialog(context),
        child: const Icon(Icons.card_giftcard),
      ),
    );
  }

  void _showGiftDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send Gift',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Gifts are sent using diamonds',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _GiftItem(
                  icon: '🎁',
                  name: 'Rose',
                  diamonds: 10,
                  onTap: () => _sendGift(context, 'rose', 10),
                ),
                _GiftItem(
                  icon: '💝',
                  name: 'Love',
                  diamonds: 50,
                  onTap: () => _sendGift(context, 'love', 50),
                ),
                _GiftItem(
                  icon: '🚀',
                  name: 'Rocket',
                  diamonds: 100,
                  onTap: () => _sendGift(context, 'rocket', 100),
                ),
                _GiftItem(
                  icon: '👑',
                  name: 'Crown',
                  diamonds: 500,
                  onTap: () => _sendGift(context, 'crown', 500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendGift(
      BuildContext context,
      String giftType,
      int diamondCost,
      ) async {
    try {
      // Check diamond balance using UserService helper method
      final hasEnough = await _checkDiamondBalance(userId, diamondCost);

      if (!hasEnough) {
        final currentDiamonds = await _getCurrentDiamondBalance(userId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough diamonds! You need $diamondCost diamonds but only have $currentDiamonds.',
            ),
          ),
        );
        return;
      }

      // Get the host's user ID from the live stream
      final liveDoc = await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(liveId)
          .get();
      final hostUserId = liveDoc.data()?['hostId'] ?? '';

      if (hostUserId.isEmpty) {
        throw Exception('Host user ID not found');
      }

      final coinValue = diamondCost * 10; // 1 diamond = 10 coins

      // Use the UserService to process the gift transaction
      await UserService.processGiftTransaction(
        senderId: userId,
        receiverId: hostUserId,
        giftType: giftType,
        diamondCost: diamondCost,
        coinValue: coinValue,
      );

      // Update live stream gift total (in coins)
      await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(liveId)
          .update({'total_gift_value': FieldValue.increment(coinValue)});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent $giftType gift worth $diamondCost diamonds!'),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send gift: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _checkDiamondBalance(String userId, int requiredDiamonds) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final currentDiamonds = (userData?['wallet']?['diamond_balance'] as int?) ?? 0;
        return currentDiamonds >= requiredDiamonds;
      }
      return false;
    } catch (e) {
      print('❌ Error checking diamond balance: $e');
      return false;
    }
  }

  Future<int> _getCurrentDiamondBalance(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        return (userData?['wallet']?['diamond_balance'] as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ Error getting diamond balance: $e');
      return 0;
    }
  }
}

class _GiftItem extends StatelessWidget {
  final String icon;
  final String name;
  final int diamonds;
  final VoidCallback onTap;

  const _GiftItem({
    required this.icon,
    required this.name,
    required this.diamonds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 30)),
            Text(name),
            Text(
              '$diamonds 💎',
              style: const TextStyle(color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}