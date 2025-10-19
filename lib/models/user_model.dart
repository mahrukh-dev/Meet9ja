import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String username;
  final int age;
  final String? photoUrl;
  final Map<String, dynamic> mode;
  final String preferences;
  final String type;
  final Map<String, dynamic> livePreferences;
  final List<String> following;
  final List<String> followers;
  final bool liveStatus;
  final Map<String, dynamic> wallet;
  final List<String> interests;
  final Map<String, dynamic> firstPhotos;
  final String? bio;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.age,
    required this.username,
    this.photoUrl,
    required this.mode,
    required this.preferences,
    required this.type,
    required this.livePreferences,
    required this.following,
    required this.followers,
    required this.liveStatus,
    required this.wallet,
    required this.interests,
    required this.firstPhotos,
    this.bio,
    this.location,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['UID'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      username: data['username'] ?? '',
      photoUrl: data['photo_url'],
      mode: Map<String, dynamic>.from(data['mode'] ?? {}),
      preferences: data['preferences'] ?? '',
      type: data['type'] ?? 'nonpremium',
      livePreferences: Map<String, dynamic>.from(data['live_preferences'] ?? {}),
      following: List<String>.from(data['following'] ?? []),
      followers: List<String>.from(data['followers'] ?? []),
      liveStatus: data['live_status'] ?? false,
      wallet: Map<String, dynamic>.from(data['wallet'] ?? {}),
      interests: List<String>.from(data['interests'] ?? []),
      firstPhotos: Map<String, dynamic>.from(data['first_photos'] ?? {}),
      bio: data['bio'],
      location: data['location'],
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
      status: data['status'] ?? 'active',
    );
  }
}