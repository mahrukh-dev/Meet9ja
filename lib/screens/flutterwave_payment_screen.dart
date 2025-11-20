import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlutterwavePaymentScreen extends StatefulWidget {
  const FlutterwavePaymentScreen({super.key});

  @override
  State<FlutterwavePaymentScreen> createState() => _FlutterwavePaymentScreenState();
}

class _FlutterwavePaymentScreenState extends State<FlutterwavePaymentScreen> {
  final emailController = TextEditingController();
  final phoneNumberController = TextEditingController();
  bool isLoading = false;
  bool isPremium = false;
  bool isTestMode = true;

  // Corrected Flutterwave sandbox credentials from the image
  final String publicKey = "FLWPUBK_TEST-befed163ca7c7e9909b525da24b1332d-X";
  final String secretKey = "FLWSECK_TEST-40e21085dd94e60bb65a13d7987295af-X";
  final String encryptionKey = "FLWSECK_TEST31158107b2db";

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isPremium = prefs.getBool('isPremium') ?? false;
    });
  }

  Future<void> _updatePremiumStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', status);
    setState(() {
      isPremium = status;
    });
  }

  void makeSubscriptionPayment() async {
    // Validate email
    if (emailController.text.isEmpty || !emailController.text.contains('@')) {
      _showErrorDialog('Please enter a valid email address');
      return;
    }

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
        // context: context,
        publicKey: publicKey,
        currency: "USD",
        amount: "1.00",
        customer: customer,
        txRef: Uuid().v4(),
        paymentOptions: "card, ussd, banktransfer",
        customization: Customization(
          title: "Premium Subscription",
          description: "Upgrade to premium account",
        ),
        redirectUrl: "https://www.google.com",
        isTestMode: isTestMode,
      );

      print('Initiating payment...');
      print('Public Key: $publicKey');
      print('Test Mode: $isTestMode');

      final ChargeResponse response = await flutterwave.charge(context);

      print('Payment response: ${response.toJson()}');

      if (mounted) {
        if (response.success == true) {
          // Payment successful
          await _updatePremiumStatus(true);
          _showSuccessDialog(response.txRef!);
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

  void _showSuccessDialog(String transactionRef) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Subscription Successful!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome to Premium! Your account has been upgraded.'),
              const SizedBox(height: 10),
              Text('Transaction Reference: $transactionRef'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
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
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Payment Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Test card information widget
  Widget _buildTestCardInfo() {
    if (!isTestMode) return const SizedBox();

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Test Card Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Use these test details for payment:'),
            const SizedBox(height: 8),
            const Text('Card: 5531 8866 5214 2950'),
            const Text('CVV: 564'),
            const Text('Expiry: 09/32'),
            const Text('PIN: 3310'),
            const Text('OTP: 12345'),
            const SizedBox(height: 8),
            const Text(
              'Note: Make sure Test Mode is ON and you\'re using the correct test keys.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Subscription'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: isPremium ? Colors.green[50] : Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isPremium ? Icons.verified : Icons.person_outline,
                      color: isPremium ? Colors.green : Colors.blue,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPremium ? 'Premium Account' : 'Free Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isPremium ? Colors.green : Colors.blue,
                            ),
                          ),
                          Text(
                            isPremium
                                ? 'You have access to all premium features'
                                : 'Upgrade to unlock premium features',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Test card info
            _buildTestCardInfo(),

            const SizedBox(height: 20),

            if (!isPremium) ...[
              // Subscription Details
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Premium Subscription',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '\$1.00 - One Time Payment',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('✓ All premium features included'),
                      const Text('✓ No recurring charges'),
                      const Text('✓ Lifetime access'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // User Input
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  hintText: 'Enter your email address',
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: 'Enter your phone number',
                ),
              ),

              const SizedBox(height: 20),

              // Test Mode Toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.safety_check, color: Colors.blue),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Mode',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Use test payment credentials',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isTestMode,
                        onChanged: (value) {
                          setState(() {
                            isTestMode = value;
                          });
                        },
                      ),
                      Text(
                        isTestMode ? 'ON' : 'OFF',
                        style: TextStyle(
                          color: isTestMode ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Subscribe Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : makeSubscriptionPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upgrade),
                      SizedBox(width: 8),
                      Text(
                        'Upgrade to Premium - \$1.00',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (isPremium) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.verified, color: Colors.green, size: 60),
                      const SizedBox(height: 16),
                      const Text(
                        'Premium Member',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'You have full access to all premium features. Thank you for your subscription!',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to premium features
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Explore Premium Features'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
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