import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/user_model.dart';
import '../db_functions/user_service.dart';
import '../constants/app_colors.dart';

class MatchedUsersScreen extends StatefulWidget {
  final String userId;

  const MatchedUsersScreen({super.key, required this.userId});

  @override
  State<MatchedUsersScreen> createState() => _MatchedUsersScreenState();
}

class _MatchedUsersScreenState extends State<MatchedUsersScreen> {
  List<UserModel> _matchedUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatchedUsers();
  }

  Future<void> _loadMatchedUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Get mutual matches where both users have liked each other
      final matchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('UID', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'match')
          .where('is_mutual', isEqualTo: true)
          .get();

      final matchedUserIds = matchesSnapshot.docs
          .map((doc) => doc.data()['matched_user_ID'] as String)
          .toList();

      final users = await Future.wait(
        matchedUserIds.map((userId) => UserService.getUserProfile(userId)),
      );

      setState(() {
        _matchedUsers = users.whereType<UserModel>().toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load matches: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Matches',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : _matchedUsers.isEmpty
          ? _buildEmptyState()
          : _buildMatchedUsersList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading matches...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.exclamationTriangle,
            size: 60,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Matches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black45),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadMatchedUsers,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.heart,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No matches yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'When you match with someone, they will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedUsersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _matchedUsers.length,
      itemBuilder: (context, index) {
        final user = _matchedUsers[index];
        final profilePhotoUrl = UserService.getProfilePhotoUrl(user);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: profilePhotoUrl != null
                  ? NetworkImage(profilePhotoUrl)
                  : const NetworkImage("https://i.pravatar.cc/100?img=8")
              as ImageProvider,
            ),
            title: Text(
              user.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              UserService.getDisplayUsername(user),
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
            trailing: const Icon(
              FontAwesomeIcons.heart,
              color: Colors.red,
              size: 20,
            ),
            onTap: () {
              // Navigate to user profile or start chat
              // You can implement this based on your app's navigation
            },
          ),
        );
      },
    );
  }
}