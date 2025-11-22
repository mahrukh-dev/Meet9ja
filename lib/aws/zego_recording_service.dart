import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
    required String bucket,
    required String region,
    required String accessKeyId,
    required String accessKeySecret,
  }) async {
    try {
      await _checkNetworkConnectivity();

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateSignatureNonce();

      // Generate signature using MD5 as per Zego documentation
      final signature = _generateSignature(
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

      // Updated request body to match API exactly
      final Map<String, dynamic> requestBody = {
        "RoomId": roomId,
        "RecordInputParams": {
          "RecordMode": 1, // Single stream recording
          "StreamType": 3, // Both audio and video
          "RecordStreamList": [
            {
              "StreamId": "${roomId}_${userId}_main" // Use proper stream ID format
            }
          ],
          "FillBlank": false,
          "FillFrame": {
            "FrameFillMode": 1,
            "FrameFillColor": 0
          },
          "RecordMuteAudio": 1,
          "RecordMuteAudioSplitThreshold": 0,
          "HasWhiteboard": false,
          "MaxIdleTime": 60,
          "MaxRecordTime": 86400,
        },
        "RecordOutputParams": {
          "OutputFileFormat": "mp4",
          "OutputFolder": "zego_recordings/$roomId/",
          "OutputFileRule": 1,
          "SnapshotInterval": 10,
          "CallbackUrl": "",
          "FragmentSeconds": 15,
          "RealtimeUploadFragment": true,
          "ShortFragmentPath": true
        },
        "StorageParams": {
          "Vendor": 1, // AWS S3
          "Region": region,
          "Bucket": bucket,
          "AccessKeyId": accessKeyId,
          "AccessKeySecret": accessKeySecret,
          "EndPoint": "" // Optional: Custom S3 endpoint
        }
      };

      print('🌐 Sending recording start request to Zego...');
      print('🔑 Signature details:');
      print('   - AppId: $appId');
      print('   - Timestamp: $timestamp');
      print('   - Nonce: $nonce');
      print('   - Signature: $signature');

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      )
          .timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['Code'] == 0) {
          print('✅ Zego Cloud Recording started successfully');
          return result;
        } else {
          throw Exception(
            'Zego API error: Code ${result['Code']} - ${result['Message']}',
          );
        }
      } else {
        throw HttpException('HTTP ${response.statusCode}: ${response.body}');
      }
    } on SocketException catch (e) {
      throw Exception(
        'Network error: Cannot connect to Zego servers. Details: $e',
      );
    } catch (e) {
      throw Exception('Recording start error: $e');
    }
  }

  static Future<Map<String, dynamic>> stopRecording({
    required int appId,
    required String serverSecret,
    required String taskId,
  }) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateSignatureNonce();

      final signature = _generateSignature(
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

      final Map<String, dynamic> requestBody = {"TaskId": taskId};

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      print('🛑 Stopping recording with Task ID: $taskId');

      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      )
          .timeout(const Duration(seconds: 30));

      print('🛑 Stop recording response: ${response.statusCode}');
      print('🛑 Stop recording body: ${response.body}');

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

  // Updated to use DescribeRecordStatus as per Zego documentation
  static Future<Map<String, dynamic>> queryRecordingStatus({
    required int appId,
    required String serverSecret,
    required String taskId,
  }) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateSignatureNonce();

      final signature = _generateSignature(
        appId: appId,
        serverSecret: serverSecret,
        timestamp: timestamp,
        nonce: nonce,
      );

      final queryParams = {
        'Action': 'DescribeRecordStatus', // Correct action name
        'AppId': appId.toString(),
        'SignatureNonce': nonce,
        'Timestamp': timestamp,
        'SignatureVersion': _signatureVersion,
        'Signature': signature,
      };

      final Map<String, dynamic> requestBody = {"TaskId": taskId};

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      print('📊 Querying recording status for Task ID: $taskId');

      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      )
          .timeout(const Duration(seconds: 30));

      print('📊 Query recording status response: ${response.statusCode}');
      print('📊 Query recording status body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Recording query error: $e');
    }
  }

  /// Generate a 16-character hexadecimal random string (hex encoding of 8-byte random number)
  static String _generateSignatureNonce() {
    final random = Random.secure();
    final nonceBytes = List<int>.generate(8, (_) => random.nextInt(256));
    return _bytesToHex(nonceBytes);
  }

  /// Convert bytes to hex string
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate signature according to Zego documentation:
  /// Signature = md5(AppId + SignatureNonce + ServerSecret + Timestamp)
  static String _generateSignature({
    required int appId,
    required String serverSecret,
    required String timestamp,
    required String nonce,
  }) {
    try {
      // Format: AppId + SignatureNonce + ServerSecret + Timestamp
      final payload = '$appId$nonce$serverSecret$timestamp';

      // Generate MD5 hash
      final bytes = utf8.encode(payload);
      final digest = md5.convert(bytes);
      return digest.toString();
    } catch (e) {
      throw Exception('MD5 signature generation error: $e');
    }
  }

  static Future<void> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup(
        'cloudrecord-api.zego.im',
      ).timeout(const Duration(seconds: 10));

      if (result.isEmpty) {
        throw SocketException('No addresses found for cloudrecord-api.zego.im');
      }
    } on SocketException catch (e) {
      throw SocketException('Cannot resolve Zego server address. Details: $e');
    }
  }
}