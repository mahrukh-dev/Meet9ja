// lib/filter.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'discover_page.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  static const kPrimary = Color(0xFFE43AA8);
  static const kGradA = Color(0xFFFDF2F8);
  static const kGradB = Color(0xFFF8EAFE);
  static const kGradC = Color(0xFFFFF7FB);

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  // --- Basic
  String whoToDate = "Women";
  RangeValues age = const RangeValues(18, 28);
  bool flexAgeIfRunOut = true;

  final List<String> allInterests = [
    "🎨 Art",
    "📝 Writing",
    "🎟️ Gigs",
    "📺 Horror",
    "🎵 Music",
    "🏃 Fitness",
    "🍳 Cooking",
  ];
  final Set<String> selectedInterests = {
    "🎨 Art",
    "📝 Writing",
    "🎟️ Gigs",
    "📺 Horror",
  };
  bool flexInterestIfRunOut = true;
  bool verifiedOnly = true;

  // --- Advanced
  RangeValues heightCm = const RangeValues(140, 200);
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

  int tabIndex = 0; // 0: Basic, 1: Advanced

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [FilterPage.kGradA, FilterPage.kGradB, FilterPage.kGradC],
          ),
        ),
        child: CustomPaint(
          painter: _BackgroundLines(),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
                  child: Row(
                    children: [
                      // cross -> back to Discover
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 26),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DiscoverPage(),
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
                      const SizedBox(width: 40), // balance
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
                          child: const Text("Reset"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FilterPage.kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                          ),
                          onPressed: () {
                            // yahan tum apni filter apply logic laga do
                            Navigator.pop(context); // close after apply
                          },
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
                  activeColor: FilterPage.kPrimary,
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
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- ADVANCED ----------------
  Widget _buildAdvanced() {
    final bool anyHeight =
        heightCm.start <= 140 && heightCm.end >= 200; // full span selected

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
                  activeColor: FilterPage.kPrimary,
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
                    activeColor: FilterPage.kPrimary,
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
                          Icons.check_rounded,
                          color: FilterPage.kPrimary,
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

  void _resetAll() {
    setState(() {
      whoToDate = "Women";
      age = const RangeValues(18, 28);
      flexAgeIfRunOut = true;
      selectedInterests
        ..clear()
        ..addAll({"🎨 Art", "📝 Writing", "🎟️ Gigs", "📺 Horror"});
      flexInterestIfRunOut = true;
      verifiedOnly = true;

      heightCm = const RangeValues(140, 200);
      flexHeightIfRunOut = true;
      for (final it in intentions) it.checked = false;
      flexIntentIfRunOut = false;
      tabIndex = 0;
    });
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
            color: selected ? FilterPage.kPrimary : Colors.transparent,
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
        trailing: const Icon(Icons.chevron_right_rounded),
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
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Switch.adaptive(
          value: value,
          activeColor: FilterPage.kPrimary,
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
      selectedColor: FilterPage.kPrimary,
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
