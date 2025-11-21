import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleModel {
  final String id;
  final String uid;
  final String title;
  final String description;
  final DateTime scheduledTime;
  final DateTime? notifiedAt;
  final String status; // 'scheduled', 'live', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  ScheduleModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.description,
    required this.scheduledTime,
    this.notifiedAt,
    this.status = 'scheduled',
    required this.createdAt,
    required this.updatedAt,
  });

  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduleModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      scheduledTime: (data['scheduled_time'] as Timestamp).toDate(),
      notifiedAt: data['notified_at'] != null
          ? (data['notified_at'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'scheduled',
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'scheduled_time': Timestamp.fromDate(scheduledTime),
      'notified_at': notifiedAt != null ? Timestamp.fromDate(notifiedAt!) : null,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  ScheduleModel copyWith({
    String? title,
    String? description,
    DateTime? scheduledTime,
    String? status,
    DateTime? notifiedAt,
  }) {
    return ScheduleModel(
      id: id,
      uid: uid,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      notifiedAt: notifiedAt ?? this.notifiedAt,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}