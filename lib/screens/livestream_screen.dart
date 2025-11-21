import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';


class ZegoRecordingService {
  static const String _baseUrl = 'https://cloudrecord-api.zego.im';
  static const String _signatureVersion = '2.0';

  static Future<Map<String, dynamic>> startRecording({
    required int appId,
    required String serverSecret,
    required String roomId,
    required String userId,
  }) async {
    try {
      await _checkNetworkConnectivity();

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateNonce();

      final signature = _generateSignatureV2(
        appId: appId,
        serverSecret: serverSecret,
        timestamp: timestamp,
        nonce: nonce,
      );

      final queryParams = {
        'Action': 'StartRecord',
        'AppId': appId.toString(),
        'SignatureNonce': nonce,
        'Timestamp': timestamp,
        'SignatureVersion': _signatureVersion,
        'Signature': signature,
      };

      final Map<String, dynamic> requestBody = {
        "RoomId": roomId,
        "RecordInputParams": {
          "RecordMode": 1,
          "StreamType": 3,
          "MaxIdleTime": 60,
          "RecordStreamList": [
            {
              "StreamId": "${userId}_main"
            }
          ],
        },
        "RecordOutputParams": {
          "OutputFileFormat": "mp4",
          "OutputFolder": "zego_recordings/",
        },
        "StorageParams": {
          "Vendor": 1,
          "Region": "eu-north-1",
          "Bucket": "meet9ja-recordings",
          "AccessKeyId": "AKIAZ44G2F7RDNUFZT6U",
          "AccessKeySecret": "G1HnXmP+BIZzNRJhUlcFI1sXHMTsDTQLSWGPJoep",
        }
      };

      print('🌐 Sending recording start request to Zego...');

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['Code'] == 0) {
          print('✅ Zego Cloud Recording started successfully');
          return result;
        } else {
          throw Exception('Zego API error: Code ${result['Code']} - ${result['Message']}');
        }
      } else {
        throw HttpException('HTTP ${response.statusCode}: ${response.body}');
      }
    } on SocketException catch (e) {
      throw Exception('Network error: Cannot connect to Zego servers. Details: $e');
    } catch (e) {
      throw Exception('Recording start error: $e');
    }
  }

  static Future<Map<String, dynamic>> stopRecording({
    required int appId,
    required String serverSecret,
    required String roomId,
  }) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateNonce();

      final signature = _generateSignatureV2(
        appId: appId,
        serverSecret: serverSecret,
        timestamp: timestamp,
        nonce: nonce,
      );

      final queryParams = {
        'Action': 'StopRecord',
        'AppId': appId.toString(),
        'SignatureNonce': nonce,
        'Timestamp': timestamp,
        'SignatureVersion': _signatureVersion,
        'Signature': signature,
      };

      final Map<String, dynamic> requestBody = {
        "RoomId": roomId,
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Recording stop error: $e');
    }
  }

  static Future<Map<String, dynamic>> queryRecordingStatus({
    required int appId,
    required String serverSecret,
    required String roomId,
  }) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateNonce();

      final signature = _generateSignatureV2(
        appId: appId,
        serverSecret: serverSecret,
        timestamp: timestamp,
        nonce: nonce,
      );

      final queryParams = {
        'Action': 'QueryRecord',
        'AppId': appId.toString(),
        'SignatureNonce': nonce,
        'Timestamp': timestamp,
        'SignatureVersion': _signatureVersion,
        'Signature': signature,
      };

      final Map<String, dynamic> requestBody = {
        "RoomId": roomId,
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Recording query error: $e');
    }
  }

  static String _generateNonce() {
    return 'm8pb55tp79n${DateTime.now().millisecondsSinceEpoch}';
  }

  static String _generateSignatureV2({
    required int appId,
    required String serverSecret,
    required String timestamp,
    required String nonce,
  }) {
    try {
      final payload = '$appId$timestamp$nonce';
      final key = utf8.encode(serverSecret);
      final bytes = utf8.encode(payload);
      final hmac = Hmac(sha256, key);
      final digest = hmac.convert(bytes);
      return digest.toString();
    } catch (e) {
      throw Exception('Signature generation error: $e');
    }
  }

  static Future<void> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('cloudrecord-api.zego.im')
          .timeout(const Duration(seconds: 10));

      if (result.isEmpty) {
        throw SocketException('No addresses found for cloudrecord-api.zego.im');
      }
    } on SocketException catch (e) {
      throw SocketException('Cannot resolve Zego server address. Details: $e');
    }
  }
}

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

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  // Zego Configuration
  final int _zegoAppId = 51745598;
  final String _zegoServerSecret = 'd47d53d464da3b6ff8a8141dcb4e8b3b';
  final String _zegoAppSign = '5bfa67bea457bf8b27014d411711518683ef0465f4a09f64832ea8d56e92e7a4';

  // AWS S3 Configuration
  final String _awsBucketName = 'meet9ja-recordings';
  final String _awsRegion = 'eu-north-1';
  final String _awsAccessKey = 'AKIAZ44G2F7RDNUFZT6U';
  final String _awsSecretKey = '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';

  // Recording state
  bool _isRecording = false;
  bool _isUploading = false;
  String? _recordingUrl;
  List<String> _recordingUrls = [];
  String? _recordingError;
  String? _recordingTaskId;
  bool _usingFallback = false;
  bool _zegoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeZego();
    _updateViewerCount();
  }

  void _initializeZego() {
    // Zego UIKit should be initialized automatically, but we set a flag
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _zegoInitialized = true;
      });

      if (widget.isHost) {
        // Wait for Zego to fully initialize before starting recording
        Future.delayed(const Duration(seconds: 3), () {
          _startZegoRecordingWithRetry();
        });
      }
    });
  }

  Future<void> _startZegoRecordingWithRetry() async {
    if (!widget.isHost || !_zegoInitialized) return;

    print('🎥 Attempting to start Zego Cloud Recording...');
    print('✅ Zego initialized: $_zegoInitialized');
    print('👤 Is host: ${widget.isHost}');

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await _startZegoRecording();
        return;
      } catch (e) {
        _recordingError = e.toString();
        print('❌ Recording attempt $attempt failed: $e');

        if (attempt < 3) {
          final delay = Duration(seconds: attempt * 3);
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
      );

      if (result['Code'] == 0) {
        setState(() {
          _isRecording = true;
          _recordingError = null;
          _usingFallback = false;
          _recordingTaskId = result['Data']?['TaskId']?.toString();
        });
        print('✅ Zego Cloud Recording started successfully. Task ID: $_recordingTaskId');
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
    if (!_isRecording || _usingFallback) return;

    try {
      print('🛑 Stopping Zego recording...');

      final result = await ZegoRecordingService.stopRecording(
        appId: _zegoAppId,
        serverSecret: _zegoServerSecret,
        roomId: widget.liveId,
      );

      if (result['Code'] == 0) {
        setState(() {
          _isRecording = false;
        });
        print('✅ Zego recording stopped successfully');

        // Wait for recording to be processed
        await Future.delayed(const Duration(seconds: 10));
        await _getRecordingUrl();
      } else {
        throw Exception('Stop recording failed: ${result['Message']}');
      }
    } catch (e) {
      print('❌ Error stopping Zego recording: $e');
      _handleRecordingFallback('Failed to stop Zego recording: $e');
    }
  }

  void _startRecordingStatusPolling() {
    if (!_isRecording || _usingFallback) return;

    Future.delayed(const Duration(seconds: 30), () {
      _queryRecordingStatus();
      _startRecordingStatusPolling();
    });
  }

  Future<void> _queryRecordingStatus() async {
    if (!_isRecording || _usingFallback) return;

    try {
      final status = await ZegoRecordingService.queryRecordingStatus(
        appId: _zegoAppId,
        serverSecret: _zegoServerSecret,
        roomId: widget.liveId,
      );

      print('📊 Recording status: ${status['Code']}');

      if (status['Code'] == 0 && status['Data'] != null) {
        final recordingData = status['Data'];
        final files = recordingData['FileList'] as List<dynamic>?;

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
          }
        }
      }
    } catch (e) {
      print('❌ Error querying recording status: $e');
    }
  }

  Future<void> _getRecordingUrl() async {
    try {
      print('🔍 Querying for final recording URL...');

      for (int attempt = 1; attempt <= 5; attempt++) {
        print('🔄 Attempt $attempt to get recording URL...');

        await Future.delayed(const Duration(seconds: 5));

        final status = await ZegoRecordingService.queryRecordingStatus(
          appId: _zegoAppId,
          serverSecret: _zegoServerSecret,
          roomId: widget.liveId,
        );

        if (status['Code'] == 0 && status['Data'] != null) {
          final recordingData = status['Data'];
          final files = recordingData['FileList'] as List<dynamic>?;

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
              print('✅ Final recording URLs obtained: ${urls.length} files');
              return;
            }
          }
        }
      }

      _handleRecordingFallback('No recording URLs found after multiple attempts');
    } catch (e) {
      print('❌ Error getting recording URL: $e');
      _handleRecordingFallback('Error getting recording URL: $e');
    }
  }

  Future<void> _handleRecordingFallback(String error) async {
    print('🔄 Using fallback recording method: $error');

    try {
      final String recordingContent = '''
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

      final String fileName = 'fallback_recordings/${widget.liveId}_${DateTime.now().millisecondsSinceEpoch}.txt';

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
      _recordingUrl = 'https://$_awsBucketName.s3.$_awsRegion.amazonaws.com/error_${widget.liveId}.txt';
    }
  }

  void _updateViewerCount() async {
    if (!widget.isHost) {
      try {
        await FirebaseFirestore.instance
            .collection('liveStreams')
            .doc(widget.liveId)
            .update({
          'viewers': FieldValue.increment(1),
        });
      } catch (e) {
        print('Error updating viewer count: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              onEnded: (ZegoLiveStreamingEndEvent event, VoidCallback defaultHandle) {
                _onLeaveLiveStreaming(defaultHandle);
              },

            ),
          ),

          // Status indicators
          if (widget.isHost) _buildStatusIndicators(),

          // Gift overlay for audience
          if (!widget.isHost)
            _GiftOverlay(
              liveId: widget.liveId,
              userId: widget.userId,
            ),
        ],
      ),
    );
  }

  void _handleZegoError(int code, String message) {
    print('🎯 Handling Zego error: $code - $message');

    switch (code) {
      case 1000001:
        print('⚠️ Engine not initialized');
        break;
      case 1000002:
        print('⚠️ Not logged in to room');
        break;
      case 1000003:
        print('⚠️ Audio/video module not started');
        break;
      default:
        print('⚠️ Unknown Zego error: $code');
    }

    // If we're the host and get initialization errors, use fallback recording
    if (widget.isHost && code >= 1000001 && code <= 1000003) {
      _handleRecordingFallback('Zego initialization error: $code - $message');
    }
  }

  Widget _buildStatusIndicators() {
    return Positioned(
      top: 60,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zego initialization status
          if (!_zegoInitialized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Initializing Zego...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Recording indicator
          if (_isRecording && !_usingFallback)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'RECORDING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (_usingFallback)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.white, size: 12),
                  SizedBox(width: 6),
                  Text(
                    'FALLBACK MODE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Status message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusMessage(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),

          // Task ID
          if (_recordingTaskId != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Task: ${_recordingTaskId!.substring(0, 8)}...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusMessage() {
    if (!_zegoInitialized) return 'Initializing...';
    if (_usingFallback) return 'Fallback Recording';
    if (_isRecording) return 'Recording...';
    if (_recordingUrl != null) return 'Recording Ready';
    return 'Ready';
  }

  Future<void> _onLeaveLiveStreaming(VoidCallback defaultHandle) async {
    print('🚪 Leaving live stream...');

    if (!widget.isHost) {
      try {
        await FirebaseFirestore.instance
            .collection('liveStreams')
            .doc(widget.liveId)
            .update({
          'viewers': FieldValue.increment(-1),
        });
      } catch (e) {
        print('Error decrementing viewer count: $e');
      }
    } else {
      print('🛑 Host is leaving - handling recording...');
      if (!_usingFallback) {
        await _stopZegoRecording();
      }
      await _saveRecordingToFirestore();
    }

    defaultHandle();
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

      // Save to history
      await FirebaseFirestore.instance
          .collection('live_history')
          .doc(widget.liveId)
          .set({
        'live_id': widget.liveId,
        'UID': widget.userId,
        'host_name': widget.userName,
        'start_time': liveData?['startedAt'],
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
        'recording_type': _usingFallback ? 'fallback_metadata' : 'zego_cloud_recording',
        'zego_task_id': _recordingTaskId,
        'recording_error': _recordingError,
        'duration_seconds': _calculateDuration(liveData?['startedAt']),
        'file_count': _recordingUrls.length,
      });

      print('✅ Live ended and recording saved to Firestore');
      print('🎯 Recording URL: $_recordingUrl');

    } catch (e) {
      print('❌ Error saving recording to Firestore: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  int _calculateDuration(Timestamp? startTime) {
    if (startTime == null) return 0;
    return DateTime.now().difference(startTime.toDate()).inSeconds;
  }
}

// AWS S3 Upload Function (same as before)
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

    final Uint8List payload = fileBytes ?? Uint8List.fromList(utf8.encode(content!));

    final date = DateTime.now().toUtc();
    final isoDate = _formatAmzDate(date);
    final dateStamp = isoDate.substring(0, 8);

    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final payloadHash = sha256.convert(payload).toString();

    final canonicalHeaders = 'host:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$isoDate\n';
    final signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest = '''
PUT
/${_uriEncode(objectKey, encodeSlash: false)}

$canonicalHeaders
$signedHeaders
$payloadHash''';

    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

    final stringToSign = '''
AWS4-HMAC-SHA256
$isoDate
$credentialScope
$canonicalRequestHash''';

    List<int> kSecret = utf8.encode('AWS4$secretKey');
    List<int> kDate = Hmac(sha256, kSecret).convert(utf8.encode(dateStamp)).bytes;
    List<int> kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    List<int> kService = Hmac(sha256, kRegion).convert(utf8.encode('s3')).bytes;
    List<int> kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;

    final signature = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

    final authorization = 'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

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

    if (response.statusCode == 200) {
      return 'https://$host/$objectKey';
    } else {
      throw Exception('S3 Upload failed with status ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
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
      encoded.write('%${codeUnit.toRadixString(16).padLeft(2, '0').toUpperCase()}');
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

// Gift Overlay Widget (same as before)
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
            const Text('Send Gift', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _GiftItem(icon: '🎁', name: 'Rose', coins: 10, onTap: () => _sendGift(context, 'rose', 10)),
                _GiftItem(icon: '💝', name: 'Love', coins: 50, onTap: () => _sendGift(context, 'love', 50)),
                _GiftItem(icon: '🚀', name: 'Rocket', coins: 100, onTap: () => _sendGift(context, 'rocket', 100)),
                _GiftItem(icon: '👑', name: 'Crown', coins: 500, onTap: () => _sendGift(context, 'crown', 500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendGift(BuildContext context, String giftType, int coins) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>?;
      final currentBalance = (userData?['wallet']?['coin_balance'] as int?) ?? 0;

      if (currentBalance < coins) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not enough coins! You need $coins but have $currentBalance')),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      batch.update(FirebaseFirestore.instance.collection('users').doc(userId), {
        'wallet.coin_balance': FieldValue.increment(-coins),
      });

      batch.set(
        FirebaseFirestore.instance.collection('transactions').doc('${DateTime.now().millisecondsSinceEpoch}_$userId'),
        {
          'transaction_id': '${DateTime.now().millisecondsSinceEpoch}_$userId',
          'type': 'gift',
          'UID': userId,
          'amount': coins,
          'date_time': FieldValue.serverTimestamp(),
          'given_live': liveId,
          'gift_type': giftType,
        },
      );

      batch.update(FirebaseFirestore.instance.collection('liveStreams').doc(liveId), {
        'total_gift_value': FieldValue.increment(coins),
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent $giftType gift!')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send gift: $e')),
      );
    }
  }
}

class _GiftItem extends StatelessWidget {
  final String icon;
  final String name;
  final int coins;
  final VoidCallback onTap;

  const _GiftItem({
    required this.icon,
    required this.name,
    required this.coins,
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
            Text('$coins coins', style: const TextStyle(color: Colors.orange)),
          ],
        ),
      ),
    );
  }
}