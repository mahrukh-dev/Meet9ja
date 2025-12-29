import 'package:flutter/material.dart';

import 'app_colors.dart';

class PrivacyPolicyPopup extends StatelessWidget {
  const PrivacyPolicyPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            'Privacy Policy',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildSectionTitle('Information We Collect'),
              _buildBulletPoint('• Personal Information: Name, email, age, gender, and profile information'),
              _buildBulletPoint('• Photos: Profile pictures you upload'),
              _buildBulletPoint('• Usage Data: How you interact with our platform'),
              _buildBulletPoint('• Location: Approximate location for matching (with your consent)'),
              _buildBulletPoint('• Messages: Content of conversations on our platform'),

              const SizedBox(height: 20),
              _buildSectionTitle('How We Use Your Information'),
              _buildBulletPoint('• To create and maintain your account'),
              _buildBulletPoint('• To provide personalized matches and recommendations'),
              _buildBulletPoint('• To ensure platform safety and security'),
              _buildBulletPoint('• To improve our services and develop new features'),
              _buildBulletPoint('• To communicate with you about updates and features'),

              const SizedBox(height: 20),
              _buildSectionTitle('Data Sharing'),
              _buildBulletPoint('• We do not sell your personal information to third parties'),
              _buildBulletPoint('• We share information only with your consent or when required by law'),
              _buildBulletPoint('• Service providers who help us operate the platform'),
              _buildBulletPoint('• Other users as per your privacy settings'),

              const SizedBox(height: 20),
              _buildSectionTitle('Your Rights'),
              _buildBulletPoint('• Access and download your data'),
              _buildBulletPoint('• Correct inaccurate information'),
              _buildBulletPoint('• Delete your account and data'),
              _buildBulletPoint('• Opt-out of marketing communications'),
              _buildBulletPoint('• Control your privacy settings'),

              const SizedBox(height: 20),
              _buildSectionTitle('Data Security'),
              _buildBulletPoint('• End-to-end encryption for messages'),
              _buildBulletPoint('• Secure storage with industry-standard protection'),
              _buildBulletPoint('• Regular security audits and updates'),
              _buildBulletPoint('• Access controls and authentication measures'),

              const SizedBox(height: 20),
              const Text(
                'By using Meet9ja, you acknowledge that you have read and understood this Privacy Policy.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
      scrollable: true,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}