// lib/home_screen.dart
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:meet9ja/screens/explore_live_screen.dart';
import 'package:meet9ja/screens/update_profile_screen.dart';
import '../constants/app_colors.dart';
import 'home_screen_filters.dart';
import 'discover_screen.dart';
import 'messages_screen.dart';
import 'profiles_list_screen.dart'; // ⬅️ updated import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageCtrl;
  int _index = 0;

  // Track page safely without using controller.position
  double _currentPage = 0.0;

  // ---- DATA: 7+ profiles ----
  final List<_Profile> profiles = [
    _Profile.net(
      name: "Zara",
      age: 19,
      job: "Customer Support",
      edu: "Bahria University 2029",
      url: "https://i.pravatar.cc/800?img=65",
      newHere: true,
      verified: true,
    ),
    _Profile.net(
      name: "Um",
      age: 24,
      job: "Marketing Associate",
      edu: "IoBM 2022",
      url: "https://i.pravatar.cc/800?img=47",
      newHere: true,
      verified: false,
    ),
    _Profile.net(
      name: "Areeba",
      age: 22,
      job: "UX Intern",
      edu: "NCA 2026",
      url: "https://i.pravatar.cc/800?img=57",
      newHere: false,
      verified: true,
    ),
    _Profile.net(
      name: "Hira",
      age: 25,
      job: "Product Designer",
      edu: "FAST 2021",
      url: "https://i.pravatar.cc/800?img=68",
      newHere: false,
      verified: true,
    ),
    _Profile.net(
      name: "Noor",
      age: 23,
      job: "Customer Success",
      edu: "Habib University 2024",
      url: "https://i.pravatar.cc/800?img=56",
      newHere: true,
      verified: false,
    ),
    _Profile.net(
      name: "Mariam",
      age: 26,
      job: "Data Analyst",
      edu: "IBA 2020",
      url: "https://i.pravatar.cc/800?img=49",
      newHere: false,
      verified: true,
    ),
    _Profile.net(
      name: "Laiba",
      age: 21,
      job: "Student",
      edu: "SZABIST 2026",
      url: "https://i.pravatar.cc/800?img=66",
      newHere: false,
      verified: false,
    ),
    _Profile.net(
      name: "Anaya",
      age: 24,
      job: "Front Desk",
      edu: "UoK 2023",
      url: "https://i.pravatar.cc/800?img=58",
      newHere: false,
      verified: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.92);
    _currentPage = _pageCtrl.initialPage.toDouble();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_index < profiles.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  void _onSwipeRight(_Profile p) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("You liked ${p.name}"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 800),
      ),
    );
    _goNext();
  }

  void _onSwipeLeft(_Profile p) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("You passed on ${p.name}"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 700),
      ),
    );
    _goNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // ✅ solid white background
        child: SafeArea(
          child: Column(
            children: [
              // ----- Top bar: LIVE + Logo + Filter -----
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                child: Row(
                  children: [
                    _LivePill(onTap: () => _openLiveSheet(context)),
                    const Expanded(child: Center(child: _Meet9jaLogo())),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.line_horizontal_3_decrease,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreenFilters()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ----- progress (how many profiles viewed) -----
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                child: Row(
                  children: List.generate(profiles.length, (i) {
                    final active = i <= _index;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : Colors.black12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // ----- Swipeable cards (swipe to match) -----
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    // Only handle PageView notifications
                    if (n.metrics is PageMetrics) {
                      final m = n.metrics as PageMetrics;
                      setState(() {
                        _currentPage = m.page ?? _index.toDouble();
                      });
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemCount: profiles.length,
                    itemBuilder: (context, i) {
                      // Compute transform from tracked _currentPage
                      final t = (_currentPage - i).abs().clamp(0.0, 1.0);
                      final scale = lerpDouble(1.0, 0.94, t)!;
                      final translateY = lerpDouble(0, 14, t)!;

                      return Transform.translate(
                        offset: Offset(0, translateY),
                        child: Transform.scale(
                          scale: scale,
                          child: _SwipeCard(
                            profile: profiles[i],
                            onSwipeLeft: () => _onSwipeLeft(profiles[i]),
                            onSwipeRight: () => _onSwipeRight(profiles[i]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ----- Bottom nav -----
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: _BottomNav(current: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLiveSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LiveHeader(),
              const SizedBox(height: 12),

              // Start Live button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(CupertinoIcons.circle_filled),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExploreLiveScreen()),
                    );
                  },
                  label: const Text(
                    "Go live",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Join Lives button (with thicker outline)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(CupertinoIcons.tv),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Colors.black12,
                      width: 2.0, // ✅ increased outline thickness
                    ),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Watch Live Stream"),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(milliseconds: 900),
                      ),
                    );
                  },
                  label: const Text(
                    "Join Lives",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Go live to stream yourself and hop into video calls.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}

// ---------------- Widgets ----------------

class _SwipeCard extends StatefulWidget {
  const _SwipeCard({
    required this.profile,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  final _Profile profile;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> {
  Offset _offset = Offset.zero;
  double _rotation = 0.0; // radians
  bool _swipingRight = false;
  bool _swipingLeft = false;

  static const double _threshold = 120; // px to count as swipe
  static const double _maxRotation = 0.10; // ~6 deg

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _offset += d.delta;
      _rotation = (_offset.dx / 300).clamp(-_maxRotation, _maxRotation);
      _swipingRight = _offset.dx > 30;
      _swipingLeft = _offset.dx < -30;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_offset.dx > _threshold) {
      widget.onSwipeRight();
    } else if (_offset.dx < -_threshold) {
      widget.onSwipeLeft();
    }
    setState(() {
      _offset = Offset.zero;
      _rotation = 0.0;
      _swipingLeft = false;
      _swipingRight = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: _offset,
        child: Transform.rotate(
          angle: _rotation,
          child: Stack(
            children: [
              _ProfileCard(profile: widget.profile),

              // LIKE / NOPE stamps
              Positioned(
                top: 18,
                left: 18,
                child: AnimatedOpacity(
                  opacity: _swipingRight ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: _SwipeStamp(
                    text: "LIKE",
                    color: Colors.green.shade600,
                  ),
                ),
              ),
              Positioned(
                top: 18,
                right: 18,
                child: AnimatedOpacity(
                  opacity: _swipingLeft ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: _SwipeStamp(text: "NOPE", color: Colors.red.shade600),
                ),
              ),

              // Gesture layer
              Positioned.fill(
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,

                  // ⬇️ tap: open detailed profile in ProfileDisplay
                  onTap: () {
                    final p = widget.profile;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilesListScreen(
                          name: p.name,
                          age: p.age,
                          job: p.job,
                          edu: p.edu,
                          image: p.image,
                          isAsset: p.isAsset,
                          verified: p.verified,
                          newHere: p.newHere,
                          bio: "Intro pending…",
                          interests: const [
                            "Music",
                            "Reading",
                            "Coffee",
                            "Hiking",
                          ],
                          distanceKm: 3,
                          location: "Karachi",
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withOpacity(0.85),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});
  final _Profile profile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ⬇️ Hero wrap (unique tag per image)
            Hero(
              tag: 'profile-img-${profile.image}',
              child: _ProfileImage(profile: profile),
            ),

            Positioned(
              right: 10,
              top: 10,
              child: _CircleBtn(icon: CupertinoIcons.share, onTap: () {}),
            ),

            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 60, 14, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black54,
                      Colors.black87,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (profile.newHere) const _Chip("New here"),
                        if (profile.verified)
                          const _Chip.icon("Photo verified", CupertinoIcons.checkmark_circle_fill),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${profile.name}, ${profile.age}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (profile.job.isNotEmpty)
                      _InfoRow(icon: CupertinoIcons.briefcase, text: profile.job),
                    if (profile.edu.isNotEmpty)
                      _InfoRow(icon: FontAwesomeIcons.graduationCap, text: profile.edu),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _PillBtn(
                          icon: CupertinoIcons.multiply,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("You passed on ${profile.name}"),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(milliseconds: 700),
                              ),
                            );
                          },
                          bg: Colors.white.withOpacity(0.85),
                          fg: Colors.red.shade600,
                        ),
                        const SizedBox(width: 10),
                        _PillBtn(
                          icon: CupertinoIcons.heart_fill,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("You liked ${profile.name}"),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(milliseconds: 800),
                              ),
                            );
                          },
                          bg: AppColors.primary,
                          fg: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ⬇️ Tap layer: open detailed ProfileDisplay + hero transition
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final p = profile;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilesListScreen(
                          name: p.name,
                          age: p.age,
                          job: p.job,
                          edu: p.edu,
                          image: p.image,
                          isAsset: p.isAsset,
                          verified: p.verified,
                          newHere: p.newHere,
                          bio: "Intro pending…",
                          interests: const [
                            "Music",
                            "Reading",
                            "Coffee",
                            "Hiking",
                          ],
                          distanceKm: 3,
                          location: "Karachi",
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  const _ProfileImage({required this.profile});
  final _Profile profile;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: Colors.grey.shade200,
      image: DecorationImage(
        image: profile.isAsset
            ? AssetImage(profile.image) as ImageProvider
            : NetworkImage(profile.image),
        fit: BoxFit.cover,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6)),
      ],
    );
    return Container(decoration: decoration);
  }
}

class _Meet9jaLogo extends StatelessWidget {
  const _Meet9jaLogo();

  @override
  Widget build(BuildContext context) {
    return Text(
      "Meet9ja",
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
        color: Colors.black87,
        shadows: [
          Shadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.primary.withOpacity(0.10),
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.tv,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            const Text(
              "LIVE",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveHeader extends StatelessWidget {
  const _LiveHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(CupertinoIcons.tv, color: AppColors.primary),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            "Go Live",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {super.key}) : _icon = null;
  const _Chip.icon(this.text, this._icon, {super.key});

  final String text;
  final IconData? _icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_icon != null) ...[
            Icon(_icon, size: 14, color: Colors.black87),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBtn extends StatelessWidget {
  const _PillBtn({
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.fg,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Material(
          color: bg,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Icon(icon, color: fg, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white70,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: Colors.black87),
        ),
      ),
    );
  }
}

// --------- Bottom Nav ----------
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, this.onTap});
  final int current; // 0..4
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final icons = const [
      CupertinoIcons.person,
      FontAwesomeIcons.compass,
      FontAwesomeIcons.userGroup,
      FontAwesomeIcons.heart,
      FontAwesomeIcons.comment,
    ];
    final labels = const [
      "Profile",
      "Discover",
      "People",
      "Liked You",
      "Chats",
    ];

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(icons.length, (i) {
          final selected = i == current;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (onTap != null) {
                  onTap!(i);
                  return;
                }
                if (i == 0 && current != 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => UpdateProfileScreen()),
                  );
                  return;
                }
                if (i == 1 && current != 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DiscoverScreen()),
                  );
                  return;
                }
                if (i == 4 && current != 4) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()),
                  );
                  return;
                }
                // 2 current; 3 placeholder
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[i],
                      size: selected ? 30 : 28,
                      color: selected ? AppColors.primary : Colors.black54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.0,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ===== Model =====
class _Profile {
  final String name;
  final int age;
  final String job;
  final String edu;
  final String image;
  final bool isAsset;
  final bool verified;
  final bool newHere;

  const _Profile._({
    required this.name,
    required this.age,
    required this.job,
    required this.edu,
    required this.image,
    required this.isAsset,
    required this.verified,
    required this.newHere,
  });

  factory _Profile.net({
    required String name,
    required int age,
    required String job,
    required String edu,
    required String url,
    bool verified = false,
    bool newHere = false,
  }) => _Profile._(
    name: name,
    age: age,
    job: job,
    edu: edu,
    image: url,
    isAsset: false,
    verified: verified,
    newHere: newHere,
  );

  factory _Profile.asset({
    required String name,
    required int age,
    required String job,
    required String edu,
    required String assetPath,
    bool verified = false,
    bool newHere = false,
  }) => _Profile._(
    name: name,
    age: age,
    job: job,
    edu: edu,
    image: assetPath,
    isAsset: true,
    verified: verified,
    newHere: newHere,
  );
}
