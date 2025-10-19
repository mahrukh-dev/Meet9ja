import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'constants/app_colors.dart';
import 'screens/livestream_screen.dart'; // Assuming 'livestream_screen.dart' exists for LiveStreamPage

class StartLivePage extends StatefulWidget {
  const StartLivePage({super.key});
  @override
  State<StartLivePage> createState() => _StartLivePageState();
}

class _StartLivePageState extends State<StartLivePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final List<String> _liveFilters = const [
    "All",
    "Drops & Loot",
    "Fortnite",
    "Call of Duty: Warzone",
  ];
  int _liveFilterIndex = 0;

  final List<_ReelItem> _followingReels = List.generate(
    8,
        (i) => _ReelItem(
      user: "Creator ${i + 1}",
      title:
      "Hanging out — say hi! 👋  | Day ${i + 1} | 15% to charity | Nigeria schools",
      viewers: (32000 + i * 1200),
      thumb:
      "https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?q=80&w=1080&auto=format&fit=crop",
    ),
  );

  final List<_ReelItem> _clipsReels = List.generate(
    10,
        (i) => _ReelItem(
      user: "ProGamer_${i + 1}",
      title: "Insane clutch 🔥 — clip #$i",
      viewers: (7800 + i * 300),
      thumb:
      "https://images.unsplash.com/photo-1535223289827-42f1e9919769?q=80&w=1080&auto=format&fit=crop",
    ),
  );

  final List<_LiveCard> _liveRooms = List.generate(
    12,
        (i) => _LiveCard(
      title: "MAFIATHON 3 ▪ Day ${i + 1}",
      user: "KaiCenat",
      viewers: 186000 + (i * 1200),
      thumb:
      "https://images.unsplash.com/photo-1517705008128-361805f42e86?q=80&w=1080&auto=format&fit=crop",
      game: i.isEven ? "Fortnite" : "Just Chatting",
    ),
  );

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The dark background color used in the images
    const Color darkBackground = Color(0xFF333333);

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: const Icon(FontAwesomeIcons.arrowLeft, color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌸 Custom Tabs (Following, Live, Clips) - NOW WITH UNDERLINE INDICATOR
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: darkBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.transparent),
              ),
              child: TabBar(
                controller: _tab,
                // 👇 MODIFIED: Use UnderlineTabIndicator for a line
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(
                    width: 3.0,
                    color: Colors.white, // White line
                  ),
                  insets: EdgeInsets.symmetric(horizontal: 20.0), // Control line length/position
                ),
                // 👇 MODIFIED: Both selected and unselected text colors are white
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18, // Increased font size slightly to match the image
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18, // Increased font size slightly to match the image
                ),
                indicatorSize: TabBarIndicatorSize.label, // Indicator only spans the text label
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                padding: const EdgeInsets.all(6),
                labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                tabs: const [
                  Tab(text: "Following"),
                  Tab(text: "Live"),
                  Tab(text: "Clips"),
                ],
              ),
            ),
          ],
        ),
      ),

      // Body content
      body: Container(
        color: darkBackground,
        child: TabBarView(
          controller: _tab,
          children: [
            _ReelsFeed(items: _followingReels),
            Column(
              children: [
                const SizedBox(height: 8),
                // Live Filters Bar maintains the white-selected box style
                _LiveFiltersBar(
                  filters: _liveFilters,
                  selected: _liveFilterIndex,
                  onTap: (i) => setState(() => _liveFilterIndex = i),
                  backgroundColor: darkBackground,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                                (context, i) => _LiveTile(room: _liveRooms[i]),
                            childCount: _liveRooms.length,
                          ),
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 9 / 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _ReelsFeed(items: _clipsReels),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.black12.withOpacity(.4)),
          ),
          color: Colors.white,
        ),
        height: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _BottomItem(
                icon: FontAwesomeIcons.house, label: "Home", selected: true),
            const _BottomItem(icon: FontAwesomeIcons.compass, label: "Browse"),
            _BottomCreateButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LiveStreamScreen(
                      liveId: 'specific_live_id',
                      userId: 'audience_123',
                      userName: 'Viewer',
                      isHost: true,
                    ),
                  ),
                );
              },
            ),
            const _BottomItem(icon: FontAwesomeIcons.bell, label: "Activity"),
            const _BottomItem(icon: FontAwesomeIcons.user, label: "Profile"),
          ],
        ),
      ),
    );
  }


  String timeOfDayText() {
    final now = TimeOfDay.now();
    final h = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final m = now.minute.toString().padLeft(2, '0');
    final suffix = now.period == DayPeriod.am ? "AM" : "PM";
    return "$h:$m $suffix";
  }
}

