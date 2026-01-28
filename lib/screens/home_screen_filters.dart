import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import 'home_screen.dart';

class HomeScreenFilters extends StatefulWidget {
  const HomeScreenFilters({super.key});

  @override
  State<HomeScreenFilters> createState() => _HomeScreenFiltersState();
}

class _HomeScreenFiltersState extends State<HomeScreenFilters> {
  // --- Basic Filters
  String whoToDate = "Women"; // Default for male users
  RangeValues age = const RangeValues(18, 60); // Full age range
  bool flexAgeIfRunOut = true;
  String location = "Any distance";
  bool flexLocationIfRunOut = true;

  final List<String> allInterests = [
    "🎨 Art",
    "📝 Writing",
    "🎟️ Gigs",
    "📺 Horror",
    "🎵 Music",
    "🏃 Fitness",
    "🍳 Cooking",
    "✈️ Travel",
    "📚 Reading",
    "🎬 Movies",
    "🎮 Gaming",
    "🍽️ Foodie",
    "🏋️‍♂️ Gym",
    "🌳 Nature",
    "📸 Photography",
    "🎤 Singing",
    "💃 Dancing",
    "🧘‍♀️ Yoga",
    "🏀 Sports",
    "🔬 Science",
  ];

  final Set<String> selectedInterests = {};
  bool flexInterestIfRunOut = true;
  bool verifiedOnly = false; // Default: show both verified and unverified

  // --- Advanced Filters
  RangeValues heightCm = const RangeValues(140, 200); // Full height range
  bool flexHeightIfRunOut = true;

  final List<_CheckItem> intentions = [
    _CheckItem("A long-term relationship"),
    _CheckItem("Fun, casual dates"),
    _CheckItem("Marriage"),
    _CheckItem("Intimacy, without commitment"),
    _CheckItem("A life partner"),
    _CheckItem("Ethical non-monogamy"),
  ];
  bool flexIntentIfRunOut = false;

  int tabIndex = 0;
  bool _isLoading = false;

  // Store current user's gender
  String _currentUserGender = 'male'; // Default to male

  @override
  void initState() {
    super.initState();
    _getCurrentUserGender();
    _loadUserPreferences();
  }

