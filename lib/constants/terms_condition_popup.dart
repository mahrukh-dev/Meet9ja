import 'package:flutter/material.dart';

import 'app_colors.dart';

class TermsConditionsPopup extends StatelessWidget {
  const TermsConditionsPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.gavel_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            'Terms & Conditions',
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
              const Text(
                'Last Updated: January 1, 2025',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              _buildSectionTitle('1. Agreement to Terms'),
              const Text(
                'By accessing or using the Meet9ja mobile application and services, you agree to be bound by these Terms of Service. If you disagree with any part of these terms, you may not access the service. These terms apply to all visitors, users, and others who access or use the service.',
              ),

              const SizedBox(height: 20),
              _buildSectionTitle('2. Eligibility'),
              _buildBulletPoint('• Be at least 18 years of age'),
              _buildBulletPoint('• Have legal capacity to enter into a binding agreement'),
              _buildBulletPoint('• Not be prohibited from using the service under applicable laws'),
              _buildBulletPoint('• Not have been previously banned or removed from Meet9ja'),
              _buildBulletPoint('• Comply with all local, state, and federal laws'),

              const SizedBox(height: 20),
              _buildSectionTitle('3. User Conduct'),
              const Text('You agree NOT to:'),
              _buildBulletPoint('• Use the service for any illegal or unauthorized purpose'),
              _buildBulletPoint('• Harass, abuse, threaten, or intimidate other users'),
              _buildBulletPoint('• Post false, misleading, or fraudulent content'),
              _buildBulletPoint('• Impersonate any person or entity'),
              _buildBulletPoint('• Share sexually explicit, violent, or hateful content'),
              _buildBulletPoint('• Solicit money or personal information from other users'),
              _buildBulletPoint('• Use the service for commercial purposes without authorization'),
              _buildBulletPoint('• Attempt to access another user\'s account without permission'),
              _buildBulletPoint('• Upload viruses or malicious code'),
              _buildBulletPoint('• Interfere with the proper functioning of the service'),

              const SizedBox(height: 20),
              _buildSectionTitle('4. Account Responsibility'),
              const Text('When you create an account, you must:'),
              _buildBulletPoint('• Provide accurate, complete, and current information'),
              _buildBulletPoint('• Maintain and promptly update your account information'),
              _buildBulletPoint('• Maintain the security of your account credentials'),
              _buildBulletPoint('• Accept responsibility for all activities under your account'),
              _buildBulletPoint('• Immediately notify us of any unauthorized use or security breach'),

              const SizedBox(height: 20),
              _buildSectionTitle('5. Content Rights'),
              const Text('Your Content: You retain ownership of content you post on Meet9ja. However, by posting content, you grant us a worldwide, non-exclusive, royalty-free license to use, display, and distribute your content in connection with operating and improving the service.'),

              const SizedBox(height: 20),
              _buildSectionTitle('6. Premium Subscriptions'),
              _buildBulletPoint('• Subscriptions automatically renew unless canceled'),
              _buildBulletPoint('• Fees are charged to your payment method on renewal date'),
              _buildBulletPoint('• You can cancel anytime through account settings'),
              _buildBulletPoint('• Refunds are not provided for partial subscription periods'),
              _buildBulletPoint('• We reserve the right to change pricing with advance notice'),

              const SizedBox(height: 20),
              _buildSectionTitle('7. Termination'),
              const Text('We may terminate or suspend your account immediately, without prior notice, for:'),
              _buildBulletPoint('• Breach of these Terms of Service'),
              _buildBulletPoint('• Fraudulent or illegal activity'),
              _buildBulletPoint('• Harassment or abuse of other users'),

              const SizedBox(height: 20),
              _buildSectionTitle('8. Disclaimer'),
              const Text(
                'THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND. MEET9JA DOES NOT WARRANT THAT THE SERVICE WILL BE UNINTERRUPTED OR ERROR-FREE.',
              ),

              const SizedBox(height: 20),
              _buildSectionTitle('9. Governing Law'),
              const Text(
                'These Terms shall be governed by and construed in accordance with the laws of Nigeria. Any disputes shall be resolved in the courts of Lagos, Nigeria.',
              ),

              const SizedBox(height: 20),
              const Text(
                'By continuing to use Meet9ja, you agree to these Terms & Conditions.',
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
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}