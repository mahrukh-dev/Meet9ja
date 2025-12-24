
// Like a profile - updated for your DB structure
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'createMatchRecord.dart';
import 'createMutualMatch.dart';
import 'notification_service.dart';

// Update your existing likeProfile function or create this new one
Future<void> likeProfile(String targetUserId) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw 'User not logged in';

    // Add to liked_profiles array
    await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
      'liked_profiles': FieldValue.arrayUnion([targetUserId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Create match record
    await createMatchRecord(currentUser.uid, targetUserId, 'like');

    print('✅ Liked profile: $targetUserId');
  } catch (e) {
    print('❌ Error liking profile: $e');
    throw 'Failed to like profile: $e';
  }
}