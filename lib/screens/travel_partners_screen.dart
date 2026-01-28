import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meet9ja/models/user_model.dart';
import 'package:meet9ja/db_functions/user_service.dart';
import 'package:meet9ja/screens/other_dating_profile_screen.dart';
import 'package:meet9ja/db_functions/likeProfile.dart';
import 'package:meet9ja/db_functions/passProfile.dart';
import 'package:meet9ja/db_functions/getUserName.dart';
import 'package:meet9ja/db_functions/isUserPremium.dart';
import '../constants/app_colors.dart';
import '../db_functions/match_service.dart';

class TravelPartnersScreen extends StatefulWidget {
  final String city;
  final String country;
  final String travelHistoryId;

  const TravelPartnersScreen({
    super.key,
    required this.city,
    required this.country,
    required this.travelHistoryId,
  });

  @override
  State<TravelPartnersScreen> createState() => _TravelPartnersScreenState();
}

class _TravelPartnersScreenState extends State<TravelPartnersScreen> {
  List<UserModel> _travelPartners = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<String> _likedUsers = {};
  final Set<String> _passedUsers = {};

  @override
  void initState() {
    super.initState();
    _loadTravelPartners();
  }

  Future<void> _loadTravelPartners() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Get current user ID
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in';
        });
        return;
      }

      // Find other users who have visited the same location
      final travelHistorySnapshot = await FirebaseFirestore.instance
          .collection('travel_history')
          .where('city', isEqualTo: widget.city)
          .where('country', isEqualTo: widget.country)
          .where('userId', isNotEqualTo: currentUserId) // Exclude current user
          .limit(10) // Limit to 10 users
          .get();

      if (travelHistorySnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _travelPartners = [];
        });
        return;
      }

      // Get unique user IDs from travel history
      final userIds = travelHistorySnapshot.docs
          .map((doc) => doc['userId'] as String)
          .toSet()
          .toList();

      // Limit to first 5 users (4-5 profiles as requested)
      final limitedUserIds = userIds.take(5).toList();

      // Fetch user profiles
      final users = await UserService.getUsersByIds(limitedUserIds);

      // Filter out already liked/passed users
      final filteredUsers = await _filterLikedAndPassedUsers(users, currentUserId);

      setState(() {
        _travelPartners = filteredUsers;
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading travel partners: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load travel partners: $e';
      });
    }
  }

  Future<List<UserModel>> _filterLikedAndPassedUsers(List<UserModel> users, String currentUserId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (!userDoc.exists) return users;

      final userData = userDoc.data() as Map<String, dynamic>;

      // Get arrays from user document
      final likedProfiles = List<String>.from(userData['liked_profiles'] ?? []);
      final passedProfiles = List<String>.from(userData['passed_profiles'] ?? []);

      // Filter out users already liked or passed
      return users.where((user) {
        return !likedProfiles.contains(user.uid) &&
            !passedProfiles.contains(user.uid);
      }).toList();

    } catch (e) {
      print('Error filtering users: $e');
      return users;
    }
  }

  Future<void> _likeUser(UserModel user) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      await MatchService.likeProfile(
        currentUserId: currentUserId,
        targetUserId: user.uid,
      );

      // Remove from local list
      if (mounted) {
        setState(() {
          _travelPartners.removeWhere((u) => u.uid == user.uid);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _passUser(UserModel user) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      await MatchService.passProfile(
        currentUserId: currentUserId,
        targetUserId: user.uid,
      );

      // Remove from local list
      if (mounted) {
        setState(() {
          _travelPartners.removeWhere((u) => u.uid == user.uid);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _viewUserProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherDatingProfileScreen(
          conversationId: '',
          userId: user.uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Travel Partners',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(FontAwesomeIcons.arrowsRotate),
            onPressed: _loadTravelPartners,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage.isNotEmpty
          ? _buildErrorState()
          : _travelPartners.isEmpty
          ? _buildEmptyState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Finding travel partners...',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.exclamationTriangle,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadTravelPartners,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.usersSlash,
              size: 80,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              'No travel partners yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Be the first to visit ${widget.city}, ${widget.country}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Other users who visit this location will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 16),
            // Show if all users were liked/passed
            if (_likedUsers.isNotEmpty || _passedUsers.isNotEmpty)
              Column(
                children: [
                  SizedBox(height: 20),
                  Text(
                    'You\'ve liked or passed on all available travel partners',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadTravelPartners,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Check for new travelers'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  FontAwesomeIcons.locationDot,
                  color: AppColors.primary,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.city,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        widget.country,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'People who have also visited this location',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _StatChip(
                  icon: FontAwesomeIcons.heart,
                  count: _likedUsers.length,
                  label: 'Liked',
                  color: Colors.green,
                ),
                SizedBox(width: 8),
                _StatChip(
                  icon: FontAwesomeIcons.xmark,
                  count: _passedUsers.length,
                  label: 'Passed',
                  color: Colors.orange,
                ),
                SizedBox(width: 8),
                _StatChip(
                  icon: FontAwesomeIcons.users,
                  count: _travelPartners.length,
                  label: 'Available',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),

          SizedBox(height: 4),

          // Travel Partners Grid
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: _travelPartners.length,
            itemBuilder: (context, index) {
              final user = _travelPartners[index];
              final isLiked = _likedUsers.contains(user.uid);
              return _TravelPartnerCard(
                user: user,
                isLiked: isLiked,
                onLike: () => _likeUser(user),
                onPass: () => _passUser(user),
                onTap: () => _viewUserProfile(user),
              );
            },
          ),

          SizedBox(height: 24),

          // Info Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.infoCircle,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'How travel partners work',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  '• Connect with people who have visited the same locations as you',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                SizedBox(height: 6),
                Text(
                  '• Share travel experiences and tips',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                SizedBox(height: 6),
                Text(
                  '• Plan future trips together',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                SizedBox(height: 6),
                Text(
                  '• Discover new places through friends',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                SizedBox(height: 12),
                Divider(),
                SizedBox(height: 8),
                Text(
                  'Note: When you like or pass on someone, they will be removed from this list just like in the main discovery feed.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelPartnerCard extends StatelessWidget {
  final UserModel user;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final VoidCallback onTap;

  const _TravelPartnerCard({
    required this.user,
    required this.isLiked,
    required this.onLike,
    required this.onPass,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = UserService.getProfilePhotoUrl(user);
    final tags = user.interests?.take(2).toList() ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                color: Colors.grey.shade200,
                image: profilePhotoUrl != null
                    ? DecorationImage(
                  image: NetworkImage(profilePhotoUrl),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: profilePhotoUrl == null
                  ? Center(
                child: Icon(
                  FontAwesomeIcons.user,
                  size: 40,
                  color: Colors.grey.shade400,
                ),
              )
                  : Stack(
                children: [
                  // Like button (top right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onLike,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isLiked
                                ? FontAwesomeIcons.solidHeart
                                : FontAwesomeIcons.heart,
                            size: 16,
                            color: isLiked
                                ? AppColors.primary
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Pass button (bottom left)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: onPass,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            FontAwesomeIcons.xmark,
                            size: 16,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Premium badge (top left)
                  if (user.type == 'premium')
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FontAwesomeIcons.crown,
                              size: 10,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Premium',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // User Info
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name.split(' ').first,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${user.age} years',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags.map((tag) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}