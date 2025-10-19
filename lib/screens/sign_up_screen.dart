import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meet9ja/screens/selfie_onboarding_screen.dart';

import '../constants/app_colors.dart';
import '../db_functions/firebase_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final PageController _page = PageController();
  int _step = 0;

  final TextEditingController _nameCtrl = TextEditingController(text: "John");
  final TextEditingController _emailCtrl = TextEditingController(text: "test@example.com");
  final TextEditingController _passwordCtrl = TextEditingController(text: "123456");
  final TextEditingController _ageCtrl = TextEditingController(text: "25");
  int? _modeIndex = 1;
  int? _travelWithIndex = 3;

  static const double kSide = 20.0;

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _next() async {
    if (_step < 3) {
      setState(() => _step++);
      _page.animateToPage(
        _step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      // Validate all fields before registration
      if (_nameCtrl.text.isEmpty ||
          _emailCtrl.text.isEmpty ||
          _passwordCtrl.text.isEmpty ||
          _ageCtrl.text.isEmpty) {
        _showErrorDialog('Please fill in all fields');
        return;
      }

      // Validate age
      int? age = int.tryParse(_ageCtrl.text.trim());
      if (age == null || age < 18 || age > 100) {
        _showErrorDialog('Please enter a valid age between 18 and 100');
        return;
      }

      // Validate email format
      if (!_isValidEmail(_emailCtrl.text.trim())) {
        _showErrorDialog('Please enter a valid email address');
        return;
      }

      // Validate password length
      if (_passwordCtrl.text.length < 6) {
        _showErrorDialog('Password must be at least 6 characters long');
        return;
      }

      // Complete registration
      try {
        await FirebaseService.completeRegistration(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          age: age, // Use the validated age
          selectedMode: _getSelectedMode(),
          travelPreference: _getTravelPreference(),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SelfieOnboardingScreen()),
        );
      } catch (e) {
        _showErrorDialog(e.toString());
      }
    }
  }

  // Helper methods
  String _getSelectedMode() {
    switch (_modeIndex) {
      case 0: return 'Date';
      case 1: return 'Travel partner';
      case 2: return 'BFF';
      case 3: return 'Bizz';
      default: return 'Bizz';
    }
  }

  String _getTravelPreference() {
    switch (_travelWithIndex) {
      case 0: return 'Women';
      case 1: return 'Men';
      case 2: return 'Couples';
      case 3: return 'Anyone';
      default: return 'Anyone';
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registration Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _page.animateToPage(
        _step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // ✅ Background set to solid white
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // progress line
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: kSide),
                    child: _ProgressLine(
                      progress: (_step + 1) / 4.0,
                      trackColor: Colors.black12,
                      barColor: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: PageView(
                      controller: _page,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildNameStep(),
                        _buildPhotosStep(),
                        _buildModeStep(),
                        _buildTravelWithStep(),
                      ],
                    ),
                  ),
                ],
              ),

              if (_step > 0)
                Positioned(
                  left: 6,
                  top: 6,
                  child: IconButton(
                    onPressed: _back,
                    icon: const Icon(
                      color: Colors.black87,
                      CupertinoIcons.back,
                    ),
                  ),
                ),

              Positioned(
                right: 20,
                bottom: 24,
                child: FloatingActionButton(
                  onPressed: _next,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: const CircleBorder(),
                  child: const Icon(CupertinoIcons.arrow_right, size: 30),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Step 1: Name & Basic Info ----------
  Widget _buildNameStep() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kSide),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _H1("Let's create your\nprofile"),
            const SizedBox(height: 8),
            const _BodyText("Fill in your basic information to get started"),
            const SizedBox(height: 28),

            // Name
            const _SectionLabel("Name"),
            const SizedBox(height: 10),
            _PinkField(
              controller: _nameCtrl,
              hint: "Enter your name",
            ),
            const SizedBox(height: 20),

            // Email
            const _SectionLabel("Email"),
            const SizedBox(height: 10),
            _PinkField(
              controller: _emailCtrl,
              hint: "Enter your email",
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            // Password
            const _SectionLabel("Password"),
            const SizedBox(height: 10),
            _PinkField(
              controller: _passwordCtrl,
              hint: "Create a password",
              obscureText: true,
            ),
            const SizedBox(height: 20),

            // Age
            const _SectionLabel("Age"),
            const SizedBox(height: 10),
            _PinkField(
              controller: _ageCtrl,
              hint: "Enter your age",
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ---------- Step 2: Photos ----------
  Widget _buildPhotosStep() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kSide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _H1("Add your first 2\nphotos"),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 300,
                child: GridView.count(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _PhotoTile.sample(),
                    _PhotoTile.add(onTap: () {}),
                    _PhotoTile.add(onTap: () {}),
                    _PhotoTile.add(onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ---------- Step 3: Mode ----------
  Widget _buildModeStep() {
    final items = const [
      ("Date", "Make moves to find that spark"),
      ("Travel partner", "Make travel buddies"),
      ("BFF", "Make friends and find community"),
      ("Bizz", "Move your career forward"),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kSide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _H1("Choose a mode to\nget started"),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final (title, sub) = items[i];
                final selected = _modeIndex == i;
                return _SelectCard(
                  title: title,
                  subtitle: sub,
                  selected: selected,
                  onTap: () => setState(() => _modeIndex = i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Step 4: Travel With ----------
  Widget _buildTravelWithStep() {
    final items = const ["Women", "Men", "Couples", "Anyone"];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kSide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _H1("With whom would\nyou like to travel?"),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final selected = _travelWithIndex == i;
                return _RadioCard(
                  label: items[i],
                  selected: selected,
                  onTap: () => setState(() => _travelWithIndex = i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Shared UI bits =====

class _ProgressLine extends StatelessWidget {
  final double progress;
  final Color trackColor;
  final Color barColor;
  const _ProgressLine({
    required this.progress,
    required this.trackColor,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progress.clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _H1 extends StatelessWidget {
  final String text;
  const _H1(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF16151A),
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF2B2930),
        fontSize: 14,
        height: 1.35,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF16151A),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ✅ Pink styled text field for Name
class _PinkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;

  const _PinkField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: Colors.white,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor:AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _PhotoTile._(this.child, {this.onTap});

  factory _PhotoTile.add({VoidCallback? onTap}) {
    return _PhotoTile._(
      const Icon(CupertinoIcons.add, size: 42, color:AppColors.primary),
      onTap: onTap,
    );
  }

  factory _PhotoTile.sample() {
    return const _PhotoTile._(
      Icon(CupertinoIcons.photo, size: 38, color:AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pink = AppColors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? pink : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: pink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
              color: pink,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pink = AppColors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? pink : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: pink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              selected ? CupertinoIcons.circle_filled : CupertinoIcons.circle,
              color: pink,
            ),
          ],
        ),
      ),
    );
  }
}