/* ----------------------- LIVE FILTER BAR ----------------------- */
// This section remains the same as you requested the white-box style for the filters
class _LiveFiltersBar extends StatelessWidget {
  const _LiveFiltersBar({
    required this.filters,
    required this.selected,
    required this.onTap,
    required this.backgroundColor,
  });

  final List<String> filters;
  final int selected;
  final ValueChanged<int> onTap;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    // Define the colors based on the requested style
    const Color selectedBgColor = Colors.white;
    const Color unselectedBgColor = Color(0xFF333333); // Dark background
    const Color selectedTextColor = Colors.black87;
    const Color unselectedTextColor = Colors.white;

    return Container(
      color: backgroundColor,
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final sel = i == selected;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                // Use white for selected, dark for unselected
                color: sel ? selectedBgColor : unselectedBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? selectedBgColor : unselectedBgColor,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  filters[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    // Use black for selected text, white for unselected text
                    color: sel ? selectedTextColor : unselectedTextColor,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }
}

/* ----------------------- LIVE TILE ----------------------- */
class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.room});
  final _LiveCard room;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(room.thumb, fit: BoxFit.cover),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(.65), Colors.transparent],
                  stops: const [0, .55],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "LIVE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _pill(
              icon: FontAwesomeIcons.eye,
              text: _formatViewers(room.viewers),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(FontAwesomeIcons.solidCircleCheck,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        room.user,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  room.game,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatViewers(int v) {
    if (v >= 1000000) return "${(v / 1000000).toStringAsFixed(1)}M";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(1)}K";
    return "$v";
  }
}

/* ----------------------- REELS FEED ----------------------- */
class _ReelsFeed extends StatelessWidget {
  const _ReelsFeed({required this.items});
  final List<_ReelItem> items;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(it.thumb, fit: BoxFit.cover),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Colors.black.withOpacity(.75), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 110,
              child: Column(
                children: [
                  _CircleIcon(icon: FontAwesomeIcons.heart, onTap: () {}),
                  const SizedBox(height: 16),
                  _CircleIcon(icon: FontAwesomeIcons.comment, onTap: () {}),
                  const SizedBox(height: 16),
                  _CircleIcon(icon: FontAwesomeIcons.share, onTap: () {}),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 80,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(FontAwesomeIcons.solidCircleCheck,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        it.user,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "LIVE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    it.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        FontAwesomeIcons.eye,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatViewers(it.viewers),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatViewers(int v) {
    if (v >= 1000000) return "${(v / 1000000).toStringAsFixed(1)}M";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(1)}K";
    return "$v";
  }
}

/* ----------------------- MODELS ----------------------- */
class _ReelItem {
  final String user;
  final String title;
  final int viewers;
  final String thumb;
  const _ReelItem({
    required this.user,
    required this.title,
    required this.viewers,
    required this.thumb,
  });
}

class _LiveCard {
  final String title;
  final String user;
  final int viewers;
  final String thumb;
  final String game;
  const _LiveCard({
    required this.title,
    required this.user,
    required this.viewers,
    required this.thumb,
    required this.game,
  });
}

/* ----------------------- BOTTOM NAV ----------------------- */
class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon,
            color: selected ? AppColors.primary : Colors.black87, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: selected ? AppColors.primary : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _BottomCreateButton extends StatelessWidget {
  const _BottomCreateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {

    return InkWell(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(.35),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(FontAwesomeIcons.plus, color: Colors.white, size: 20),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}