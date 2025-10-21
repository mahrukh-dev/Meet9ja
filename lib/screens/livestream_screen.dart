import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

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
  // AWS S3 Configuration
  final String _awsBucketName = 'meet9ja-recordings';
  final String _awsRegion = 'eu-north-1';
  final String _awsAccessKey = 'AKIAZ44G2F7RDNUFZT6U';
  final String _awsSecretKey = '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';

  // Camera recording state
  CameraController? _cameraController;
  bool _isRecording = false;
  String? _recordingFilePath;
  bool _isCameraInitialized = false;
  bool _isUploading = false;
  bool _permissionsChecked = false;

  // Performance optimization
  ResolutionPreset _resolutionPreset = ResolutionPreset.medium;

  @override
  void initState() {
    super.initState();
    _updateViewerCount();
    if (widget.isHost) {
      Future.delayed(const Duration(seconds: 2), () {
        _initializeCamera();
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      // Check permissions first without requesting
      final hasPermissions = await _checkPermissions();

      if (!hasPermissions) {
        print('⚠️ Camera permissions not granted, skipping recording');
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('❌ No cameras available');
        return;
      }

      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        _resolutionPreset,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize().then((_) {
        setState(() {
          _isCameraInitialized = true;
        });
        print('✅ Camera initialized with ${_resolutionPreset.name}');

        Future.delayed(const Duration(seconds: 1), _startRecording);
      }).catchError((e) {
        print('❌ Camera initialization failed: $e');
        _tryLowerResolution();
      });

    } catch (e) {
      print('❌ Error initializing camera: $e');
      _tryLowerResolution();
    }
  }

  Future<bool> _checkPermissions() async {
    try {
      // Check current permission status without requesting
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;
      final storageStatus = await Permission.storage.status;

      print('🔍 Permission Status - Camera: $cameraStatus, Microphone: $microphoneStatus, Storage: $storageStatus');

      // If permissions are permanently denied, don't proceed
      if (cameraStatus.isPermanentlyDenied || microphoneStatus.isPermanentlyDenied) {
        print('❌ Camera or microphone permissions permanently denied');
        return false;
      }

      // If permissions are denied (but not permanently), request them
      if (!cameraStatus.isGranted || !microphoneStatus.isGranted) {
        print('🔄 Requesting camera and microphone permissions...');
        final cameraResult = await Permission.camera.request();
        final microphoneResult = await Permission.microphone.request();

        if (!cameraResult.isGranted || !microphoneResult.isGranted) {
          print('❌ Camera or microphone permission not granted after request');
          return false;
        }
      }

      // Storage permission is less critical, but nice to have
      if (!storageStatus.isGranted && !storageStatus.isPermanentlyDenied) {
        await Permission.storage.request();
      }

      setState(() {
        _permissionsChecked = true;
      });

      return cameraStatus.isGranted && microphoneStatus.isGranted;

    } catch (e) {
      print('❌ Error checking permissions: $e');
      return false;
    }
  }

  Future<void> _tryLowerResolution() async {
    try {
      if (_resolutionPreset != ResolutionPreset.low) {
        _resolutionPreset = ResolutionPreset.low;
        print('🔄 Trying lower resolution: ${_resolutionPreset.name}');
        await _initializeCamera();
      }
    } catch (e) {
      print('❌ Failed to initialize with low resolution: $e');
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

  Future<void> _startRecording() async {
    if (!widget.isHost || !_isCameraInitialized || _isRecording) return;

    try {
      final directory = await getTemporaryDirectory();
      final fileName = '${widget.liveId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      _recordingFilePath = '${directory.path}/$fileName';

      print('🎥 Starting recording: $_recordingFilePath');

      await _cameraController!.startVideoRecording();

      setState(() {
        _isRecording = true;
      });

      print('✅ Recording started successfully');

    } catch (e) {
      print('❌ Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      print('🛑 Stopping recording...');

      final XFile videoFile = await _cameraController!.stopVideoRecording();

      // Copy file to desired location
      final File originalFile = File(videoFile.path);
      final File destinationFile = File(_recordingFilePath!);

      await originalFile.copy(destinationFile.path);
      await originalFile.delete();

      setState(() {
        _isRecording = false;
      });

      final fileSize = await destinationFile.length();

      print('✅ Recording stopped');
      print('📁 File: ${destinationFile.path}');
      print('📊 Size: $fileSize bytes');

    } catch (e) {
      print('❌ Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Zego UI Kit
          ZegoUIKitPrebuiltLiveStreaming(
            appID: 51745598,
            appSign: '5bfa67bea457bf8b27014d411711518683ef0465f4a09f64832ea8d56e92e7a4',
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

          // Hidden camera preview
          if (widget.isHost && _isCameraInitialized)
            Positioned(
              top: -1000,
              left: -1000,
              child: Opacity(
                opacity: 0.0,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: CameraPreview(_cameraController!),
                ),
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

  Widget _buildStatusIndicators() {
    return Positioned(
      top: 50,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recording indicator
          if (_isRecording)
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
                    'REC',
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

          // Camera status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _getStatusText(),
          ),

          // Upload status
          if (_isUploading)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Uploading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Text _getStatusText() {
    if (!_permissionsChecked) {
      return const Text(
        'Checking permissions...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      );
    } else if (_isRecording) {
      return const Text(
        'Recording...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      );
    } else if (_isCameraInitialized) {
      return const Text(
        'Camera Ready',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      );
    } else {
      return const Text(
        'Camera Unavailable',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      );
    }
  }

  Future<void> _onLeaveLiveStreaming(VoidCallback defaultHandle) async {
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
      await _stopRecording();
      await _uploadRecordingAndEndLive();
    }

    defaultHandle();
  }
  // Add upload progress tracking
  Future<void> _uploadWithProgress(String s3Url, Uint8List data) async {
    try {
      final request = http.MultipartRequest('PUT', Uri.parse(s3Url));
      request.headers['Content-Type'] = 'video/mp4';

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        data,
        filename: 'recording.mp4',
      );

      request.files.add(multipartFile);

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        print('✅ Upload completed successfully');
      } else {
        throw Exception('Upload failed with status: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }

  Future<void> _uploadRecordingAndEndLive() async {
    if (!widget.isHost) return;

    setState(() {
      _isUploading = true;
    });

    try {
      String s3Url = 'https://$_awsBucketName.s3.$_awsRegion.amazonaws.com/fallback_${widget.liveId}.mp4';
      String uploadStatus = 'failed';
      String recordingType = 'metadata_only';

      // Try to upload actual video
      if (_recordingFilePath != null && File(_recordingFilePath!).existsSync()) {
        try {
          s3Url = await _uploadVideoRecordingToS3();
          uploadStatus = 'success';
          recordingType = 'video';
        } catch (e) {
          print('⚠️ Video upload failed: $e');
          // Fallback to metadata
          try {
            s3Url = await _createAndUploadRecordingMetadata();
            uploadStatus = 'partial_success';
            recordingType = 'metadata_fallback';
          } catch (e2) {
            print('⚠️ Metadata upload failed: $e2');
          }
        }
      } else {
        // Upload metadata only
        try {
          s3Url = await _createAndUploadRecordingMetadata();
          uploadStatus = 'success';
          recordingType = 'metadata_only';
        } catch (e) {
          print('⚠️ Metadata upload failed: $e');
        }
      }

      await _endLiveStream(s3Url, uploadStatus, recordingType);

    } catch (e) {
      print('❌ Error in upload process: $e');
      await _endLiveStream(
          'https://$_awsBucketName.s3.$_awsRegion.amazonaws.com/error_${widget.liveId}.txt',
          'error',
          'error'
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<String> _uploadVideoRecordingToS3() async {
    if (_recordingFilePath == null) {
      throw Exception('No recording file path');
    }

    final File videoFile = File(_recordingFilePath!);
    if (!await videoFile.exists()) {
      throw Exception('Recording file not found');
    }

    final String fileName = 'videos/${widget.liveId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final Uint8List videoBytes = await videoFile.readAsBytes();

    print('📤 Uploading video (${videoBytes.length} bytes) to S3...');


    final String s3Url = await uploadToS3Improved(
      fileBytes: videoBytes,
      accessKey: _awsAccessKey,
      secretKey: _awsSecretKey,
      bucket: _awsBucketName,
      region: _awsRegion,
      objectKey: fileName,
      contentType: 'video/mp4',
    );


    await videoFile.delete();
    print('🧹 Local file cleaned up');

    return s3Url;
  }

  Future<String> _createAndUploadRecordingMetadata() async {
    final String recordingContent = '''
LIVE_STREAM_METADATA
Live ID: ${widget.liveId}
Host: ${widget.userName}
Host ID: ${widget.userId}
Start Time: ${DateTime.now().toIso8601String()}
End Time: ${DateTime.now().toIso8601String()}
Viewers: ${await _getCurrentViewerCount()}
Status: COMPLETED
Recording Type: CAMERA_RECORDING
Total Gifts Value: ${await _getTotalGiftValue()}
Duration: ${_calculateDuration(await _getStartTime())} seconds
Note: Camera recording completed
METADATA_END
''';

    final String fileName = 'metadata/${widget.liveId}_${DateTime.now().millisecondsSinceEpoch}.txt';

    final String s3Url = await uploadToS3Improved(
      content: recordingContent,
      accessKey: _awsAccessKey,
      secretKey: _awsSecretKey,
      bucket: _awsBucketName,
      region: _awsRegion,
      objectKey: fileName,
      contentType: 'text/plain',
    );

    return s3Url;
  }

  Future<void> _endLiveStream(String s3Url, String uploadStatus, String recordingType) async {
    try {
      await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(widget.liveId)
          .update({
        'isLive': false,
        'endedAt': FieldValue.serverTimestamp(),
        'status': 'ended',
      });

      final liveDoc = await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(widget.liveId)
          .get();

      final liveData = liveDoc.data() as Map<String, dynamic>?;

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
        'live_replay_media_url': s3Url,
        'storage_bucket': _awsBucketName,
        'storage_region': _awsRegion,
        'uploaded_at': FieldValue.serverTimestamp(),
        'upload_status': uploadStatus,
        'recording_type': recordingType,
        'duration_seconds': _calculateDuration(liveData?['startedAt']),
      });

      print('✅ Live ended - Status: $uploadStatus, Type: $recordingType');

    } catch (e) {
      print('❌ Error ending live stream: $e');
    }
  }

  int _calculateDuration(Timestamp? startTime) {
    if (startTime == null) return 0;
    return DateTime.now().difference(startTime.toDate()).inSeconds;
  }

  Future<int> _getCurrentViewerCount() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(widget.liveId)
          .get();
      return (doc.data()?['viewers'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getTotalGiftValue() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(widget.liveId)
          .get();
      return (doc.data()?['total_gift_value'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<Timestamp?> _getStartTime() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(widget.liveId)
          .get();
      return doc.data()?['startedAt'] as Timestamp?;
    } catch (e) {
      return null;
    }
  }


// Keep the existing AWS S3 upload functions and gift overlay widgets...
}

// AWS S3 Upload Function (keep the same as before)
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

    // Determine payload based on input
    final Uint8List payload = fileBytes ?? Uint8List.fromList(utf8.encode(content!));

    final date = DateTime.now().toUtc();
    final isoDate = _formatAmzDate(date);
    final dateStamp = isoDate.substring(0, 8);

    print('🔧 S3 Upload Debug:');
    print('  - Host: $host');
    print('  - Object Key: $objectKey');
    print('  - Content Type: $contentType');
    print('  - File Size: ${payload.length} bytes');
    print('  - Upload Type: ${fileBytes != null ? 'Binary' : 'Text'}');

    // --- Create AWS signature (V4 signing) ---
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

    print('  - Canonical Request Hash: $canonicalRequestHash');

    // Derive signing key
    List<int> kSecret = utf8.encode('AWS4$secretKey');
    List<int> kDate = Hmac(sha256, kSecret).convert(utf8.encode(dateStamp)).bytes;
    List<int> kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    List<int> kService = Hmac(sha256, kRegion).convert(utf8.encode('s3')).bytes;
    List<int> kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;

    final signature = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

    final authorization = 'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    print('  - Signature: ${signature.substring(0, 16)}...');

    // --- Send the request ---
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

    print('  - Response Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      print('✅ Upload successful: $url');
      return 'https://$host/$objectKey';
    } else {
      print('❌ Upload failed: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('S3 Upload failed with status ${response.statusCode}: ${response.body}');
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
      encoded.write('%${codeUnit.toRadixString(16).padLeft(2, '0').toUpperCase()}');
    }
  }
  return encoded.toString();
}

bool _isUnreserved(String char) {
  return (char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90) || // A-Z
      (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122) || // a-z
      (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) || // 0-9
      char == '-' ||
      char == '.' ||
      char == '_' ||
      char == '~';
}

// Gift Overlay Widget (keep the same as before)
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
      print('❌ Error sending gift: $e');
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


