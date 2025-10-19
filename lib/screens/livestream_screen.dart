import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

class LiveStreamScreen extends StatelessWidget {
  final String liveId;
  final String userId;
  final bool isHost;
  final String userName;

  const LiveStreamScreen({
    super.key,
    required this.liveId,
    required this.userId,
    required this.isHost,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZegoUIKitPrebuiltLiveStreaming(
        appID: 51745598,
        appSign: '5bfa67bea457bf8b27014d411711518683ef0465f4a09f64832ea8d56e92e7a4',
        userID: userId,
        userName: userName,
        liveID: liveId,
        config: isHost
            ? ZegoUIKitPrebuiltLiveStreamingConfig.host()
            : ZegoUIKitPrebuiltLiveStreamingConfig.audience(),
      ),
    );
  }
}