// lib/user_channel.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const Color kPrimary = Color(0xFFE43AA8);

class UserChannelScreen extends StatefulWidget {
  final bool isMyProfile;
  const UserChannelScreen({super.key, this.isMyProfile = true});

  @override
  State<UserChannelScreen> createState() => _UserChannelScreenState();
}

class _UserChannelScreenState extends State<UserChannelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ---- Dummy user data ----
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

  List<String> get _tabLabels {
    final baseTabs = ["Home", "Clips", "About", "Schedules"];
    if (widget.isMyProfile) {
      return ["Home", "Clips", "Wallet", "About", "Schedules"];
    }
    return baseTabs;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: Colors.white,
      body: DefaultTabController(
        length: _tabLabels.length,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              _SliverHeader(
                isMyProfile: widget.isMyProfile,
                displayName: displayName,
                username: username,
                followers: followers,
                following: following,
                subscribers: subscribers,
                isSmallScreen: isSmallScreen,
              ),

              // Tab Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: kPrimary,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.black54,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                    tabs: _tabLabels.map((label) =>
                        Tab(text: label)
                    ).toList(),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: _getTabContent(isSmallScreen),
          ),
        ),
      ),
    );
  }

  List<Widget> _getTabContent(bool isSmallScreen) {
    return [
      // Live Tab
      const _LiveTab(),

      // Clips Tab
      const _ClipsTab(),

      // Wallet Tab (only for my profile)
      if (widget.isMyProfile) const _WalletTab(),

      // About Tab
      _AboutTab(
        bio: bio,
        location: location,
        joined: joined,
        website: website,
        email: email,
        xHandle: xHandle,
        instagram: instagram,
        isMyProfile: widget.isMyProfile,
      ),
    ];
  }
}

// Tab Bar Delegate for proper sizing
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}

/* ---------------- FIXED SLIVER HEADER ---------------- */
class _SliverHeader extends StatelessWidget {
  const _SliverHeader({
    required this.isMyProfile,
    required this.displayName,
    required this.username,
    required this.followers,
    required this.following,
    required this.subscribers,
    required this.isSmallScreen,
  });

  final bool isMyProfile;
  final String displayName;
  final String username;
  final int followers;
  final int following;
  final int subscribers;
  final bool isSmallScreen;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: isSmallScreen ? 260.0 : 280.0,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
      shadowColor: Colors.black12,

      // ADD BACK BUTTON HERE
      leading: IconButton(
        icon: const Icon(FontAwesomeIcons.arrowLeft, color: Colors.black),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),

      actions: [
        if (isMyProfile)
          IconButton(
            icon: const Icon(FontAwesomeIcons.gear, size: 20),
            onPressed: () {},
          )
        else
          IconButton(
            icon: const Icon(FontAwesomeIcons.ellipsisVertical, size: 20),
            onPressed: () {},
          ),
      ],

      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header Row
                Container(
                  padding: EdgeInsets.only(left: 40),

                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: isSmallScreen ? 30 : 36,
                            backgroundImage: const NetworkImage("https://i.pravatar.cc/160?img=8"),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    fontSize: isSmallScreen ? 20 : 22,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  username,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14,
                                    color: Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isMyProfile)
                            Container(
                              padding: EdgeInsets.only(top:28),
                              child: SizedBox(
                                width: isSmallScreen ? 70 : 80,
                                child: OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    side: const BorderSide(color: Colors.black12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Container(

                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(FontAwesomeIcons.pencil, size: isSmallScreen ? 12 : 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Edit",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: isSmallScreen ? 12 : 14
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stats Row
                SizedBox(
                  height: 80,
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(label: "Followers", value: followers),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(label: "Following", value: following),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(label: "Subs", value: subscribers),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                const SizedBox(height: 8),
                if (isMyProfile)
                  _buildMyProfileActions()
                else
                  _buildOtherProfileActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... rest of the methods remain the same
  Widget _buildMyProfileActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(FontAwesomeIcons.userGroup, size: 14),
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
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(FontAwesomeIcons.shareFromSquare, size: 14),
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
      ],
    );
  }

  Widget _buildOtherProfileActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: "Follow",
            icon: FontAwesomeIcons.userPlus,
            color: kPrimary,
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            label: "Message",
            icon: FontAwesomeIcons.solidCommentDots,
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: _ActionButton(
            label: "Gift",
            icon: FontAwesomeIcons.solidGem,
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}
  Widget _buildMyProfileActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(FontAwesomeIcons.userGroup, size: 14),
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
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(FontAwesomeIcons.shareFromSquare, size: 14),
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
      ],
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: textColor,
          fontSize: 14,
        ),
      ),
    );
  }
}

