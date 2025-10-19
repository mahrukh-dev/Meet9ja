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

    // Get current user data to check preferences and already interacted profiles
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!currentUserDoc.exists) {
      print('❌ Current user document not found');
      return [];
    }

    final currentUserData = currentUserDoc.data()!;
    // final likedProfiles = List<String>.from(currentUserData['liked_profiles'] ?? []);
    // final passedProfiles = List<String>.from(currentUserData['passed_profiles'] ?? []);
    // final userPreference = currentUserData['preferences'] ?? 'anyone';
    //
    // print('📊 User preferences - Liked: ${likedProfiles.length}, Passed: ${passedProfiles.length}, Preference: $userPreference');

    // Build query
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('UID', isNotEqualTo: currentUser.uid);

    // Filter out already liked/passed profiles
    // final excludedProfiles = [...likedProfiles, ...passedProfiles];
    // if (excludedProfiles.isNotEmpty) {
    //   query = query.where('UID', whereNotIn: excludedProfiles);
    // }
    //
    // // Filter by gender preference if not 'anyone'
    // if (userPreference != 'anyone') {
    //   query = query.where('preferences', isEqualTo: userPreference);
    // }

    query = query.limit(20);

    final querySnapshot = await query.get();
    print('✅ Found ${querySnapshot.docs.length} profiles');

    final profiles = querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'uid': doc.id,
        ...data,
      };
    }).toList();

    return profiles;
  } catch (e) {
    print('❌ Error getting discovery profiles: $e');
    return [];
  }
}