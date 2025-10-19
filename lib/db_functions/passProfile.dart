// Pass on a profile - updated for your DB structure
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'createMatchRecord.dart';

Future<void> passProfile(String targetUserId) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw 'User not logged in';

    await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
      'passed_profiles': FieldValue.arrayUnion([targetUserId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Create match record with pass status
    await createMatchRecord(currentUser.uid, targetUserId, 'pass');

    print('✅ Passed on profile: $targetUserId');
  } catch (e) {
    print('❌ Error passing profile: $e');
    throw 'Failed to pass profile: $e';
  }
}

