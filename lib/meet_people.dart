/// lib/meet_people.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'login.dart';

class MeetPeoplePage extends StatefulWidget {
  const MeetPeoplePage({super.key});
  @override
  State<MeetPeoplePage> createState() => _MeetPeoplePageState();
}

class _MeetPeoplePageState extends State<MeetPeoplePage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  double _page = 0;

  final List<_OnboardData> _pages = const [
    _OnboardData(
      icon: Icons.people,
      title: "Meet People",
      description:
          "People meet naturally based on innumerable attraction. So, choose your partner from your interest",
    ),
    _OnboardData(
      icon: Icons.chat_bubble_outline,
      title: "Start Chatting",
      description:
          "Connect instantly and start meaningful conversations with people you like.",
    ),
    _OnboardData(
      icon: Icons.videocam_outlined,
      title: "Go Live",
      description:
          "Go live to stream yourself and jump into video calls with people you match—real-time, fun, and safe.",
    ),
    _OnboardData(
      icon: Icons.favorite_border,
      title: "Find Love",
      description:
          "Build deeper connections and maybe find the love of your life.",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _page = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              Column(
                children: [
                  // top bar (Skip only, dot removed)
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: _AppColors.primary,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text("Skip"),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // pages
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (context, index) {
                        final data = _pages[index];
                        final t = (_page - index).clamp(-1.0, 1.0);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // animated icon (no glass card)
                                TweenAnimationBuilder<double>(
                                  key: ValueKey(index),
                                  tween: Tween(begin: 0.9, end: 1.0),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.elasticOut,
                                  builder: (context, scale, child) {
                                    final tilt = -t * 8 * (math.pi / 180);
                                    return Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..rotateZ(tilt)
                                        ..scale(scale),
                                      child: child,
                                    );
                                  },
                                  child: Icon(
                                    data.icon,
                                    size: 96,
                                    color: _AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 28),

                                _FadeSlide(
                                  key: ValueKey('title-$index'),
                                  child: Text(
                                    data.title,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: const Color(0xFF16151A),
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _FadeSlide(
                                  delay: 120,
                                  key: ValueKey('desc-$index'),
                                  child: Text(
                                    data.description,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(
                                        0xFF2B2930,
                                      ).withOpacity(0.75),
                                      fontSize: 16,
                                      height: 1.55,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // indicators + CTA
                  SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _pages.length,
                            (i) => _buildDot(i == _currentIndex),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: _AppColors.primary.withOpacity(0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: () {
                              if (_currentIndex < _pages.length - 1) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 450),
                                  curve: Curves.easeOutCubic,
                                );
                              } else {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              _currentIndex < _pages.length - 1
                                  ? "Continue"
                                  : "Get Started",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 10,
      width: isActive ? 26 : 10,
      decoration: BoxDecoration(
        color: isActive
            ? _AppColors.primary
            : _AppColors.primary.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ---------- Animations ----------
class _FadeSlide extends StatefulWidget {
  final Widget child;
  final int delay;
  const _FadeSlide({super.key, required this.child, this.delay = 0});

  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _offset = Tween(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), _c.forward);
  }

  @override
  void didUpdateWidget(covariant _FadeSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.key != widget.key) {
      _c
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}

// brand colors
class _AppColors {
  static const primary = Color(0xFFE43AA8);
}

// data class
class _OnboardData {
  final IconData icon;
  final String title;
  final String description;
  const _OnboardData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
