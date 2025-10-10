// lib/user_channel.dart
import 'package:flutter/material.dart';

class UserChannelScreen extends StatelessWidget {
  const UserChannelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ---- Dummy user data (wire with backend later) ----
    const username = "@abdullah_k";
    const displayName = "Abdullah Khan";
    const location = "Lahore, PK";
    final joined = DateTime(2024, 6, 12);
    const bio =
        "Streamer • Developer • chai enthusiast ☕️\n"
        "Mostly IRL + gaming. Weekends = community Q&A.";

    const followers = 1280;
    const following = 342;
    const subscribers = 96;

    const website = "abdullah.dev";
    const email = "hello@abdullah.dev";
    const xHandle = "@abdullah";
    const instagram = "@abdullah.ig";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          // Header
          Row(
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundImage: NetworkImage(
                  "https://i.pravatar.cc/160?img=8",
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit, size: 18),
                label: const Text(
                  "Edit",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            username,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),

          // Stats row
          Row(
            children: const [
              _StatTile(label: "Followers", value: followers),
              SizedBox(width: 10),
              _StatTile(label: "Following", value: following),
              SizedBox(width: 10),
              _StatTile(label: "Subscribers", value: subscribers),
            ],
          ),
          const SizedBox(height: 14),

          // Actions row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined),
                  label: const Text(
                    "Share Profile",
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
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.people_outline),
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
            ],
          ),
          const SizedBox(height: 20),

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
                  icon: Icons.location_on_outlined,
                  label: "Location",
                  value: location,
                ),
                _InfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: "Joined",
                  value: _fmtDate(joined),
                ),
                const _InfoTile(
                  icon: Icons.verified_outlined,
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
              children: const [
                _InfoTile(
                  icon: Icons.language_outlined,
                  label: "Website",
                  value: website,
                ),
                _InfoTile(
                  icon: Icons.mail_outline,
                  label: "Email",
                  value: email,
                ),
                _InfoTile(
                  icon: Icons.alternate_email,
                  label: "X",
                  value: xHandle,
                ),
                _InfoTile(
                  icon: Icons.camera_alt_outlined,
                  label: "Instagram",
                  value: instagram,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Preferences / Settings CTA
          _SectionCard(
            title: "Preferences",
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.lock_outline,
                  title: "Privacy",
                  subtitle: "Followers-only chat, hide online status",
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.notifications_active_outlined,
                  title: "Notifications",
                  subtitle: "Mentions, new subs, gifts",
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.palette_outlined,
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

/* ---------------- Components ---------------- */

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
          Icon(icon, color: Colors.black87),
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
            Icon(icon, color: Colors.black87),
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
            const Icon(Icons.chevron_right, color: Colors.black45),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
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
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
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
