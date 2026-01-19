import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:meet9ja/screens/edit_profile_screen.dart';
import 'package:meet9ja/screens/signin_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/privacy_policy_popup.dart';
import '../constants/terms_condition_popup.dart';
import '../db_functions/user_service.dart';
import 'package:mailto/mailto.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  // Firebase instances
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Section
              _SettingsSection(
                title: 'Account',
                children: [
                  _SettingsTile(
                    icon: FontAwesomeIcons.user,
                    title: 'Edit Profile',
                    subtitle: 'Update your profile information',
                    onTap: () => _navigateToEditProfile(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.trash,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account',
                    onTap: () => _showDeleteAccountDialog(context),
                    iconColor: Colors.red,
                    showArrow: true,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Payments Section
              _SettingsSection(
                title: 'Payments',
                children: [
                  _SettingsTile(
                    icon: FontAwesomeIcons.receipt,
                    title: 'Transaction History',
                    subtitle: 'View your payment history',
                    onTap: () => _showTransactionHistory(context),
                    showArrow: true,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Safety & Support Section
              _SettingsSection(
                title: 'Safety & Support',
                children: [
                  _SettingsTile(
                    icon: FontAwesomeIcons.shieldHalved,
                    title: 'Community Guidelines',
                    subtitle: 'Read our community rules',
                    onTap: () => _showCommunityGuidelines(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.flag,
                    title: 'Report a Problem',
                    subtitle: 'Report issues or concerns',
                    onTap: () => _showReportProblemDialog(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.history,
                    title: 'Report History',
                    subtitle: 'View your submitted reports',
                    onTap: () => _showReportHistory(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.headset,
                    title: 'Help Center',
                    subtitle: 'Get help and support',
                    onTap: () => _openHelpCenterEmail(context),
                    showArrow: true,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Legal Section
              _SettingsSection(
                title: 'Legal',
                children: [
                  _SettingsTile(
                    icon: FontAwesomeIcons.lock,
                    title: 'Privacy Policy',
                    subtitle: 'How we protect your data',
                    onTap: () => _showPrivacyPolicy(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.gavel,
                    title: 'Terms & Conditions',
                    subtitle: 'Our terms of service',
                    onTap: () => _showTermsConditions(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.cookie,
                    title: 'Cookie Policy',
                    subtitle: 'How we use cookies',
                    onTap: () => _showCookiePolicy(context),
                    showArrow: true,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // About Section
              _SettingsSection(
                title: 'About',
                children: [
                  _SettingsTile(
                    icon: FontAwesomeIcons.building,
                    title: 'Meet9ja Limited',
                    subtitle: 'About our company',
                    onTap: () => _showAboutCompany(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.envelope,
                    title: 'Contact Us',
                    subtitle: 'Get in touch with us',
                    onTap: () => _showContactUs(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.star,
                    title: 'Rate App',
                    subtitle: 'Rate us on app store',
                    onTap: () => _rateApp(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.codeBranch,
                    title: 'App Version',
                    subtitle: 'Version 1.0.0',
                    onTap: () {},
                    showArrow: false,
                    isVersion: true,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Log Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutConfirmation(context),
                  icon: const Icon(FontAwesomeIcons.rightFromBracket),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red.shade200, width: 1),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Delete Account Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _showDeleteAccountDialog(context),
                  child: const Text(
                    'Delete My Account',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Footer
              const Center(
                child: Column(
                  children: [
                    Text(
                      'Meet9ja Dating App',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '© 2025 Meet9ja Limited. All rights reserved.',
                      style: TextStyle(color: Colors.black38, fontSize: 12),
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

  // ============ NAVIGATION METHODS ============
  void _navigateToEditProfile(BuildContext context) async {
    try {
      final currentUser = SettingsScreen._auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to edit profile'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading profile...'),
            ],
          ),
        ),
      );

      // Use UserService to get profile
      final userProfile = await UserService.getUserProfile(currentUser.uid);

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (userProfile != null) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditProfileScreen(userProfile: userProfile),
          ),
        );

        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User profile not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print('❌ Error loading profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ ACCOUNT DELETION ============
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(FontAwesomeIcons.triangleExclamation, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Account'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone. All your data, including:',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            SizedBox(height: 8),
            Text('• Profile information'),
            Text('• Messages and matches'),
            Text('• Photos and posts'),
            Text('• Payment history'),
            SizedBox(height: 12),
            Text(
              'Will be permanently deleted from our servers.',
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _processAccountDeletion(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _processAccountDeletion(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting your account...'),
          ],
        ),
      ),
    );

    try {
      final currentUser = SettingsScreen._auth.currentUser;
      if (currentUser == null) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No user logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userId = currentUser.uid;

      // 1. Delete user data from Firestore
      await _deleteUserData(userId);

      // 2. Delete authentication account
      await currentUser.delete();

      // 3. Navigate to login screen
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close confirmation dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Signinscreen()),
        (route) => false,
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      print('❌ Error deleting account: $e');

      // If user needs to re-authenticate
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        _showReauthenticationDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUserData(String userId) async {
    try {
      final batch = SettingsScreen._firestore.batch();

      // Delete user document
      batch.delete(SettingsScreen._firestore.collection('users').doc(userId));

      // Delete user's posts
      final postsQuery = await SettingsScreen._firestore
          .collection('user_feed')
          .where('UID', isEqualTo: userId)
          .get();

      for (final doc in postsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's stories
      final storiesQuery = await SettingsScreen._firestore
          .collection('stories')
          .where('UID', isEqualTo: userId)
          .get();

      for (final doc in storiesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Remove user from other users' followers/following lists
      await _removeUserFromSocialLists(userId);

      // Delete matches
      final matchesQuery = await SettingsScreen._firestore
          .collection('matches')
          .where('user1Id', isEqualTo: userId)
          .where('user2Id', isEqualTo: userId)
          .get();

      for (final doc in matchesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete chat messages
      final chatsQuery = await SettingsScreen._firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      for (final doc in chatsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete notifications
      final notificationsQuery = await SettingsScreen._firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in notificationsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ User data deleted successfully');
    } catch (e) {
      print('❌ Error deleting user data: $e');
      throw e;
    }
  }

  Future<void> _removeUserFromSocialLists(String userId) async {
    try {
      // Get all users who have this user in their followers/following
      final usersQuery = await SettingsScreen._firestore
          .collection('users')
          .where('followers', arrayContains: userId)
          .get();

      final batch = SettingsScreen._firestore.batch();

      for (final doc in usersQuery.docs) {
        batch.update(doc.reference, {
          'followers': FieldValue.arrayRemove([userId]),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      final followingQuery = await SettingsScreen._firestore
          .collection('users')
          .where('following', arrayContains: userId)
          .get();

      for (final doc in followingQuery.docs) {
        batch.update(doc.reference, {
          'following': FieldValue.arrayRemove([userId]),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('❌ Error removing user from social lists: $e');
    }
  }

  void _showReauthenticationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-authentication Required'),
        content: const Text(
          'For security purposes, please log in again before deleting your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout(context); // Log out and have user log in again
            },
            child: const Text('Re-authenticate'),
          ),
        ],
      ),
    );
  }

  // ============ TRANSACTION HISTORY ============
  void _showTransactionHistory(BuildContext context) async {
    try {
      final currentUser = SettingsScreen._auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to view transaction history'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading transactions...'),
            ],
          ),
        ),
      );

      // Fetch transactions from Firestore
      final transactionsQuery = await SettingsScreen._firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      Navigator.pop(context); // Close loading dialog

      if (transactionsQuery.docs.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(FontAwesomeIcons.receipt, color: Colors.blue),
                SizedBox(width: 12),
                Text('Transaction History'),
              ],
            ),
            content: const Text('No transactions found.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      // Show transaction history dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(FontAwesomeIcons.receipt, color: Colors.blue),
              SizedBox(width: 12),
              Text('Transaction History'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Text(
                  'Total Transactions: ${transactionsQuery.docs.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final doc in transactionsQuery.docs)
                          _TransactionItem(doc.data()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading transactions: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ REPORT HISTORY ============
  void _showReportHistory(BuildContext context) async {
    try {
      final currentUser = SettingsScreen._auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to view report history'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading reports...'),
            ],
          ),
        ),
      );

      final userId = currentUser.uid;

      // Fetch reports from BOTH collections
      final List<Future<QuerySnapshot>> futures = [
        // Problem reports from settings
        SettingsScreen._firestore
            .collection('problem_reports')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get(),

        // Profile reports from matched users screen
        SettingsScreen._firestore
            .collection('reports')
            .where('reporterId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get(),
      ];

      final List<QuerySnapshot> results = await Future.wait(futures);

      final problemReports = results[0].docs;
      final profileReports = results[1].docs;

      // Combine all reports
      final List<Map<String, dynamic>> allReports = [];

      // Process problem reports (from settings)
      for (final doc in problemReports) {
        final data = doc.data() as Map<String, dynamic>;
        allReports.add({
          'type': 'problem_report',
          'data': data,
          'timestamp': data['createdAt'],
          'id': doc.id,
        });
      }

      // Process profile reports (from matched users screen)
      for (final doc in profileReports) {
        final data = doc.data() as Map<String, dynamic>;

        // Fetch reported user's name for display
        String reportedUserName = 'User';
        try {
          final reportedUserId = data['reportedUserId'];
          if (reportedUserId != null) {
            final reportedUserDoc = await SettingsScreen._firestore
                .collection('users')
                .doc(reportedUserId)
                .get();
            if (reportedUserDoc.exists) {
              final userData = reportedUserDoc.data() as Map<String, dynamic>?;
              reportedUserName = userData?['name'] ?? 'User';
            }
          }
        } catch (e) {
          print('❌ Error fetching reported user data: $e');
        }

        // Format profile report data
        allReports.add({
          'type': 'profile_report',
          'data': {
            ...data,
            'reportedUserName': reportedUserName,
          },
          'timestamp': data['createdAt'],
          'id': doc.id,
        });
      }

      // Sort all reports by timestamp (newest first)
      allReports.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      Navigator.pop(context); // Close loading dialog

      if (allReports.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(FontAwesomeIcons.history, color: Colors.blue),
                SizedBox(width: 12),
                Text('Report History'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FontAwesomeIcons.file, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No reports found',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'You haven\'t submitted any reports yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      // Show report history dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Container(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                const Icon(FontAwesomeIcons.history, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report History',
                        style: TextStyle(fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${allReports.length} reports',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                // Summary Statistics
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ReportStat(
                        count: allReports
                            .where((r) => r['type'] == 'profile_report')
                            .length,
                        label: 'Profile Reports',
                        color: Colors.red,
                      ),
                      _ReportStat(
                        count: allReports
                            .where((r) => r['type'] == 'problem_report')
                            .length,
                        label: 'Problem Reports',
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Report Type Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Reports'),
                        selected: true,
                        onSelected: null,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        labelStyle: const TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Reports List
                Expanded(
                  child: allReports.isEmpty
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FontAwesomeIcons.file, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No reports found'),
                      ],
                    ),
                  )
                      : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final report in allReports)
                          _CombinedReportItem(
                            report: report,
                            onViewDetails: () => _showReportDetails(
                              context,
                              report,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print('❌ Error loading reports: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading reports: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Show detailed report view
  void _showReportDetails(BuildContext context, Map<String, dynamic> report) {
    final type = report['type'];
    final data = report['data'] as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              type == 'profile_report'
                  ? FontAwesomeIcons.user
                  : FontAwesomeIcons.flag,
              color: type == 'profile_report' ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 12),
            Text(
              type == 'profile_report'
                  ? 'Profile Report Details'
                  : 'Problem Report Details',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Report Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: type == 'profile_report'
                      ? Colors.red.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  type == 'profile_report' ? 'PROFILE REPORT' : 'PROBLEM REPORT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: type == 'profile_report' ? Colors.red : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (type == 'profile_report') ...[
                // Profile Report Details
                _DetailItem(
                  label: 'Reported User:',
                  value: data['reportedUserName'] ?? 'User',
                  icon: FontAwesomeIcons.user,
                ),
                _DetailItem(
                  label: 'Reason:',
                  value: data['reason'] ?? 'Not specified',
                  icon: FontAwesomeIcons.exclamationTriangle,
                ),
                if (data['details'] != null && data['details'].toString().isNotEmpty)
                  _DetailItem(
                    label: 'Additional Details:',
                    value: data['details'].toString(),
                    icon: FontAwesomeIcons.noteSticky,
                  ),
              ] else if (type == 'problem_report') ...[
                // Problem Report Details
                _DetailItem(
                  label: 'Category:',
                  value: data['category'] ?? 'General',
                  icon: FontAwesomeIcons.tags,
                ),
                _DetailItem(
                  label: 'Description:',
                  value: data['description'] ?? 'No description',
                  icon: FontAwesomeIcons.comment,
                ),
              ],

              const SizedBox(height: 16),

              // Status Information
              _DetailItem(
                label: 'Status:',
                value: _getStatusText(data['status']),
                icon: FontAwesomeIcons.circle,
                valueColor: _getStatusColor(data['status']),
              ),

              // Timestamps
              if (data['createdAt'] != null) ...[
                const SizedBox(height: 12),
                _DetailItem(
                  label: 'Submitted:',
                  value: _formatTimestamp(data['createdAt']),
                  icon: FontAwesomeIcons.calendar,
                ),
              ],

              if (data['updatedAt'] != null) ...[
                const SizedBox(height: 8),
                _DetailItem(
                  label: 'Last Updated:',
                  value: _formatTimestamp(data['updatedAt']),
                  icon: FontAwesomeIcons.clock,
                ),
              ],

              // Report ID
              const SizedBox(height: 16),
              _DetailItem(
                label: 'Report ID:',
                value: data['reportId']?.toString().substring(0, 12) ?? 'N/A',
                icon: FontAwesomeIcons.fingerprint,
                copyable: true,
                onCopy: () => _copyToClipboard(context, data['reportId'].toString()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (type == 'profile_report')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Optionally navigate to user profile
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report details closed'),
                    backgroundColor: Colors.grey,
                  ),
                );
              },
              child: const Text('View Profile'),
            ),
        ],
      ),
    );
  }

  String _getStatusText(String? status) {
    if (status == null) return 'Pending';

    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending Review';
      case 'reviewed':
        return 'Under Review';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.orange;

    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (timestamp is String) {
        return timestamp;
      } else if (timestamp is DateTime) {
        return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      print('❌ Error formatting timestamp: $e');
    }
    return 'Date not available';
  }

  // ============ COMING SOON FEATURES ============
  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // ============ COMMUNITY GUIDELINES ============
  void _showCommunityGuidelines(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Container(
          padding: const EdgeInsets.only(right: 12), // Fix overflow issue
          child: const Row(
            children: [
              Icon(FontAwesomeIcons.shieldHalved, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Community Guidelines',
                  style: TextStyle(fontSize: 18),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To ensure a safe and respectful environment for all users, please follow these guidelines:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              _GuidelineItem(
                icon: FontAwesomeIcons.user,
                title: 'Be Respectful',
                description:
                    'Treat all users with kindness and respect. Harassment, hate speech, and bullying will not be tolerated.',
              ),

              _GuidelineItem(
                icon: FontAwesomeIcons.camera,
                title: 'Authentic Profiles',
                description:
                    'Use recent, clear photos of yourself. No impersonation or fake profiles allowed.',
              ),

              _GuidelineItem(
                icon: FontAwesomeIcons.ban,
                title: 'No Inappropriate Content',
                description:
                    'Do not share explicit, violent, or offensive content. Keep conversations appropriate.',
              ),

              _GuidelineItem(
                icon: FontAwesomeIcons.shield,
                title: 'Protect Your Privacy',
                description:
                    'Never share personal information like passwords, financial details, or home addresses.',
              ),

              _GuidelineItem(
                icon: FontAwesomeIcons.flag,
                title: 'Report Violations',
                description:
                    'Report any suspicious or inappropriate behavior immediately using the in-app reporting tools.',
              ),

              _GuidelineItem(
                icon: FontAwesomeIcons.moneyBillWave,
                title: 'No Financial Scams',
                description:
                    'Do not ask for money or financial information from other users.',
              ),

              const SizedBox(height: 16),
              const Text(
                'Violations may result in account suspension or permanent ban.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ============ REPORT PROBLEM ============
  void _showReportProblemDialog(BuildContext context) {
    final TextEditingController problemController = TextEditingController();
    String selectedCategory = 'Bug Report';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(FontAwesomeIcons.flag, color: Colors.blue),
                SizedBox(width: 12),
                Text('Report a Problem'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please describe the issue you\'re experiencing:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Category Selection
                  const Text('Category:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Bug Report',
                        child: Text('Bug Report'),
                      ),
                      DropdownMenuItem(
                        value: 'Feature Request',
                        child: Text('Feature Request'),
                      ),
                      DropdownMenuItem(
                        value: 'Account Issue',
                        child: Text('Account Issue'),
                      ),
                      DropdownMenuItem(
                        value: 'Payment Problem',
                        child: Text('Payment Problem'),
                      ),
                      DropdownMenuItem(
                        value: 'Safety Concern',
                        child: Text('Safety Concern'),
                      ),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Problem Description
                  const Text('Description:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: problemController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Describe the problem in detail...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Screenshot Option
                  const Text('Optional: Attach screenshots'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Screenshot attachment coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.attach_file, size: 16),
                    label: const Text('Attach Screenshot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _submitProblemReport(
                  context,
                  selectedCategory,
                  problemController.text,
                ),
                child: const Text('Submit Report'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _submitProblemReport(
    BuildContext context,
    String category,
    String description,
  ) async {
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the problem')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Submitting report...'),
          ],
        ),
      ),
    );

    try {
      final currentUser = SettingsScreen._auth.currentUser;
      if (currentUser == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to submit a report'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final reportId = SettingsScreen._firestore.collection('problem_reports').doc().id;
      final now = DateTime.now();
      final reportData = {
        'reportId': reportId,
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'userName': currentUser.displayName,
        'category': category,
        'description': description,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'appVersion': '1.0.0',
        'platform': '${Theme.of(context).platform}',
        'formattedDate': '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}',
      };

      await SettingsScreen._firestore
          .collection('problem_reports')
          .doc(reportId)
          .set(reportData);

      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close report dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted successfully! We\'ll review it soon.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the page to show updated report history
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ HELP CENTER ============
  void _openHelpCenterEmail(BuildContext context) async {
    try {
      final mailtoLink = Mailto(
        to: ['help@meet9ja.com'],
        subject: 'Meet9ja Help Request',
        body: 'Hello Meet9ja Support Team,\n\nI need help with:',
      );

      final url = Uri.parse(mailtoLink.toString());
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        // Fallback to copying email to clipboard
        await Clipboard.setData(const ClipboardData(text: 'help@meet9ja.com'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email copied to clipboard: help@meet9ja.com'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot open email client: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ PRIVACY POLICY ============
  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PrivacyPolicyPopup(),
    );
  }

  // ============ TERMS & CONDITIONS ============
  void _showTermsConditions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TermsConditionsPopup(),
    );
  }

  // ============ COOKIE POLICY ============
  void _showCookiePolicy(BuildContext context) async {
    try {
      const url = 'https://meet9ja.com/cookie-policy';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // Fallback to detailed dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(FontAwesomeIcons.cookie, color: Colors.brown),
                SizedBox(width: 12),
                Text('Cookie Policy'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Our Cookie Policy',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We use cookies and similar tracking technologies to enhance your experience on Meet9ja.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Types of Cookies
                  const Text(
                    'Types of Cookies We Use:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _CookieItem('🍪 Essential Cookies', 
                    'Required for basic functions like login and security'),
                  _CookieItem('🎯 Performance Cookies', 
                    'Help us understand how you use our app to improve it'),
                  _CookieItem('🔒 Security Cookies', 
                    'Protect your account from unauthorized access'),
                  _CookieItem('📊 Analytics Cookies', 
                    'Collect anonymous data to analyze app performance'),
                  _CookieItem('🎨 Preference Cookies', 
                    'Remember your settings and preferences'),

                  const SizedBox(height: 16),

                  // How We Use Cookies
                  const Text(
                    'How We Use Cookies:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _CookieUsageItem('Authentication', 
                    'Keep you logged in during your session'),
                  _CookieUsageItem('Security', 
                    'Prevent fraudulent use of login credentials'),
                  _CookieUsageItem('Preferences', 
                    'Remember your language and display settings'),
                  _CookieUsageItem('Analytics', 
                    'Understand which features are most popular'),
                  _CookieUsageItem('Performance', 
                    'Monitor and improve app loading times'),

                  const SizedBox(height: 16),

                  // Third-Party Cookies
                  const Text(
                    'Third-Party Cookies:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We may use third-party services like Google Analytics and Firebase that set their own cookies to help us analyze app usage.',
                    style: TextStyle(fontSize: 13),
                  ),

                  const SizedBox(height: 16),

                  // Cookie Management
                  const Text(
                    'Managing Cookies:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You can control cookies through your device settings. However, disabling essential cookies may affect app functionality.',
                    style: TextStyle(fontSize: 13),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'By using Meet9ja, you consent to our use of cookies as described above.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openWebsite(context, 'https://meet9ja.com/cookie-policy');
                },
                child: const Text('View Full Policy'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open cookie policy at this time'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ ABOUT COMPANY ============
  void _showAboutCompany(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(FontAwesomeIcons.building, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Meet9ja Limited'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.1),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.heart,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Company Description
              const Text(
                'Meet9ja is Nigeria\'s premier dating and connection platform, founded in 2023. We\'re on a mission to help Nigerians find meaningful connections, whether for dating, friendship, business, or travel.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Vision
              const Text(
                'Our Vision:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'To become Africa\'s most trusted platform for genuine human connections.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),

              // Mission
              const Text(
                'Our Mission:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'To create a safe, inclusive space where Nigerians can connect authentically, build relationships, and expand their social circles.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Key Features
              const Text(
                'Key Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _AboutFeature(
                '🎯 Smart Matching',
                'AI-powered matching based on preferences',
              ),
              _AboutFeature(
                '🔒 Safety First',
                'Advanced safety features and verification',
              ),
              _AboutFeature('📹 Live Streaming', 'Real-time video connections'),
              _AboutFeature(
                '🌍 Global Reach',
                'Connect with Nigerians worldwide',
              ),
              _AboutFeature(
                '💼 Multiple Modes',
                'Date, Travel, BFF, and Business modes',
              ),

              const SizedBox(height: 16),

              // Contact
              const Text(
                'Contact Information:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _ContactInfo('🏢', 'Headquarters:', 'Lagos, Nigeria'),
              _ContactInfo('📧', 'Email:', 'hello@meet9ja.com'),
              _ContactInfo('🌐', 'Website:', 'www.meet9ja.com'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ============ CONTACT US ============
  void _showContactUs(BuildContext context) {
    final TextEditingController messageController = TextEditingController();
    String selectedTopic = 'General Inquiry';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(FontAwesomeIcons.envelope, color: Colors.blue),
                SizedBox(width: 12),
                Text('Contact Us'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'We\'d love to hear from you! Please fill out the form below:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Topic Selection
                  const Text('Topic:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedTopic,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'General Inquiry',
                        child: Text('General Inquiry'),
                      ),
                      DropdownMenuItem(
                        value: 'Technical Support',
                        child: Text('Technical Support'),
                      ),
                      DropdownMenuItem(
                        value: 'Account Help',
                        child: Text('Account Help'),
                      ),
                      DropdownMenuItem(
                        value: 'Business Inquiry',
                        child: Text('Business Inquiry'),
                      ),
                      DropdownMenuItem(
                        value: 'Partnership',
                        child: Text('Partnership'),
                      ),
                      DropdownMenuItem(value: 'Press', child: Text('Press')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedTopic = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Message
                  const Text('Message:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: messageController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Type your message here...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact Methods
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Other ways to reach us:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  _ContactMethod(
                    icon: FontAwesomeIcons.envelope,
                    label: 'Email',
                    value: 'support@meet9ja.com',
                    onTap: () =>
                        _copyToClipboard(context, 'support@meet9ja.com'),
                  ),

                  _ContactMethod(
                    icon: FontAwesomeIcons.phone,
                    label: 'Phone',
                    value: '+234 800 000 0000',
                    onTap: () => _copyToClipboard(context, '+2348000000000'),
                  ),

                  _ContactMethod(
                    icon: FontAwesomeIcons.globe,
                    label: 'Website',
                    value: 'www.meet9ja.com',
                    onTap: () => _copyToClipboard(context, 'www.meet9ja.com'),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'Business hours: Monday - Friday, 9am - 6pm WAT',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _submitContactForm(
                  context,
                  selectedTopic,
                  messageController.text,
                ),
                child: const Text('Send Message'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _submitContactForm(
    BuildContext context,
    String topic,
    String message,
  ) async {
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your message')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Sending message...'),
          ],
        ),
      ),
    );

    try {
      final currentUser = SettingsScreen._auth.currentUser;
      final userEmail = currentUser?.email ?? 'Not provided';
      final userName = currentUser?.displayName ?? 'Anonymous User';
      final userId = currentUser?.uid ?? 'anonymous';

      final contactId = SettingsScreen._firestore.collection('contact_messages').doc().id;
      final contactData = {
        'contactId': contactId,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'topic': topic,
        'message': message,
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await SettingsScreen._firestore
          .collection('contact_messages')
          .doc(contactId)
          .set(contactData);

      // Send email notification (in a real app, this would be a Cloud Function)
      print('📧 Contact form submitted: $topic - $message');

      Navigator.pop(context); // Close loading
      Navigator.pop(context); // Close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message sent successfully! We\'ll respond within 24 hours.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyToClipboard(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied: $text'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ RATE APP ============
  void _rateApp(BuildContext context) async {
    // Determine platform
    final platform = Theme.of(context).platform;

    String appStoreUrl;
    if (platform == TargetPlatform.iOS) {
      appStoreUrl = 'https://apps.apple.com/app/meet9ja/idYOUR_APP_ID';
    } else if (platform == TargetPlatform.android) {
      appStoreUrl =
          'https://play.google.com/store/apps/details?id=com.meet9ja.app';
    } else {
      appStoreUrl = 'https://meet9ja.com';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(FontAwesomeIcons.star, color: Colors.amber),
            SizedBox(width: 12),
            Text('Rate Meet9ja'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enjoying Meet9ja? We\'d love your feedback!',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rate us on the App Store/Play Store to help improve our app and reach more people.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            if (platform != TargetPlatform.iOS &&
                platform != TargetPlatform.android)
              const Text(
                'You\'ll be redirected to our website.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _openStoreRating(context, appStoreUrl);
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _openStoreRating(BuildContext context, String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot open store: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ LOGOUT ============
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(FontAwesomeIcons.rightFromBracket, color: Colors.red),
            SizedBox(width: 12),
            Text('Log Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _performLogout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _performLogout(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Logging out...'),
          ],
        ),
      ),
    );

    try {
      await SettingsScreen._auth.signOut();

      Navigator.pop(context); // Close loading
      Navigator.pop(context); // Close confirmation

      // Navigate to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Signinscreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to logout: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ HELPER METHODS ============
  Future<void> _openWebsite(BuildContext context, String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot open website: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ============ UI COMPONENTS ============

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showArrow;
  final Color? iconColor;
  final bool isVersion;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showArrow = true,
    this.iconColor,
    this.isVersion = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    iconColor?.withOpacity(0.1) ??
                    AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (showArrow)
              Icon(
                FontAwesomeIcons.chevronRight,
                size: 14,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }
}

class _GuidelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _GuidelineItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      )
    );
  }
}

class _AboutFeature extends StatelessWidget {
  final String icon;
  final String text;

  const _AboutFeature(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      )
    );
  }
}

class _ContactInfo extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _ContactInfo(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      )
    );
  }
}

class _ContactMethod extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactMethod({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                FontAwesomeIcons.copy,
                size: 12,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CookieItem extends StatelessWidget {
  final String title;
  final String description;

  const _CookieItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cookie, size: 16, color: Colors.brown),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      )
    );
  }
}

class _CookieUsageItem extends StatelessWidget {
  final String title;
  final String description;

  const _CookieUsageItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      )
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionItem(this.transaction);

  @override
  Widget build(BuildContext context) {
    final amount = transaction['amount'] ?? 0.0;
    final type = transaction['type'] ?? 'unknown';
    final status = transaction['status'] ?? 'pending';
    final timestamp = transaction['timestamp'] != null 
      ? (transaction['timestamp'] as Timestamp).toDate() 
      : DateTime.now();
    
    Color statusColor = Colors.grey;
    String statusText = status;
    
    if (status == 'completed') {
      statusColor = Colors.green;
      statusText = 'Completed';
    } else if (status == 'failed') {
      statusColor = Colors.red;
      statusText = 'Failed';
    } else if (status == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₦${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Type: ${type.toString().toUpperCase()}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            'Date: ${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// Report Stat Widget
class _ReportStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _ReportStat({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Combined Report Item Widget
class _CombinedReportItem extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onViewDetails;

  const _CombinedReportItem({
    required this.report,
    required this.onViewDetails,
  });

  // Add these static helper methods in the _SettingsScreenState class
  static Color _getStatusColor(String? status) {
    if (status == null) return Colors.orange;

    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static String _getStatusText(String? status) {
    if (status == null) return 'Pending';

    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending Review';
      case 'reviewed':
        return 'Under Review';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  static String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (timestamp is String) {
        return timestamp;
      } else if (timestamp is DateTime) {
        return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      print('❌ Error formatting timestamp: $e');
    }
    return 'Date not available';
  }

  String _getDescriptionPreview(String description) {
    if (description.isEmpty) return 'No description';

    // Use the shorter of: description length or 50
    final maxLength = description.length < 50 ? description.length : 50;
    return description.substring(0, maxLength);
  }

  @override
  Widget build(BuildContext context) {
    final type = report['type'];
    final data = report['data'] as Map<String, dynamic>;
    final status = data['status'] ?? 'pending';

    // Determine colors and icons based on report type
    Color typeColor = type == 'profile_report' ? Colors.red : Colors.blue;
    IconData typeIcon = type == 'profile_report'
        ? FontAwesomeIcons.user
        : FontAwesomeIcons.flag;

    // Determine status color
    Color statusColor = _getStatusColor(status);

    // Get report title
    String title = type == 'profile_report'
        ? data['reportedUserName'] ?? 'Profile Report'
        : data['category'] ?? 'Problem Report';

    // Get description preview
// Get description preview
    String description = type == 'profile_report'
        ? data['reason'] ?? 'Profile report'
        : _getDescriptionPreview(data['description']?.toString() ?? 'No description');

// Add this helper method to get a safe substring

    // Format timestamp
    final timestamp = data['createdAt'];
    String timeText = 'Recently';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        timeText = 'Just now';
      } else if (difference.inHours < 1) {
        timeText = '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        timeText = '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        timeText = '${difference.inDays}d ago';
      } else {
        timeText = '${date.day}/${date.month}/${date.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onViewDetails,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Report Type Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, size: 18, color: typeColor),
                ),

                const SizedBox(width: 12),

                // Report Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.clock,
                            size: 10,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeText,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),

                          const Spacer(),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              type == 'profile_report'
                                  ? 'Profile'
                                  : 'Problem',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // View Details Arrow
                const Icon(
                  FontAwesomeIcons.chevronRight,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Detail Item for Report Details
class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool copyable;
  final VoidCallback? onCopy;

  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.copyable = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          color: valueColor ?? Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (copyable)
                      IconButton(
                        icon: const Icon(
                          FontAwesomeIcons.copy,
                          size: 14,
                          color: Colors.blue,
                        ),
                        onPressed: onCopy,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
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

class _ReportHistoryItem extends StatelessWidget {
  final Map<String, dynamic> report;

  const _ReportHistoryItem(this.report);

  @override
  Widget build(BuildContext context) {
    final category = report['category'] ?? 'Unknown';
    final status = report['status'] ?? 'pending';
    final description = report['description'] ?? 'No description';
    final createdAt = report['createdAt'] != null 
      ? (report['createdAt'] as Timestamp).toDate() 
      : DateTime.now();
    
    Color statusColor = Colors.grey;
    String statusText = status;
    
    if (status == 'resolved') {
      statusColor = Colors.green;
      statusText = 'Resolved';
    } else if (status == 'reviewed') {
      statusColor = Colors.blue;
      statusText = 'Reviewed';
    } else if (status == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Submitted: ${createdAt.day}/${createdAt.month}/${createdAt.year}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}