// lib/splash_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'onboarding_screen.dart'; // <-- make sure this exists

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      // Check if user is already authenticated
      _checkAuthStatus();
    });
  }

  void _checkAuthStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in - go to main app
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // User not logged in - go to onboarding
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Light status bar icons for the pink background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
    );

    return const Scaffold(
      backgroundColor: Color(0xFFFF4DA6), // pink background
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HeartLogo(size: 90), // Heart.png here
              SizedBox(height: 20),
              _BrandText(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandText extends StatelessWidget {
  const _BrandText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Meet9ja',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.0,
      ),
    );
  }
}

/// Heart logo widget
class _HeartLogo extends StatelessWidget {
  final double size;
  const _HeartLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset("assets/images/Heart.png", fit: BoxFit.contain),
    );
  }
}