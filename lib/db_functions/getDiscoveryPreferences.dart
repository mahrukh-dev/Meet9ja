
// Get user's discovery preferences
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<Map<String, dynamic>> getDiscoveryPreferences() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {};

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) return {};

    final userData = userDoc.data()!;
    return {
      'preferences': userData['preferences'] ?? 'anyone',
      'mode': userData['mode'] ?? {
        'date': false,
        'travel_partner': true,
        'BFF': false,
        'bizz': false,
      },
      'location': userData['location'] ?? '',
    };
  } catch (e) {
    print('❌ Error getting discovery preferences: $e');
    return {};
  }
}