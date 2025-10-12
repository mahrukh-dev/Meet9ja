// live_stream_page.dart (or the relevant class in your file)
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:camera/camera.dart'; // 👈 Import the camera package

// Note: kPrimary must be accessible or passed in
const Color kPrimary = Color(0xFFE43AA8);

// Global variable to hold available cameras
late List<CameraDescription> cameras;

class LiveStreamPage extends StatefulWidget {
  const LiveStreamPage({super.key});

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  CameraController? _controller;
  CameraDescription? _frontCamera;
  bool _isLive = false;
  bool _isMuted = false;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // 1. Ensure cameras are loaded (should be done on app startup for best results)
      cameras = await availableCameras();

      // 2. Find the front camera
      _frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first, // Fallback to the first available camera
      );

      // 3. Initialize the controller
      _controller = CameraController(
        _frontCamera!,
        ResolutionPreset.high,
        enableAudio: true,
      );

      // 4. Initialize the camera, then mark it ready
      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
      });
    } on CameraException catch (e) {
      // Handle initialization errors (e.g., permissions denied)
      debugPrint("Camera Error: $e");
      setState(() {
        _isCameraReady = false;
      });
    }
  }

  void _toggleLive() {
    setState(() {
      _isLive = !_isLive;
    });
    // Stream logic: In a real app, this is where you'd start/stop the stream
    // using packages like 'agora' or 'janus'.
    if (_isLive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream Started! You are LIVE! 🔴')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream Ended.')),
      );
    }
  }

  @override
  void dispose() {
    // 5. Dispose the controller when the widget is removed
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator until the camera is ready
    if (!_isCameraReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: kPrimary),
        ),
      );
    }

    // Camera Preview takes the place of the placeholder
    return Scaffold(
      body: Stack(
        children: [
          // 1. Actual Camera Feed View
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CameraPreview(_controller!),
          ),

          // 2. Top Controls (Exit and Mic)
          Positioned(
            top: 40,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Exit Button
                _ControlCircle(
                  icon: FontAwesomeIcons.xmark,
                  onTap: () => Navigator.pop(context),
                  color: Colors.black54,
                ),
                // Mic Toggle Button
                _ControlCircle(
                  icon: _isMuted
                      ? FontAwesomeIcons.microphoneSlash
                      : FontAwesomeIcons.microphone,
                  onTap: () => setState(() => _isMuted = !_isMuted),
                  color: _isMuted ? Colors.red.withOpacity(0.8) : Colors.black54,
                ),
              ],
            ),
          ),

          // 3. Bottom Go Live Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _toggleLive,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLive ? Colors.redAccent : kPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  elevation: 10,
                ),
                child: Text(
                  _isLive ? 'END STREAM' : 'GO LIVE',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5
                  ),
                ),
              ),
            ),
          ),

          // 4. Live indicator (only visible when streaming)
          if (_isLive)
            Positioned(
              top: 50,
              left: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// A simple reusable widget for the circular control buttons
class _ControlCircle extends StatelessWidget {
  const _ControlCircle({
    required this.icon,
    required this.onTap,
    this.color = Colors.black54,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}