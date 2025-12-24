// lib/db_functions/getDiscoveryProfiles.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<List<Map<String, dynamic>>> getDiscoveryProfiles() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No user logged in');
      return [];
    }

    print('🔍 Fetching discovery profiles for user: ${currentUser.uid}');

    // Get current user data to check already interacted profiles
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!currentUserDoc.exists) {
      print('❌ Current user document not found');
      return [];
    }

    final currentUserData = currentUserDoc.data()!;

    // Get liked profiles (from your Firestore structure)
    final likedProfiles = List<String>.from(currentUserData['liked_profiles'] ?? []);

    // Get passed profiles - we need to check for profiles in match records
    final matchesQuery = await FirebaseFirestore.instance
        .collection('matches')
        .where('users', arrayContains: currentUser.uid)
        .get();

    final passedProfileIds = matchesQuery.docs
        .where((doc) => doc.data()['status'] == 'pass')
        .map((doc) {
      final data = doc.data();
      final users = List<String>.from(data['users'] ?? []);
      // Get the other user ID (not current user)
      return users.firstWhere((id) => id != currentUser.uid);
    })
        .where((id) => id != null && id.isNotEmpty)
        .toList();

    // Combine all excluded profiles
    final excludedProfiles = [...likedProfiles, ...passedProfileIds, currentUser.uid];
    print('🚫 Excluding ${excludedProfiles.length} profiles (${likedProfiles.length} liked, ${passedProfileIds.length} passed)');

    // Build query
    Query query = FirebaseFirestore.instance.collection('users');

    // Filter out current user and already interacted profiles
    // We use whereNotIn for all excluded profiles including current user
    if (excludedProfiles.isNotEmpty) {
      query = query.where(FieldPath.documentId, whereNotIn: excludedProfiles);
    } else {
      // If no excluded profiles, still exclude current user
      query = query.where(FieldPath.documentId, isNotEqualTo: currentUser.uid);
    }

    // Limit results for better performance
    query = query.limit(20);

    final querySnapshot = await query.get();
    print('✅ Found ${querySnapshot.docs.length} profiles after filtering');

    // Additional filtering on client side if needed
    final profiles = querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'uid': doc.id, // Document ID
        'UID': data['UID'] ?? doc.id, // Keep UID field
        ...data,
      };
    }).toList();

    return profiles;
  } catch (e) {
    print('❌ Error getting discovery profiles: $e');
    return [];
  }
}