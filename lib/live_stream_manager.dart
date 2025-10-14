// live_stream_manager.dart
import 'dart:math';

class LiveStreamManager {
  static final LiveStreamManager _instance = LiveStreamManager._internal();
  factory LiveStreamManager() => _instance;
  LiveStreamManager._internal();

  // ZegoCloud credentials - Replace with your actual credentials
  final int appID = 1234567890; // Replace with your actual ZegoCloud App ID
  final String appSign = 'your_app_sign_here'; // Replace with your actual ZegoCloud App Sign

  String generateLiveId() {
    return 'live_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
            (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  Future<bool> validateCredentials() {
    return Future.value(appID != 1234567890 && appSign != 'your_app_sign_here');
  }

  Map<String, dynamic> getLiveStreamData(String liveId, String userId, String userName, bool isHost) {
    return {
      'liveId': liveId,
      'userId': userId,
      'userName': userName,
      'isHost': isHost,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'active',
    };
  }
}