// lib/discover.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Note: Ensure 'home_screen_filters.dart' and 'home_screen.dart' exist or remove these imports.
import '../constants/app_colors.dart';
import 'home_screen_filters.dart';
import 'home_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final Set<String> liked = {};
  bool _travelAlertsOn = true;

  // Sample data (kept as is)
  final List<_Person> recommended = [
    _Person(
      "Misbah",
      25,
      "https://i.pravatar.cc/800?img=12",
      verified: true,
      tags: ["🎨 Art"],
    ),
    _Person(
      "Yusra",
      23,
      "https://i.pravatar.cc/800?img=15",
      verified: false,
      tags: ["🎵 Music"],
    ),
    _Person(
      "Anum",
      24,
      "https://i.pravatar.cc/800?img=32",
      verified: true,
      tags: ["📚 Books"],
    ),
  ];

  final List<_Person> similarInterests = [
    _Person(
      "Ayesha",
      23,
      "https://i.pravatar.cc/800?img=21",
      verified: true,
      tags: ["🎊 Festivals", "+2"],
    ),
    _Person(
      "Rumi",
      22,
      "https://i.pravatar.cc/800?img=25",
      verified: true,
      tags: ["🎨 Art", "🎊 Festivals"],
    ),
    _Person(
      "Iqra",
      24,
      "https://i.pravatar.cc/800?img=27",
      verified: false,
      tags: ["📷 Photography"],
    ),
    _Person(
      "Hafsa",
      23,
      "https://i.pravatar.cc/800?img=28",
      verified: true,
      tags: ["🧗 Gym"],
    ),
  ];

  final List<_Person> sameGoals = [
    _Person(
      "Z",
      22,
      "https://i.pravatar.cc/800?img=31",
      verified: true,
      goal: "Long-term",
    ),
    _Person(
      "Mahnoor",
      25,
      "https://i.pravatar.cc/800?img=33",
      verified: true,
      goal: "Long-term",
    ),
    _Person(
      "Noor",
      24,
      "https://i.pravatar.cc/800?img=34",
      verified: false,
      goal: "Marriage",
    ),
    _Person(
      "Eman",
      23,
      "https://i.pravatar.cc/800?img=35",
      verified: true,
      goal: "Fun, casual",
    ),
  ];

  // Recently traveled (Country, State/Region, City)
  final List<_Trip> recentTrips = const [
    _Trip(
      country: "UAE",
      state: "Dubai",
      city: "Dubai",
      image: "https://images.unsplash.com/photo-1504610926078-a1611febcad3",
    ),
    _Trip(
      country: "Turkey",
      state: "Istanbul",
      city: "Beyoğlu",
      image: "https://images.unsplash.com/photo-1524231757912-21f4fe3a7200",
    ),
    _Trip(
      country: "Pakistan",
      state: "Punjab",
      city: "Lahore",
      image: "https://images.unsplash.com/photo-1591604129939-1cb13857dc3a",
    ),
    _Trip(
      country: "Saudi Arabia",
      state: "Makkah",
      city: "Jeddah",
      image: "https://images.unsplash.com/photo-1602071792473-99137559e889",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // ✅ solid white background
        child: SafeArea(
          child: Column(
            children: [
              // Top bar (centered title + filter)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    const Expanded(
                      child: Text(
                        "Discover",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        FontAwesomeIcons.sliders, // Filter icon (sliders)
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

              // Feed
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  children: [
                    // --- NEW SEARCH BAR (without filter icon) ---
                    const _SearchBar(),
                    const SizedBox(height: 18),

                    // --- NEW TRENDING CLIPS (with generic image) ---
                    const _SectionHeader("Trending Clips 🎬"),
                    const SizedBox(height: 10),
                    const _TrendingClipsStrip(),
                    const SizedBox(height: 22),

                    // --- NEW POPULAR PROFILES ---
                    const _SectionHeader("Popular Profiles ⭐"),
                    const SizedBox(height: 10),
                    _PopularProfilesStrip(
                      people: similarInterests.take(6).toList(),
                    ),
                    const SizedBox(height: 24),
                    // --- END OF NEW EXPLORE CONTENT ---

                    // pink pill + subtext (text -> BLACK now)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(
                            255,
                            212,
                            45,
                            137,
                          ), // pink background
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          "See new people in 6 hours",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.black, // ✅ black text for readability
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Connect over common ground with people who match your vibe, refreshed every day.",
                      style: TextStyle(fontSize: 14.5, color: Colors.black87),
                    ),

                    const SizedBox(height: 18),

                    // Recently traveled section + alerts toggle (UI only)
                    Row(
                      children: [
                        const _SectionHeader("Recently traveled"),
                        const Spacer(),
                        Icon(
                          _travelAlertsOn
                              ? FontAwesomeIcons.bell // notifications_active_rounded
                              : FontAwesomeIcons.bellSlash, // notifications_none_rounded
                          size: 18,
                          color: _travelAlertsOn
                              ? AppColors.primary
                              : Colors.black45,
                        ),
                        const SizedBox(width: 6),
                        Switch.adaptive(
                          value: _travelAlertsOn,
                          activeColor: AppColors.primary,
                          onChanged: (v) {
                            setState(() => _travelAlertsOn = v);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  v
                                      ? "Travel alerts enabled — you'll get notified when your profile shows up in a new country."
                                      : "Travel alerts turned off.",
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(milliseconds: 1200),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TravelStrip(trips: recentTrips),

                    const SizedBox(height: 22),

                    const _SectionHeader("Recommended for you"),
                    const SizedBox(height: 10),
                    _RecommendedStrip(
                      people: recommended,
                      liked: liked,
                      onLikeToggle: _toggleLike,
                    ),

                    const SizedBox(height: 24),

                    // Similar interests section with light surface
                    _SurfaceBlock(
                      title: "Similar interests",
                      child: _SmallCardsGrid(
                        people: similarInterests,
                        liked: liked,
                        onLikeToggle: _toggleLike,
                        chipFromTags: true,
                      ),
                    ),

                    const SizedBox(height: 18),

                    _SurfaceBlock(
                      title: "Same dating goals",
                      child: _SmallCardsGrid(
                        people: sameGoals,
                        liked: liked,
                        onLikeToggle: _toggleLike,
                        chipFromGoal: true,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom nav — Discover selected
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: _BottomNav(current: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleLike(String id) {
    setState(() {
      if (liked.contains(id)) {
        liked.remove(id);
      } else {
        liked.add(id);
      }
    });
  }
}

// -------------------- NEW WIDGETS FOR EXPLORE --------------------

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: const Row(
        children: [
          Icon(FontAwesomeIcons.magnifyingGlass, color: Colors.black54),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by name, tags, or location...",
                hintStyle: TextStyle(color: Colors.black54),
                border: InputBorder.none,
              ),
              style:
              TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ),
          // REMOVED: Icon(FontAwesomeIcons.filter, color: Colors.black54, size: 20),
        ],
      ),
    );
  }
}

class _TrendingClipsStrip extends StatelessWidget {
  const _TrendingClipsStrip();

  // Placeholder data for clips using a single, different generic image
  final String genericClipThumb = "https://images.unsplash.com/photo-1504610926078-a1611febcad3";

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4, // Still showing 4 items
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Clip Thumbnail
                Container(
                  width: 120,
                  height: 180,
                  color: Colors.grey.shade200,
                  child: Image.network(
                    genericClipThumb,
                    fit: BoxFit.cover,
                    // Minimalistic overlay
                    color: Colors.black.withOpacity(0.35),
                    colorBlendMode: BlendMode.darken,
                  ),
                ),
                // Play Icon
                const Positioned.fill(
                  child: Center(
                    child: Icon(
                      FontAwesomeIcons.solidCirclePlay,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                // Trending Text
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "#${i + 1} Trending",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PopularProfilesStrip extends StatelessWidget {
  const _PopularProfilesStrip({required this.people});
  final List<_Person> people;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: people.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final p = people[i];
          return Column(
            children: [
              // Circular Profile Image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                  Border.all(color: AppColors.primary, width: 3),
                  image: DecorationImage(
                    image: NetworkImage(p.image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Name
              Text(
                p.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -------------------- Travel widgets --------------------

class _TravelStrip extends StatelessWidget {
  const _TravelStrip({required this.trips});
  final List<_Trip> trips;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardW = w * 0.68;
    final cardH = cardW * 0.62;

    return SizedBox(
      height: cardH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: trips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) =>
            _TravelCard(trip: trips[i], width: cardW, height: cardH),
      ),
    );
  }
}

class _TravelCard extends StatelessWidget {
  const _TravelCard({
    required this.trip,
    required this.width,
    required this.height,
  });
  final _Trip trip;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // image
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              image: DecorationImage(
                image: NetworkImage(trip.image),
                fit: BoxFit.cover,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 12),
              ],
            ),
          ),

          // overlay info
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(12, 48, 12, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      "Recent trip",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${trip.city}, ${trip.state}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    trip.country,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Trip {
  final String country;
  final String state; // state/region/province
  final String city;
  final String image;

  const _Trip({
    required this.country,
    required this.state,
    required this.city,
    required this.image,
  });
}

// -------------------- UI Bits --------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _SurfaceBlock extends StatelessWidget {
  const _SurfaceBlock({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RecommendedStrip extends StatelessWidget {
  const _RecommendedStrip({
    required this.people,
    required this.liked,
    required this.onLikeToggle,
  });

  final List<_Person> people;
  final Set<String> liked;
  final void Function(String id) onLikeToggle;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardW = w * 0.78;
    final cardH = cardW * 1.2;

    return SizedBox(
      height: cardH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: people.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _BigCard(
          p: people[i],
          width: cardW,
          height: cardH,
          liked: liked.contains(people[i].id),
          onLike: () => onLikeToggle(people[i].id),
        ),
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  const _BigCard({
    required this.p,
    required this.width,
    required this.height,
    required this.liked,
    required this.onLike,
  });

  final _Person p;
  final double width;
  final double height;
  final bool liked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.grey.shade200,
        image: DecorationImage(image: NetworkImage(p.image), fit: BoxFit.cover),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Stack(
        children: [
          // bottom info
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                "${p.name}, ${p.age}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (p.verified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                FontAwesomeIcons.certificate, // Verified icon
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (p.tags.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: p.tags
                                .take(2)
                                .map((t) => _blackChip(t))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onLike,
                    icon: Icon(
                      liked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart, // Heart icons
                      color: liked ? AppColors.primary : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blackChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SmallCardsGrid extends StatelessWidget {
  const _SmallCardsGrid({
    required this.people,
    required this.liked,
    required this.onLikeToggle,
    this.chipFromTags = false,
    this.chipFromGoal = false,
  });

  final List<_Person> people;
  final Set<String> liked;
  final void Function(String id) onLikeToggle;
  final bool chipFromTags;
  final bool chipFromGoal;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: people.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, i) {
        final p = people[i];
        final likedNow = liked.contains(p.id);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(child: Image.network(p.image, fit: BoxFit.cover)),
              // bottom overlay
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 48, 10, 10),
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
                      if (chipFromTags && p.tags.isNotEmpty)
                        _darkPill(p.tags.first),
                      if (chipFromGoal && p.goal.isNotEmpty) _darkPill(p.goal),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${p.name}, ${p.age}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (p.verified)
                            const Icon(
                              FontAwesomeIcons.certificate, // Verified icon
                              size: 14,
                              color: Colors.white,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // like button
              Positioned(
                right: 8,
                bottom: 8,
                child: _circleBtn(
                  icon: likedNow ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart, // Heart icons
                  color: likedNow ? AppColors.primary : Colors.white,
                  onTap: () => onLikeToggle(p.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _darkPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// -------- Bottom Nav (Discover selected) --------
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, this.onTap});
  final int current;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    // All Font Awesome Icons
    final icons = const [
      FontAwesomeIcons.user, // Profile
      FontAwesomeIcons.compass, // Discover
      FontAwesomeIcons.userGroup, // People
      FontAwesomeIcons.heart, // Liked You
      FontAwesomeIcons.solidCommentDots, // Chats
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
        children: List.generate(icons.length, (i) {
          final selected = i == current;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // agar parent ne custom handler diya ho to usko call kar do
                if (onTap != null) {
                  onTap!(i);
                  return;
                }
                // DEFAULT ROUTING:
                // People tab -> DiscoverPage (swipe cards)
                if (i == 2 && current != 2) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                }
                // baqi tabs abhi noop; zarurat ho to routes add kar lena
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6),
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
                      size: selected ? 24 : 22, // Adjusted size for FA icons
                      color: selected
                          ? AppColors.primary
                          : Colors.black54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
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

// -------- Model --------
class _Person {
  final String name;
  final int age;
  final String image;
  final bool verified;
  final List<String> tags;
  final String goal;
  String get id => "$name-$age";

  _Person(
      this.name,
      this.age,
      this.image, {
        this.verified = false,
        this.tags = const [],
        this.goal = "",
      });
}