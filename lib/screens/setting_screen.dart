import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:meet9ja/screens/edit_profile_screen.dart';
import 'package:meet9ja/screens/home_screen.dart';
import 'package:meet9ja/screens/signin_screen.dart';
import 'package:path/path.dart';
import '../constants/app_colors.dart';
import '../constants/privacy_policy_popup.dart';
import '../constants/terms_condition_popup.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
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
                    icon: FontAwesomeIcons.creditCard,
                    title: 'Payment Methods',
                    subtitle: 'Manage your payment cards',
                    onTap: () => _showComingSoon(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.receipt,
                    title: 'Transaction History',
                    subtitle: 'View your payment history',
                    onTap: () => _showComingSoon(context),
                    showArrow: true,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: FontAwesomeIcons.shield,
                    title: 'Security & PIN',
                    subtitle: 'Set up transaction security',
                    onTap: () => _showComingSoon(context),
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
                    icon: FontAwesomeIcons.headset,
                    title: 'Help Center',
                    subtitle: 'Get help and support',
                    onTap: () => _showComingSoon(context),
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
                    onTap: () => _showComingSoon(context),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
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
                      style: TextStyle(
                        color: Colors.black38,
                        fontSize: 12,
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

  // Navigation and Dialog Methods
  void _navigateToEditProfile(BuildContext context) {
    // For now, navigate back to home
    // In a real app, you would navigate to the actual EditProfileScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

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

  void _processAccountDeletion(BuildContext context) {
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

    // Simulate account deletion process
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close confirmation dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Signinscreen()),
            (route) => false,
      );
    });
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showCommunityGuidelines(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(FontAwesomeIcons.shieldHalved, color: Colors.blue),
            SizedBox(width: 12),
            Text('Community Guidelines'),
          ],
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
                description: 'Treat all users with kindness and respect. Harassment, hate speech, and bullying will not be tolerated.',
              ),

              _GuidelineItem(
                icon: FontAwesomeIcons.camera,
                title: 'Authentic Profiles',
                description: 'Use recent, clear photos of yourself. No impersonation or fake profiles allowed.',
              ),

              _GuidelineItem(
                icon: FontAwesomeIcons.ban,
                title: 'No Inappropriate Content',
                description: 'Do not share explicit, violent, or offensive content. Keep conversations appropriate.',
              ),

              _GuidelineItem(
                icon: FontAwesomeIcons.shield,
                title: 'Protect Your Privacy',
                description: 'Never share personal information like passwords, financial details, or home addresses.',
              ),

              _GuidelineItem(
                icon: FontAwesomeIcons.flag,
                title: 'Report Violations',
                description: 'Report any suspicious or inappropriate behavior immediately using the in-app reporting tools.',
              ),

              _GuidelineItem(
                icon: FontAwesomeIcons.moneyBillWave,
                title: 'No Financial Scams',
                description: 'Do not ask for money or financial information from other users.',
              ),

              const SizedBox(height: 16),
              const Text(
                'Violations may result in account suspension or permanent ban.',
                style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Bug Report', child: Text('Bug Report')),
                      DropdownMenuItem(value: 'Feature Request', child: Text('Feature Request')),
                      DropdownMenuItem(value: 'Account Issue', child: Text('Account Issue')),
                      DropdownMenuItem(value: 'Payment Problem', child: Text('Payment Problem')),
                      DropdownMenuItem(value: 'Safety Concern', child: Text('Safety Concern')),
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
                      // TODO: Implement screenshot attachment
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Screenshot attachment coming soon')),
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

  void _submitProblemReport(BuildContext context, String category, String description) {
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

    // Simulate API call
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close report dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully! We\'ll review it soon.'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PrivacyPolicyPopup(),
    );
  }

  void _showTermsConditions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TermsConditionsPopup(),
    );
  }

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
              _AboutFeature('🎯 Smart Matching', 'AI-powered matching based on preferences'),
              _AboutFeature('🔒 Safety First', 'Advanced safety features and verification'),
              _AboutFeature('📹 Live Streaming', 'Real-time video connections'),
              _AboutFeature('🌍 Global Reach', 'Connect with Nigerians worldwide'),
              _AboutFeature('💼 Multiple Modes', 'Date, Travel, BFF, and Business modes'),

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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'General Inquiry', child: Text('General Inquiry')),
                      DropdownMenuItem(value: 'Technical Support', child: Text('Technical Support')),
                      DropdownMenuItem(value: 'Account Help', child: Text('Account Help')),
                      DropdownMenuItem(value: 'Business Inquiry', child: Text('Business Inquiry')),
                      DropdownMenuItem(value: 'Partnership', child: Text('Partnership')),
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
                    onTap: () => _copyToClipboard(context, 'support@meet9ja.com'),
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

  void _submitContactForm(BuildContext context, String topic, String message) {
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

    // Simulate sending
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading
      Navigator.pop(context); // Close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent successfully! We\'ll respond within 24 hours.'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _copyToClipboard(BuildContext context, String text) async {
    // In a real app, use: await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied: $text')),
    );
  }

  void _rateApp(BuildContext context) {
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enjoying Meet9ja? We\'d love your feedback!',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'Rate us on the App Store/Play Store to help improve our app and reach more people.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openStoreRating(context);
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  void _openStoreRating(BuildContext context) {
    // In a real app, you would open the app store page
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redirecting to app store...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

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

  void _performLogout(BuildContext context) {
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

    // Simulate logout process
    Future.delayed(const Duration(seconds: 2), () {
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
    });
  }
}

// UI Components
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

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
          child: Column(
            children: children,
          ),
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
                color: iconColor?.withOpacity(0.1) ?? AppColors.primary.withOpacity(0.1),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
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
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
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
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
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