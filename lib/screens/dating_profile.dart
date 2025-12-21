import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meet9ja/constants/app_colors.dart';
import 'package:meet9ja/screens/explore_live_screen.dart';
import 'package:meet9ja/screens/home_screen.dart';
import 'package:meet9ja/screens/profile_screen.dart';
import 'package:meet9ja/screens/subscription_management_screen.dart';
import 'package:meet9ja/screens/subscription_screen.dart';
import 'package:meet9ja/screens/edit_profile_screen.dart';
import 'package:meet9ja/models/user_model.dart';
import '../db_functions/user_service.dart';
import 'MatchedUserScreen.dart';
import 'activity_screen.dart';
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
  Map<String, int> _userStats = {
    'followers': 0,
    'following': 0,
    'subscribers': 0,
  };
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
      MaterialPageRoute(builder: (_) => SubscriptionPage()),
    );
  }

  void _navigateToEditProfileScreen() async {
    final userProfile = await UserService.getUserProfile(
      UserService.currentUserId!,
    );

    if (!mounted || userProfile == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(userProfile: userProfile),
      ),
    ).then((_) => _loadUserData());
  }

  void _navigateToTransactionHistory() {
    // You'll need to create this screen
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (_) => TransactionHistoryScreen()),
    // );
  }

  void _navigateToWithdrawalScreen() {
    // You'll need to create this screen
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (_) => WithdrawalScreen()),
    // );
  }

  void _navigateToProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen()),
    );
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
                        onOpenMyProfile: _navigateToProfileScreen,
                        onExplorePremium: _navigateToSubscriptionScreen,
                        onEarningsTap: _navigateToProfileScreen,
                        onWithdrawTap: _navigateToProfileScreen,
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
    final age = 18; // Default age

    // Get profile photo URL - using the actual user's profile photo
    final profilePhotoUrl = UserService.getProfilePhotoUrl(user!);
    return Row(
      children: [
        Stack(
          alignment: Alignment.bottomLeft,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage:
              profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
                  ? NetworkImage(profilePhotoUrl)
                  : const NetworkImage("https://i.pravatar.cc/120?img=8")
              as ImageProvider,
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
                  fontSize: 18,
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
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
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
    required this.onEarningsTap,
    required this.onWithdrawTap,
    this.user,
  });

  final VoidCallback onOpenMyProfile;
  final VoidCallback onExplorePremium;
  final VoidCallback onEarningsTap;
  final VoidCallback onWithdrawTap;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final isPremium = user != null ? UserService.isPremium(user!) : false;
    final diamondBalance = user != null ? UserService.getDiamondBalance(user!) : 0;
    final coinBalance = user != null ? UserService.getCoinBalance(user!) : 0;
    final totalEarnings = user != null
        ? UserService.getTotalEarnings(user!)
        : 0.0;

    return Column(
      children: [
        // User Stats Cards - Updated with diamonds and coins
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onEarningsTap,
                child: _UserStatCard(
                  title: "Diamonds",
                  value: diamondBalance.toString(),
                  color: Colors.blue,
                  icon: Icons.diamond_outlined,
                  subtitle: "Purchased",
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onEarningsTap,
                child: _UserStatCard(
                  title: "Coins",
                  value: coinBalance.toString(),
                  color: Colors.amber,
                  icon: Icons.monetization_on_outlined,
                  subtitle: "Earnings",
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Earnings Card
        GestureDetector(
          onTap: onWithdrawTap,
          child: _UserStatCard(
            title: "Total Earnings",
            value: "\$${totalEarnings.toStringAsFixed(2)}",
            color: Colors.green,
            icon: Icons.attach_money_outlined,
            subtitle: "Available for withdrawal",
          ),
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
              // In _PayPlanTab widget - update the ElevatedButton
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isPremium ? Colors.green : AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isPremium
                    ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubscriptionManagementScreen(),
                    ),
                  );
                }
                    : onExplorePremium,
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
    this.subtitle = "",
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String subtitle;

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
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
        const _AdviceSectionTitle("Featured Articles"),
        const SizedBox(height: 10),

        // Expanded article list with all the provided content
        _ArticleList(
          articles: [
            _ArticleData(
              category: "Dating Advice for Men",
              title: "How to Make a Great First Impression",
              shortSummary:
              "Your first impression decides everything. How you talk, smell, and behave can instantly make a woman feel safe or not.",
              fullContent:
              "A great first impression starts with preparation. Wear clean clothes that fit well; they don't need to be expensive. Your hygiene matters more than your outfit—fresh breath, trimmed nails, and a light scent make a big difference.\n\nBe confident but not arrogant. Look her in the eye when you speak, but don't stare. Ask genuine questions instead of trying to show off. Women notice how you treat waiters, taxi drivers, and strangers.\n\nDon't rush anything. A calm, relaxed energy shows maturity. And most important: listen more than you talk. Listening beats looks.",
            ),
            _ArticleData(
              category: "Dating Advice for Men",
              title: "How to Text a Woman Without Killing Attraction",
              shortSummary:
              "Good texting keeps attraction alive. Don't overthink—be natural, playful, and consistent.",
              fullContent:
              "Texting is the bridge between meeting and the first date. Avoid one-word replies because they kill the vibe. Ask light, open-ended questions. Add small jokes or playful energy, but don't overdo it.\n\nDon't double-text aggressively, but also don't disappear for days. Consistency builds trust.\n\nIf she takes long to reply, relax—people are busy.\n\nWhen the conversation flows well, move forward by suggesting a meet-up. Texting is only a tool; it's not the relationship itself.",
            ),
            _ArticleData(
              category: "Dating Advice for Women",
              title: "How to Attract a Genuine, Serious Man",
              shortSummary:
              "Attracting a serious man starts with clarity. Know what you want and don't settle for half effort.",
              fullContent:
              "A serious man is attracted to a woman who values herself. Communicate your standards calmly. A man who wants something real will respect your boundaries.\n\nDon't try to fix or change a man. His intentions are clear from the beginning—effort, consistency, and respect.\n\nPut yourself in environments where serious men exist: professional events, classes, business spaces, hobbies.\n\nRemember: emotional stability and independence naturally attract the right men.",
            ),
            _ArticleData(
              category: "Dating Advice for Women",
              title: "How to Know If a Man Likes You",
              shortSummary:
              "Men show interest through actions, not words. Consistency is the real sign.",
              fullContent:
              "A man who likes you puts in effort without being forced. He checks on you, plans dates, and stays present.\n\nHe doesn't disappear for days. He remembers small things about you.\n\nPay attention to how he behaves around other women—constant flirting is a red flag.\n\nA serious man will eventually introduce you to his friends or family.\n\nIf you constantly feel confused, that's your answer. Real interest feels clear, not stressful.",
            ),
            _ArticleData(
              category: "Relationship Red Flags",
              title: "Red Flags You Should Never Ignore",
              shortSummary:
              "Red flags protect you. Ignoring them early leads to pain later.",
              fullContent:
              "The biggest red flag is inconsistency—someone who is warm today but cold tomorrow.\n\nAnother red flag is poor communication, especially people who avoid responsibility or refuse to talk during conflict.\n\nWatch out for jealousy disguised as love. Controlling behavior is not affection.\n\nSomeone who lies about small things will eventually lie about big things.\n\nIf a person never apologizes or always blames others, walk away.\n\nTrust your instincts. If something feels off, it usually is.",
            ),
            _ArticleData(
              category: "Building Confidence",
              title: "How to Build Unshakeable Dating Confidence",
              shortSummary:
              "Confidence is built from habits, mindset, and experience, not from perfection.",
              fullContent:
              "Confidence starts with accepting who you are right now. Fix your posture, walk with purpose, and maintain eye contact.\n\nTake care of your body—exercise improves confidence.\n\nAvoid comparing yourself to others. Everyone has weaknesses.\n\nLearn communication skills: how to speak clearly, how to listen, and how to stay calm.\n\nExpose yourself to more social interactions. Confidence grows with practice, not isolation.",
            ),
            _ArticleData(
              category: "Dating Safety Tips",
              title: "Safety Rules Everyone Should Follow When Dating",
              shortSummary:
              "Safety comes before attraction. Protect yourself in every situation.",
              fullContent:
              "Always meet in public for the first few dates. Tell a friend or sibling where you are and who you're with.\n\nDon't drink too much—stay aware.\n\nAvoid going to someone's home or hotel room too soon.\n\nProtect your private information: your address, financial details, password, and family issues.\n\nObserve how the person behaves when angry or stressed.\n\nIf someone pressures you into anything, that is your sign to leave.\n\nYour safety matters more than chemistry.",
            ),
          ],
        ),

        const SizedBox(height: 18),
      ],
    );
  }
}

