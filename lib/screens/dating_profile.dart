import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meet9ja/constants/app_colors.dart';
import 'package:meet9ja/screens/explore_live_screen.dart';
import 'package:meet9ja/screens/profile_screen.dart';
import 'package:meet9ja/screens/subscription_screen.dart';
import 'package:meet9ja/screens/edit_profile_screen.dart';
import 'package:meet9ja/models/user_model.dart';
import '../db_functions/user_service.dart';
import 'MatchedUserScreen.dart';
import 'discover_screen.dart';
import 'messages_screen.dart';

class DatingProfileScreen extends StatefulWidget {
  const DatingProfileScreen({super.key});

  @override
  State<DatingProfileScreen> createState() => _DatingProfileScreenState();
}

class _DatingProfileScreenState extends State<DatingProfileScreen> {
  int _tab = 0;
  UserModel? _currentUser;
  Map<String, int> _userStats = {'followers': 0, 'following': 0, 'subscribers': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final currentUserId = UserService.currentUserId;
    if (currentUserId != null) {
      try {
        final user = await UserService.getUserProfile(currentUserId);
        final stats = await UserService.getUserStats(currentUserId);

        setState(() {
          _currentUser = user;
          _userStats = stats;
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading user data: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToSubscriptionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionPage(),
      ),
    );
  }

  void _navigateToEditProfileScreen() async {
    final userProfile = await UserService.getUserProfile(UserService.currentUserId!);

    if (!mounted || userProfile == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(userProfile: userProfile),
      ),
    ).then((_) => _loadUserData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Profile",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_outlined),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // Scroll body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  children: [
                    _Header(
                      user: _currentUser,
                      stats: _userStats,
                      onEditProfile: _navigateToEditProfileScreen,
                    ),
                    const SizedBox(height: 12),
                    _Segments(
                      current: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: 12),

                    if (_tab == 0)
                      _PayPlanTab(
                        user: _currentUser,
                        onOpenMyProfile: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(),
                            ),
                          );
                        },
                        onExplorePremium: _navigateToSubscriptionScreen,
                        onSpotlightTap: _navigateToSubscriptionScreen,
                        onSuperSwipeTap: _navigateToSubscriptionScreen,
                        onEarningsTap: _navigateToSubscriptionScreen,
                      )
                    else if (_tab == 1)
                      _AdviceTab()
                    else
                      _PhotoInsightsTab(
                        onFindOutHowTap: _navigateToSubscriptionScreen,
                      ),
                  ],
                ),
              ),

              // Bottom nav — Profile selected
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: _BottomNav(current: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- HEADER --------------------
class _Header extends StatelessWidget {
  const _Header({this.user, required this.stats, this.onEditProfile});
  final UserModel? user;
  final Map<String, int> stats;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    // Calculate age from date of birth
    final age = 18;// Default age

    // Get profile photo URL - using the actual user's profile photo
    final profilePhotoUrl = UserService.getProfilePhotoUrl(user!);
    return Row(
      children: [
        Stack(
          alignment: Alignment.bottomLeft,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
                  ? NetworkImage(profilePhotoUrl)
                  : const NetworkImage("https://i.pravatar.cc/120?img=8") as ImageProvider,
            ),
            Container(
              margin: const EdgeInsets.only(left: 2, bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${stats['followers'] ?? 0}",
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${user?.name ?? 'User'}, $age",
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18
                ),
              ),
              const SizedBox(height: 6),

            ],
          ),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onEditProfile,
          child: const Text(
            "Complete profile",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// -------------------- STAT ITEM WIDGET --------------------
class _StatItem extends StatelessWidget {
  const _StatItem({required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

// -------------------- SEGMENTS --------------------
class _Segments extends StatelessWidget {
  const _Segments({required this.current, required this.onChanged});
  final int current;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    List<String> items = ["Pay plan", "Dating advice", "Photo insights"];
    return Row(
      children: List.generate(items.length, (i) {
        final selected = i == current;
        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              alignment: Alignment.center,
              child: Text(
                items[i],
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// -------------------- TAB: PAY PLAN --------------------
class _PayPlanTab extends StatelessWidget {
  const _PayPlanTab({
    required this.onOpenMyProfile,
    required this.onExplorePremium,
    required this.onSpotlightTap,
    required this.onSuperSwipeTap,
    required this.onEarningsTap,
    this.user,
  });

  final VoidCallback onOpenMyProfile;
  final VoidCallback onExplorePremium;
  final VoidCallback onSpotlightTap;
  final VoidCallback onSuperSwipeTap;
  final VoidCallback onEarningsTap;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final isPremium = user != null ? UserService.isPremium(user!) : false;
    final coinBalance = user != null ? UserService.getCoinBalance(user!) : 0;
    final totalEarnings = user != null ? UserService.getTotalEarnings(user!) : 0;
    final primaryMode = user != null ? UserService.getPrimaryMode(user!) : 'Not Set';

    return Column(
      children: [
        // User Stats Cards
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onEarningsTap,
                child: _UserStatCard(
                  title: "Coins",
                  value: coinBalance.toString(),
                  color: Colors.amber,
                  icon: Icons.monetization_on_outlined,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onEarningsTap,
                child: _UserStatCard(
                  title: "Earnings",
                  value: "₦$totalEarnings",
                  color: Colors.green,
                  icon: Icons.attach_money_outlined,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Spotlight / SuperSwipe
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onSpotlightTap,
                child: const _FeatureCard(title: "Spotlight", subtitle: "Stand out"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onSuperSwipeTap,
                child: const _FeatureCard(title: "SuperSwipe", subtitle: "Get noticed"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Premium banner (pink) + My Profile button (right side)
        Container(
          decoration: BoxDecoration(
            color: isPremium ? Colors.green : AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: title + My Profile button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isPremium ? "Premium+" : "Go Premium+",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.white, width: 1.2),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onPressed: onOpenMyProfile,
                    icon: const Icon(Icons.person_rounded, size: 18),
                    label: const Text(
                      "My Profile",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isPremium
                    ? "You're enjoying VIP treatment with better ways to connect with incredible people."
                    : "Get the VIP treatment, and enjoy better ways to connect with incredible people.",
                style: const TextStyle(fontSize: 14.5, color: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isPremium ? Colors.green : AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onExplorePremium,
                child: Text(
                  isPremium ? "Manage Subscription" : "Explore Premium+",
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // What you get table
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "What you get:",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 10),
        _BenefitsRow.headings(),
        const Divider(),
        const _BenefitsRow(text: "Get exclusive photo insights"),
        const _BenefitsRow(text: "Fast track your likes"),
        const _BenefitsRow(text: "Stand out every day"),
        const _BenefitsRow(text: "Unlimited likes", premiumOnly: false),
        const _BenefitsRow(text: "See who liked you"),
        const _BenefitsRow(text: "Advanced filters"),
        const _BenefitsRow(text: "Incognito mode"),
        const _BenefitsRow(text: "Travel mode"),
        const _BenefitsRow(text: "10 SuperSwipes a week"),
        const _BenefitsRow(text: "2 Spotlights a week"),
        const _BenefitsRow(text: "Unlimited Extends"),
        const _BenefitsRow(text: "Unlimited Rematch"),
        const _BenefitsRow(text: "Unlimited Backtrack"),
      ],
    );
  }
}

// -------------------- USER STAT CARD --------------------
class _UserStatCard extends StatelessWidget {
  const _UserStatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
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

// -------------------- INFO CARD --------------------
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFAD3EA),
            ),
            child: const Icon(
              Icons.star,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
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

class _BenefitsRow extends StatelessWidget {
  const _BenefitsRow({
    this.text = "",
    this.premiumPlus = true,
    this.premiumOnly = true,
    this.isHeading = false,
  });

  final String text;
  final bool premiumPlus; // check in Premium+
  final bool premiumOnly; // check in Premium
  final bool isHeading;

  factory _BenefitsRow.headings() => const _BenefitsRow(
    text: "What you get",
    premiumPlus: true,
    premiumOnly: false,
    isHeading: true,
  );

  @override
  Widget build(BuildContext context) {
    final styleLeft = TextStyle(
      fontWeight: isHeading ? FontWeight.w800 : FontWeight.w600,
      color: Colors.black87,
    );

    Widget tick(bool on, {bool faint = false}) => Icon(
      Icons.check,
      size: 18,
      color: on ? Colors.black87 : Colors.black26,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 7, child: Text(text, style: styleLeft)),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Center(child: tick(premiumPlus))),
          Expanded(
            flex: 3,
            child: Center(child: tick(premiumOnly, faint: true)),
          ),
        ],
      ),
    );
  }
}

// -------------------- TAB: DATING ADVICE --------------------
class _AdviceTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AdviceSectionTitle("Articles we think you'll like"),
        const SizedBox(height: 10),
        _HorizontalCards(
          items: const [
            _AdviceCardData(
              title: "How did it go? 5 post-date reflections",
              tag: "Short article",
              image:
              "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4",
            ),
            _AdviceCardData(
              title: "How emotionally available are you?",
              tag: "Short article",
              image:
              "https://images.unsplash.com/photo-1529336953121-a0f91c7d6429",
            ),
            _AdviceCardData(
              title: "4 questions to ask yourself before dating",
              tag: "Short article",
              image:
              "https://images.unsplash.com/photo-1517486808906-6ca8b3f04846",
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _AdviceSectionTitle("Collections"),
        const SizedBox(height: 10),
        const _CollectionsList(),
        const SizedBox(height: 18),
        const _AdviceSectionTitle("Shorts from our experts"),
        const SizedBox(height: 10),
        _HorizontalCards(
          items: const [
            _AdviceCardData(
              title: "And breathe: calm pre-date nerves",
              tag: "Short",
              image:
              "https://images.unsplash.com/photo-1524504388940-b1c1722653e1",
            ),
            _AdviceCardData(
              title: "Is it ok to date more than one person?",
              tag: "Short",
              image:
              "https://images.unsplash.com/photo-1520813792240-56fc4a3765a7",
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _AdviceSectionTitle extends StatelessWidget {
  const _AdviceSectionTitle(this.t);
  final String t;
  @override
  Widget build(BuildContext context) {
    return Text(
      t,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _CollectionsList extends StatelessWidget {
  const _CollectionsList();

  @override
  Widget build(BuildContext context) {
    final items = [
      "Being yourself on Bumble",
      "Connecting with others",
      "Moving to IRL",
      "First dates and beyond",
    ];
    return Column(
      children: [
        for (final t in items) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HorizontalCards extends StatelessWidget {
  const _HorizontalCards({required this.items});
  final List<_AdviceCardData> items;

  @override
  Widget build(BuildContext context) {
    final h = 190.0;
    final w = MediaQuery.of(context).size.width * 0.64;

    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: w,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(items[i].image, fit: BoxFit.cover),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 54, 12, 12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black54,
                          Colors.black87,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            items[i].tag,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          items[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdviceCardData {
  final String title, tag, image;
  const _AdviceCardData({
    required this.title,
    required this.tag,
    required this.image,
  });
}

// -------------------- TAB: PHOTO INSIGHTS --------------------
class _PhotoInsightsTab extends StatelessWidget {
  const _PhotoInsightsTab({required this.onFindOutHowTap});

  final VoidCallback onFindOutHowTap;

  @override
  Widget build(BuildContext context) {
    final bars = List.generate(
      7,
          (i) => _BarWithThumb(heightFactor: 0.35 + (i % 4) * 0.12),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onFindOutHowTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: const [
                Icon(Icons.bolt_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Find out how your photos are performing with Premium+",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          "How are your photos doing?",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          "See which of your photos are getting the most attention.",
          style: TextStyle(color: Colors.black87),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 190,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: bars,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Icon(Icons.access_time, size: 18),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                "Photo insights can take a little while to appear. Make sure you have Best Photo on.",
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BarWithThumb extends StatelessWidget {
  const _BarWithThumb({required this.heightFactor});
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 26,
              height: 140 * heightFactor,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey.shade200, Colors.grey.shade400],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage("https://i.pravatar.cc/80?img=11"),
        ),
      ],
    );
  }
}

// -------------------- BOTTOM NAV --------------------
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, this.onTap});
  final int current; // 0..4
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final icons = const [
      Icons.person_outline, // Profile
      Icons.explore_outlined, // Discover
      Icons.people_alt_outlined, // People
      Icons.favorite_border, // Liked You
      Icons.chat_bubble_outline, // Chats
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
                if (i == 1 && current != 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiscoverScreen()),
                  );
                } else if (i == 2 && current != 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ExploreLiveScreen()),
                  );
                }

                if (i == 3 && current != 3) { // Changed from 4 to 3 for Live tab

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MatchedUsersScreen(userId: UserService.currentUserId!,)),
                  );
                  return;
                }
                if (i == 4 && current != 4) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()),
                  );
                  return;
                }
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
                    Icon(
                      icons[i],
                      size: selected ? 30 : 28,
                      color: selected ? AppColors.primary : Colors.black54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.0,
                        fontSize: 11,
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