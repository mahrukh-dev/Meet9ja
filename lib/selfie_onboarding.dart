import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class SelfieOnboardingPage extends StatefulWidget {
  const SelfieOnboardingPage({super.key});

  // Brand magenta
  static const Color kPrimary = Color(0xFFE43AA8);

  @override
  State<SelfieOnboardingPage> createState() => _SelfieOnboardingPageState();
}

class _SelfieOnboardingPageState extends State<SelfieOnboardingPage>
    with TickerProviderStateMixin {
  // Animations (background controller removed)
  late final AnimationController _floatCtrl; // gentle float for icon
  late final AnimationController _pulseCtrl; // pulsing rings behind icon
  late final AnimationController _introCtrl; // initial fade/slide in
  late final AnimationController _tapCtrl; // CTA micro-bounce

  late final Animation<double> _floatAnim;
  late final Animation<double> _introFade;
  late final Animation<Offset> _introSlide;
  late final Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat();

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _floatAnim = Tween(
      begin: -8.0,
      end: 8.0,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_floatCtrl);

    _introFade = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);
    _introSlide = Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_introCtrl);

    _tapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.97), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.0), weight: 50),
    ]).animate(_tapCtrl);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _introCtrl.dispose();
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ solid white background
      body: Stack(
        children: [
          // Foreground content
          SafeArea(
            child: Column(
              children: [
                // top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Skip",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Animated icon (no box) with pulsing rings
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: _introFade,
                      child: SlideTransition(
                        position: _introSlide,
                        child: Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _PulseRings(controller: _pulseCtrl),
                              // camera icon
                              Icon(
                                CupertinoIcons.camera,
                                size: 148,
                                color: SelfieOnboardingPage.kPrimary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // page dots
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Dot(active: true),
                    SizedBox(width: 8),
                    _Dot(active: false),
                  ],
                ),

                const SizedBox(height: 22),

                // CTA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ScaleTransition(
                    scale: _tapScale,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SelfieOnboardingPage.kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 8,
                          shadowColor: SelfieOnboardingPage.kPrimary
                              .withOpacity(0.45),
                        ),
                        onPressed: () async {
                          await _tapCtrl.forward();
                          await _tapCtrl.reverse();

                          // TODO: Open camera/selfie flow here
                        },
                        child: const Text(
                          "Take a selfie",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                const Padding(
                  padding: EdgeInsets.only(bottom: 22.0),
                  child: Text(
                    "Don’t worry, we won’t share it with anyone",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- UI bits (no glass card) ----------

class _PulseRings extends StatelessWidget {
  const _PulseRings({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [_ring(1.0, t), _ring(0.6, (t + 0.5) % 1.0)],
        );
      },
    );
  }

  Widget _ring(double maxScale, double t) {
    final scale = 0.7 + (maxScale - 0.7) * t;
    final opacity = (1 - t).clamp(0.0, 1.0) * 0.6;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: SelfieOnboardingPage.kPrimary.withOpacity(opacity),
            width: 2,
          ),
        ),
      ),
    );
  }
}

// --- dots ---
class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: active ? 12 : 8,
      height: active ? 12 : 8,
      decoration: BoxDecoration(
        color: active ? SelfieOnboardingPage.kPrimary : Colors.black26,
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: SelfieOnboardingPage.kPrimary.withOpacity(0.45),
                  blurRadius: 10,
                  spreadRadius: 1.5,
                ),
              ]
            : null,
      ),
    );
  }
}
