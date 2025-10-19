
// Save user profile to Firestore
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> saveUserProfile({
  required String uid,
  required String email,
  required String name,
  required String username,
  required int age,
  required String selectedMode,
  required String travelPreference,
  required String bio,
}) async {
  try {
    print('💾 Saving user profile to Firestore for UID: $uid, username: $username');

    final userData = {
      'UID': uid,
      'email': email,
      'name': name,
      'age': age,
      'username': username.toLowerCase(),
      'username_lowercase': username.toLowerCase(),
      'bio': bio,
      'mode': {
        'date': selectedMode == 'Date',
        'travel_partner': selectedMode == 'Travel partner',
        'BFF': selectedMode == 'BFF',
        'bizz': selectedMode == 'Bizz',
      },
      'preferences': travelPreference,
      'type': 'nonpremium',
      'live_preferences': {'visibility': 'public'},
      'following': [],
      'followers': [],
      'live_status': false,
      'wallet': {'coin_balance': 0, 'total_earning': 0},
      'interests': [],
      'first_photos': {'photo1url': '', 'photo2url': '', 'photo3url': '', 'photo4url': ''},
      'location': '',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'status': 'active',
    };

    await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);
    print('✅ User profile saved successfully with username: $username');
  } catch (e) {
    print('❌ Error saving user profile: $e');
    throw 'Failed to save user profile: $e';
  }
}
