import 'package:cloud_firestore/cloud_firestore.dart';

class LiveHistory {
  final String liveId;
  final String uid;
  final String hostName;
  final String title;
  final Timestamp startTime;
  final Timestamp endTime;
  final int viewerCount;
  final int totalGiftValue;
  final String liveReplayMediaUrl;
  final String uploadStatus;
  final String recordingType;
  final int durationSeconds;

  LiveHistory({
    required this.liveId,
    required this.uid,
    required this.hostName,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.viewerCount,
    required this.totalGiftValue,
    required this.liveReplayMediaUrl,
    required this.uploadStatus,
    required this.recordingType,
    required this.durationSeconds,
  });

  factory LiveHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveHistory(
      liveId: data['live_id'] ?? '',
      uid: data['UID'] ?? '',
      hostName: data['host_name'] ?? '',
      title: data['title'] ?? 'Live Stream',
      startTime: data['start_time'] ?? Timestamp.now(),
      endTime: data['end_time'] ?? Timestamp.now(),
      viewerCount: data['viewer_count'] ?? 0,
      totalGiftValue: data['total_gift_value'] ?? 0,
      liveReplayMediaUrl: data['live_replay_media_url'] ?? '',
      uploadStatus: data['upload_status'] ?? 'unknown',
      recordingType: data['recording_type'] ?? 'unknown',
      durationSeconds: data['duration_seconds'] ?? 0,
    );
  }
}