import 'package:flutter/material.dart';

class OthersProfileScreen extends StatelessWidget {
  const OthersProfileScreen({
    super.key,
    required this.name,
    required this.age,
    required this.job,
    required this.edu,
    required this.image,
    required this.isAsset,
    this.verified = false,
    this.newHere = false,
    this.bio,
    this.interests = const [],
    this.distanceKm,
    this.location,
  });

  final String name;
  final int age;
  final String job;
  final String edu;
  final String image;
  final bool isAsset;
  final bool verified;
  final bool newHere;

  final String? bio;
  final List<String> interests;
  final int? distanceKm;
  final String? location;

  ImageProvider get _imgProvider =>
      isAsset ? AssetImage(image) : NetworkImage(image) as ImageProvider;
  @override
  Widget build(BuildContext context) {
    final flagGreen = const Color(0xFF008751);
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            centerTitle: false,
            elevation: 0,
            expandedHeight: 420,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
              color: Colors.white,
              tooltip: "Back",
            ),
            actions: [
              IconButton(
                tooltip: "Share",
                onPressed: () {},
                icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'profile-img-$image',
                    child: Image(image: _imgProvider, fit: BoxFit.cover),
                  ),
                  // top gradient shade
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),
                  // bottom chips & name
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (newHere) _chip("New here"),
                              if (verified)
                                _chipIcon("Photo verified", Icons.verified),
                              if (distanceKm != null)
                                _chip("${distanceKm} km away"),
                              if (location != null)
                                _chipIcon(location!, Icons.place_outlined),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "$name, $age",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _roundIcon(
                                context,
                                icon: Icons.favorite_rounded,
                                bg: flagGreen,
                                fg: Colors.white,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("You liked $name"),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(
                                        milliseconds: 900,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ===== Content =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(
                    title: "About",
                    child: Text(
                      bio?.trim().isNotEmpty == true
                          ? bio!.trim()
                          : "Hi, I’m $name. I like good coffee, long walks, and stealing the aux. "
                                "Currently working as $job. Studied at $edu.",
                      style: const TextStyle(
                        fontSize: 15.5,
                        color: Colors.black87,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _divider(),

                  const SizedBox(height: 14),
                  _section(
                    title: "Basics",
                    child: Column(
                      children: [
                        _tile(
                          icon: Icons.work_outline,
                          label: "Work",
                          value: job,
                        ),
                        _tile(
                          icon: Icons.school_outlined,
                          label: "Education",
                          value: edu,
                        ),
                        if (location != null)
                          _tile(
                            icon: Icons.place_outlined,
                            label: "Location",
                            value: location!,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _divider(),

                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section(
                      title: "Interests",
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: interests.map((e) => _tag(e)).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _divider(),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                              color: Colors.black12,
                              width: 1.5,
                            ),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Say hi 👋 (demo)"),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(milliseconds: 900),
                              ),
                            );
                          },
                          label: const Text(
                            "Message",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.favorite),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: flagGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("You liked $name"),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(milliseconds: 900),
                              ),
                            );
                          },
                          label: const Text(
                            "Like",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- UI bits ----
  static Widget _section({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  static Widget _divider() => const Divider(height: 1, color: Colors.black12);

  static Widget _tile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget _chipIcon(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 5),
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

  static Widget _roundIcon(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    required Color bg,
    required Color fg,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: fg, size: 22),
        ),
      ),
    );
  }
}
