import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:meet9ja/Discover.dart';
import 'package:meet9ja/discover_page.dart';
import 'package:meet9ja/messages.dart';
import 'package:meet9ja/profile.dart';
import 'package:meet9ja/splash.dart';
import 'package:meet9ja/startlive.dart';
import 'package:meet9ja/user_channel.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
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
          seedColor: const Color(0xFFE43AA8),
          primary: const Color(0xFFE43AA8),
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: MessagesScreen(),
    );
  }
}
