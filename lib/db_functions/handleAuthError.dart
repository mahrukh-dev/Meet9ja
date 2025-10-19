
// Error handling
import 'package:firebase_auth/firebase_auth.dart';

String handleAuthError(FirebaseAuthException e) {
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