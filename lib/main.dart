import 'package:flutter/material.dart';
import 'package:meet9ja/splash.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meet9ja', // Updated title
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Using a custom seed color based on the app's primary pink
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE43AA8), // DiscoverPage.kPrimary
          // Optional: You can set primary color directly for consistency
          primary: const Color(0xFFE43AA8),
        ),
        useMaterial3: true,
        fontFamily: 'Inter', // Assuming Inter font is used or desired
      ),
      home: const SplashScreen(), // Made const for performance
    );
  }
}
