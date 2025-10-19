// Get user's name
String getUserName(Map<String, dynamic> userData) {
  return userData['name']?.toString() ?? 'Unknown';
}

