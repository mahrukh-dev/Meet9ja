import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meet9ja/screens/selfie_onboarding_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_colors.dart';
import '../constants/privacy_policy_popup.dart';
import '../constants/terms_condition_popup.dart';
import '../db_functions/firebase_service.dart';
import '../db_functions/image_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final PageController _page = PageController();
  int _step = 0;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  int? _modeIndex = 1;
  int? _travelWithIndex = 3;
  bool _acceptedTerms = false;

  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  String _usernameError = '';
  Timer? _usernameDebounceTimer;

  // Photo management
  List<File> _selectedPhotos = [];
  bool _isUploadingPhotos = false;

  static const double kSide = 20.0;

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _ageCtrl.dispose();
    _usernameCtrl.dispose();
    _usernameDebounceTimer?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_step == 0) return true;

    final shouldExit = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Registration?'),
        content: const Text('Your progress will be lost. Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  void _checkUsernameAvailability(String username) {
    _usernameDebounceTimer?.cancel();

    final trimmedUsername = username.trim();

    if (trimmedUsername.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameError = '';
      });
      return;
    }

    if (trimmedUsername.length < 3) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameError = 'Username must be at least 3 characters';
      });
      return;
    }

    // More lenient username validation
    if (!_isValidUsername(trimmedUsername)) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameError = 'Username can contain letters, numbers, dots, and underscores';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = '';
    });

    _usernameDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final isAvailable = await FirebaseService.isUsernameAvailable(trimmedUsername);

        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = isAvailable;
            _usernameError = isAvailable ? '' : 'Username is already taken';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            // Don't show error message for checking, just indicate not available
            _isUsernameAvailable = false;
          });
        }
      }
    });
  }

  bool _isValidUsername(String username) {
    // More lenient regex: allows letters, numbers, dots, and underscores
    final usernameRegex = RegExp(r'^[a-zA-Z0-9._]+$');
    return usernameRegex.hasMatch(username);
  }

  // Password strength validation
  String? _validatePassword(String password) {
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Include at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one number';
    }
    return null;
  }

  // Age validation
  String? _validateAge(String ageText) {
    if (ageText.isEmpty) {
      return 'Please enter your age';
    }

    final age = int.tryParse(ageText);
    if (age == null) {
      return 'Please enter a valid number';
    }

    if (age < 18) {
      return 'You must be at least 18 years old';
    }

    if (age > 100) {
      return 'Please enter a valid age';
    }

    return null;
  }

  // Photo quality validation
  Future<bool> _validatePhotoQuality(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      final sizeInMB = fileSize / (1024 * 1024);

      if (sizeInMB > 10) { // 10MB limit
        _showErrorDialog('Photo is too large (${sizeInMB.toStringAsFixed(1)}MB). Maximum size is 10MB.');
        return false;
      }

      if (sizeInMB < 0.01) { // 10KB minimum
        _showErrorDialog('Photo is too small. Please choose a higher quality image.');
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating photo: $e');
      return true; // Continue anyway if validation fails
    }
  }

  // Photo handling methods
  Future<void> _pickAndAddPhoto() async {
    try {
      _showLoadingDialog('Opening gallery...');

      File? imageFile = await ImageService.pickImageFromGallery();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (imageFile != null && mounted) {
        // Validate photo quality
        final isValid = await _validatePhotoQuality(imageFile);
        if (!isValid) return;

        if (_selectedPhotos.length < 4) {
          setState(() {
            _selectedPhotos.add(imageFile);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo added successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          _showErrorDialog('Maximum 4 photos allowed. Please remove one to add another.');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show appropriate error message
        if (e.toString().contains('permission') ||
            e.toString().contains('Permission') ||
            e.toString().contains('access denied') ||
            e.toString().contains('denied')) {
          _showPermissionDialog(e.toString());
        } else {
          _showErrorDialog(e.toString());
        }
      }
    }
  }

  Future<void> _pickMultiplePhotos() async {
    try {
      _showLoadingDialog('Opening gallery...');

      List<File> imageFiles = await ImageService.pickMultipleImagesFromGallery();

      if (mounted) {
        Navigator.pop(context);
      }

      if (imageFiles.isNotEmpty && mounted) {
        // Validate all photos first
        for (final imageFile in imageFiles) {
          final isValid = await _validatePhotoQuality(imageFile);
          if (!isValid) return;
        }

        int remainingSlots = 4 - _selectedPhotos.length;

        if (remainingSlots > 0) {
          int imagesToAdd = imageFiles.length > remainingSlots ? remainingSlots : imageFiles.length;

          setState(() {
            _selectedPhotos.addAll(imageFiles.take(imagesToAdd));
          });

          if (imageFiles.length > remainingSlots) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added $imagesToAdd photos (maximum 4 total)'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${imageFiles.length} photos successfully!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          _showErrorDialog('You already have 4 photos. Please remove some to add more.');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);

        if (e.toString().contains('permission') ||
            e.toString().contains('Permission') ||
            e.toString().contains('access denied') ||
            e.toString().contains('denied')) {
          _showPermissionDialog(e.toString());
        } else {
          _showErrorDialog(e.toString());
        }
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo removed'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showPermissionDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gallery Access Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meet9ja needs access to your photos to select profile pictures.',
            ),
            const SizedBox(height: 10),
            Text(
              'Error: ${errorMessage.contains('denied') ? 'Permission was denied' : 'Permission required'}',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please grant photo access permission to continue:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text('• Go to Device Settings'),
            const Text('• Tap on "Apps" or "Application Manager"'),
            const Text('• Find "Meet9ja"'),
            const Text('• Tap on "Permissions"'),
            const Text('• Enable "Photos" or "Storage" permission'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              // After returning from settings, check if permission is granted
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissionAndRetry();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPermissionAndRetry() async {
    try {
      print('🔍 Checking permission status after settings...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please try selecting photos again after granting permission'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ Error checking permission: $e');
    }
  }

  void _next() async {
    if (_step < 3) {
      // Validate current step before proceeding
      if (_step == 1 && _selectedPhotos.length < 2) {
        _showErrorDialog('Please add at least 2 photos to continue');
        return;
      }

      setState(() => _step++);
      _page.animateToPage(
        _step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      // Final validation and registration
      await _completeRegistration();
    }
  }

  Future<void> _completeRegistration() async {
    // Validate all fields before registration
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty ||
        _ageCtrl.text.isEmpty ||
        _usernameCtrl.text.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    // Validate name
    if (_nameCtrl.text.trim().isEmpty) {
      _showErrorDialog('Please enter your name');
      return;
    }

    // Validate username
    final trimmedUsername = _usernameCtrl.text.trim();
    if (!_isValidUsername(trimmedUsername)) {
      _showErrorDialog('Username can contain letters, numbers, dots, and underscores');
      return;
    }

    if (trimmedUsername.length < 3) {
      _showErrorDialog('Username must be at least 3 characters long');
      return;
    }

    // Check username availability one more time before registration
    if (!_isUsernameAvailable) {
      _showErrorDialog('Username "$trimmedUsername" is not available. Please choose a different one.');
      return;
    }

    // Validate age
    final ageError = _validateAge(_ageCtrl.text.trim());
    if (ageError != null) {
      _showErrorDialog(ageError);
      return;
    }

    // Validate email format
    if (!_isValidEmail(_emailCtrl.text.trim())) {
      _showErrorDialog('Please enter a valid email address');
      return;
    }

    // Validate password
    final passwordError = _validatePassword(_passwordCtrl.text);
    if (passwordError != null) {
      _showErrorDialog(passwordError);
      return;
    }

    // Validate photos
    if (_selectedPhotos.length < 2) {
      _showErrorDialog('Please add at least 2 photos');
      return;
    }

    // Validate terms acceptance
    if (!_acceptedTerms) {
      _showErrorDialog('Please accept the Terms of Service and Privacy Policy');
      return;
    }

    // Show loading dialog
    _showLoadingDialog('Creating your account...');

    try {
      setState(() => _isUploadingPhotos = true);

      print('📝 Starting registration process...');
      print('📧 Email: ${_emailCtrl.text.trim()}');
      print('👤 Username: $trimmedUsername');
      print('📸 Photos to upload: ${_selectedPhotos.length}');

      await FirebaseService.completeRegistration(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        age: int.parse(_ageCtrl.text.trim()),
        username: trimmedUsername,
        selectedMode: _getSelectedMode(),
        travelPreference: _getTravelPreference(),
        photoFiles: _selectedPhotos,
      );

      // Send email verification
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('✅ Verification email sent to ${user.email}');
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        print('✅ Registration successful, navigating to next screen');

        // Show email verification reminder
        _showVerificationReminder();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        print('❌ Registration error in UI: $e');
        _showErrorDialog('Registration failed: $e');

        // Show email verification reminder
        _showVerificationReminder();
      }
    } finally {
      setState(() => _isUploadingPhotos = false);
    }
  }

  void _showVerificationReminder() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Your Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We\'ve sent a verification email to:'),
            Text(
              _emailCtrl.text.trim(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Please check your inbox and verify your email to complete registration.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelfieOnboardingScreen()),
              );
            },
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resendVerificationEmail();
            },
            child: const Text('Resend Email'),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent to ${user.email}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Failed to resend verification email: $e');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          color: Colors.white,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
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
                        CupertinoIcons.back,
                        color: Colors.black87,
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
            const SizedBox(height: 20),

            // Name
            const _SectionLabel("Name"),
            const SizedBox(height: 5),
            _PinkField(
              controller: _nameCtrl,
              hint: "Enter your name",
            ),
            const SizedBox(height: 10),

            // Email
            const _SectionLabel("Email"),
            const SizedBox(height: 5),
            _PinkField(
              controller: _emailCtrl,
              hint: "Enter your email",
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),

            // Username with validation
            const _SectionLabel("Username"),
            const SizedBox(height: 5),
            _UsernameField(
              controller: _usernameCtrl,
              hint: "Choose a username",
              onChanged: _checkUsernameAvailability,
              isChecking: _isCheckingUsername,
              isAvailable: _isUsernameAvailable,
              errorText: _usernameError,
            ),
            const SizedBox(height: 10),

            // Password
            const _SectionLabel("Password"),
            const SizedBox(height: 5),
            _PinkField(
              controller: _passwordCtrl,
              hint: "Create a password",
              obscureText: true,
            ),
            if (_passwordCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _validatePassword(_passwordCtrl.text) ?? 'Password strength: Good',
                style: TextStyle(
                  color: _validatePassword(_passwordCtrl.text) == null ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Age with validation
            const _SectionLabel("Age"),
            const SizedBox(height: 5),
            _PinkField(
              controller: _ageCtrl,
              hint: "Enter your age (18+)",
              keyboardType: TextInputType.number,
              onChanged: (value) {
                // Real-time age validation
                final error = _validateAge(value);
                setState(() {});
              },
            ),
            if (_ageCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _validateAge(_ageCtrl.text) ?? 'Age accepted',
                style: TextStyle(
                  color: _validateAge(_ageCtrl.text) == null ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Terms of Service
            Row(
              children: [
                Checkbox(
                  value: _acceptedTerms,
                  onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black87, fontSize: 12),
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => const TermsConditionsPopup(),
                              );
                            },
                            child: Text(
                              'Terms of Service',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' and '),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => const PrivacyPolicyPopup(),
                              );
                            },
                            child: Text(
                              'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
          _H1("Add your photos"),
          const SizedBox(height: 8),
          const _BodyText("Choose 2-4 photos for your profile"),
          const SizedBox(height: 20),

          // Photo selection buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickAndAddPhoto,
                  icon: const Icon(Icons.add_photo_alternate, size: 20),
                  label: const Text('Add Single Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickMultiplePhotos,
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: const Text('Add Multiple'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Photos grid
          Expanded(
            child: _selectedPhotos.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_camera_back,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No photos yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the buttons above to add photos\nfrom your gallery',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _selectedPhotos.length,
              itemBuilder: (context, index) {
                return _PhotoTile.image(
                  imageFile: _selectedPhotos[index],
                  onTap: () => _removePhoto(index),
                );
              },
            ),
          ),

          // Photo counter and validation
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  '${_selectedPhotos.length}/4 Photos Added',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _selectedPhotos.length >= 2 ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                if (_selectedPhotos.length < 2)
                  Text(
                    'Add at least 2 photos to continue',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  )
                else if (_selectedPhotos.length == 4)
                  Text(
                    'Maximum photos reached',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeStep() {
    final items = const [
      {'title': 'Date', 'subtitle': 'Make moves to find that spark'},
      {'title': 'Travel partner', 'subtitle': 'Make travel buddies'},
      {'title': 'BFF', 'subtitle': 'Make friends and find community'},
      {'title': 'Bizz', 'subtitle': 'Move your career forward'},
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
                final title = items[i]['title']!;
                final sub = items[i]['subtitle']!;
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

// ===== Username Field with Validation =====
class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool isChecking;
  final bool isAvailable;
  final String errorText;

  const _UsernameField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.isChecking,
    required this.isAvailable,
    required this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          cursorColor: Colors.white,
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
            suffixIcon: isChecking
                ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
                : controller.text.trim().length >= 3
                ? Icon(
              isAvailable ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
            )
                : null,
          ),
          onChanged: onChanged,
        ),
        if (errorText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            errorText,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ] else if (controller.text.trim().length >= 3 && isAvailable) ...[
          const SizedBox(height: 4),
          Text(
            'Username is available!',
            style: TextStyle(
              color: Colors.green[600],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

// ===== PhotoTile Widget =====
class _PhotoTile extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final File? imageFile;

  const _PhotoTile(this.child, {this.onTap, this.imageFile});

  factory _PhotoTile.add({VoidCallback? onTap}) {
    return _PhotoTile(
      const Icon(CupertinoIcons.add, size: 42, color: AppColors.primary),
      onTap: onTap,
    );
  }

  factory _PhotoTile.empty() {
    return _PhotoTile(
      const Icon(CupertinoIcons.photo, size: 38, color: Colors.grey),
    );
  }

  factory _PhotoTile.image({required File imageFile, VoidCallback? onTap}) {
    return _PhotoTile(
      const SizedBox.shrink(),
      onTap: onTap,
      imageFile: imageFile,
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
          border: Border.all(
            color: imageFile != null ? Colors.transparent : AppColors.primary.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            if (imageFile != null)
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: imageFile != null
            ? Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                imageFile!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            if (onTap != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        )
            : Center(child: child),
      ),
    );
  }
}

// ===== UI Component Widgets =====
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
            widthFactor: progress.clamp(0.0, 1.0),
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

class _PinkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _PinkField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: Colors.white,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      onChanged: onChanged,
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