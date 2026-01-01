import 'package:cloud_firestore/cloud_firestore.dart';

class TravelHistory {
  final String id;
  final String userId;
  final String city;
  final String country;
  final String countryCode;
  final double latitude;
  final double longitude;
  final String address;
  final String locationImageUrl;
  final DateTime visitedAt;
  final DateTime createdAt;

  TravelHistory({
    required this.id,
    required this.userId,
    required this.city,
    required this.country,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.locationImageUrl,
    required this.visitedAt,
    required this.createdAt,
  });

  factory TravelHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TravelHistory(
      id: doc.id,
      userId: data['userId'] ?? '',
      city: data['city'] ?? '',
      country: data['country'] ?? '',
      countryCode: data['countryCode'] ?? '',
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      address: data['address'] ?? '',
      locationImageUrl: data['locationImageUrl'] ?? '',
      visitedAt: (data['visitedAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'city': city,
      'country': country,
      'countryCode': countryCode,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'locationImageUrl': locationImageUrl,
      'visitedAt': Timestamp.fromDate(visitedAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}