/* ---------------- TAB CONTENT ---------------- */

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

class _ClipsTab extends StatelessWidget {
  const _ClipsTab();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 400 ? 2 : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
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
                "https://i.pravatar.cc/120?img=${index + 10}",
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

class _WalletTab extends StatelessWidget {
  const _WalletTab();

  Widget _walletTile({
    required String title,
    required String value,
    required IconData icon,
    Color iconColor = Colors.black87,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800)
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            if (onTap != null)
              const SizedBox(width: 8),
            if (onTap != null)
              const Icon(FontAwesomeIcons.chevronRight, size: 14, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current Balance",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 18
            ),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 18
            ),
          ),
          const SizedBox(height: 12),
          _walletTile(
            title: "Top-up Coins",
            value: "Buy",
            icon: FontAwesomeIcons.creditCard,
            onTap: () {},
          ),
          _walletTile(
            title: "Earnings",
            value: "\$1,200",
            icon: FontAwesomeIcons.sackDollar,
          ),
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

class _AboutTab extends StatelessWidget {
  const _AboutTab({
    required this.bio,
    required this.location,
    required this.joined,
    required this.website,
    required this.email,
    required this.xHandle,
    required this.instagram,
    required this.isMyProfile,
  });

  final String bio;
  final String location;
  final DateTime joined;
  final String website;
  final String email;
  final String xHandle;
  final String instagram;
  final bool isMyProfile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio Section
          _SectionCard(
            title: "Bio",
            child: Text(
              bio,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.4,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info Section
          _SectionCard(
            title: "Info",
            child: Column(
              children: [
                _InfoTile(
                  icon: FontAwesomeIcons.locationDot,
                  label: "Location",
                  value: location,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: FontAwesomeIcons.calendar,
                  label: "Joined",
                  value: _fmtDate(joined),
                ),
                const SizedBox(height: 12),
                const _InfoTile(
                  icon: FontAwesomeIcons.certificate,
                  label: "Verified",
                  value: "No",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Links Section
          _SectionCard(
            title: "Links",
            child: Column(
              children: [
                _InfoTile(
                  icon: FontAwesomeIcons.globe,
                  label: "Website",
                  value: website,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: FontAwesomeIcons.solidEnvelope,
                  label: "Email",
                  value: email,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: FontAwesomeIcons.xTwitter,
                  label: "X",
                  value: xHandle,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: FontAwesomeIcons.instagram,
                  label: "Instagram",
                  value: instagram,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Preferences Section (Only for own profile)
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
                  const SizedBox(height: 12),
                  _SettingRow(
                    icon: FontAwesomeIcons.bell,
                    title: "Notifications",
                    subtitle: "Mentions, new subs, gifts",
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _SettingRow(
                    icon: FontAwesomeIcons.palette,
                    title: "Theme",
                    subtitle: "Light / Dark / System",
                    onTap: () {},
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20), // Bottom padding
        ],
      ),
    );
  }
}

/* ---------------- COMPONENTS ---------------- */

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.black87, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(FontAwesomeIcons.chevronRight,
                color: Colors.black45, size: 14),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _shortNumber(value),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- HELPER FUNCTIONS ---------------- */

String _fmtDate(DateTime d) {
  final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return "${months[d.month - 1]} ${d.day}, ${d.year}";
}

String _shortNumber(int n) {
  if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
  if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
  return n.toString();
}