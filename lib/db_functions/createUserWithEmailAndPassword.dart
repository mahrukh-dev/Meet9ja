// Create user with email and password
import 'package:firebase_auth/firebase_auth.dart';

import 'handleAuthError.dart';
import 'isUsernameAvailable.dart';

Future<User?> createUserWithEmailAndPassword({
  required String email,
  required String password,
  required String username,
}) async {
  try {
    print('🔥 Attempting to create user with email: $email, username: $username');

    // Check if username is available
    final isAvailable = await isUsernameAvailable(username);
    if (!isAvailable) {
      throw 'Username "$username" is already taken. Please choose another one.';
    }

    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update display name in Firebase Auth
    await userCredential.user?.updateDisplayName(username);

    print('✅ User created successfully: ${userCredential.user?.uid}');
    return userCredential.user;
  } on FirebaseAuthException catch (e) {
    print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
    throw handleAuthError(e);
  } catch (e) {
    print('❌ Unexpected error during user creation: $e');
    throw 'Failed to create account: $e';
  }
}

