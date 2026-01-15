import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:meet9ja/screens/explore_live_screen.dart';
import 'package:meet9ja/screens/flutterwave_payment_screen.dart';
import 'package:meet9ja/screens/home_screen.dart';
import 'package:meet9ja/screens/profile_screen.dart';
import 'package:meet9ja/screens/signin_screen.dart';
import 'package:meet9ja/screens/splash_screen.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

import 'constants/ENVconfig.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: "assets/.env");
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