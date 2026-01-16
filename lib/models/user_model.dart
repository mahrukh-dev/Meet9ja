import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String username;
  final int age;
  final String gender;
  final String? photoUrl;
  final Map<String, dynamic> mode;
  final String preferences;
  final String type; // premium/nonpremium
  final Map<String, dynamic> livePreferences;
  final List<String> following;
  final List<String> followers;
  final List<String> likedProfiles; // NEW: Added liked profiles
  final List<String> likedBy; // NEW: Added liked by others
  final bool liveStatus;
  final Map<String, dynamic> wallet;
  final List<String> interests;
  final Map<String, dynamic> firstPhotos;
  final String? bio;
  final String? location;
  final String? website;
  final String? instagram;
  final String? twitter;
  final String? facebook;
  final String? tiktok;
  final String? youtube;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.age,
    required this.gender,
    required this.username,
    this.photoUrl,
    required this.mode,
    required this.preferences,
    required this.type,
    required this.livePreferences,
    required this.following,
    required this.followers,
    required this.likedProfiles, // NEW
    required this.likedBy, // NEW
    required this.liveStatus,
    required this.wallet,
    required this.interests,
    required this.firstPhotos,
    this.bio,
    this.location,
    this.website,
    this.instagram,
    this.twitter,
    this.facebook,
    this.tiktok,
    this.youtube,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['UID'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      gender: data['gender'] ?? '',
      age: data['age'] ?? 0,
      username: data['username'] ?? '',
      photoUrl: data['photo_url'],
      mode: Map<String, dynamic>.from(data['mode'] ?? {}),
      preferences: data['preferences'] ?? '',
      type: data['type'] ?? 'nonpremium',
      livePreferences: Map<String, dynamic>.from(data['live_preferences'] ?? {}),
      following: List<String>.from(data['following'] ?? []),
      followers: List<String>.from(data['followers'] ?? []),
      likedProfiles: List<String>.from(data['liked_profiles'] ?? []), // NEW
      likedBy: List<String>.from(data['liked_by'] ?? []), // NEW
      liveStatus: data['live_status'] ?? false,
      wallet: Map<String, dynamic>.from(data['wallet'] ?? {}),
      interests: List<String>.from(data['interests'] ?? []),
      firstPhotos: Map<String, dynamic>.from(data['first_photos'] ?? {}),
      bio: data['bio'],
      location: data['location'],
      website: data['website'],
      instagram: data['instagram'],
      twitter: data['twitter'],
      facebook: data['facebook'],
      tiktok: data['tiktok'],
      youtube: data['youtube'],
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'UID': uid,
      'email': email,
      'name': name,
      'age': age,
      'gender': gender,
      'username': username,
      'photo_url': photoUrl,
      'mode': mode,
      'preferences': preferences,
      'type': type,
      'live_preferences': livePreferences,
      'following': following,
      'followers': followers,
      'liked_profiles': likedProfiles, // NEW
      'liked_by': likedBy, // NEW
      'live_status': liveStatus,
      'wallet': {
        'diamond_balance': 0,
        'coin_balance': 0,
        'total_earning': 0.0,
      },
      'interests': interests,
      'first_photos': firstPhotos,
      'bio': bio,
      'location': location,
      'website': website,
      'instagram': instagram,
      'twitter': twitter,
      'facebook': facebook,
      'tiktok': tiktok,
      'youtube': youtube,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'status': status,
    };
  }
}