  // Get current user's gender
  Future<void> _getCurrentUserGender() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final gender = (userData['gender'] ?? 'male').toString().toLowerCase();
        setState(() {
          _currentUserGender = gender;
          // Set default whoToDate based on user's gender
          whoToDate = gender == 'male' ? 'Women' : 'Men';
        });
      }
    } catch (e) {
      print('Error getting user gender: $e');
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      final doc = await FirebaseFirestore.instance
          .collection('preferences')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          whoToDate = data['whoToDate'] ?? (whoToDate); // Use stored or default
          age = RangeValues(
            (data['ageRangeStart'] ?? 18).toDouble(),
            (data['ageRangeEnd'] ?? 60).toDouble(),
          );
          flexAgeIfRunOut = data['flexAgeIfRunOut'] ?? true;
          location = data['locationPreference'] ?? "Any distance";
          flexLocationIfRunOut = data['flexLocationIfRunOut'] ?? true;
          selectedInterests.clear();
          selectedInterests.addAll(
            List<String>.from(data['selectedInterests'] ?? []),
          );
          flexInterestIfRunOut = data['flexInterestIfRunOut'] ?? true;
          verifiedOnly = data['verifiedOnly'] ?? false; // Default to false
          heightCm = RangeValues(
            (data['heightRangeStart'] ?? 140).toDouble(),
            (data['heightRangeEnd'] ?? 200).toDouble(),
          );
          flexHeightIfRunOut = data['flexHeightIfRunOut'] ?? true;

          final savedIntentions = List<String>.from(data['intentions'] ?? []);
          for (final intention in intentions) {
            intention.checked = savedIntentions.contains(intention.label);
          }

          flexIntentIfRunOut = data['flexIntentIfRunOut'] ?? false;
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      final preferencesData = {
        'UID': user.uid,
        'whoToDate': whoToDate,
        'ageRangeStart': age.start.toInt(),
        'ageRangeEnd': age.end.toInt(),
        'flexAgeIfRunOut': flexAgeIfRunOut,
        'locationPreference': location,
        'flexLocationIfRunOut': flexLocationIfRunOut,
        'selectedInterests': selectedInterests.toList(),
        'flexInterestIfRunOut': flexInterestIfRunOut,
        'verifiedOnly': verifiedOnly,
        'heightRangeStart': heightCm.start.toInt(),
        'heightRangeEnd': heightCm.end.toInt(),
        'flexHeightIfRunOut': flexHeightIfRunOut,
        'intentions': intentions.where((i) => i.checked).map((i) => i.label).toList(),
        'flexIntentIfRunOut': flexIntentIfRunOut,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('preferences')
          .doc(user.uid)
          .set(preferencesData, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Filters saved successfully! Profiles will refresh.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving filters: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.kGradA, AppColors.kGradB, AppColors.kGradC],
          ),
        ),
        child: CustomPaint(
          painter: _BackgroundLines(),
          child: SafeArea(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
                : Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(FontAwesomeIcons.xmark, size: 22),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          "Narrow your search",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Segmented tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _Segmented(
                    left: "Basic filters",
                    right: "Advanced filters",
                    index: tabIndex,
                    onChanged: (i) => setState(() => tabIndex = i),
                  ),
                ),

                const SizedBox(height: 8),

                // Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: tabIndex == 0 ? _buildBasic() : _buildAdvanced(),
                  ),
                ),

                // Bottom actions
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: BorderSide(
                              color: Colors.black26.withOpacity(0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _resetAll,
                          child: const Text("Reset to Default"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                          ),
                          onPressed: _savePreferences,
                          child: const Text(
                            "Apply filters",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- BASIC ----------------
  Widget _buildBasic() {
    return SingleChildScrollView(
      key: const ValueKey("basic"),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle("Who would you like to date?"),
          _ValueTile(value: whoToDate, onTap: () => _openWhoSheet()),
          const SizedBox(height: 18),

          const _SectionTitle("Where are they?"),
          _ValueTile(value: location, onTap: () => _openLocationSheet()),
          const SizedBox(height: 8),
          _CardBox(
            child: _SwitchLine(
              label: "Show people outside this range if I run out",
              value: flexLocationIfRunOut,
              onChanged: (v) => setState(() => flexLocationIfRunOut = v),
            ),
          ),
          const SizedBox(height: 18),

          const _SectionTitle("How old are they?"),
          _CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Between ${age.start.round()} and ${age.end.round()}",
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                RangeSlider(
                  values: age,
                  min: 18,
                  max: 60,
                  divisions: 42,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => age = v),
                ),
                const SizedBox(height: 4),
                _SwitchLine(
                  label: "See people 2 years either side if I run out",
                  value: flexAgeIfRunOut,
                  onChanged: (v) => setState(() => flexAgeIfRunOut = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const _SectionTitle("Do they share any of your interests?"),
          const SizedBox(height: 6),
          const Text(
            "Filter by your interests",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 10),
          _CardBox(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in allInterests)
                  _InterestChip(
                    label: i,
                    selected: selectedInterests.contains(i),
                    onTap: () {
                      setState(() {
                        if (selectedInterests.contains(i)) {
                          selectedInterests.remove(i);
                        } else {
                          selectedInterests.add(i);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'll try to show you people who share any one of the interests you select.",
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          _SwitchLine(
            label: "Show other people if I run out",
            value: flexInterestIfRunOut,
            onChanged: (v) => setState(() => flexInterestIfRunOut = v),
          ),

          const SizedBox(height: 20),
          const _SectionTitle("Have they verified themselves?"),
          _CardBox(
            child: _SwitchLine(
              label: "Verified profiles only",
              value: verifiedOnly,
              onChanged: (v) => setState(() => verifiedOnly = v),
              icon: FontAwesomeIcons.certificate,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- ADVANCED ----------------
  Widget _buildAdvanced() {
    final bool anyHeight =
        heightCm.start <= 140 && heightCm.end >= 200;

    return SingleChildScrollView(
      key: const ValueKey("advanced"),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle("How tall are they?"),
          _CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anyHeight
                      ? "Any height is just fine"
                      : "Between ${heightCm.start.round()} cm and ${heightCm.end.round()} cm",
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                RangeSlider(
                  values: heightCm,
                  min: 140,
                  max: 200,
                  divisions: 60,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => heightCm = v),
                ),
                _SwitchLine(
                  label: "Show other people if I run out",
                  value: flexHeightIfRunOut,
                  onChanged: (v) => setState(() => flexHeightIfRunOut = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const _SectionTitle("What are they looking for?"),
          _CardBox(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Column(
              children: [
                for (final it in intentions)
                  CheckboxListTile(
                    value: it.checked,
                    onChanged: (v) => setState(() => it.checked = v ?? false),
                    title: Text(it.label),
                    activeColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _SwitchLine(
            label: "Show other people if I run out",
            value: flexIntentIfRunOut,
            onChanged: (v) => setState(() => flexIntentIfRunOut = v),
          ),
        ],
      ),
    );
  }

  // ---------------- Helpers ----------------
  void _openWhoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final options = ["Women", "Men", "Everyone"];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
              for (final o in options)
                ListTile(
                  title: Text(
                    o,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: whoToDate == o
                      ? const Icon(
                    FontAwesomeIcons.check,
                    size: 16,
                    color: AppColors.primary,
                  )
                      : null,
                  onTap: () {
                    setState(() => whoToDate = o);
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  void _openLocationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final options = [
          "5 miles (Near Me)",
          "10 miles (New York, NY)",
          "25 miles (New Jersey)",
          "50 miles (Pennsylvania)",
          "Any distance",
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
              for (final o in options)
                ListTile(
                  title: Text(
                    o,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: location == o
                      ? const Icon(
                    FontAwesomeIcons.check,
                    size: 16,
                    color: AppColors.primary,
                  )
                      : null,
                  onTap: () {
                    setState(() => location = o);
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  void _resetAll() {
    setState(() {
      // Set gender based on current user's gender
      if (_currentUserGender == 'male') {
        whoToDate = "Women"; // Male users see females
      } else {
        whoToDate = "Men"; // Female users see males
      }

      // Full age range (18-60)
      age = const RangeValues(18, 60);
      flexAgeIfRunOut = true;

      // Any location
      location = "Any distance";
      flexLocationIfRunOut = true;

      // No specific interests
      selectedInterests.clear();
      flexInterestIfRunOut = true;

      // Show both verified and unverified profiles
      verifiedOnly = false;

      // Full height range
      heightCm = const RangeValues(140, 200);
      flexHeightIfRunOut = true;

      // No specific intentions
      for (final it in intentions) it.checked = false;
      flexIntentIfRunOut = false;

      tabIndex = 0;
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reset to default: ${_currentUserGender == 'male' ? 'Women' : 'Men'}, All ages, Verified & Unverified',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ================== UI Bits ==================

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.right,
    required this.index,
    required this.onChanged,
  });

  final String left;
  final String right;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
      ),
      child: Row(children: [_segBtn(left, 0), _segBtn(right, 1)]),
    );
  }

  Expanded _segBtn(String text, int i) {
    final selected = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(i),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black54,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(FontAwesomeIcons.chevronRight, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _CardBox extends StatelessWidget {
  const _CardBox({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.7)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Switch.adaptive(
          value: value,
          activeColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        selected ? label : "$label  +",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.black12.withOpacity(0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _CheckItem {
  _CheckItem(this.label);
  final String label;
  bool checked = false;
}

// ---- Background painter (same theme) ----
class _BackgroundLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB388EB).withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const step = 140.0;
    for (double r = step; r < size.width * 1.5; r += step) {
      canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}