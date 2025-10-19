// Get user's age
int getUserAge(Map<String, dynamic> userData) {
  return (userData['age'] as int?) ?? 0;
}
