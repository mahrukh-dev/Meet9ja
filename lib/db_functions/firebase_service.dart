import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'image_service.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if username is available
  static Future<bool> isUsernameAvailable(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      print('❌ Error checking username availability: $e');
      throw 'Failed to check username availability: $e';
    }
  }

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

  // Save user profile to Firestore with photos
  static Future<void> saveUserProfile({
    required String uid,
    required String email,
    required String name,
    required String username,
    required int age,
    required String selectedMode,
    required String travelPreference,
    required Map<String, String> firstPhotos, // Add this parameter
  }) async {
    try {
      print('💾 Saving user profile to Firestore for UID: $uid');

      final userData = {
        'UID': uid,
        'email': email,
        'name': name,
        'age': age,
        'username': username.toLowerCase(),
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
        'first_photos': firstPhotos, // Use the provided photos
        'bio': '',
        'location': '',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      await _firestore.collection('users').doc(uid).set(userData);
      print('✅ User profile saved successfully with photos');
    } catch (e) {
      print('❌ Error saving user profile: $e');
      throw 'Failed to save user profile: $e';
    }
  }

  // Updated completeRegistration method in FirebaseService
  static Future<void> completeRegistration({
    required String email,
    required String password,
    required String name,
    required String username,
    required int age,
    required String selectedMode,
    required String travelPreference,
    required List<File> photoFiles,
  }) async {
    User? user;

    try {
      print('🚀 Starting complete registration process...');
      print('📧 Email: $email');
      print('👤 Username: $username');
      print('📸 Number of photos: ${photoFiles.length}');

      // Step 1: Create user in Firebase Auth
      user = await createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user == null) {
        throw 'User creation returned null';
      }

      final String userId = user.uid;
      print('👤 User created with UID: $userId');

      // Step 2: Upload photos to Firebase Storage
      print('📤 Starting photo upload process...');
      Map<String, String> photoUrls = await ImageService.uploadFirstPhotos(
        userId: userId,
        photoFiles: photoFiles,
      );

      // Check if any photos were successfully uploaded
      final successfulUploads = photoUrls.values.where((url) => url.isNotEmpty).length;
      print('✅ Photos uploaded successfully: $successfulUploads/${photoFiles.length}');
      print('🔗 Photo URLs: $photoUrls');

      if (successfulUploads == 0) {
        throw 'No photos were successfully uploaded';
      }

      await user.sendEmailVerification();

      // Step 3: Save user profile with photo URLs
      print('💾 Saving user profile to Firestore...');
      await saveUserProfile(
        uid: userId,
        email: email,
        name: name,
        age: age,
        username: username,
        selectedMode: selectedMode,
        travelPreference: travelPreference,
        firstPhotos: photoUrls,
      );

      print('🎉 Registration completed successfully!');
      print('👤 User: $userId');
      print('📸 Photos saved: $photoUrls');

    } catch (e) {
      print('❌ Registration failed: $e');
      print('🔍 Error type: ${e.runtimeType}');

      // If registration fails, delete the created user from Auth
      if (user != null) {
        try {
          await user.delete();
          print('🗑️ Deleted user from Auth due to registration failure');
        } catch (deleteError) {
          print('⚠️ Could not delete user from Auth: $deleteError');
        }
      }

      // Re-throw with more context
      throw 'Registration failed: $e';
    }
  }

  // Add to lib/db_functions/firebase_service.dart
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ User signed out successfully');

      // Optional: Clear any local data/cache
      // await _clearLocalData();

    } catch (e) {
      print('❌ Error signing out: $e');
      throw 'Failed to sign out: $e';
    }
  }

  // --- Login Method ---
  static Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('🔥 Attempting to sign in user with email: $email');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ User signed in successfully: ${userCredential.user?.uid}');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error during login: ${e.code} - ${e.message}');
      throw _handleAuthError(e);
    } catch (e) {
      print('❌ Unexpected error during sign in: $e');
      throw 'Failed to sign in: $e';
    }
  }

  // Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Error handling
  static String _handleAuthError(FirebaseAuthException e) {
    print('🔍 Handling auth error: ${e.code}');
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'Your account has been disabled. Please contact support.';
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Registration/Authentication failed: ${e.message}';
    }
  }

  // Add these methods to your lib/db_functions/firebase_service.dart
  static Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('✅ Verification email sent to ${user.email}');
      }
    } catch (e) {
      print('❌ Error sending verification email: $e');
      throw 'Failed to send verification email: $e';
    }
  }

  static Future<bool> checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Reload user to get latest email verification status
        await user.reload();
        final updatedUser = _auth.currentUser;
        return updatedUser?.emailVerified ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error checking email verification: $e');
      return false;
    }
  }

// Password reset method
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Password reset email sent to $email');
    } catch (e) {
      print('❌ Error sending password reset email: $e');
      throw _handleAuthError(e as FirebaseAuthException);
    }
  }

}