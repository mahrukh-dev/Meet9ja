import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_colors.dart';
import 'home_screen.dart';

class SelfieOnboardingScreen extends StatefulWidget {
  const SelfieOnboardingScreen({super.key});
  @override
  State<SelfieOnboardingScreen> createState() => _SelfieOnboardingScreenState();
}

class _SelfieOnboardingScreenState extends State<SelfieOnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _introCtrl;
  late final AnimationController _tapCtrl;

  late final Animation<double> _floatAnim;
  late final Animation<double> _introFade;
  late final Animation<Offset> _introSlide;
  late final Animation<double> _tapScale;

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat();

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _floatAnim = Tween(
      begin: -8.0,
      end: 8.0,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_floatCtrl);

    _introFade = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);
    _introSlide = Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_introCtrl);

    _tapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.97), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.0), weight: 50),
    ]).animate(_tapCtrl);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _introCtrl.dispose();
    _tapCtrl.dispose();
    super.dispose();
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final fileName = 'user_profiles/${user.uid}/profile.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photo_url': downloadUrl},
      );

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _completeUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profile_completed': true,
        'onboarding_completed': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('✅ User profile marked as complete');
    } catch (e) {
      print('❌ Error completing user profile: $e');
    }
  }

  void _showCameraPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Access Required'),
        content: const Text('Meet9ja needs camera access to take your profile selfie.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
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

  Future<bool> _validateSelfie(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      final sizeInMB = fileSize / (1024 * 1024);

      if (sizeInMB > 5) {
        _showErrorDialog('Selfie is too large (${sizeInMB.toStringAsFixed(1)}MB). Please take a smaller photo.');
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating selfie: $e');
      return true;
    }
  }

  Future<void> _takeSelfie() async {
    await _tapCtrl.forward();
    await _tapCtrl.reverse();

    try {
      final permissionStatus = await Permission.camera.status;
      if (!permissionStatus.isGranted) {
        final requestedStatus = await Permission.camera.request();
        if (!requestedStatus.isGranted) {
          _showCameraPermissionDialog();
          return;
        }
      }

      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile == null) return;

      final file = File(pickedFile.path);

      final isValid = await _validateSelfie(file);
      if (!isValid) {
        return;
      }

      setState(() => _isUploading = true);

      final url = await _uploadImageToFirebase(file);

      setState(() => _isUploading = false);

      if (url != null && mounted) {
        await _completeUserProfile();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selfie uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showErrorDialog('Camera error: $e');
    }
  }

  void _skipSelfie() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'selfie_skipped': true,
          'onboarding_completed': true,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      print('Error skipping selfie: $e');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      GestureDetector(
                        onTap: _skipSelfie,
                        child: const Text(
                          "Skip",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: _introFade,
                      child: SlideTransition(
                        position: _introSlide,
                        child: AnimatedBuilder(
                          animation: _floatCtrl,
                          builder: (context, _) => Transform.translate(
                            offset: Offset(0, _floatAnim.value),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _PulseRings(controller: _pulseCtrl),
                                Icon(
                                  CupertinoIcons.camera,
                                  size: 148,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Dot(active: true),
                    SizedBox(width: 8),
                    _Dot(active: false),
                  ],
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ScaleTransition(
                    scale: _tapScale,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 8,
                          shadowColor: AppColors.primary.withOpacity(0.45),
                        ),
                        onPressed: _isUploading ? null : _takeSelfie,
                        child: _isUploading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          "Take a selfie",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.only(bottom: 22.0),
                  child: Text(
                    "Don't worry, we won't share it with anyone",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRings extends StatelessWidget {
  const _PulseRings({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [_ring(1.0, t), _ring(0.6, (t + 0.5) % 1.0)],
        );
      },
    );
  }

  Widget _ring(double maxScale, double t) {
    final scale = 0.7 + (maxScale - 0.7) * t;
    final opacity = (1 - t).clamp(0.0, 1.0) * 0.6;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withOpacity(opacity),
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: active ? 12 : 8,
      height: active ? 12 : 8,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.black26,
        shape: BoxShape.circle,
        boxShadow: active
            ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.45),
            blurRadius: 10,
            spreadRadius: 1.5,
          ),
        ]
            : null,
      ),
    );
  }
}