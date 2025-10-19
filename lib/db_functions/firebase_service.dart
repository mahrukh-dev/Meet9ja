import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      throw 'Failed to check username availability';
    }
  }

  // Create user with email and password
  static Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      print('🔥 Attempting to create user with email: $email, username: $username');

      final isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw 'Username "$username" is already taken. Please choose another one.';
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.updateDisplayName(username);
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
    required String username,
    required int age,
    required String selectedMode,
    required String travelPreference,
    required Map<String, String> firstPhotos,
  }) async {
    try {
      print('💾 Saving user profile to Firestore for UID: $uid, username: $username');

      final userData = {
        'UID': uid,
        'email': email,
        'name': name,
        'age': age,
        'username': username.toLowerCase(), // Store in lowercase for case-insensitive search
        'username_lowercase': username.toLowerCase(), // Additional field for easy searching
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
        'first_photos': firstPhotos,
        'bio': '',
        'location': '',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      await _firestore.collection('users').doc(uid).set(userData);
      print('✅ User profile saved successfully with username: $username');
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
    required String username,
    required int age,
    required String selectedMode,
    required String travelPreference,
    required Map<String, String> firstPhotos,
  }) async {
    try {
      print('🚀 Starting complete registration process for username: $username');

      User? user = await createUserWithEmailAndPassword(
        email: email,
        password: password,
        username: username,
      );

      if (user != null) {
        await saveUserProfile(
          uid: user.uid,
          email: email,
          name: name,
          age: age,
          username: username,
          selectedMode: selectedMode,
          travelPreference: travelPreference,
          firstPhotos: firstPhotos,
        );
        print('🎉 Registration completed successfully for username: $username!');
      } else {
        throw 'User creation returned null';
      }
    } catch (e) {
      print('❌ Registration failed: $e');
      rethrow;
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

      // Get user data from Firestore to verify username exists
      final userDoc = await _firestore.collection('users').doc(userCredential.user?.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final username = userData?['username'] ?? 'No username';
        print('✅ User signed in successfully: ${userCredential.user?.uid}, username: $username');
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error during login: ${e.code} - ${e.message}');
      throw _handleAuthError(e);
    } catch (e) {
      print('❌ Unexpected error during sign in: $e');
      throw 'Failed to sign in: $e';
    }
  }

  // Get user data including username
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // Get current user's username
  static Future<String?> getCurrentUsername() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userData = await getUserData(user.uid);
      return userData?['username'] as String?;
    }
    return null;
  }

  // Update username
  static Future<void> updateUsername(String newUsername) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No user logged in';

      // Check if new username is available
      final isAvailable = await isUsernameAvailable(newUsername);
      if (!isAvailable) {
        throw 'Username "$newUsername" is already taken. Please choose another one.';
      }

      // Update in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'username': newUsername.toLowerCase(),
        'username_lowercase': newUsername.toLowerCase(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update in Firebase Auth display name
      await user.updateDisplayName(newUsername);

      print('✅ Username updated successfully to: $newUsername');
    } catch (e) {
      print('❌ Error updating username: $e');
      rethrow;
    }
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
}