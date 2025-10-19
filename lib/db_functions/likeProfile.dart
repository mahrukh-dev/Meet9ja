
// Like a profile - updated for your DB structure
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'createMatchRecord.dart';
import 'createMutualMatch.dart';

Future<void> likeProfile(String targetUserId) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw 'User not logged in';

    final batch = FirebaseFirestore.instance.batch();

    // Update current user's liked profiles
    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    batch.update(currentUserRef, {
      'liked_profiles': FieldValue.arrayUnion([targetUserId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Create match record
    await createMatchRecord(currentUser.uid, targetUserId, 'like');

    // Check for mutual like (match)
    final targetUserDoc = await FirebaseFirestore.instance.collection('users').doc(targetUserId).get();
    final targetUserLikes = List.from(targetUserDoc.data()?['liked_profiles'] ?? []);

    if (targetUserLikes.contains(currentUser.uid)) {
      // It's a mutual match!
      await createMutualMatch(currentUser.uid, targetUserId);
    }

    await batch.commit();

    print('✅ Liked profile: $targetUserId');
  } catch (e) {
    print('❌ Error liking profile: $e');
    throw 'Failed to like profile: $e';
  }
}