// -------------------- ARTICLE LIST WIDGET --------------------
class _ArticleList extends StatelessWidget {
  const _ArticleList({required this.articles});
  final List<_ArticleData> articles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final article in articles) ...[
          _ArticleListItem(article: article),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// -------------------- ARTICLE LIST ITEM --------------------
class _ArticleListItem extends StatelessWidget {
  const _ArticleListItem({required this.article});
  final _ArticleData article;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showArticleDialog(context, article);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                article.category,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              article.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              article.shortSummary,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  "Read more",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showArticleDialog(BuildContext context, _ArticleData article) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        article.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    article.category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  article.shortSummary,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  article.fullContent,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// -------------------- ARTICLE DATA MODEL --------------------
class _ArticleData {
  final String category;
  final String title;
  final String shortSummary;
  final String fullContent;

  const _ArticleData({
    required this.category,
    required this.title,
    required this.shortSummary,
    required this.fullContent,
  });
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
class _PhotoInsightsTab extends StatefulWidget {
  const _PhotoInsightsTab({required this.onFindOutHowTap});

  final VoidCallback onFindOutHowTap;

  @override
  State<_PhotoInsightsTab> createState() => _PhotoInsightsTabState();
}

class _PhotoInsightsTabState extends State<_PhotoInsightsTab> {
  int _selectedTimeFrame = 0; // 0: Last 7 days, 1: Last 30 days, 2: All time
  bool _isLoading = true;
  Map<String, dynamic> _insightsData = {};

  @override
  void initState() {
    super.initState();
    _loadInsightsData();
  }

  Future<void> _loadInsightsData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUserId = UserService.currentUserId;
      if (currentUserId != null) {
        final insights = await _fetchUserInsights(currentUserId);
        setState(() {
          _insightsData = insights;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading insights: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchUserInsights(String userId) async {
    // Get date range based on selected time frame
    final DateTimeRange dateRange = _getDateRange();

    // Fetch all data in parallel
    final results = await Future.wait([
      _calculateTotalReach(userId, dateRange),
      _calculateEngagementRate(userId, dateRange),
      _getProfileViews(userId, dateRange),
      _getPostsData(userId, dateRange),
      _getStoriesData(userId, dateRange),
      _getLiveStreamsData(userId, dateRange),
      _getAudienceDemographics(userId, dateRange),
    ]);

    return {
      'totalReach': results[0],
      'engagementRate': results[1],
      'profileViews': results[2],
      'posts': results[3],
      'stories': results[4],
      'liveStreams': results[5],
      'audienceDemographics': results[6],
    };
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedTimeFrame) {
      case 0: // Last 7 days
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 1: // Last 30 days
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 2: // All time
      default:
        startDate = DateTime(2020); // Very old date to get all data
        break;
    }

    return DateTimeRange(start: startDate, end: now);
  }

  // Calculate total reach (unique users who saw any content)
  Future<int> _calculateTotalReach(
      String userId,
      DateTimeRange dateRange,
      ) async {
    try {
      // Get unique viewers from posts
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: dateRange.start)
          .where('createdAt', isLessThanOrEqualTo: dateRange.end)
          .get();

      Set<String> uniqueViewers = {};

      for (final post in postsSnapshot.docs) {
        final postData = post.data();
        // Add users who liked the post
        final likes = List.from(postData['likes'] ?? []);
        uniqueViewers.addAll(likes.whereType<String>());

        // Add users who commented on the post
        final comments = List.from(postData['comments'] ?? []);
        for (final comment in comments) {
          if (comment is Map<String, dynamic> && comment['userId'] != null) {
            uniqueViewers.add(comment['userId'].toString());
          }
        }

        // Add view count as estimated unique viewers
        final viewCount = postData['viewCount'] ?? 0;
        if (viewCount > 0) {
          uniqueViewers.add('post_${post.id}_viewers');
        }
      }

      // Get unique viewers from stories
      final storiesSnapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: dateRange.start)
          .where('createdAt', isLessThanOrEqualTo: dateRange.end)
          .get();

      for (final story in storiesSnapshot.docs) {
        final storyData = story.data();
        final views = List.from(storyData['views'] ?? []);
        uniqueViewers.addAll(views.whereType<String>());
      }

      // Get unique viewers from live streams
      final liveStreamsSnapshot = await FirebaseFirestore.instance
          .collection('live_history')
          .where('UID', isEqualTo: userId)
          .where('start_time', isGreaterThanOrEqualTo: dateRange.start)
          .where('start_time', isLessThanOrEqualTo: dateRange.end)
          .get();

      for (final live in liveStreamsSnapshot.docs) {
        final liveData = live.data();
        final viewers = liveData['viewerCount'] ?? 0;
        // For live streams, we estimate reach as viewer count
        if (viewers > 0) {
          uniqueViewers.add('live_${live.id}');
        }
      }

      return uniqueViewers.length;
    } catch (e) {
      print('Error calculating total reach: $e');
      return 0;
    }
  }

  // Calculate engagement rate (interactions / reach * 100)
  Future<double> _calculateEngagementRate(
      String userId,
      DateTimeRange dateRange,
      ) async {
    try {
      int totalInteractions = 0;
      int totalReach = 0;

      // Posts engagement
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: dateRange.start)
          .where('createdAt', isLessThanOrEqualTo: dateRange.end)
          .get();

      for (final post in postsSnapshot.docs) {
        final postData = post.data();
        final likes = List.from(postData['likes'] ?? []).length;
        final comments = List.from(postData['comments'] ?? []).length;
        final shares = (postData['shareCount'] ?? 0) as int;

        totalInteractions += likes + comments + shares;
        totalReach += (postData['viewCount'] ?? 0) as int;
      }

      // Stories engagement
      final storiesSnapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: dateRange.start)
          .where('createdAt', isLessThanOrEqualTo: dateRange.end)
          .get();

      for (final story in storiesSnapshot.docs) {
        final storyData = story.data();
        final views = List.from(storyData['views'] ?? []).length;
        final replies = List.from(storyData['replies'] ?? []).length;

        totalInteractions += replies;
        totalReach += views;
      }

      // Live streams engagement - FIXED THE TYPE ERRORS HERE
      final liveStreamsSnapshot = await FirebaseFirestore.instance
          .collection('live_history')
          .where('UID', isEqualTo: userId)
          .where('start_time', isGreaterThanOrEqualTo: dateRange.start)
          .where('start_time', isLessThanOrEqualTo: dateRange.end)
          .get();

      for (final live in liveStreamsSnapshot.docs) {
        final liveData = live.data();
        final viewers = (liveData['viewerCount'] ?? 0) as int; // Fixed: cast to int
        final gifts = (liveData['totalGiftValue'] ?? 0) as int; // Fixed: cast to int

        totalInteractions = totalInteractions + viewers + (gifts * 10);
        totalReach += viewers;
      }

      if (totalReach == 0) return 0.0;
      return ((totalInteractions / totalReach) * 100).clamp(0.0, 100.0);
    } catch (e) {
      print('Error calculating engagement rate: $e');
      return 0.0;
    }
  }

  // Get profile views count
  Future<int> _getProfileViews(String userId, DateTimeRange dateRange) async {
    try {
      final profileViewsSnapshot = await FirebaseFirestore.instance
          .collection('profile_views')
          .where('viewedUserId', isEqualTo: userId)
          .where('viewedAt', isGreaterThanOrEqualTo: dateRange.start)
          .where('viewedAt', isLessThanOrEqualTo: dateRange.end)
          .get();

      return profileViewsSnapshot.docs.length;
    } catch (e) {
      print('Error getting profile views: $e');
      // Fallback: count unique followers
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final followers = List.from(userDoc.data()?['followers'] ?? []);
      return followers.length;
    }
  }

  // Get posts data with insights
  Future<List<Map<String, dynamic>>> _getPostsData(
      String userId,
      DateTimeRange dateRange,
      ) async {
    try {
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: dateRange.start)
          .where('createdAt', isLessThanOrEqualTo: dateRange.end)
          .orderBy('createdAt', descending: true)
          .limit(10) // Limit to recent 10 posts for performance
          .get();

      return postsSnapshot.docs.map((doc) {
        final data = doc.data();
        final likes = List.from(data['likes'] ?? []);
        final comments = List.from(data['comments'] ?? []);
        final viewCount = (data['viewCount'] ?? 0) as int;
        final shareCount = (data['shareCount'] ?? 0) as int;

        final totalInteractions = likes.length + comments.length + shareCount;
        final engagementRate = viewCount > 0
            ? (totalInteractions / viewCount * 100)
            : 0;

        return {
          'id': doc.id,
          'mediaUrl': data['mediaUrl'] ?? '',
          'likes': likes.length,
          'comments': comments.length,
          'shares': shareCount,
          'reach': viewCount,
          'engagement': engagementRate.clamp(0.0, 100.0),
          'timestamp': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error getting posts data: $e');
      return [];
    }
  }

  // Get stories data with insights
  Future<List<Map<String, dynamic>>> _getStoriesData(
      String userId,
      DateTimeRange dateRange,
      ) async {
    try {
      final storiesSnapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: dateRange.start)
          .where('createdAt', isLessThanOrEqualTo: dateRange.end)
          .orderBy('createdAt', descending: true)
          .get();

      return storiesSnapshot.docs.map((doc) {
        final data = doc.data();
        final views = List.from(data['views'] ?? []);
        final replies = List.from(data['replies'] ?? []);

        // Calculate completion rate (assume 70% completion for views with replies, 40% for views without replies)
        final completionRate = views.isNotEmpty
            ? ((replies.length / views.length) * 70 +
            (views.length - replies.length) / views.length * 40)
            .clamp(0.0, 100.0)
            : 0.0;

        return {
          'id': doc.id,
          'mediaUrl': data['mediaUrl'] ?? '',
          'views': views.length,
          'replies': replies.length,
          'completionRate': completionRate,
          'timestamp': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error getting stories data: $e');
      return [];
    }
  }

  // Get live streams data with insights
  Future<List<Map<String, dynamic>>> _getLiveStreamsData(
      String userId,
      DateTimeRange dateRange,
      ) async {
    try {
      final liveStreamsSnapshot = await FirebaseFirestore.instance
          .collection('live_history')
          .where('UID', isEqualTo: userId)
          .where('start_time', isGreaterThanOrEqualTo: dateRange.start)
          .where('start_time', isLessThanOrEqualTo: dateRange.end)
          .orderBy('start_time', descending: true)
          .get();

      return liveStreamsSnapshot.docs.map((doc) {
        final data = doc.data();
        final peakViewers = (data['peakViewers'] ?? data['viewerCount'] ?? 0) as int;
        final totalViewers = (data['viewerCount'] ?? 0) as int;
        final duration = (data['durationSeconds'] ?? 0) as int;
        final gifts = (data['totalGiftValue'] ?? 0) as int;

        // Calculate engagement score (0-10)
        final engagementScore = duration > 0
            ? ((peakViewers / 50 * 4) + (gifts / 10 * 3) + (duration / 600 * 3))
            .clamp(0.0, 10.0)
            : 0.0;

        return {
          'id': doc.id,
          'title': data['title'] ?? 'Live Stream',
          'peakViewers': peakViewers,
          'totalViewers': totalViewers,
          'duration': duration,
          'giftsReceived': gifts,
          'engagementScore': engagementScore,
          'timestamp': (data['end_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('Error getting live streams data: $e');
      return [];
    }
  }

  // Get audience demographics
  Future<Map<String, dynamic>> _getAudienceDemographics(
      String userId,
      DateTimeRange dateRange,
      ) async {
    try {
      // For demo purposes, return mock data. In a real app, you'd aggregate this from user interactions
      return {
        'ageGroups': {'18-24': 35, '25-34': 45, '35-44': 15, '45+': 5},
        'gender': {'male': 60, 'female': 40},
        'topLocations': {
          'Lagos': 25,
          'Abuja': 18,
          'Port Harcourt': 12,
          'Others': 45,
        },
      };
    } catch (e) {
      print('Error getting audience demographics: $e');
      return {'ageGroups': {}, 'gender': {}, 'topLocations': {}};
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? _buildLoadingState()
        : SizedBox( // Wrap with SizedBox to provide constraints
      height: MediaQuery.of(context).size.height,
      child: _buildInsightsContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Loading your insights...',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsContent() {
    return RefreshIndicator(
      onRefresh: _loadInsightsData,
      child: SingleChildScrollView( // Changed from ListView to SingleChildScrollView
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Premium Banner
            _buildPremiumBanner(),
            const SizedBox(height: 20),

            // Time Frame Selector
            _buildTimeFrameSelector(),
            const SizedBox(height: 20),

            // Overview Cards
            _buildOverviewCards(),
            const SizedBox(height: 20),

            // Posts Performance
            if ((_insightsData['posts'] as List).isNotEmpty)
              _buildPostsPerformance(),
            if ((_insightsData['posts'] as List).isNotEmpty)
              const SizedBox(height: 20),

            // Stories Performance
            if ((_insightsData['stories'] as List).isNotEmpty)
              _buildStoriesPerformance(),
            if ((_insightsData['stories'] as List).isNotEmpty)
              const SizedBox(height: 20),

            // Live Streams Performance
            if ((_insightsData['liveStreams'] as List).isNotEmpty)
              _buildLiveStreamsPerformance(),
            if ((_insightsData['liveStreams'] as List).isNotEmpty)
              const SizedBox(height: 20),

            // Audience Demographics
            _buildAudienceDemographics(),

            const SizedBox(height: 20), // Add some bottom padding
          ],
        ),
      ),
    );
  }
  Widget _buildPremiumBanner() {
    return GestureDetector(
      onTap: widget.onFindOutHowTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Colors.pink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.insights, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Advanced Insights",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Get detailed analytics and performance metrics with Premium+",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFrameSelector() {
    final timeFrames = ['Last 7 days', 'Last 30 days', 'All time'];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(timeFrames.length, (index) {
          final isSelected = _selectedTimeFrame == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTimeFrame = index;
                });
                _loadInsightsData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeFrames[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildOverviewCard(
              'Total Reach',
              '${_formatNumber(_insightsData['totalReach'] ?? 0)}',
              Icons.people,
              Colors.blue,
            ),
            _buildOverviewCard(
              'Engagement Rate',
              '${(_insightsData['engagementRate'] ?? 0.0).toStringAsFixed(1)}%',
              Icons.trending_up,
              Colors.green,
            ),
            _buildOverviewCard(
              'Profile Views',
              '${_formatNumber(_insightsData['profileViews'] ?? 0)}',
              Icons.remove_red_eye,
              Colors.orange,
            ),
            _buildOverviewCard(
              'Total Posts',
              '${(_insightsData['posts'] as List).length}',
              Icons.photo_library,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildOverviewCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostsPerformance() {
    final posts = _insightsData['posts'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Posts Performance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...posts.map((post) => _buildPostInsightItem(post)).toList(),
      ],
    );
  }

  Widget _buildPostInsightItem(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Post Thumbnail
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              image: DecorationImage(
                image: NetworkImage(post['mediaUrl'] ?? ''),
                fit: BoxFit.cover,
              ),
            ),
            child: post['mediaUrl'] == null || post['mediaUrl']!.isEmpty
                ? Container(
              color: Colors.grey[200],
              child: const Icon(Icons.photo, color: Colors.grey),
            )
                : null,
          ),
          const SizedBox(width: 12),

          // Post Metrics
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem('❤️', '${post['likes']}'),
                      _buildMetricItem('💬', '${post['comments']}'),
                      _buildMetricItem('🔄', '${post['shares']}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem('👁️', '${post['reach']}'),
                      _buildMetricItem('📊', '${(post['engagement'] as double).toStringAsFixed(1)}%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String emoji, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStoriesPerformance() {
    final stories = _insightsData['stories'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stories Performance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...stories.map((story) => _buildStoryInsightItem(story)).toList(),
      ],
    );
  }

  Widget _buildStoryInsightItem(Map<String, dynamic> story) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Story Thumbnail
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: story['mediaUrl'] != null && story['mediaUrl']!.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(story['mediaUrl']!),
                fit: BoxFit.cover,
              )
                  : null,
              color: story['mediaUrl'] == null || story['mediaUrl']!.isEmpty
                  ? Colors.grey[200]
                  : null,
            ),
            child: story['mediaUrl'] == null || story['mediaUrl']!.isEmpty
                ? const Icon(Icons.photo, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),

          // Story Metrics
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStoryMetric('Views', '${story['views']}'),
                    _buildStoryMetric('Replies', '${story['replies']}'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (story['completionRate'] ?? 0) / 100,
                  backgroundColor: Colors.grey[200],
                  color: AppColors.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  'Completion: ${(story['completionRate'] as double).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLiveStreamsPerformance() {
    final liveStreams = _insightsData['liveStreams'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Streams Performance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...liveStreams
            .map((live) => _buildLiveStreamInsightItem(live))
            .toList(),
      ],
    );
  }

  Widget _buildLiveStreamInsightItem(Map<String, dynamic> live) {
    final duration = Duration(seconds: live['duration'] ?? 0);
    final durationText = '${duration.inMinutes} min';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            live['title'] ?? 'Live Stream',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLiveMetric('Peak Viewers', '${live['peakViewers']}'),
              _buildLiveMetric('Total Viewers', '${live['totalViewers']}'),
              _buildLiveMetric('Duration', durationText),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLiveMetric('Gifts', '${live['giftsReceived']}'),
              _buildLiveMetric('Engagement', '${(live['engagementScore'] as double).toStringAsFixed(1)}/10'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildAudienceDemographics() {
    final demographics = _insightsData['audienceDemographics'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Audience Demographics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Age Groups
        _buildDemographicSection(
          'Age Groups',
          demographics['ageGroups'] ?? {},
          Icons.person,
        ),
        const SizedBox(height: 16),

        // Gender
        _buildDemographicSection(
          'Gender',
          demographics['gender'] ?? {},
          Icons.people,
        ),
        const SizedBox(height: 16),

        // Top Locations
        _buildDemographicSection(
          'Top Locations',
          demographics['topLocations'] ?? {},
          Icons.location_on,
        ),
      ],
    );
  }

  Widget _buildDemographicSection(
      String title,
      Map<String, dynamic> data,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.isEmpty)
            const Text(
              'No data available',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...data.entries
                .map(
                  (entry) => _buildDemographicItem(entry.key, '${entry.value}%'),
            )
                .toList(),
        ],
      ),
    );
  }

  Widget _buildDemographicItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
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
                    MaterialPageRoute(builder: (_) => HomeScreen()),
                  );
                }

                if (i == 3 && current != 3) {
                  // Changed from 4 to 3 for Live tab

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ActivityScreen()
                    ),
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
                        color: selected ? AppColors.primary : Colors.black54,
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


