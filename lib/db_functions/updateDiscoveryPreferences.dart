
// Update user's discovery preferences
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> updateDiscoveryPreferences({
  String? preferences,
  Map<String, bool>? mode,
  String? location,
}) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw 'User not logged in';

    final updates = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (preferences != null) updates['preferences'] = preferences;
    if (mode != null) updates['mode'] = mode;
    if (location != null) updates['location'] = location;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .update(updates);

    print('✅ Discovery preferences updated');
  } catch (e) {
    print('❌ Error updating discovery preferences: $e');
    throw 'Failed to update preferences: $e';
  }
}

