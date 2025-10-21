import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

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

  @override
  void initState() {
    super.initState();
    _updateViewerCount();
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

          if (!widget.isHost)
            _GiftOverlay(
              liveId: widget.liveId,
              userId: widget.userId,
            ),
        ],
      ),
    );
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
      await _endLiveStream();
    }

    defaultHandle();
  }

  Future<void> _endLiveStream() async {
    try {
      // First update live stream status
      await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(widget.liveId)
          .update({
        'isLive': false,
        'endedAt': FieldValue.serverTimestamp(),
        'status': 'ended',
      });

      // Try to upload recording to S3, but don't fail the whole process if it fails
      String s3Url = 'https://$_awsBucketName.s3.$_awsRegion.amazonaws.com/fallback_${widget.liveId}.txt';

      try {
        s3Url = await _createAndUploadRecording();
        print('✅ Recording uploaded to S3: $s3Url');
      } catch (e) {
        print('⚠️ S3 upload failed, using fallback URL: $e');
        // Continue with fallback URL
      }

      // Create live history record
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
        'upload_status': s3Url.contains('fallback') ? 'failed' : 'success',
      });

      print('✅ Live stream ended successfully');
    } catch (e) {
      print('❌ Error ending live stream: $e');
    }
  }

  // 🆕 Improved recording upload with better error handling
  Future<String> _createAndUploadRecording() async {
    try {
      // Create a simple recording metadata
      final String recordingContent = '''
Live Stream Recording Metadata
Live ID: ${widget.liveId}
Host: ${widget.userName} (${widget.userId})
Date: ${DateTime.now().toIso8601String()}
Viewers: ${await _getCurrentViewerCount()}
Status: Completed
''';

      final String fileName = 'recordings/${widget.liveId}_${DateTime.now().millisecondsSinceEpoch}.txt';

      // Use the improved S3 upload function
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
    } catch (e) {
      print('❌ Error in createAndUploadRecording: $e');
      rethrow;
    }
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
}

// 🆕 IMPROVED AWS S3 UPLOAD FUNCTION
Future<String> uploadToS3Improved({
  required String content,
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
    final payload = utf8.encode(content);

    final date = DateTime.now().toUtc();
    final isoDate = _formatAmzDate(date);
    final dateStamp = isoDate.substring(0, 8);

    print('🔧 S3 Upload Debug:');
    print('  - Host: $host');
    print('  - Object Key: $objectKey');
    print('  - Date: $isoDate');

    // --- Create AWS signature (V4 signing) ---
    final credentialScope = '$dateStamp/$region/s3/aws4_request';

    // Use actual payload hash instead of UNSIGNED-PAYLOAD for better security
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
    print('  - Authorization: ${authorization.substring(0, 50)}...');

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

// 🆕 Test function to verify S3 credentials and permissions
Future<void> testS3Connection() async {
  final accessKey = 'AKIAZ44G2F7RDNUFZT6U';
  final secretKey = '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';
  final bucket = 'meet9ja-recordings';
  final region = 'eu-north-1';

  try {
    print('🧪 Testing S3 connection...');

    final testContent = 'S3 Connection Test - ${DateTime.now().toIso8601String()}';
    final testKey = 'test-connection-${DateTime.now().millisecondsSinceEpoch}.txt';

    final result = await uploadToS3Improved(
      content: testContent,
      accessKey: accessKey,
      secretKey: secretKey,
      bucket: bucket,
      region: region,
      objectKey: testKey,
      contentType: 'text/plain',
    );

    print('✅ S3 Connection Test PASSED: $result');
  } catch (e) {
    print('❌ S3 Connection Test FAILED: $e');
  }
}

// Gift Overlay Widget (unchanged)
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