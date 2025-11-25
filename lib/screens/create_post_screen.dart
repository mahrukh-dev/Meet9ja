import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../aws/video_thumbnail_service.dart';
import '../constants/app_colors.dart';
import '../db_functions/user_service.dart';
import '../db_functions/image_service.dart';
import '../models/post_model.dart';

class CreatePostScreen extends StatefulWidget {
  final String userId;
  const CreatePostScreen({super.key, required this.userId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  File? _selectedMedia;
  bool _isLoading = false;
  String _mediaType = 'image'; // 'image' or 'video'
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final imageFile = await ImageService.pickImageFromGallery();
      if (imageFile != null && mounted) {
        setState(() {
          _selectedMedia = imageFile;
          _mediaType = 'image';
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? videoFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5), // 5 minute limit
      );

      if (videoFile != null && mounted) {
        setState(() {
          _selectedMedia = File(videoFile.path);
          _mediaType = 'video';
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick video: $e');
    }
  }

  Future<void> _showMediaSelection() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Choose Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    if (_selectedMedia == null) {
      _showErrorDialog('Please select media for your post');
      return;
    }

    if (_captionController.text.trim().isEmpty) {
      _showErrorDialog('Please add a caption for your post');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String mediaUrl;
      String? thumbnailUrl;

      if (_mediaType == 'image') {
        // Upload image to Firebase Storage
        mediaUrl = await ImageService.uploadPostImage(
          imageFile: _selectedMedia!,
          userId: widget.userId,
        );
      } else {
        // Upload video to Firebase Storage
        mediaUrl = await ImageService.uploadPostVideo(
          videoFile: _selectedMedia!,
          userId: widget.userId,
        );

        // Generate and upload thumbnail for video
        final thumbnailFile = await VideoThumbnailService.generateThumbnailFromFile(_selectedMedia!);
        if (thumbnailFile != null) {
          thumbnailUrl = await VideoThumbnailService.uploadThumbnail(
            thumbnailFile,
            widget.userId,
            'temp_${DateTime.now().millisecondsSinceEpoch}',
          );
        } else {
          print('⚠️ Could not generate thumbnail for video');
        }
      }

      // Create post in Firestore with thumbnail URL
      await UserService.createPost(
        userId: widget.userId,
        caption: _captionController.text.trim(),
        mediaUrl: mediaUrl,
        type: _mediaType,
        thumbnailUrl: thumbnailUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to create post: $e');
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

  Widget _buildMediaPreview() {
    if (_selectedMedia == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Tap to select media',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Images or Videos',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    if (_mediaType == 'image') {
      return Image.file(
        _selectedMedia!,
        fit: BoxFit.cover,
      );
    } else {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Try to show video thumbnail preview
          FutureBuilder<File?>(
            future: VideoThumbnailService.generateThumbnailFromFile(_selectedMedia!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }

              if (snapshot.hasData && snapshot.data != null) {
                return Image.file(
                  snapshot.data!,
                  fit: BoxFit.cover,
                );
              }

              // Fallback to video icon if thumbnail generation fails
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_filled,
                        size: 60,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Video Preview',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'VIDEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
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
              onPressed: _createPost,
              child: const Text(
                'Share',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Media Selection
            GestureDetector(
              onTap: _showMediaSelection,
              child: Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[300]!,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildMediaPreview(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Media type indicator
            if (_selectedMedia != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _mediaType == 'image' ? Icons.photo : Icons.videocam,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _mediaType == 'image' ? 'Image Post' : 'Video Post',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (_mediaType == 'video') ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Thumbnail will be auto-generated',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),

            const SizedBox(height: 24),

            // Caption
            TextField(
              controller: _captionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Caption',
                labelStyle: const TextStyle(color: Colors.black54),
                hintText: 'Write a caption...',
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
          ],
        ),
      ),
    );
  }
}