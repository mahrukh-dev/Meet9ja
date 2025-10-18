// subscription_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'constants/app_colors.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(FontAwesomeIcons.arrowLeft),
        title: const Text(
          'Go Premium ✨',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                FontAwesomeIcons.crown,
                color: AppColors.primary,
                size: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unlock Exclusive Features',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Upgrade to Premium to gain access to live streaming, ad-free viewing, and custom badges.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              _FeatureTile(
                icon: FontAwesomeIcons.video,
                title: 'Start Live Streams',
                subtitle: 'Go live and connect with your audience instantly.',
              ),
              _FeatureTile(
                icon: FontAwesomeIcons.solidCircle,
                title: 'Ad-Free Experience',
                subtitle: 'Enjoy uninterrupted viewing across all feeds and rooms.',
              ),
              _FeatureTile(
                icon: FontAwesomeIcons.solidGem,
                title: 'Premium Badge',
                subtitle: 'Show off your status with an exclusive profile badge.',
              ),
              _FeatureTile(
                icon: FontAwesomeIcons.film,
                title: 'HD Quality',
                subtitle: 'Stream and watch in high definition quality.',
              ),
              _FeatureTile(
                icon: FontAwesomeIcons.bolt,
                title: 'Priority Access',
                subtitle: 'Get priority placement in discovery feeds.',
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement actual subscription purchase logic here (e.g., In-App Purchase)
                  Navigator.pop(context); // Simulate a successful purchase, then close
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('🎉 Premium Activated!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 8,
                ),
                child: const Text(
                  'Upgrade to Premium - \$4.99/mo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Maybe Later',
                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.3,
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