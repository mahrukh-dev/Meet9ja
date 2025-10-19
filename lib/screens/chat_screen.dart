// lib/conversation.dart
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

// DEFINE A MOCK ENUM TO REPLACE ImageSource, since the package isn't imported
enum MockImageSource { camera, gallery }


class ChatScreen extends StatefulWidget {
  final String name;
  final String avatar;

  /// messages: List of maps: { 'other': bool, 'text': String, 'type': 'text'/'image'/'vn' }
  final List<Map<String, dynamic>> messages;

  const ChatScreen({
    super.key,
    required this.name,
    required this.avatar,
    required this.messages,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late List<Map<String, dynamic>> msgs;
  final TextEditingController _ctrl = TextEditingController();

  // State to manage whether the user is holding down the voice note button
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    // Ensure messages are initialized, adding 'type' if missing
    msgs = List<Map<String, dynamic>>.from(widget.messages.map((m) => {
      ...m,
      'type': m['type'] ?? 'text',
    }));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // --- Core Message Handlers ---

  void _send({String type = 'text', String? text, String? mediaUrl}) {
    if (type == 'text' && (text?.isEmpty ?? true)) return;
    if (type != 'text' && (mediaUrl?.isEmpty ?? true)) return;

    setState(() {
      msgs.add({
        'other': false,
        'type': type,
        'text': text,
        'mediaUrl': mediaUrl,
      });
      _ctrl.clear();
      // In a real app, you'd scroll to the bottom here
    });
  }

  void _startCall({required bool video}) {
    final kind = video ? "Video call" : "Audio call";
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(kind),
        content: Text("Pretend we're starting a $kind with ${widget.name}."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // --- Media Feature Logic (MOCKED) ---

  void _pickImage({required MockImageSource source}) async {
    final String sourceName = source == MockImageSource.camera ? "Camera" : "Gallery";
    print("MOCK: Attempting to pick image from $sourceName");

    // MOCK SUCCESS: Send a placeholder image message
    _send(
      type: 'image',
      mediaUrl: 'https://via.placeholder.com/200x200.png?text=Image+From+$sourceName',
    );
  }

  void _showMediaOptions() {
    // This is the function triggered by the '+' button
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(CupertinoIcons.camera_fill, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(source: MockImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.photo_fill, color: AppColors.primary),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(source: MockImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startRecording() {
    // MOCK: Start voice note recording
    setState(() => _isRecording = true);
    print("Recording started...");
  }

  void _stopRecording() {
    // MOCK: Stop recording, upload, and send
    setState(() => _isRecording = false);
    print("Recording stopped. Voice note sent.");

    // MOCK SUCCESS: Send a placeholder voice note message
    _send(
      type: 'vn',
      text: '0:05', // Use a simple duration
      mediaUrl: 'vn_file_url',
    );
  }

  // --- Message Bubble Content Builder ---

  Widget _buildMessageContent(Map<String, dynamic> m, bool other) {
    final contentColor = other ? AppColors.primary : Colors.black87;

    switch (m['type']) {
      case 'image':
      // Display Image (using mediaUrl)
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            m['mediaUrl'] as String,
            width: 200, // Fixed size for chat preview
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo),
          ),
        );
      case 'vn':
      // Display Voice Note (MIMICKED)
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Play/Pause Button
            GestureDetector(
              onTap: () {
                print("MOCK: Playing Voice Note: ${m['text']}");
              },
              child: Icon(
                CupertinoIcons.play_circle_fill, // Play button icon
                size: 24,
                color: contentColor,
              ),
            ),

            const SizedBox(width: 12),

            // 2. Waveform Mock
            Expanded(
              child: Container(
                height: 20,
                // MOCK: Placeholder for a visual waveform
                decoration: BoxDecoration(
                  color: contentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    "━━━━━━━━━━━━━━", // Simple visual representation
                    style: TextStyle(
                      color: contentColor.withOpacity(0.7),
                      letterSpacing: 0.5,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 3. Duration Text
            Text(
              m['text'] as String, // e.g., "0:05"
              style: TextStyle(
                fontSize: 13,
                color: contentColor.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case 'text':
      default:
      // Default Text Message
        return Text(
          m['text'] as String,
          style: const TextStyle(color: Colors.black87, fontSize: 15.5),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // --- Top Bar ---
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.arrow_left),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CircleAvatar(
                      backgroundImage: NetworkImage(widget.avatar),
                      radius: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text("Online", style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55))),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _startCall(video: false),
                      icon: const Icon(CupertinoIcons.phone_fill, color: Colors.black87),
                    ),
                    IconButton(
                      onPressed: () => _startCall(video: true),
                      icon: const Icon(CupertinoIcons.video_camera_solid, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              // --- Messages list ---
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final bool other = m['other'] as bool;
                    final align = other ? Alignment.centerLeft : Alignment.centerRight;

                    final bg = other ? Colors.white : AppColors.primary.withOpacity(0.12);

                    final isMedia = m['type'] != 'text';
                    final padding = isMedia
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

                    return Align(
                      alignment: align,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: padding,
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(other ? 4 : 16),
                            bottomRight: Radius.circular(other ? 16 : 4),
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: _buildMessageContent(m, other),
                      ),
                    );
                  },
                ),
              ),

              // --- Input Bar ---
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: Row(
                  children: [
                    // Media Attachment Button
                    InkWell(
                      onTap: _showMediaOptions,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          CupertinoIcons.add_circled_solid,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Text Input Field
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: TextField(
                            controller: _ctrl,
                            decoration: InputDecoration(
                              hintText: _isRecording ? "Recording Voice Note..." : "Type a message…",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _send(text: _ctrl.text),
                            onChanged: (_) => setState(() {}), // Force rebuild to update button icon
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Voice Note / Send Button
                    GestureDetector(
                      // Handle Voice Note recording on press and hold
                      onLongPress: _startRecording,
                      onLongPressUp: _stopRecording,
                      onTap: _isRecording || _ctrl.text.isEmpty
                          ? null // Disable tap if recording or if text field is empty
                          : () => _send(text: _ctrl.text),
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            _isRecording
                                ? CupertinoIcons.mic_fill
                                : (_ctrl.text.isNotEmpty
                                ? CupertinoIcons.arrowtriangle_right_fill // Show send if text is present
                                : CupertinoIcons.mic_fill // Default to mic for voice note long-press
                            ),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}