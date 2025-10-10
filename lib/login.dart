import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'profile_setup.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const Color kPrimary = Color(0xFFE43AA8);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final List<String> _bgImages = const [
    'assets/images/bg1.jpg',
    'assets/images/bg2.jpg',
    'assets/images/bg3.jpg',
    'assets/images/bg4.jpg',
  ];

  int _bgIndex = 0;
  Timer? _switchTimer;

  late final AnimationController _zoomCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _zoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
      reverseDuration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeInOut));

    _switchTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      setState(() => _bgIndex = (_bgIndex + 1) % _bgImages.length);
    });
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    _zoomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Fullscreen background with zoom effect
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scaleAnim,
              builder: (context, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: ClipRect(
                    key: ValueKey(_bgIndex),
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: screenSize.width,
                            height: screenSize.height,
                            child: Image.asset(
                              _bgImages[_bgIndex],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Soft white overlay
          Positioned.fill(
            child: Container(color: Colors.white.withOpacity(0.05)),
          ),

          // 3. Foreground UI
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 70), // was 40 → nudged content down
                // Top area: logo and brand stacked together
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      const Spacer(flex: 1),

                      // Logo + brand
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Bigger circular logo with soft shadow
                          Container(
                            width: 140, // was 110
                            height: 140, // was 110
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Padding(
                                padding: const EdgeInsets.all(10.0), // was 8.0
                                child: Image.asset(
                                  "assets/images/Heart.png",
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12), // was 10
                          // Slightly larger brand name
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 38, // was 34
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                              children: [
                                TextSpan(
                                  text: "Meet",
                                  style: TextStyle(color: Colors.white),
                                ),
                                TextSpan(
                                  text: "9",
                                  style: TextStyle(color: Color(0xFF008751)),
                                ),
                                TextSpan(
                                  text: "j",
                                  style: TextStyle(color: Colors.white),
                                ),
                                TextSpan(
                                  text: "a",
                                  style: TextStyle(color: Color(0xFF008751)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Spacer(flex: 1),
                    ],
                  ),
                ),

                const Spacer(),

                // Glassy card containing buttons (centered and elevated)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 22.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Primary login button (solid)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 20,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: LoginPage.kPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                  shadowColor: Colors.black.withOpacity(0.05),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ProfileSetupPage(),
                                    ),
                                  );
                                },
                                label: const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Secondary sign up button (outline style)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Colors.white,
                                    width: 1.3,
                                  ),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ProfileSetupPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Small helper row
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "By signing up, you agree to our Terms. See how we use your data in our Privacy Policy.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
