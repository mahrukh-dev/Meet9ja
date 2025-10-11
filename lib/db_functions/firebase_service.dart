import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create user with email and password
  static Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('🔥 Attempting to create user with email: $email');
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ User created successfully: ${userCredential.user?.uid}');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      throw _handleAuthError(e);
    } catch (e) {
      print('❌ Unexpected error during user creation: $e');
      throw 'Failed to create account: $e';
    }
  }

  // Save user profile to Firestore
  static Future<void> saveUserProfile({
    required String uid,
    required String email,
    required String name,
    required int age,
    required String selectedMode,
    required String travelPreference,
  }) async {
    try {
      print('💾 Saving user profile to Firestore for UID: $uid');

      final userData = {
        'UID': uid,
        'email': email,
        'name': name,
        'age': age,
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
        'bio': '',
        'location': '',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      await _firestore.collection('users').doc(uid).set(userData);
      print('✅ User profile saved successfully');
    } catch (e) {
      print('❌ Error saving user profile: $e');
      throw 'Failed to save user profile: $e';
    }
  }

  // Complete registration process
  static Future<void> completeRegistration({
    required String email,
    required String password,
    required String name,
    required int age,
    required String selectedMode,
    required String travelPreference,
  }) async {
    try {
      print('🚀 Starting complete registration process...');

      User? user = await createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user != null) {
        await saveUserProfile(
          uid: user.uid,
          email: email,
          name: name,
          age: age,
          selectedMode: selectedMode,
          travelPreference: travelPreference,
        );
        print('🎉 Registration completed successfully!');
      } else {
        throw 'User creation returned null';
      }
    } catch (e) {
      print('❌ Registration failed: $e');
      rethrow;
    }
  }

  // Error handling
  static String _handleAuthError(FirebaseAuthException e) {
    print('🔍 Handling auth error: ${e.code}');
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Registration failed: ${e.message}';
    }
  }
}