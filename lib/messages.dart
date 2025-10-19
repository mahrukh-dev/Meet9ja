import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:meet9ja/screens/update_profile_screen.dart';
import 'screens/discover_screen.dart';
import 'constants/app_colors.dart';
import 'conversation.dart';
import 'screens/home_screen.dart';


class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // --- Search State ---
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  // --------------------

  // ---- Stories (top) ----
  final List<_Story> stories = const [
    _Story("You", "https://i.pravatar.cc/150?img=1"),
    _Story("Ayesha", "https://i.pravatar.cc/150?img=22"),
    _Story("Sara", "https://i.pravatar.cc/150?img=24"),
    _Story("Noor", "https://i.pravatar.cc/150?img=26"),
    _Story("Huda", "https://i.pravatar.cc/150?img=28"),
    _Story("Rida", "https://i.pravatar.cc/150?img=30"),
  ];

  // ---- Conversations (list) ----
  final List<_Conversation> chats = [
    _Conversation(
      name: "Ayesha",
      avatar: "https://i.pravatar.cc/200?img=22",
      lastMessage: "Haha yes, let's do Saturday 🎬",
      time: "2:21 PM",
      unread: 2,
      messages: const [
        _Msg(other: true, text: "You free this weekend?"),
        _Msg(other: false, text: "Maybe! Movie night?"),
        _Msg(other: true, text: "Haha yes, let's do Saturday 🎬"),
      ],
    ),
    _Conversation(
      name: "Rumi",
      avatar: "https://i.pravatar.cc/200?img=25",
      lastMessage: "Coffee spot near your office works?",
      time: "11:04 AM",
      unread: 0,
      messages: const [
        _Msg(other: true, text: "I found a cute cafe ☕"),
        _Msg(other: false, text: "Send location!"),
        _Msg(other: true, text: "Coffee spot near your office works?"),
      ],
    ),
    _Conversation(
      name: "Hafsa",
      avatar: "https://i.pravatar.cc/200?img=28",
      lastMessage: "Nice meeting you yesterday 👋",
      time: "Mon",
      unread: 0,
      messages: const [
        _Msg(other: true, text: "Nice meeting you yesterday 👋"),
      ],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Widget _buildTitleBar(BuildContext context) {
    if (_isSearching) {
      // Search Bar View
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Search chats...",
              hintStyle: const TextStyle(color: Colors.black54),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(FontAwesomeIcons.multiply, color: AppColors.primary),
                onPressed: () {
                  _searchController.clear();
                  // Optionally filter results here
                },
              ),
            ),
            onSubmitted: (value) {
              // Handle search submission
            },
          ),
        ),
      );
    } else {
      // Default Title View
      return const Expanded(
        child: Center(
          child: Text(
            "Chats",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body now has a plain white background
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar (now dynamic)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  children: [
                    if (_isSearching)
                      IconButton( // Back arrow when searching
                        // CHANGED TO FONT AWESOME ICON
                        icon: const FaIcon(
                          FontAwesomeIcons.arrowLeft,
                          color: Colors.black87,
                          size: 20, // Match the search icon size
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchController.clear();
                          });
                        },
                      )
                    else
                      const SizedBox(width: 48), // balance for right icon

                    _buildTitleBar(context), // Dynamic title/search input

                    if (!_isSearching) // Only show search icon when not searching
                      IconButton(
                        // Search icon is already FA
                        icon: const FaIcon(
                          FontAwesomeIcons.magnifyingGlass,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearching = true;
                          });
                        },
                      ),
                  ],
                ),
              ),

              // Content as a single scroll view (always shown for now)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  children: [
                    // Stories strip
                    const _SectionHeader("Stories"),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _StoryCircle(story: stories[i]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionHeader("Conversations"),
                    const SizedBox(height: 10),
                    ...List.generate(
                      chats.length,
                          (i) => Column(
                        children: [
                          _ChatTile(
                            chat: chats[i],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConversationScreen(
                                    name: chats[i].name,
                                    avatar: chats[i].avatar,
                                    messages: chats[i].messages
                                        .map(
                                          (m) => {
                                        'other': m.other,
                                        'text': m.text,
                                      },
                                    )
                                        .toList(),
                                  ),
                                ),
                              ).then((_) {
                                // Mark read when returning
                                setState(
                                      () => chats[i] = chats[i].copyWith(unread: 0),
                                );
                              });
                            },
                          ),

                          const Divider(height: 0),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom nav — Chats selected (index 4)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: _BottomNav(current: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Stories ----------
class _StoryCircle extends StatelessWidget {
  const _StoryCircle({required this.story});
  final _Story story;

  @override
  Widget build(BuildContext context) {
    final isYou = story.name == "You";
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isYou
                  ? [AppColors.primary.withOpacity(0.35), Colors.white]
                  : [AppColors.primary, const Color(0xFFFFC107)],
            ),
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(story.avatar),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            story.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ---------- Chat List Tile ----------
class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});
  final _Conversation chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(radius: 26, backgroundImage: NetworkImage(chat.avatar)),
          if (chat.unread > 0)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "${chat.unread}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            chat.time,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.black.withOpacity(0.7),
          fontWeight: chat.unread > 0 ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      // UPDATED TO FA ICON
      trailing: const FaIcon(
        FontAwesomeIcons.chevronRight,
        color: Colors.black26,
        size: 16,
      ),
    );
  }
}

