import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meet9ja/discover_page.dart';
import 'package:meet9ja/profile_setup.dart';

import 'db_functions/firebase_service.dart';


class Signinscreen extends StatefulWidget {
  const Signinscreen({super.key});

  @override
  State<Signinscreen> createState() => _SigninscreenState();
}

class _SigninscreenState extends State<Signinscreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  static const Color kPrimary = Color(0xFFE43AA8);
  static const double kSide = 20.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      _showErrorDialog('Please enter both email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseService.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      // 🎯 SUCCESS: Navigate to the main application page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DiscoverPage()),
      );

    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Failed'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSide),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),
                      _H1("Welcome Back"),
                      const SizedBox(height: 8),
                      const _BodyText("Sign in to continue discovering new connections."),
                      const SizedBox(height: 48),

                      // Email Field
                      const _SectionLabel("Email"),
                      const SizedBox(height: 10),
                      _PinkField(
                        controller: _emailCtrl,
                        hint: "Enter your email",
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      const _SectionLabel("Password"),
                      const SizedBox(height: 10),
                      _PinkField(
                        controller: _passwordCtrl,
                        hint: "Enter your password",
                        obscureText: true,
                      ),
                      const SizedBox(height: 40),

                      // Login Button
                      _PrimaryButton(
                        text: _isLoading ? 'Signing In...' : 'Sign In',
                        onTap: _isLoading ? null : _login,
                      ),

                      const SizedBox(height: 20),

                      // Registration Link
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const ProfileSetupPage()),
                            );
                          },
                          child: Text(
                            "Don't have an account? Register Here",
                            style: TextStyle(color: kPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Back button is optional for a dedicated login screen, but you can add it if needed.
            ],
          ),
        ),
      ),
    );
  }
}


// ===== Reusing UI components (Assume these are moved to a shared file or copied) =====

// NOTE: For a real app, you should extract these into a separate shared_ui.dart file!
// For this example, we'll redefine them or assume they are accessible.

class _H1 extends StatelessWidget { /* ... same as in ProfileSetupPage ... */
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

class _BodyText extends StatelessWidget { /* ... same as in ProfileSetupPage ... */
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

class _SectionLabel extends StatelessWidget { /* ... same as in ProfileSetupPage ... */
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

class _PinkField extends StatelessWidget { /* ... same as in ProfileSetupPage ... */
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
        fillColor: _SigninscreenState.kPrimary,
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

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _PrimaryButton({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _SigninscreenState.kPrimary,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}