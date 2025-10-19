import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:meet9ja/screens/livestream_screen.dart';
import 'package:meet9ja/screens/chat_screen.dart';
import 'package:meet9ja/screens/discover_screen.dart';
import 'package:meet9ja/screens/home_screen.dart';
import 'package:meet9ja/screens/messages_screen.dart' hide ChatScreen;
import 'package:meet9ja/profile.dart';
import 'package:meet9ja/screens/splash_screen.dart';
import 'package:meet9ja/screens/explore_live_screen.dart';
import 'package:meet9ja/user_channel.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  ZegoUIKit().initLog().then((value) {
    runApp(const MyApp());
  });

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meet9ja', // Updated title
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xA1C31A85),
          primary: const Color(0xB5C31A85),
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: ZegoUIKitPrebuiltLiveStreamingMiniPopScope(
        child: SplashScreen(),
      ),
    );
  }
}
