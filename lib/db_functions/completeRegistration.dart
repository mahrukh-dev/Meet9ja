
// Complete registration process
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meet9ja/db_functions/saveUserProfile.dart';

import 'createUserWithEmailAndPassword.dart';

Future<void> completeRegistration({
  required String email,
  required String password,
  required String name,
  required String username,
  required int age,
  required String selectedMode,
  required String travelPreference,
  required String bio,
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
        bio: bio,
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

