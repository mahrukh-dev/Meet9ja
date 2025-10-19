
// Get user's bio
String getUserBio(Map<String, dynamic> userData) {
  return userData['bio']?.toString() ?? 'No bio yet';
}