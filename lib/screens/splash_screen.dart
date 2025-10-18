// lib/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    // 5 seconds delay then navigate
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
      );
    });
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