// ---------- Chat Screen (with a few messages) ----------
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conv});
  final _Conversation conv;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  late List<_Msg> msgs;

  @override
  void initState() {
    super.initState();
    // Must clone the list to allow local mutation
    msgs = List<_Msg>.from(widget.conv.messages);
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
      msgs.add(_Msg(other: false, text: txt));
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ChatScreen also uses plain white background now
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CircleAvatar(
                      backgroundImage: NetworkImage(widget.conv.avatar),
                      radius: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.conv.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_vert, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final align = m.other
                        ? Alignment.centerLeft
                        : Alignment.centerRight;
                    final bg = m.other
                        ? Colors.white
                        : AppColors.primary.withOpacity(0.12);
                    final fg = m.other ? Colors.black87 : Colors.black87;
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
                            bottomLeft: Radius.circular(m.other ? 4 : 16),
                            bottomRight: Radius.circular(m.other ? 16 : 4),
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          m.text,
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
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _send,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          // UPDATED TO FA ICON
                          child: FaIcon(
                            FontAwesomeIcons.solidPaperPlane,
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

// ---------- Bottom Nav (same style; Chats selected when current==4) ----------
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, this.onTap});
  final int current; // 0..4
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    // UPDATED ICONS TO FAICONS
    final icons = const [
      FontAwesomeIcons.solidUser, // Profile
      FontAwesomeIcons.compass, // Discover
      FontAwesomeIcons.solidCircleUser, // People
      FontAwesomeIcons.solidHeart, // Liked You
      FontAwesomeIcons.solidCommentDots, // Chats
    ];
    final labels = const [
      "Profile",
      "Discover",
      "People",
      "Liked You",
      "Chats",
    ];

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: Row(
        children: List.generate(icons.length, (i) {
          final selected = i == current;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (onTap != null) {
                  onTap!(i);
                  return;
                }
                // Navigation mapping
                if (i == 0 && current != 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                  return;
                }
                if (i == 1 && current != 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DiscoverScreen()),
                  );
                  return;
                }
                if (i == 2 && current != 2) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                  return;
                }
                // 3 (Liked You) – Add your route when ready
                // 4 (Chats) – already here
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // UPDATED TO FA ICON
                    FaIcon(
                      icons[i],
                      size: selected ? 26 : 24,
                      color: selected ? AppColors.primary : Colors.black54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.0,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------- Shared bits ----------
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _BackgroundLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB388EB).withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const step = 140.0;
    for (double r = step; r < size.width * 1.5; r += step) {
      canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------- Models ----------
class _Story {
  final String name;
  final String avatar;
  const _Story(this.name, this.avatar);
}

class _Conversation {
  final String name;
  final String avatar;
  final String lastMessage;
  final String time;
  final int unread;
  final List<_Msg> messages;

  const _Conversation({
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.messages,
  });

  _Conversation copyWith({int? unread}) => _Conversation(
    name: name,
    avatar: avatar,
    lastMessage: lastMessage,
    time: time,
    unread: unread ?? this.unread,
    messages: messages,
  );
}

class _Msg {
  final bool other; // true => from other person
  final String text;
  const _Msg({required this.other, required this.text});
}