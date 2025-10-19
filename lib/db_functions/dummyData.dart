// lib/db_functions/addDummyData.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> addDummyData() async {
  try {
    print('🚀 Starting to add dummy data...');

    final batch = FirebaseFirestore.instance.batch();

    // ===== DUMMY USERS =====
    final dummyUsers = [
      {
        'UID': 'user_001',
        'email': 'sarah.traveler@example.com',
        'username': 'sarah_adventures',
        'name': 'Sarah Johnson',
        'age': 26,
        'bio': 'Passionate traveler and foodie. Love exploring new cultures and making meaningful connections around the world! 🌍',
        'location': 'New York',
        'preferences': 'anyone',
        'type': 'premium',
        'status': 'active',
        'first_photos': {
          'photo1url': 'https://i.pravatar.cc/300?img=1',
          'photo2url': 'https://i.pravatar.cc/300?img=2',
          'photo3url': 'https://i.pravatar.cc/300?img=3',
          'photo4url': 'https://i.pravatar.cc/300?img=4',
        },
        'mode': {
          'date': true,
          'travel_partner': true,
          'BFF': false,
          'bizz': false,
        },
        'live_preferences': {
          'visibility': 'public',
        },
        'following': ['user_002', 'user_003'],
        'followers': ['user_002', 'user_004'],
        'live_status': false,
        'wallet': {
          'coin_balance': 1500,
          'total_earning': 500,
        },
        'interests': ['Travel', 'Food', 'Photography', 'Hiking', 'Music'],
        'liked_profiles': [],
        'passed_profiles': [],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      {
        'UID': 'user_002',
        'email': 'mike.explorer@example.com',
        'username': 'mike_explorer',
        'name': 'Mike Chen',
        'age': 29,
        'bio': 'Digital nomad and adventure seeker. Always planning my next trip! ✈️',
        'location': 'San Francisco',
        'preferences': 'women',
        'type': 'nonpremium',
        'status': 'active',
        'first_photos': {
          'photo1url': 'https://i.pravatar.cc/300?img=5',
          'photo2url': 'https://i.pravatar.cc/300?img=6',
          'photo3url': '',
          'photo4url': '',
        },
        'mode': {
          'date': false,
          'travel_partner': true,
          'BFF': true,
          'bizz': true,
        },
        'live_preferences': {
          'visibility': 'friends',
        },
        'following': ['user_001', 'user_003'],
        'followers': ['user_001'],
        'live_status': true,
        'wallet': {
          'coin_balance': 800,
          'total_earning': 200,
        },
        'interests': ['Technology', 'Travel', 'Coffee', 'Startups', 'Hiking'],
        'liked_profiles': ['user_001'],
        'passed_profiles': [],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      {
        'UID': 'user_003',
        'email': 'lisa.wanderer@example.com',
        'username': 'lisa_wanderlust',
        'name': 'Lisa Rodriguez',
        'age': 24,
        'bio': 'Art lover and spontaneous traveler. Life is too short to stay in one place! 🎨',
        'location': 'Miami',
        'preferences': 'anyone',
        'type': 'premium',
        'status': 'active',
        'first_photos': {
          'photo1url': 'https://i.pravatar.cc/300?img=7',
          'photo2url': 'https://i.pravatar.cc/300?img=8',
          'photo3url': 'https://i.pravatar.cc/300?img=9',
          'photo4url': '',
        },
        'mode': {
          'date': true,
          'travel_partner': false,
          'BFF': true,
          'bizz': false,
        },
        'live_preferences': {
          'visibility': 'public',
        },
        'following': ['user_001'],
        'followers': ['user_001', 'user_002'],
        'live_status': false,
        'wallet': {
          'coin_balance': 2000,
          'total_earning': 800,
        },
        'interests': ['Art', 'Dancing', 'Beaches', 'Fashion', 'Yoga'],
        'liked_profiles': ['user_001', 'user_002'],
        'passed_profiles': [],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      {
        'UID': 'user_004',
        'email': 'david.entrepreneur@example.com',
        'username': 'david_global',
        'name': 'David Kim',
        'age': 32,
        'bio': 'Business traveler building connections worldwide. Let\'s network and explore! 💼',
        'location': 'London',
        'preferences': 'women',
        'type': 'nonpremium',
        'status': 'active',
        'first_photos': {
          'photo1url': 'https://i.pravatar.cc/300?img=10',
          'photo2url': 'https://i.pravatar.cc/300?img=11',
          'photo3url': '',
          'photo4url': '',
        },
        'mode': {
          'date': false,
          'travel_partner': false,
          'BFF': false,
          'bizz': true,
        },
        'live_preferences': {
          'visibility': 'followers',
        },
        'following': ['user_001'],
        'followers': ['user_001'],
        'live_status': false,
        'wallet': {
          'coin_balance': 500,
          'total_earning': 100,
        },
        'interests': ['Business', 'Networking', 'Golf', 'Wine', 'Luxury Travel'],
        'liked_profiles': [],
        'passed_profiles': ['user_003'],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      {
        'UID': 'user_005',
        'email': 'emma.adventurer@example.com',
        'username': 'emma_adventures',
        'name': 'Emma Wilson',
        'age': 27,
        'bio': 'Mountain climber and nature enthusiast. Always looking for my next adventure! ⛰️',
        'location': 'Denver',
        'preferences': 'anyone',
        'type': 'premium',
        'status': 'active',
        'first_photos': {
          'photo1url': 'https://i.pravatar.cc/300?img=12',
          'photo2url': 'https://i.pravatar.cc/300?img=13',
          'photo3url': 'https://i.pravatar.cc/300?img=14',
          'photo4url': 'https://i.pravatar.cc/300?img=15',
        },
        'mode': {
          'date': true,
          'travel_partner': true,
          'BFF': true,
          'bizz': false,
        },
        'live_preferences': {
          'visibility': 'public',
        },
        'following': ['user_001', 'user_003'],
        'followers': ['user_002', 'user_003'],
        'live_status': true,
        'wallet': {
          'coin_balance': 1200,
          'total_earning': 400,
        },
        'interests': ['Hiking', 'Camping', 'Photography', 'Animals', 'Outdoors'],
        'liked_profiles': ['user_002'],
        'passed_profiles': ['user_004'],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
    ];

    // Add users to batch
    for (var user in dummyUsers) {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user['UID'] as String?);
      batch.set(docRef, user);
    }

    // ===== DUMMY MATCHES =====
    final dummyMatches = [
      {
        'matchId': 'user_001_user_002',
        'UID': 'user_001',
        'matched_user_ID': 'user_002',
        'status': 'like',
        'time_stamp': FieldValue.serverTimestamp(),
      },
      {
        'matchId': 'user_002_user_001',
        'UID': 'user_002',
        'matched_user_ID': 'user_001',
        'status': 'like',
        'time_stamp': FieldValue.serverTimestamp(),
      },
      {
        'matchId': 'user_003_user_001',
        'UID': 'user_003',
        'matched_user_ID': 'user_001',
        'status': 'like',
        'time_stamp': FieldValue.serverTimestamp(),
      },
    ];

    // Add matches to batch
    for (var match in dummyMatches) {
      final docRef = FirebaseFirestore.instance.collection('matches').doc(match['matchId'] as String?);
      batch.set(docRef, match);
    }

    // ===== DUMMY USER FEED =====
    final dummyUserFeed = [
      {
        'ID': 'post_001',
        'UID': 'user_001',
        'date_time': FieldValue.serverTimestamp(),
        'caption': 'Beautiful sunset from my recent trip to Bali! 🌅',
        'type': 'post',
        'media_url': 'https://picsum.photos/400/600',
        'comments': [
          {
            'commenterUID': 'user_002',
            'date_time': FieldValue.serverTimestamp(),
            'text': 'Amazing shot! Which beach is this?',
          }
        ],
        'likes': [
          {
            'likerUID': 'user_002',
            'date_time': FieldValue.serverTimestamp(),
          },
          {
            'likerUID': 'user_003',
            'date_time': FieldValue.serverTimestamp(),
          }
        ],
      },
      {
        'ID': 'post_002',
        'UID': 'user_002',
        'date_time': FieldValue.serverTimestamp(),
        'caption': 'Working from beautiful Costa Rica today! 🏝️',
        'type': 'post',
        'media_url': 'https://picsum.photos/400/500',
        'comments': [],
        'likes': [
          {
            'likerUID': 'user_001',
            'date_time': FieldValue.serverTimestamp(),
          }
        ],
      },
    ];

    // Add user feed to batch
    for (var post in dummyUserFeed) {
      final docRef = FirebaseFirestore.instance.collection('user_feed').doc(post['ID'] as String?);
      batch.set(docRef, post);
    }

    // ===== DUMMY SAVED POSTS =====
    final dummySavedPosts = [
      {
        'ID': 'saved_001',
        'post_id': 'post_001',
        'saved_by': 'user_002',
      },
      {
        'ID': 'saved_002',
        'post_id': 'post_002',
        'saved_by': 'user_001',
      },
    ];

    // Add saved posts to batch
    for (var saved in dummySavedPosts) {
      final docRef = FirebaseFirestore.instance.collection('saved_post').doc(saved['ID']);
      batch.set(docRef, saved);
    }

    // ===== DUMMY LIVE HISTORY =====
    final dummyLiveHistory = [
      {
        'live_id': 'live_001',
        'UID': 'user_002',
        'start_time': FieldValue.serverTimestamp(),
        'end_time': FieldValue.serverTimestamp(),
        'title': 'Travel Q&A - Ask me anything!',
        'status': 'ended',
        'viewer_count': 150,
        'total_gift_value': 350,
        'live_replay_media_url': 'https://example.com/replay1.mp4',
        'live_attended': [
          {
            'friendUID': 'user_001',
            'start_date_time': FieldValue.serverTimestamp(),
            'end_date_time': FieldValue.serverTimestamp(),
            'gift': [
              {
                'type': 'coin',
                'qty': 50,
              }
            ],
            'comments': [
              {
                'c_text': 'Great stream!',
                'c_date_time': FieldValue.serverTimestamp(),
              }
            ],
          }
        ],
      },
    ];

    // Add live history to batch
    for (var live in dummyLiveHistory) {
      final docRef = FirebaseFirestore.instance.collection('live_history').doc(live['live_id'] as String?);
      batch.set(docRef, live);
    }

    // Commit the batch
    await batch.commit();

    print('✅ SUCCESS: Added dummy data!');
    print('   👥 ${dummyUsers.length} users');
    print('   💞 ${dummyMatches.length} matches');
    print('   📱 ${dummyUserFeed.length} feed posts');
    print('   💾 ${dummySavedPosts.length} saved posts');
    print('   🔴 ${dummyLiveHistory.length} live sessions');

  } catch (e) {
    print('❌ ERROR adding dummy data: $e');
    rethrow;
  }
}

// Function to clear all dummy data (optional)
Future<void> clearDummyData() async {
  try {
    final collections = ['users', 'matches', 'user_feed', 'saved_post', 'live_history'];

    for (var collection in collections) {
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('UID', whereIn: ['user_001', 'user_002', 'user_003', 'user_004', 'user_005'])
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    print('✅ Cleared all dummy data');
  } catch (e) {
    print('❌ Error clearing dummy data: $e');
  }
}