// lib/user_channel.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// You might need to define kPrimary here or import it from a common file.
// Assuming a constant color definition for the pink accent.
const Color kPrimary = Color(0xFFE43AA8);

class UserChannelScreen extends StatefulWidget {
  // Use this flag to determine if the profile belongs to the current user
  final bool isMyProfile;

  const UserChannelScreen({super.key, this.isMyProfile = true});

  @override
  State<UserChannelScreen> createState() => _UserChannelScreenState();
}

class _UserChannelScreenState extends State<UserChannelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  // ---- Dummy user data (used for all tabs) ----
  final String username = "@abdullah_k";
  final String displayName = "Abdullah Khan";
  final String location = "Lahore, PK";
  final DateTime joined = DateTime(2024, 6, 12);
  final String bio =
      "Streamer • Developer • chai enthusiast ☕️\n"
      "Mostly IRL + gaming. Weekends = community Q&A.";

  final int followers = 1280;
  final int following = 342;
  final int subscribers = 96;

  final String website = "abdullah.dev";
  final String email = "hello@abdullah.dev";
  final String xHandle = "@abdullah";
  final String instagram = "@abdullah.ig";

  // Tabs change based on who is viewing
  List<String> get _tabLabels {
    // ADDED "Live" as the first tab
    final baseTabs = ["Live", "Clips", "About"];
    if (widget.isMyProfile) {
      // Wallet is visible only on your own profile
      // ADDED "Live"
      return ["Live", "Clips", "Wallet", "About"];
    }
    return baseTabs;
  }

  @override
  void initState() {
    super.initState();
    // Initialize TabController with the dynamic number of tabs
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    setState(() {
      _currentTab = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. Sliver Header (Twitch-Style Layout)
          _SliverHeader(
            isMyProfile: widget.isMyProfile,
            displayName: displayName,
            username: username,
            followers: followers,
            following: following,
            subscribers: subscribers,
            tabController: _tabController,
            tabLabels: _tabLabels,
          ),

          // 2. Tab View for content (SliverFillRemaining for full height)
          SliverFillRemaining(
            hasScrollBody: true,
            child: TabBarView(
              controller: _tabController,
              children: _getTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to dynamically generate TabBarView children
  List<Widget> _getTabContent() {
    final List<Widget> tabs = [];

    // The order of content must match the order in _tabLabels

    // Live Tab (ADDED)
    tabs.add(const _LiveTab());

    // Clips Tab (Always visible)
    tabs.add(const _ClipsTab());

    // Wallet Tab (Only for self)
    if (widget.isMyProfile) {
      tabs.add(const _WalletTab());
    }

    // About Tab (Always visible, contains all the old static info)
    tabs.add(
      _AboutTab(
        isMyProfile: widget.isMyProfile,
        bio: bio,
        location: location,
        joined: joined,
        website: website,
        email: email,
        xHandle: xHandle,
        instagram: instagram,
      ),
    );

    return tabs;
  }
}

/* ---------------- SLIVER HEADER (Twitch-Style) ---------------- */

class _SliverHeader extends StatelessWidget {
  const _SliverHeader({
    required this.isMyProfile,
    required this.displayName,
    required this.username,
    required this.followers,
    required this.following,
    required this.subscribers,
    required this.tabController,
    required this.tabLabels,
  });

  final bool isMyProfile;
  final String displayName;
  final String username;
  final int followers;
  final int following;
  final int subscribers;
  final TabController tabController;
  final List<String> tabLabels;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      // Height adjusts if less info
      expandedHeight: isMyProfile ? 260.0 : 200.0,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,

      // Top Right Actions (Settings or More options)
      actions: [
        if (isMyProfile) ...[
          IconButton(
            icon: const Icon(FontAwesomeIcons.gear, size: 20),
            onPressed: () {
              // Action: Go to profile settings
            },
          ),
        ] else ...[
          IconButton(
            icon: const Icon(FontAwesomeIcons.ellipsisVertical, size: 20),
            onPressed: () {
              // Action: Report, Block, Share options
            },
          ),
        ]
      ],

      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 8),
        background: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Profile Photo & Name Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundImage: NetworkImage("https://i.pravatar.cc/160?img=8"),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        username,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Edit button for own profile
                  if (isMyProfile)
                    OutlinedButton.icon(
                      onPressed: () {
                        // Action: Navigate to profile edit screen
                      },
                      icon: const Icon(FontAwesomeIcons.pencil, size: 16),
                      label: const Text("Edit", style: TextStyle(fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats Row
              Row(
                children: [
                  _StatTile(label: "Followers", value: followers),
                  const SizedBox(width: 10),
                  _StatTile(label: "Following", value: following),
                  const SizedBox(width: 10),
                  _StatTile(label: "Subs", value: subscribers),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons (Dynamic based on isMyProfile)
              Row(
                children: isMyProfile
                    ? [
                  // Manage Subs Button (My Profile)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Action: Navigate to subscription management
                      },
                      icon: const Icon(FontAwesomeIcons.userGroup, size: 16),
                      label: const Text(
                        "Manage Subs",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Share Profile Button (My Profile)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Action: Trigger share sheet
                      },
                      icon: const Icon(FontAwesomeIcons.shareFromSquare, size: 16),
                      label: const Text(
                        "Share",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ]
                    : [
                  // Follow Button (Other's Profile) - REQUIRED
                  Expanded(
                    child: _ActionButton(
                      label: "Follow",
                      icon: FontAwesomeIcons.userPlus,
                      color: kPrimary,
                      textColor: Colors.white,
                      onPressed: () {
                        // Action: Follow user
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Message Button (Other's Profile) - REQUIRED
                  Expanded(
                    child: _ActionButton(
                      label: "Message",
                      icon: FontAwesomeIcons.solidCommentDots,
                      onPressed: () {
                        // Action: Start chat
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Gift Button (Other's Profile) - REQUIRED
                  _ActionButton(
                    label: "Gift",
                    icon: FontAwesomeIcons.solidGem,
                    onPressed: () {
                      // Action: Open gift/coin dialog
                    },
                  ),
                ],
              ),

              // Added spacing below buttons and above tabs
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // Persistent Tab Bar
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TabBar(
            controller: tabController,
            isScrollable: true,
            indicatorColor: kPrimary,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16),
            unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16),
            tabs: tabLabels.map((label) => Tab(text: label)).toList(),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFFF0F0F0),
    this.textColor = Colors.black87,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
      ),
    );
  }
}

/* ---------------- TAB CONTENT ---------------- */

// 1. Live Tab (NEWLY ADDED)
class _LiveTab extends StatelessWidget {
  const _LiveTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.video, size: 60, color: Colors.black26),
          SizedBox(height: 16),
          Text(
            "User is currently not live.",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black54),
          ),
          SizedBox(height: 8),
          Text(
            "Check back later for their stream!",
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

// 2. Clips Tab (Existing)
class _ClipsTab extends StatelessWidget {
  const _ClipsTab();

  @override
  Widget build(BuildContext context) {
    // Placeholder grid for short clips
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.65,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                "https://i.pravatar.cc/120?img=${index + 10}", // Different placeholder images
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.2),
                colorBlendMode: BlendMode.darken,
              ),
              const Center(
                child: Icon(FontAwesomeIcons.play, color: Colors.white, size: 24),
              ),
              Positioned(
                bottom: 4,
                left: 6,
                child: Text(
                  "Clip ${index + 1}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 3. Wallet Tab (Existing - Only for self)
class _WalletTab extends StatelessWidget {
  const _WalletTab();

  // Helper for wallet tiles
  Widget _walletTile(
      {required String title,
        required String value,
        required IconData icon,
        Color iconColor = Colors.black87,
        VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (onTap != null) const Icon(FontAwesomeIcons.chevronRight, size: 14, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current Balance",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 12),
          _walletTile(
            title: "My Coin Balance",
            value: "2,450 💎",
            icon: FontAwesomeIcons.solidGem,
            iconColor: kPrimary,
          ),
          const SizedBox(height: 24),

          Text(
            "Actions",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 12),
          _walletTile(
            title: "Top-up Coins",
            value: "Buy",
            icon: FontAwesomeIcons.creditCard,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _walletTile(
            title: "Earnings",
            value: "\$1,200",
            icon: FontAwesomeIcons.sackDollar,
          ),
          const SizedBox(height: 12),
          _walletTile(
            title: "Withdraw",
            value: "Cash Out",
            icon: FontAwesomeIcons.moneyBillTransfer,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// 4. About Tab (Existing)
class _AboutTab extends StatelessWidget {
  const _AboutTab({
    required this.isMyProfile,
    required this.bio,
    required this.location,
    required this.joined,
    required this.website,
    required this.email,
    required this.xHandle,
    required this.instagram,
  });

  final bool isMyProfile;
  final String bio;
  final String location;
  final DateTime joined;
  final String website;
  final String email;
  final String xHandle;
  final String instagram;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio
          _SectionCard(
            title: "Bio",
            child: Text(
              bio,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),

          // Basic Info
          _SectionCard(
            title: "Info",
            child: Column(
              children: [
                _InfoTile(
                  icon: FontAwesomeIcons.locationDot,
                  label: "Location",
                  value: location,
                ),
                _InfoTile(
                  icon: FontAwesomeIcons.calendar,
                  label: "Joined",
                  value: _fmtDate(joined),
                ),
                const _InfoTile(
                  icon: FontAwesomeIcons.certificate,
                  label: "Verified",
                  value: "No",
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Links / Contact
          _SectionCard(
            title: "Links",
            child: Column(
              children: [
                _InfoTile(
                  icon: FontAwesomeIcons.globe,
                  label: "Website",
                  value: website,
                ),
                _InfoTile(
                  icon: FontAwesomeIcons.solidEnvelope,
                  label: "Email",
                  value: email,
                ),
                _InfoTile(
                  icon: FontAwesomeIcons.xTwitter,
                  label: "X",
                  value: xHandle,
                ),
                _InfoTile(
                  icon: FontAwesomeIcons.instagram,
                  label: "Instagram",
                  value: instagram,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Preferences / Settings CTA (Only visible on own profile)
          if (isMyProfile)
            _SectionCard(
              title: "Preferences",
              child: Column(
                children: [
                  _SettingRow(
                    icon: FontAwesomeIcons.lock,
                    title: "Privacy",
                    subtitle: "Followers-only chat, hide online status",
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: FontAwesomeIcons.bell,
                    title: "Notifications",
                    subtitle: "Mentions, new subs, gifts",
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: FontAwesomeIcons.palette,
                    title: "Theme",
                    subtitle: "Light / Dark / System",
                    onTap: () {},
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* ---------------- Components (Reused/Updated) ---------------- */

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(FontAwesomeIcons.chevronRight, color: Colors.black45, size: 16),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Text(
              _shortNumber(value),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- Helpers ---------------- */

String _fmtDate(DateTime d) {
  // e.g., "Jun 12, 2024"
  final months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  return "${months[d.month - 1]} ${d.day}, ${d.year}";
}

String _shortNumber(int n) {
  if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
  if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
  return n.toString();
}