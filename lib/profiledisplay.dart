import 'package:flutter/material.dart';

class ProfileDisplay extends StatelessWidget {
  const ProfileDisplay({
    super.key,
    required this.name,
    required this.age,
    required this.job,
    required this.edu,
    required this.image,
    required this.isAsset,
    required this.verified,
    required this.newHere,
    // Optional extras
    this.bio,
    this.interests = const [],
    this.distanceKm,
    this.location,
    this.galleryImages = const [], // up to 5 more (total 6 with hero)
    // Optional custom section texts (fallbacks provided)
    this.excitedAbout,
    this.greenFlags,
    this.weekendVibe,
    this.promptOne,
    this.promptTwo,
    this.promptThree,
    this.promptFour,
    // (Optional) override chips per-section (7 lists, null -> defaults used)
    this.customChips,
  });

  // Core
  final String name;
  final int age;
  final String job;
  final String edu;
  final String image; // hero
  final bool isAsset;
  final bool verified;
  final bool newHere;

  // Optional meta
  final String? bio;
  final List<String> interests;
  final int? distanceKm;
  final String? location;

  // Gallery (extra images)
  final List<String> galleryImages;

  // Section contents (7 sections)
  final String? excitedAbout; // "I get way too excited about…"
  final String? greenFlags; // "Green flags in me"
  final String? weekendVibe; // "Weekend vibe"
  final String? promptOne;
  final String? promptTwo;
  final String? promptThree;
  final String? promptFour;

  /// Custom chips per section (length 7). Each inner list is chips for that section.
  /// If null or a section's list is null/empty, sensible defaults are used.
  final List<List<_ChipData>>? customChips;

