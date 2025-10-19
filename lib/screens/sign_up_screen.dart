import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meet9ja/screens/selfie_onboarding_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_colors.dart';
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

  final TextEditingController _nameCtrl = TextEditingController(text: "John");
  final TextEditingController _emailCtrl = TextEditingController(text: "test@example.com");
  final TextEditingController _passwordCtrl = TextEditingController(text: "123456");
  final TextEditingController _ageCtrl = TextEditingController(text: "25");
  final TextEditingController _usernameCtrl = TextEditingController(text: "john_doe");
  int? _modeIndex = 1;
  int? _travelWithIndex = 3;

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

  void _checkUsernameAvailability(String username) {
    _usernameDebounceTimer?.cancel();

    if (username.length < 3) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameError = username.isEmpty ? '' : 'Username must be at least 3 characters';
      });
      return;
    }

    if (!_isValidUsername(username)) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameError = 'Username can only contain letters, numbers, and underscores';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = '';
    });

    _usernameDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final isAvailable = await FirebaseService.isUsernameAvailable(username);

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
            _usernameError = 'Error checking username availability';
          });
        }
      }
    });
  }

  bool _isValidUsername(String username) {
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    return usernameRegex.hasMatch(username);
  }

  // Photo handling methods
  Future<void> _pickAndAddPhoto() async {
    try {
      // Show loading indicator
      _showLoadingDialog('Accessing your photos...');

      File? imageFile = await ImageService.pickImageFromGallery();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (imageFile != null && mounted) {
        if (_selectedPhotos.length < 4) {
          setState(() {
            _selectedPhotos.add(imageFile);
          });

          // Show success message
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

        // Handle permission errors specifically
        if (e.toString().contains('permission') || e.toString().contains('Permission')) {
          _showPermissionDialog();
        } else {
          _showErrorDialog(e.toString());
        }
      }
    }
  }

  Future<void> _pickMultiplePhotos() async {
    try {
      _showLoadingDialog('Accessing your photos...');

      List<File> imageFiles = await ImageService.pickMultipleImagesFromGallery();

      if (mounted) {
        Navigator.pop(context);
      }

      if (imageFiles.isNotEmpty && mounted) {
        int remainingSlots = 4 - _selectedPhotos.length;

        if (remainingSlots > 0) {
          int imagesToAdd = imageFiles.length > remainingSlots ? remainingSlots : imageFiles.length;

          setState(() {
            _selectedPhotos.addAll(imageFiles.take(imagesToAdd));
          });

          // Show appropriate message
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

        if (e.toString().contains('permission') || e.toString().contains('Permission')) {
          _showPermissionDialog();
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

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Meet9ja needs access to your photos to select profile pictures. '
              'This allows you to choose photos from your gallery for your profile.\n\n'
              'Please grant photo access permission to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
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

    if (!_isValidUsername(_usernameCtrl.text.trim())) {
      _showErrorDialog('Username can only contain letters, numbers, and underscores');
      return;
    }

    if (_usernameCtrl.text.length < 3) {
      _showErrorDialog('Username must be at least 3 characters long');
      return;
    }

    // Check username availability one more time before registration
    if (!_isUsernameAvailable) {
      _showErrorDialog('Please choose an available username');
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

    // Validate photos
    if (_selectedPhotos.length < 2) {
      _showErrorDialog('Please add at least 2 photos');
      return;
    }

    // Show loading dialog
    _showLoadingDialog('Creating your account...');

    try {
      // Upload photos first
      setState(() => _isUploadingPhotos = true);

      Map<String, String> photoUrls = await ImageService.uploadFirstPhotos(
        userId: 'temp_user_id', // We'll update this after user creation
        photoFiles: _selectedPhotos,
      );

      // Complete registration with photo URLs
      await FirebaseService.completeRegistration(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        age: age,
        username: _usernameCtrl.text.trim(),
        selectedMode: _getSelectedMode(),
        travelPreference: _getTravelPreference(),
        firstPhotos: photoUrls,
      );

      // Navigate to next screen
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SelfieOnboardingScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showErrorDialog(e.toString());
      }
    } finally {
      setState(() => _isUploadingPhotos = false);
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
    return Scaffold(
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
            const SizedBox(height: 10),

            // Age
            const _SectionLabel("Age"),
            const SizedBox(height: 5),
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
                : controller.text.length >= 3
                ? Icon(
              isAvailable ? Icons.check_circle : Icons.cancel,
              color: isAvailable ? Colors.white : Colors.white,
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
        ] else if (controller.text.length >= 3 && isAvailable) ...[
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

  const _PhotoTile._(this.child, {this.onTap, this.imageFile});

  factory _PhotoTile.add({VoidCallback? onTap}) {
    return _PhotoTile._(
      const Icon(CupertinoIcons.add, size: 42, color: AppColors.primary),
      onTap: onTap,
    );
  }

  factory _PhotoTile.empty() {
    return const _PhotoTile._(
      Icon(CupertinoIcons.photo, size: 38, color: Colors.grey),
    );
  }

  factory _PhotoTile.image({required File imageFile, VoidCallback? onTap}) {
    return _PhotoTile._(
      Container(), // Placeholder, we'll build the image in build method
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