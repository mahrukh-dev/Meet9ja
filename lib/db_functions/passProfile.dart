// Pass on a profile - updated for your DB structure
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'createMatchRecord.dart';
// Update your existing passProfile function
Future<void> passProfile(String targetUserId) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw 'User not logged in';

    // Create match record with pass status (already exists)
    await createMatchRecord(currentUser.uid, targetUserId, 'pass');

    print('✅ Passed on profile: $targetUserId');
  } catch (e) {
    print('❌ Error passing profile: $e');
    throw 'Failed to pass profile: $e';
  }
}