  @override
  Widget build(BuildContext context) {
    final heroTag = 'profile-img-$image';

    // Build a 6-image list (first = hero). If fewer provided, repeat safely.
    final base = <String>[image, ...galleryImages];
    final imgs = _fillToSix(base);

    // Defaults if texts not supplied
    final iList = interests.isNotEmpty
        ? interests
        : const ["Music", "Reading", "Coffee", "Hiking"];

    final defaults = _SectionDefaults.fallback(
      name: name,
      interests: iList,
      city: location ?? "Nearby",
    );

    final List<_SectionData> sections = <_SectionData>[
      _SectionData(
        title: "Languages",
        text: excitedAbout ?? defaults.excitedAbout,
        image: imgs[0],
        chips: _chipsOrDefault(0, customChips, [
          _ChipData("English", Icons.chat_bubble_outline),
          _ChipData("Yoruba", Icons.chat_bubble_outline),
        ]),
      ),
      _SectionData(
        title: "Green flags in me",
        text: greenFlags ?? defaults.greenFlags,
        image: imgs[1],
        chips: _chipsOrDefault(1, customChips, [
          _ChipData("Kind", Icons.favorite_border),
          _ChipData("On time", Icons.schedule_outlined),
          _ChipData("Good texter", Icons.sms_outlined),
        ]),
      ),
      _SectionData(
        title: "Weekend vibe",
        text: weekendVibe ?? defaults.weekendVibe,
        image: imgs[2],
        chips: _chipsOrDefault(2, customChips, [
          _ChipData("Brunch", Icons.brunch_dining_outlined),
          _ChipData("Workout", Icons.fitness_center_outlined),
          _ChipData("Movies", Icons.movie_outlined),
        ]),
      ),
      _SectionData(
        title: "Recent obsession",
        text: promptOne ?? defaults.p1,
        image: imgs[3],
        chips: _chipsOrDefault(3, customChips, [
          _ChipData("Playlists", Icons.queue_music),
          _ChipData("Podcasts", Icons.podcasts),
        ]),
      ),
      _SectionData(
        title: "Perfect first date",
        text: promptTwo ?? defaults.p2,
        image: imgs[4],
        chips: _chipsOrDefault(4, customChips, [
          _ChipData("Walk", Icons.directions_walk),
          _ChipData("Chai", Icons.local_cafe_outlined),
          _ChipData("View", Icons.park_outlined),
        ]),
      ),
      _SectionData(
        title: "Two truths & a lie",
        text: promptThree ?? defaults.p3,
        image: imgs[5],
        chips: _chipsOrDefault(5, customChips, [
          _ChipData("Parallel park", Icons.directions_car_filled_outlined),
          _ChipData("Alphabet ↩", Icons.abc),
          _ChipData("Pineapple pizza", Icons.local_pizza_outlined),
        ]),
      ),
      _SectionData(
        title: "Unpopular opinion",
        text: promptFour ?? defaults.p4,
        image: imgs[0], // loop back
        chips: _chipsOrDefault(6, customChips, [
          _ChipData("Consistency >", Icons.check_circle_outline),
          _ChipData("Small wins", Icons.emoji_events_outlined),
        ]),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ====== TOP: Image carousel (6 images) with Hero on the first ======
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ImageCarousel(
                    images: imgs,
                    isAsset: isAsset,
                    heroFirstTag: heroTag,
                  ),
                  // Chips overlay (verification, location, etc.)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    right: 12,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (newHere) _chip("New here"),
                        if (verified)
                          _chipIcon("Photo verified", Icons.verified),
                        if ((location ?? "").isNotEmpty)
                          _chipIcon(location!, Icons.location_on_outlined),
                        if (distanceKm != null) _chip("${distanceKm} km away"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ====== Header: Name & basics ======
          Text(
            "$name, $age",
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          if (job.isNotEmpty) _row(Icons.work_outline, job),
          if (edu.isNotEmpty) ...[
            const SizedBox(height: 6),
            _row(Icons.school_outlined, edu),
          ],

          const SizedBox(height: 14),
          if ((bio ?? "").isNotEmpty) ...[
            const Text(
              "About",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              bio!,
              style: const TextStyle(fontSize: 15.5, color: Colors.black87),
            ),
          ],

          if (iList.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Interests",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: iList.map((t) => _chip(t)).toList(),
            ),
          ],

          const SizedBox(height: 18),

          // ====== For each section: KEYWORDS PANEL -> IMAGE PANEL (screenshot vibe) ======
          for (final s in sections) ...[
            _KeywordsPanel(title: s.title, chips: s.chips),
            const SizedBox(height: 10),
            _ImagePanel(
              image: s.image,
              isAsset: isAsset,
              // Optional overlays like in screenshot
              leadingPill: _complimentPill(),
              trailingFab: _starFab(),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // ---------- helpers ----------
  static List<String> _fillToSix(List<String> base) {
    final cleaned = base.where((e) => e.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return List.filled(6, "");
    // Make exactly length 6 by repeating in order
    final out = <String>[];
    for (var i = 0; i < 6; i++) {
      out.add(cleaned[i % cleaned.length]);
    }
    return out;
  }

  static List<_ChipData> _chipsOrDefault(
    int idx,
    List<List<_ChipData>>? custom,
    List<_ChipData> fallback,
  ) {
    if (custom == null) return fallback;
    if (idx >= custom.length) return fallback;
    final list = custom[idx];
    return (list.isEmpty) ? fallback : list;
  }

  Widget _row(IconData i, String t) {
    return Row(
      children: [
        Icon(i, size: 18, color: Colors.black87),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            t,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
    );
  }

  static Widget _chipIcon(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ——— Screenshot-like extras, reused below ———
  static Widget _complimentPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.camera_alt_outlined, size: 14, color: Colors.black87),
          SizedBox(width: 6),
          Text(
            "Compliment",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _starFab() {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {},
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            Icons.star_border_rounded,
            size: 22,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

// =================== Small data holders ===================
class _SectionData {
  const _SectionData({
    required this.title,
    required this.text,
    required this.image,
    required this.chips,
  });

  final String title;
  final String text;
  final String image;
  final List<_ChipData> chips;
}

class _ChipData {
  const _ChipData(this.text, this.icon);
  final String text;
  final IconData icon;
}

// =================== Widgets ===================

class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({
    required this.images,
    required this.isAsset,
    required this.heroFirstTag,
  });

  final List<String> images; // length == 6
  final bool isAsset;
  final String heroFirstTag;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final _pageCtrl = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl.addListener(() {
      setState(() => _page = _pageCtrl.page ?? 0);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageCtrl,
          itemCount: widget.images.length,
          itemBuilder: (context, i) {
            final img = widget.images[i];
            final ImageProvider imageProvider = widget.isAsset
                ? AssetImage(img)
                : NetworkImage(img);

            final child = DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
            );

            if (i == 0) return Hero(tag: widget.heroFirstTag, child: child);
            return child;
          },
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Row(
            children: List.generate(widget.images.length, (i) {
              final active = (i - _page).abs() < 0.5;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Panel with rounded card, a title and a row/wrap of keyword chips with icons.
/// This matches the "Languages" block in your screenshot.
class _KeywordsPanel extends StatelessWidget {
  const _KeywordsPanel({required this.title, required this.chips});

  final String title;
  final List<_ChipData> chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((c) => _chipWithIcon(c.text, c.icon)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _chipWithIcon(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Big image card (3:4) with optional overlay pill and FAB on the bottom corners.
class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
    required this.image,
    required this.isAsset,
    this.leadingPill,
    this.trailingFab,
  });

  final String image;
  final bool isAsset;
  final Widget? leadingPill;
  final Widget? trailingFab;

  @override
  Widget build(BuildContext context) {
    final ImageProvider imgProvider = isAsset
        ? AssetImage(image)
        : NetworkImage(image);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  image: DecorationImage(image: imgProvider, fit: BoxFit.cover),
                ),
              ),
            ),
            if (leadingPill != null)
              Positioned(left: 12, bottom: 12, child: leadingPill!),
            if (trailingFab != null)
              Positioned(right: 12, bottom: 12, child: trailingFab!),
          ],
        ),
      ),
    );
  }
}

// =============== Defaults builder ===============
class _SectionDefaults {
  _SectionDefaults({
    required this.excitedAbout,
    required this.greenFlags,
    required this.weekendVibe,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p4,
  });

  final String excitedAbout;
  final String greenFlags;
  final String weekendVibe;
  final String p1;
  final String p2;
  final String p3;
  final String p4;

  factory _SectionDefaults.fallback({
    required String name,
    required List<String> interests,
    required String city,
  }) {
    final likeA = interests.isNotEmpty ? interests[0] : "good coffee";
    final likeB = interests.length > 1 ? interests[1] : "long walks";
    final likeC = interests.length > 2 ? interests[2] : "live music";

    return _SectionDefaults(
      excitedAbout:
          "Trying new cafés, catching golden-hour photos, and planning trips I may or may not take. If there’s $likeA involved, I’m in.",
      greenFlags:
          "Shows up on time, tips the staff, texts with intention, and laughs at terrible puns. Bonus if you like $likeB.",
      weekendVibe:
          "Slow mornings, a quick workout, street food run in $city, then a movie or board games with friends.",
      p1: "Currently obsessed with playlists that make chores feel like a montage.",
      p2: "Walk, chai, and a view. Nothing fancy—just easy conversation and room to be ourselves.",
      p3: "I can parallel park like a pro. I once learned the alphabet backwards. I totally enjoy pineapple on pizza. (One of these is a lie.)",
      p4: "We put too much pressure on ‘perfect.’ Consistency > grand gestures. Also: nap rights for adults.",
    );
  }
}
