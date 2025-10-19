import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../db_functions/image_service.dart';
import '../db_functions/user_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel userProfile;
  const EditProfileScreen({super.key, required this.userProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _ageController;
  late TextEditingController _websiteController;
  late TextEditingController _instagramController;
  late TextEditingController _twitterController;
  late TextEditingController _facebookController;
  late TextEditingController _tiktokController;
  late TextEditingController _youtubeController;

  List<File> _selectedPhotos = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadCurrentPhotos();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.userProfile.name);
    _usernameController = TextEditingController(text: widget.userProfile.username);
    _bioController = TextEditingController(text: widget.userProfile.bio ?? '');
    _locationController = TextEditingController(text: widget.userProfile.location ?? '');
    _ageController = TextEditingController(text: widget.userProfile.age.toString());
    _websiteController = TextEditingController(text: widget.userProfile.website ?? '');

    // Initialize social media controllers (you might need to add these fields to your UserModel)
    _instagramController = TextEditingController();
    _twitterController = TextEditingController();
    _facebookController = TextEditingController();
    _tiktokController = TextEditingController();
    _youtubeController = TextEditingController();
  }

  void _loadCurrentPhotos() {
    // You can load current photos here if needed
    // For now, we'll start with empty selection
    _selectedPhotos = [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _ageController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAddPhoto() async {
    try {
      File? imageFile = await ImageService.pickImageFromGallery();
      if (imageFile != null && mounted) {
        setState(() {
          if (_selectedPhotos.length < 4) {
            _selectedPhotos.add(imageFile);
          }
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? widget.userProfile.age,
        'website': _websiteController.text.trim(),
        // Add social media updates when you add these fields to your UserModel
        // 'instagram': _instagramController.text.trim(),
        // 'twitter': _twitterController.text.trim(),
        // 'facebook': _facebookController.text.trim(),
        // 'tiktok': _tiktokController.text.trim(),
        // 'youtube': _youtubeController.text.trim(),
      };

      // Upload new photos if any were selected
      if (_selectedPhotos.isNotEmpty) {
        setState(() {
          _isUploading = true;
        });

        final photoUrls = await ImageService.uploadFirstPhotos(
          userId: widget.userProfile.uid,
          photoFiles: _selectedPhotos,
        );

        updates['first_photos'] = photoUrls;

        setState(() {
          _isUploading = false;
        });
      }

      await UserService.updateUserProfile(
        userId: widget.userProfile.uid,
        updates: updates,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to update profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Photos Section
                  _buildPhotosSection(),
                  const SizedBox(height: 24),

                  // Basic Information
                  _buildSectionHeader('Basic Information'),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: FontAwesomeIcons.user,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      if (value.length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: FontAwesomeIcons.at,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      if (value.length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                        return 'Username can only contain letters, numbers, and underscores';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _ageController,
                    label: 'Age',
                    icon: FontAwesomeIcons.cakeCandles,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your age';
                      }
                      final age = int.tryParse(value);
                      if (age == null || age < 18 || age > 100) {
                        return 'Please enter a valid age between 18 and 100';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Bio Section
                  _buildSectionHeader('Bio'),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'About Me',
                      labelStyle: const TextStyle(color: Colors.black54),
                      hintText: 'Tell people about yourself...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    maxLength: 500,
                  ),
                  const SizedBox(height: 24),

                  // Location Section
                  _buildSectionHeader('Location'),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _locationController,
                    label: 'Location',
                    icon: FontAwesomeIcons.locationDot,
                  ),
                  const SizedBox(height: 24),

                  // Website Section
                  _buildSectionHeader('Website'),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _websiteController,
                    label: 'Website URL',
                    icon: FontAwesomeIcons.globe,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 32),

                  // Social Media Section (Optional - you can add this later)
                  // _buildSocialMediaSection(),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Uploading overlay
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Uploading photos...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Profile Photos'),
        const SizedBox(height: 8),
        const Text(
          'Add up to 4 photos. The first photo will be your main profile picture.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 120,
          child: Row(
            children: [
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                  children: [
                    // Display selected photos
                    ..._selectedPhotos.asMap().entries.map((entry) {
                      int index = entry.key;
                      File photo = entry.value;
                      return _PhotoTile(
                        imageFile: photo,
                        onRemove: () => _removePhoto(index),
                      );
                    }).toList(),

                    // Add button if less than 4 photos
                    if (_selectedPhotos.length < 4)
                      _AddPhotoTile(onTap: _pickAndAddPhoto),

                    // Empty slots
                    ...List.generate(
                      4 - _selectedPhotos.length - (_selectedPhotos.length < 4 ? 1 : 0),
                          (index) => const _EmptyPhotoTile(),
                    ),
                  ].sublist(0, 4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  // Optional: Social Media Section
  Widget _buildSocialMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Social Media'),
        const SizedBox(height: 16),

        _buildSocialMediaField(
          controller: _instagramController,
          label: 'Instagram',
          icon: FontAwesomeIcons.instagram,
          prefix: '@',
        ),
        const SizedBox(height: 12),

        _buildSocialMediaField(
          controller: _twitterController,
          label: 'Twitter',
          icon: FontAwesomeIcons.xTwitter,
          prefix: '@',
        ),
        const SizedBox(height: 12),

        _buildSocialMediaField(
          controller: _facebookController,
          label: 'Facebook',
          icon: FontAwesomeIcons.facebook,
        ),
        const SizedBox(height: 12),

        _buildSocialMediaField(
          controller: _tiktokController,
          label: 'TikTok',
          icon: FontAwesomeIcons.tiktok,
          prefix: '@',
        ),
        const SizedBox(height: 12),

        _buildSocialMediaField(
          controller: _youtubeController,
          label: 'YouTube',
          icon: FontAwesomeIcons.youtube,
        ),
      ],
    );
  }

  Widget _buildSocialMediaField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String prefix = '',
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: _getSocialMediaColor(icon), size: 20),
        prefixText: prefix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _getSocialMediaColor(icon)),
        ),
      ),
    );
  }

  Color _getSocialMediaColor(IconData icon) {
    switch (icon) {
      case FontAwesomeIcons.instagram:
        return const Color(0xFFE4405F);
      case FontAwesomeIcons.xTwitter:
        return Colors.black;
      case FontAwesomeIcons.facebook:
        return const Color(0xFF1877F2);
      case FontAwesomeIcons.tiktok:
        return Colors.black;
      case FontAwesomeIcons.youtube:
        return const Color(0xFFFF0000);
      default:
        return AppColors.primary;
    }
  }
}

// Photo Tile Components
class _PhotoTile extends StatelessWidget {
  final File imageFile;
  final VoidCallback onRemove;

  const _PhotoTile({
    required this.imageFile,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(imageFile),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: const Icon(
          FontAwesomeIcons.plus,
          color: AppColors.primary,
          size: 24,
        ),
      ),
    );
  }
}

class _EmptyPhotoTile extends StatelessWidget {
  const _EmptyPhotoTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
        ),
      ),
      child: const Icon(
        FontAwesomeIcons.photoFilm,
        color: Colors.grey,
        size: 20,
      ),
    );
  }
}