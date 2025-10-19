// Check if user is premium (verified)
bool isUserPremium(Map<String, dynamic> userData) {
  final userType = userData['type']?.toString() ?? 'nonpremium';
  return userType == 'premium';
}