// Sign in with email and password
import 'package:firebase_auth/firebase_auth.dart';

import 'handleAuthError.dart';

Future<User?> signInWithEmailAndPassword({
  required String email,
  required String password,
}) async {
  try {
    print('🔥 Attempting to sign in user with email: $email');
    UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    print('✅ User signed in successfully: ${userCredential.user?.uid}');
    return userCredential.user;
  } on FirebaseAuthException catch (e) {
    print('❌ Firebase Auth Error during login: ${e.code} - ${e.message}');
    throw handleAuthError(e);
  } catch (e) {
    print('❌ Unexpected error during sign in: $e');
    throw 'Failed to sign in: $e';
  }
}