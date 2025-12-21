// subscription_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../db_functions/user_service.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  UserModel? _currentUser;
  Map<String, dynamic>? _subscriptionData;
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
        final subscriptionData = await _getSubscriptionData(currentUserId);

        setState(() {
          _currentUser = user;
          _subscriptionData = subscriptionData;
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading subscription data: $e');
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

  Future<Map<String, dynamic>?> _getSubscriptionData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return {
          'premium_since': userData['premium_since'],
          'last_payment': userData['last_payment'],
          'subscription_status': userData['subscription_status'] ?? 'active',
          'type': userData['type'] ?? 'premium',
        };
      }
      return null;
    } catch (e) {
      print('Error getting subscription data: $e');
      return null;
    }
  }

  String _calculateTimeRemaining(Timestamp? premiumSince) {
    if (premiumSince == null) return 'Unknown';

    final startDate = premiumSince.toDate();
    final endDate = DateTime(startDate.year, startDate.month + 1, startDate.day);
    final now = DateTime.now();

    if (now.isAfter(endDate)) {
      return 'Expired';
    }

    final difference = endDate.difference(now);
    final days = difference.inDays;
    final hours = difference.inHours % 24;

    if (days > 0) {
      return '$days days, $hours hours';
    } else {
      return '$hours hours';
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
  }

  String _getNextBillingDate(Timestamp? lastPayment) {
    if (lastPayment == null) return 'Unknown';

    final lastPaymentDate = lastPayment.toDate();
    final nextBillingDate = DateTime(lastPaymentDate.year, lastPaymentDate.month + 1, lastPaymentDate.day);
    return DateFormat('MMM dd, yyyy').format(nextBillingDate);
  }

  Future<void> _contactSupport() async {
    const adminEmail = 'support@meet9ja.com';
    const subject = 'Meet9ja Premium Subscription Support';

    // Get user info for email body
    final userName = _currentUser?.name ?? 'User';
    final userEmail = _currentUser?.email ?? FirebaseAuth.instance.currentUser?.email ?? '';
    final subscriptionType = _subscriptionData?['type'] ?? 'premium';
    final subscriptionStatus = _subscriptionData?['subscription_status'] ?? 'active';

    final body = '''
Hello Meet9ja Support Team,

I need assistance with my Premium subscription.

User Information:
- Name: $userName
- Email: $userEmail
- Subscription Type: $subscriptionType
- Status: $subscriptionStatus

Issue/Question:
[Please describe your issue or question here]

Additional Details:
- Subscription Started: ${_formatDate(_subscriptionData?['premium_since'])}
- Next Billing Date: ${_getNextBillingDate(_subscriptionData?['last_payment'])}

Thank you,
$userName
''';

    // Properly encode the subject and body
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);

    // Create the mailto URI with encoded parameters
    final emailUrl = 'mailto:$adminEmail?subject=$encodedSubject&body=$encodedBody';

    try {
      if (await canLaunch(emailUrl)) {
        await launch(emailUrl);
      } else {
        // If mail app is not available, show alternative options
        _showEmailNotAvailableDialog(adminEmail, subject, body);
      }
    } catch (e) {
      print('Error launching email: $e');
      _showEmailErrorDialog();
    }
  }

  void _showEmailNotAvailableDialog(String email, String subject, String body) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email App Not Found'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No email app found on your device.'),
              const SizedBox(height: 16),
              const Text('You can contact us at:'),
              const SizedBox(height: 8),
              SelectableText(
                email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Copy email address:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _copyToClipboard(email);
              },
              child: const Text('Copy Email'),
            ),
          ],
        );
      },
    );
  }

  void _showEmailErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unable to Send Email'),
          content: const Text(
            'There was an error trying to open the email app. '
                'Please try again or contact us directly at support@meet9ja.com',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _copyToClipboard(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
    // In a real app, you would use Clipboard.setData()
    // For this example, I'm showing the snackbar
  }

  Widget _buildInfoCard(IconData icon, String title, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Subscription?'),
          content: const Text(
            'Are you sure you want to cancel your Premium subscription? '
                'You will lose access to all premium features at the end of your billing period.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Subscription'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCancellationNotAvailable();
              },
              child: const Text(
                'Cancel Subscription',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCancellationNotAvailable() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Cancellation Notice'),
            ],
          ),
          content: const Text(
            'To cancel your subscription, please contact our support team at support@meet9ja.com. '
                'We\'re here to help and would love to know if there\'s anything we can do to improve your experience.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Optionally, you could directly open email here
                // _contactSupport();
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _contactSupport();
              },
              child: const Text(
                'Contact Support',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Premium Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Status Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, Colors.purple],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 50,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Premium Member',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _subscriptionData?['subscription_status'] == 'active'
                        ? 'Active Subscription'
                        : 'Subscription Status: ${_subscriptionData?['subscription_status'] ?? 'Unknown'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Subscription Information
            const Text(
              'Subscription Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),

            _buildInfoCard(
              Icons.calendar_today,
              'Time Remaining',
              _calculateTimeRemaining(_subscriptionData?['premium_since']),
              Colors.green,
            ),
            const SizedBox(height: 12),

            _buildInfoCard(
              Icons.date_range,
              'Subscription Started',
              _formatDate(_subscriptionData?['premium_since']),
              Colors.blue,
            ),
            const SizedBox(height: 12),

            _buildInfoCard(
              Icons.payment,
              'Next Billing Date',
              _getNextBillingDate(_subscriptionData?['last_payment']),
              Colors.orange,
            ),

            const SizedBox(height: 24),

            // Premium Benefits
            const Text(
              'Your Premium Benefits',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  _buildBenefitItem('Ad-free experience across all features'),
                  _buildBenefitItem('HD quality streaming'),
                  _buildBenefitItem('Exclusive premium badge'),
                  _buildBenefitItem('Priority access in discovery feeds'),
                  _buildBenefitItem('Live streaming capabilities'),
                  _buildBenefitItem('Advanced filters and preferences'),
                  _buildBenefitItem('Incognito mode'),
                  _buildBenefitItem('Travel mode'),
                  _buildBenefitItem('Unlimited likes and matches'),
                  _buildBenefitItem('See who liked you'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Management Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _contactSupport,
                      icon: const Icon(Icons.support_agent),
                      label: const Text(
                        'Contact Support',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showCancelSubscriptionDialog,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text(
                        'Cancel Subscription',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Support Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Need Help?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For any questions about your subscription, billing, or premium features, our support team is here to help.',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.email, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Email: ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SelectableText(
                        'support@meet9ja.com',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Response Time: ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Text('24-48 hours'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}