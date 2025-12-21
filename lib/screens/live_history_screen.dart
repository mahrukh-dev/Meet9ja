import 'dart:async';
import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/live_history_model.dart';

class LiveHistoryScreen extends StatefulWidget {
  final LiveHistory liveHistory;

  const LiveHistoryScreen({super.key, required this.liveHistory});

  @override
  State<LiveHistoryScreen> createState() => _LiveHistoryScreenState();
}

class _LiveHistoryScreenState extends State<LiveHistoryScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isRetrying = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      if (_isRetrying) {
        await _clearVideoResources();
      }

      setState(() {
        _isLoading = true;
        _hasError = false;
        _isRetrying = false;
      });

      final videoUrl = widget.liveHistory.liveReplayMediaUrl;

      if (videoUrl.isEmpty) {
        throw Exception('No replay URL available for this stream');
      }

      // Validate video format
      if (!_isVideoFormatSupported(videoUrl)) {
        throw Exception('Unsupported video format. Try opening in browser.');
      }

      // Check network connectivity
      if (!await _checkNetworkConnectivity()) {
        throw Exception('No internet connection. Please check your network and try again.');
      }

      // Initialize video controller with options
      _videoController = VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      // Set timeout for video initialization
      _timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (_isLoading) {
          _handleTimeout();
        }
      });

      await _videoController.initialize();

      // Cancel timeout since initialization succeeded
      _timeoutTimer?.cancel();

      // Check if video has errors
      if (_videoController.value.hasError) {
        throw Exception('Video format not supported: ${_videoController.value.errorDescription}');
      }

      // Configure Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'Loading video...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Playback Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retryVideoPlayer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry Playback'),
                  ),
                ],
              ),
            ),
          );
        },
        // Add additional video player options
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        showControlsOnInitialize: false,
        aspectRatio: _videoController.value.aspectRatio,
      );

      // Listen for video controller errors
      _videoController.addListener(() {
        if (_videoController.value.hasError) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = _videoController.value.errorDescription ?? 'Unknown video error';
            });
          }
        }
      });

      setState(() {
        _isLoading = false;
      });

    } on TimeoutException catch (e) {
      _handleTimeoutError('Video loading timed out. The video might be too large or have connection issues.');
    } on SocketException catch (e) {
      _handleNetworkError('Network error: ${e.message}');
    } on PlatformException catch (e) {
      _handlePlatformError(e);
    } catch (e) {
      _handleGenericError(e);
    }
  }

  bool _isVideoFormatSupported(String url) {
    final supportedFormats = [
      '.mp4', '.m3u8', '.mov', '.avi', '.webm', '.mkv',
      '.flv', '.wmv', '.mpg', '.mpeg', '.3gp'
    ];
    return supportedFormats.any((format) => url.toLowerCase().contains(format));
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void _handleTimeout() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Video loading timed out. The video might be too large or have connection issues.';
      });
      _clearVideoResources();
    }
  }

  void _handleTimeoutError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = message;
      });
    }
  }

  void _handleNetworkError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = message;
      });
    }
  }

  void _handlePlatformError(PlatformException e) {
    String userMessage;

    if (e.code.contains('ExoPlaybackException') ||
        e.code.contains('MediaCodecVideoRenderer')) {
      userMessage = 'Video codec not supported on this device. Try opening in browser.';
    } else if (e.message?.contains('404') == true ||
        e.message?.contains('not found') == true) {
      userMessage = 'Video file not found. The replay may have been deleted.';
    } else if (e.message?.contains('Unauthorized') == true ||
        e.message?.contains('403') == true) {
      userMessage = 'You don\'t have permission to view this video.';
    } else {
      userMessage = 'Video player error: ${e.message ?? 'Unknown error'}';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = userMessage;
      });
    }
  }

  void _handleGenericError(dynamic e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = _getUserFriendlyErrorMessage(e);
      });
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('ExoPlaybackException') ||
        errorString.contains('MediaCodecVideoRenderer')) {
      return 'Video format not supported on this device. Try opening in browser instead.';
    }

    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Video file not found. The replay may have been deleted.';
    }

    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'Connection timeout. Check your internet and try again.';
    }

    if (errorString.contains('Unauthorized') || errorString.contains('403')) {
      return 'You don\'t have permission to view this video.';
    }

    if (errorString.contains('Format:') || errorString.contains('video/')) {
      return 'Video codec not supported. Please try another device or browser.';
    }

    return 'Failed to load video: ${error.toString().split('\n').first}';
  }

  Future<void> _clearVideoResources() async {
    try {
      await _videoController?.pause();
      await _videoController?.dispose();
      // await _chewieController?.dispose();
      _chewieController = null;
      _timeoutTimer?.cancel();
    } catch (e) {
      print('Error clearing video resources: $e');
    }
  }

  Future<void> _retryVideoPlayer() async {
    setState(() {
      _isRetrying = true;
    });
    await _initializeVideoPlayer();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.liveHistory.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showStreamInfo,
            tooltip: 'Stream Info',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _retryVideoPlayer,
            tooltip: 'Refresh Video',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    return Column(
      children: [
        // Video Player
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _videoController.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            ),
          ),
        ),

        // Stream Info Section
        _buildStreamInfo(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 3,
                ),
              ),
              Icon(
                Icons.videocam,
                size: 40,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading stream replay...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            widget.liveHistory.title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _openInBrowser,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            child: const Text('Open in Browser Instead'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load stream replay',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _retryVideoPlayer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Try Again'),
                ),
                OutlinedButton.icon(
                  onPressed: _openInBrowser,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.open_in_browser, size: 20),
                  label: const Text('Open in Browser'),
                ),

              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Video URL: ${widget.liveHistory.liveReplayMediaUrl}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            widget.liveHistory.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.people,
                'Viewers',
                '${widget.liveHistory.viewerCount}',
              ),
              _buildStatItem(
                Icons.card_giftcard,
                'Gifts',
                '${widget.liveHistory.totalGiftValue}',
              ),
              _buildStatItem(
                Icons.timer,
                'Duration',
                '${_formatDuration(widget.liveHistory.durationSeconds)}',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stream Date
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                _formatDate(widget.liveHistory.endTime),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status
          Row(
            children: [
              const Icon(Icons.info, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'Status: ${_getStatusText(widget.liveHistory.uploadStatus)}',
                style: TextStyle(
                  color: _getStatusColor(widget.liveHistory.uploadStatus),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Video Format Info
          if (!_hasError && _videoController.value.isInitialized)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, size: 14, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    '${_videoController.value.size.width.toInt()}x${_videoController.value.size.height.toInt()} • ${_formatDuration(_videoController.value.duration.inSeconds)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white70),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM d, y • h:mm a').format(date);
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'partial_success':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'success':
        return 'Completed';
      case 'partial_success':
        return 'Partial Recording';
      case 'failed':
        return 'Recording Failed';
      default:
        return 'Unknown';
    }
  }

  void _showStreamInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Stream Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildInfoRow('Title', widget.liveHistory.title),
                  _buildInfoRow('Viewers', '${widget.liveHistory.viewerCount}'),
                  _buildInfoRow('Gifts', '${widget.liveHistory.totalGiftValue} coins'),
                  _buildInfoRow('Duration', '${_formatDuration(widget.liveHistory.durationSeconds)}'),
                  _buildInfoRow('Status', _getStatusText(widget.liveHistory.uploadStatus)),
                  _buildInfoRow('Recording Type', widget.liveHistory.recordingType),
                  _buildInfoRow('Date', _formatDate(widget.liveHistory.endTime)),
                  _buildInfoRow('Video URL', widget.liveHistory.liveReplayMediaUrl),
                  if (!_hasError && _videoController.value.isInitialized)
                    _buildInfoRow(
                      'Video Resolution',
                      '${_videoController.value.size.width.toInt()}x${_videoController.value.size.height.toInt()}',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _copyVideoUrl,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      child: const Text('Copy URL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _copyVideoUrl() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.liveHistory.liveReplayMediaUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('URL copied to clipboard'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy URL: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _shareStream() {
    // For now, just copy the URL. You can integrate with share_plus package for better sharing
    _copyVideoUrl();
  }

  void _openInBrowser() async {
    final url = widget.liveHistory.liveReplayMediaUrl;
    if (url.isEmpty) return;

    try {
      String cleanedUrl = url;
      if (!cleanedUrl.startsWith('http://') && !cleanedUrl.startsWith('https://')) {
        cleanedUrl = 'https://$cleanedUrl';
      }

      final Uri uri = Uri.parse(cleanedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } else {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening URL: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}