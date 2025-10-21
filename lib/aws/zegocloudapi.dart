// zego_cloud_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class ZegoCloudService {
  final int appId;
  final String serverSecret;
  final bool isTest;

  ZegoCloudService({
    required this.appId,
    required this.serverSecret,
    this.isTest = false,
  });

  // 🆕 Start Cloud Recording
  Future<Map<String, dynamic>> startRecording({
    required String roomId,
    required String bucket,
    required String region,
    required String accessKeyId,
    required String accessKeySecret,
    int recordMode = 2, // 1: single-stream, 2: mixed-stream
    int streamType = 3, // 3: combined audio and video
    int maxIdleTime = 60,
    int maxRecordTime = 7200, // 2 hours
    String outputFileFormat = 'mp4',
    String outputFolder = 'recordings/',
    int vendor = 1, // 1: Amazon S3
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signatureNonce = DateTime.now().millisecondsSinceEpoch.toString();

    // Generate signature
    final signature = _generateSignature(
      action: 'StartRecord',
      timestamp: timestamp,
      signatureNonce: signatureNonce,
    );

    final url = Uri.https(
      'cloudrecord-api.zego.im',
      '',
      {
        'Action': 'StartRecord',
        'AppId': appId.toString(),
        'SignatureNonce': signatureNonce,
        'Timestamp': timestamp.toString(),
        'Signature': signature,
        'SignatureVersion': '2.0',
        'IsTest': isTest.toString(),
      },
    );

    final requestBody = {
      'RoomId': roomId,
      'RecordInputParams': {
        'RecordMode': recordMode,
        'StreamType': streamType,
        'MaxIdleTime': maxIdleTime,
        'MaxRecordTime': maxRecordTime,
        'FillBlank': true,
        'RecordMuteAudio': 1,
      },
      'RecordOutputParams': {
        'OutputFileFormat': outputFileFormat,
        'OutputFolder': outputFolder,
        'OutputFileRule': 1,
        'FragmentSeconds': 30,
      },
      'StorageParams': {
        'Vendor': vendor,
        'Region': region,
        'Bucket': bucket,
        'AccessKeyId': accessKeyId,
        'AccessKeySecret': accessKeySecret,
      },
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  // 🆕 Stop Cloud Recording
  Future<Map<String, dynamic>> stopRecording({
    required String roomId,
    required String taskId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signatureNonce = DateTime.now().millisecondsSinceEpoch.toString();

    final signature = _generateSignature(
      action: 'StopRecord',
      timestamp: timestamp,
      signatureNonce: signatureNonce,
    );

    final url = Uri.https(
      'cloudrecord-api.zego.im',
      '',
      {
        'Action': 'StopRecord',
        'AppId': appId.toString(),
        'SignatureNonce': signatureNonce,
        'Timestamp': timestamp.toString(),
        'Signature': signature,
        'SignatureVersion': '2.0',
        'IsTest': isTest.toString(),
      },
    );

    final requestBody = {
      'RoomId': roomId,
      'TaskId': taskId,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  // 🆕 Query Recording Task
  Future<Map<String, dynamic>> queryRecording({
    required String roomId,
    required String taskId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signatureNonce = DateTime.now().millisecondsSinceEpoch.toString();

    final signature = _generateSignature(
      action: 'QueryRecord',
      timestamp: timestamp,
      signatureNonce: signatureNonce,
    );

    final url = Uri.https(
      'cloudrecord-api.zego.im',
      '',
      {
        'Action': 'QueryRecord',
        'AppId': appId.toString(),
        'SignatureNonce': signatureNonce,
        'Timestamp': timestamp.toString(),
        'Signature': signature,
        'SignatureVersion': '2.0',
        'IsTest': isTest.toString(),
      },
    );

    final requestBody = {
      'RoomId': roomId,
      'TaskId': taskId,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to query recording: $e');
    }
  }

  // 🔐 Generate Signature for ZegoCloud API
  String _generateSignature({
    required String action,
    required int timestamp,
    required String signatureNonce,
  }) {
    final params = {
      'Action': action,
      'AppId': appId.toString(),
      'SignatureNonce': signatureNonce,
      'Timestamp': timestamp.toString(),
      'SignatureVersion': '2.0',
      'IsTest': isTest.toString(),
    };

    // Sort parameters by key
    final sortedKeys = params.keys.toList()..sort();
    final canonicalQueryString = sortedKeys
        .map((key) => '$key=${Uri.encodeComponent(params[key]!)}')
        .join('&');

    final stringToSign = 'POST\ncloudrecord-api.zego.im\n/\n$canonicalQueryString';

    final key = utf8.encode(serverSecret);
    final bytes = utf8.encode(stringToSign);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);

    return digest.toString();
  }
}