// lib/conversation.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class ConversationScreen extends StatefulWidget {
  final String name;
  final String avatar;

  /// messages: List of maps: { 'other': bool, 'text': String }
  final List<Map<String, dynamic>> messages;

  const ConversationScreen({
    super.key,
    required this.name,
    required this.avatar,
    required this.messages,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late List<Map<String, dynamic>> msgs;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    msgs = List<Map<String, dynamic>>.from(widget.messages);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      msgs.add({'other': false, 'text': txt});
      _ctrl.clear();
    });
    // Optionally scroll — left out for brevity
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // keep background white to match your design
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with back, avatar, name, call + video buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
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
                          Text(
                            widget.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Online", // placeholder — replace with real status if you have it
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Audio call
                    IconButton(
                      onPressed: () => _startCall(video: false),
                      icon: const Icon(Icons.call, color: Colors.black87),
                    ),

                    // Video call
                    IconButton(
                      onPressed: () => _startCall(video: true),
                      icon: const Icon(Icons.videocam, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              // Messages list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final bool other = m['other'] as bool;
                    final align = other
                        ? Alignment.centerLeft
                        : Alignment.centerRight;
                    final bg = other
                        ? Colors.white
                        : Colors.grey.withOpacity(0.12);
                    final fg = Colors.black87;
                    return Align(
                      alignment: align,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
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
                        child: Text(
                          m['text'] as String,
                          style: TextStyle(color: fg, fontSize: 15.5),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Input
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: TextField(
                            controller: _ctrl,
                            decoration: InputDecoration(
                              hintText: "Type a message…",
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
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Theme.of(context).primaryColor,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _send,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.send,
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
