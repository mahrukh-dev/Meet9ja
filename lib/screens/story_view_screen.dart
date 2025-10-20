import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import '../db_functions/user_service.dart';

class StoryViewScreen extends StatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;
  const StoryViewScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadCurrentStory();
  }

  void _loadCurrentStory() {
    final currentStory = widget.stories[_currentIndex];

    // Mark as viewed
    UserService.markStoryAsViewed(currentStory.id, UserService.currentUserId!);

    // Initialize video if needed
    if (currentStory.mediaType == 'video') {
      _videoController = VideoPlayerController.network(currentStory.mediaUrl)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
            _videoController!.play();
          }
        });
    } else {
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = true;
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _loadCurrentStory();
  }

  void _onTapDown(TapDownDetails details) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dx = details.globalPosition.dx;

    if (dx < screenWidth / 3) {
      // Tap on left side - previous story
      if (_currentIndex > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
        );
      } else {
        Navigator.pop(context);
      }
    } else {
      // Tap on right side - next story
      if (_currentIndex < widget.stories.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStory = widget.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        child: Stack(
          children: [
            // Story Content
            PageView.builder(
              controller: _pageController,
              itemCount: widget.stories.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final story = widget.stories[index];
                return _StoryContent(
                  story: story,
                  videoController: index == _currentIndex ? _videoController : null,
                  isVideoInitialized: index == _currentIndex ? _isVideoInitialized : true,
                );
              },
            ),

            // Progress Indicators
            Positioned(
              top: 40,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(widget.stories.length, (index) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index == _currentIndex ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Close Button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryContent extends StatelessWidget {
  final StoryModel story;
  final VideoPlayerController? videoController;
  final bool isVideoInitialized;

  const _StoryContent({
    required this.story,
    this.videoController,
    required this.isVideoInitialized,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Media
        if (story.mediaType == 'image')
          Image.network(
            story.mediaUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        else if (story.mediaType == 'video' && isVideoInitialized && videoController != null)
          AspectRatio(
            aspectRatio: videoController!.value.aspectRatio,
            child: VideoPlayer(videoController!),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Gradient Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
            ),
          ),
        ),

        // Time Remaining
        Positioned(
          top: 80,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${story.timeRemaining.inHours}h ${story.timeRemaining.inMinutes.remainder(60)}m',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),

        // Viewers Count
        Positioned(
          bottom: 80,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${story.viewers.length} views',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}