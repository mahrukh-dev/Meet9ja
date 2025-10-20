import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String id;
  final String uid;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewers;

  StoryModel({
    required this.id,
    required this.uid,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.expiresAt,
    required this.viewers,
  });

  factory StoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    return StoryModel(
      id: id,
      uid: data['UID'] ?? '',
      mediaUrl: data['media_url'] ?? '',
      mediaType: data['media_type'] ?? 'image',
      createdAt: (data['created_at'] as Timestamp).toDate(),
      expiresAt: (data['expires_at'] as Timestamp).toDate(),
      viewers: List<String>.from(data['viewers'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'UID': uid,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'created_at': Timestamp.fromDate(createdAt),
      'expires_at': Timestamp.fromDate(expiresAt),
      'viewers': viewers,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get timeRemaining => expiresAt.difference(DateTime.now());
}