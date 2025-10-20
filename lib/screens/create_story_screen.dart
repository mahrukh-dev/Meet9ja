import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../constants/app_colors.dart';
import '../db_functions/user_service.dart';
import '../db_functions/image_service.dart';

class CreateStoryScreen extends StatefulWidget {
  final String userId;
  const CreateStoryScreen({super.key, required this.userId});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File? _selectedMedia;
  String _mediaType = 'image'; // 'image' or 'video'
  bool _isLoading = false;
  VideoPlayerController? _videoController;

  Future<void> _pickMedia() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show option to pick image or video
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose Media Type'),
          content: const Text('Select from gallery or camera'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Text('Camera'),
            ),
          ],
        ),
      );

      if (source == null) return;

      // Let user choose between image and video
      final mediaType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Media Type'),
          content: const Text('Choose what type of story to create'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'image'),
              child: const Text('Photo'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'video'),
              child: const Text('Video'),
            ),
          ],
        ),
      );

      if (mediaType == null) return;

      if (mediaType == 'image') {
        final XFile? imageFile = await picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1080,
          maxHeight: 1920,
        );
        if (imageFile != null && mounted) {
          setState(() {
            _selectedMedia = File(imageFile.path);
            _mediaType = 'image';
          });
        }
      } else {
        final XFile? videoFile = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 15), // Limit to 15 seconds
        );
        if (videoFile != null && mounted) {
          setState(() {
            _selectedMedia = File(videoFile.path);
            _mediaType = 'video';
            _initializeVideoPlayer();
          });
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to pick media: $e');
    }
  }

  void _initializeVideoPlayer() {
    if (_selectedMedia != null && _mediaType == 'video') {
      _videoController = VideoPlayerController.file(_selectedMedia!)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController!.play();
          }
        });
    }
  }

  // In CreateStoryScreen, update the _createStory method:

  Future<void> _createStory() async {
    if (_selectedMedia == null) {
      _showErrorDialog('Please select media for your story');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload media to Firebase Storage
      final String mediaUrl = await ImageService.uploadStoryMedia(
        mediaFile: _selectedMedia!,
        userId: widget.userId,
        mediaType: _mediaType,
      );

      print('✅ Media uploaded: $mediaUrl');

      // Create story in Firestore
      await UserService.createStory(
        userId: widget.userId,
        mediaUrl: mediaUrl,
        mediaType: _mediaType,
      );

      print('✅ Story created in Firestore');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Add a small delay to ensure the story is properly saved
        await Future.delayed(const Duration(milliseconds: 500));

        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Error creating story: $e');
      if (mounted) {
        _showErrorDialog('Failed to create story: $e');
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

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Create Story',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
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
          else if (_selectedMedia != null)
            TextButton(
              onPressed: _createStory,
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
      body: Column(
        children: [
          // Media Preview
          Expanded(
            child: GestureDetector(
              onTap: _pickMedia,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                ),
                child: _selectedMedia != null
                    ? _mediaType == 'image'
                    ? Image.file(
                  _selectedMedia!,
                  fit: BoxFit.contain,
                )
                    : _videoController != null &&
                    _videoController!.value.isInitialized
                    ? AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
                    : const Center(child: CircularProgressIndicator())
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 80,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to select photo or video',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Videos up to 15 seconds',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose Media'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (_selectedMedia != null)
                  ElevatedButton.icon(
                    onPressed: _createStory,
                    icon: const Icon(Icons.send),
                    label: const Text('Share Story'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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