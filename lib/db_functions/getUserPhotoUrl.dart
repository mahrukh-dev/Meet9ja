
// Get user's primary photo URL
String getUserPhotoUrl(Map<String, dynamic> userData) {
  final firstPhotos = userData['first_photos'] as Map<String, dynamic>? ?? {};
  return firstPhotos['photo1url']?.toString() ?? '';
}