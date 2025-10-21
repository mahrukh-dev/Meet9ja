import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meet9ja/constants/app_colors.dart';
import 'package:meet9ja/screens/home_screen.dart';
import 'package:meet9ja/screens/sign_up_screen.dart';
import '../db_functions/firebase_service.dart';

class Signinscreen extends StatefulWidget {
  const Signinscreen({super.key});

  @override
  State<Signinscreen> createState() => _SigninscreenState();
}

class _SigninscreenState extends State<Signinscreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  static const double kSide = 20.0;
  bool _isLoading = false;
  bool _rememberMe = false;

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
      final user = await FirebaseService.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      // 🎯 Check if email is verified (Email 2FA)
      if (user != null && !user.emailVerified) {
        _showEmailNotVerifiedDialog(user);
        return;
      }

      // 🎯 SUCCESS: Navigate to the main application page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );

    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEmailNotVerifiedDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Not Verified'),
        content: const Text('Please verify your email address before logging in. Check your inbox for the verification link.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendVerificationEmail(user);
            },
            child: const Text('Resend Verification'),
          ),
        ],
      ),
    );
  }

  void _sendVerificationEmail(User user) async {
    try {
      setState(() => _isLoading = true);
      await user.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification email sent to ${user.email}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorDialog('Failed to send verification email: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() async {
    if (_emailCtrl.text.isEmpty) {
      _showErrorDialog('Please enter your email address to reset password.');
      return;
    }

    final email = _emailCtrl.text.trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send password reset instructions to $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendPasswordResetEmail(email);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      setState(() => _isLoading = true);
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Reset Email Sent'),
          content: Text('Check your email $email for password reset instructions.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorDialog('Failed to send password reset email: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    // Clean up Firebase-specific error messages for users
    String cleanMessage = message;

    if (message.contains('user-not-found') || message.contains('wrong-password')) {
      cleanMessage = 'Invalid email or password. Please try again.';
    } else if (message.contains('too-many-requests')) {
      cleanMessage = 'Too many login attempts. Please try again later.';
    } else if (message.contains('network-request-failed')) {
      cleanMessage = 'Network error. Please check your internet connection.';
    } else if (message.contains('user-disabled')) {
      cleanMessage = 'This account has been disabled. Please contact support.';
    } else if (message.contains('invalid-email')) {
      cleanMessage = 'Please enter a valid email address.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Failed'),
        content: Text(cleanMessage),
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

                      // Back button
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),

                      const SizedBox(height: 20),
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
                      const SizedBox(height: 16),

                      // Remember Me & Forgot Password Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Remember Me
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                activeColor: AppColors.primary,
                              ),
                              Text(
                                'Remember me',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),

                          // Forgot Password
                          TextButton(
                            onPressed: _isLoading ? null : _forgotPassword,
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
                          onPressed: _isLoading ? null : () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const SignUpScreen()),
                            );
                          },
                          child: Text(
                            "Don't have an account? Register Here",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Loading Overlay
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
        fillColor: AppColors.primary,
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
        backgroundColor: AppColors.primary,
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