import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meet9ja/models/user_model.dart';
import 'package:meet9ja/db_functions/user_service.dart';
import 'package:meet9ja/screens/other_dating_profile_screen.dart';
import '../constants/app_colors.dart';

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

      setState(() {
        _travelPartners = users;
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

  Future<void> _likeUser(String userId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await UserService.likeProfile(currentUserId, userId);

      setState(() {
        _likedUsers.add(userId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Liked user profile'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error liking user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to like user: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
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
          SizedBox(height: 16),

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
                onLike: () => _likeUser(user.uid),
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
  final VoidCallback onTap;

  const _TravelPartnerCard({
    required this.user,
    required this.isLiked,
    required this.onLike,
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
                  // Like button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: onLike,
                        icon: Icon(
                          isLiked
                              ? FontAwesomeIcons.solidHeart
                              : FontAwesomeIcons.heart,
                          size: 16,
                          color: isLiked
                              ? AppColors.primary
                              : Colors.grey.shade600,
                        ),
                        padding: EdgeInsets.all(6),
                        constraints: BoxConstraints(),
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
                      if (user.type == 'premium')
                        Icon(
                          FontAwesomeIcons.certificate,
                          size: 12,
                          color: AppColors.primary,
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