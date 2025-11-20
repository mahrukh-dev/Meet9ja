// subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:flutterwave_standard/core/flutterwave.dart';
import 'package:flutterwave_standard/models/requests/customer.dart';
import 'package:flutterwave_standard/models/requests/customizations.dart';
import 'package:flutterwave_standard/models/responses/charge_response.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_colors.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  bool isLoading = false;
  bool isTestMode = true;

  // Corrected Flutterwave sandbox credentials from the image
  final String publicKey = "FLWPUBK_TEST-befed163ca7c7e9909b525da24b1332d-X";
  final String secretKey = "FLWSECK_TEST-40e21085dd94e60bb65a13d7987295af-X";
  final String encryptionKey = "FLWSECK_TEST31158107b2db";

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  void _loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          emailController.text = userData['email'] ?? '';
          phoneNumberController.text = userData['phoneNumber'] ?? '00';
        });
      }
    }
  }

  Future<void> _updateUserToPremium() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'type': 'premium',
        'last_payment': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'subscription_status': 'active',
        'premium_since': FieldValue.serverTimestamp(),
      });

      print('✅ User upgraded to premium successfully');
    } catch (e) {
      print('❌ Error updating user to premium: $e');
      throw 'Failed to update user account: $e';
    }
  }

  void makeSubscriptionPayment() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final Customer customer = Customer(
          email: emailController.text.trim(),
          phoneNumber: phoneNumberController.text.trim().isEmpty
              ? "2348100000000" // Default test number
              : phoneNumberController.text.trim(),
          name: "Premium User"
      );

      final Flutterwave flutterwave = Flutterwave(

        publicKey: publicKey,
        currency: "USD",
        amount: "4.99",
        customer: customer,
        txRef: Uuid().v4(),
        paymentOptions: "card, ussd, banktransfer",
        customization: Customization(
          title: "Premium Subscription",
          description: "Upgrade to premium account",
        ),
        redirectUrl: "https://www.google.com",
        isTestMode: true,
      );

      print('Initiating payment...');
      print('Public Key: $publicKey');
      print('Test Mode: $isTestMode');

      final ChargeResponse response = await flutterwave.charge(context);

      print('Payment response: ${response.toJson()}');

      if (mounted) {
        if (response.status == 'successful') {
          // Payment successful - update user to premium
          await _updateUserToPremium();

          // Show success message and close
          _showSuccessDialog();
        } else {
          // Payment failed - provide more detailed error message
          String errorMessage = 'Payment failed. ';

          if (response.status != null) {
            errorMessage += 'Status: ${response.status}. ';
          }



          _showErrorDialog(errorMessage.isEmpty ? 'Payment failed. Please try again.' : errorMessage);
        }
      }
    } catch (e, stackTrace) {
      print('Payment error: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        _showErrorDialog('Payment error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text('Success!'),
            ],
          ),
          content: const Text(
            'Your payment was successful! Your account has been upgraded to Premium.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close subscription page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Premium Activated! Welcome to Premium!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('Continue', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Payment Failed'),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
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

              // Payment Information Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your phone number',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment Button
              ElevatedButton(
                onPressed: isLoading ? null : makeSubscriptionPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 8,
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
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

              // Test Mode Indicator
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Test Mode - Use test card: 5531 8866 5214 2950',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
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

  @override
  void dispose() {
    emailController.dispose();
    phoneNumberController.dispose();
    super.dispose();
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