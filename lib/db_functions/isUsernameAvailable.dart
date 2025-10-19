// Check username availability
import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> isUsernameAvailable(String username) async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase())
        .get();

    return querySnapshot.docs.isEmpty;
  } catch (e) {
    print('❌ Error checking username availability: $e');
    throw 'Failed to check username availability';
  }
}
