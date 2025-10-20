import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String uid;
  final String caption;
  final String type;
  final String mediaUrl;
  final DateTime dateTime;
  final List<Comment> comments;
  final List<Like> likes;

  PostModel({
    required this.id,
    required this.uid,
    required this.caption,
    required this.type,
    required this.mediaUrl,
    required this.dateTime,
    required this.comments,
    required this.likes,
  });

  factory PostModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PostModel(
      id: id,
      uid: data['UID'] ?? '',
      caption: data['caption'] ?? '',
      type: data['type'] ?? 'post',
      mediaUrl: data['media_url'] ?? '',
      dateTime: (data['date_time'] as Timestamp).toDate(),
      comments: (data['comments'] as List<dynamic>? ?? [])
          .map((comment) => Comment.fromMap(comment))
          .toList(),
      likes: (data['likes'] as List<dynamic>? ?? [])
          .map((like) => Like.fromMap(like))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'UID': uid,
      'caption': caption,
      'type': type,
      'media_url': mediaUrl,
      'date_time': Timestamp.fromDate(dateTime),
      'comments': comments.map((comment) => comment.toMap()).toList(),
      'likes': likes.map((like) => like.toMap()).toList(),
    };
  }
}

class Comment {
  final String commenterUID;
  final DateTime dateTime;
  final String text;

  Comment({
    required this.commenterUID,
    required this.dateTime,
    required this.text,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      commenterUID: map['commenterUID'] ?? '',
      dateTime: (map['date_time'] as Timestamp).toDate(),
      text: map['text'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commenterUID': commenterUID,
      'date_time': Timestamp.fromDate(dateTime),
      'text': text,
    };
  }
}

class Like {
  final String likerUID;
  final DateTime dateTime;

  Like({
    required this.likerUID,
    required this.dateTime,
  });

  factory Like.fromMap(Map<String, dynamic> map) {
    return Like(
      likerUID: map['likerUID'] ?? '',
      dateTime: (map['date_time'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'likerUID': likerUID,
      'date_time': Timestamp.fromDate(dateTime),
    };
  }
}