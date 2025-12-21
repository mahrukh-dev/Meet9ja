import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meet9ja/constants/app_colors.dart';
import 'package:meet9ja/models/user_model.dart';
import '../db_functions/user_service.dart';

class OtherDatingProfileScreen extends StatefulWidget {
  final String userId;
  final String conversationId;

  const OtherDatingProfileScreen({
    super.key,
    required this.userId,
    required this.conversationId,
  });

  @override
  State<OtherDatingProfileScreen> createState() => _OtherDatingProfileScreenState();
}

class _OtherDatingProfileScreenState extends State<OtherDatingProfileScreen> {
  int _tab = 0;
  UserModel? _user;
  Map<String, int> _userStats = {'followers': 0, 'following': 0, 'subscribers': 0};
  bool _isLoading = true;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkIfLiked();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await UserService.getUserProfile(widget.userId);
      final stats = await UserService.getUserStats(widget.userId);

      setState(() {
        _user = user;
        _userStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIfLiked() async {
    try {
      final currentUserId = UserService.currentUserId;
      if (currentUserId == null) return;

      final isLiked = await UserService.checkIfLiked(currentUserId, widget.userId);
      setState(() {
        _isLiked = isLiked;
      });
    } catch (e) {
      print('Error checking like status: $e');
    }
  }

  // Like profile function
  Future<void> _likeProfile() async {
    try {
      if (_user == null) return;

      final currentUserId = UserService.currentUserId;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You need to be logged in to like profiles"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final String targetUserId = widget.userId;
      final String name = _user!.name ?? 'User';
      print('❤ Liking profile: $targetUserId');

      // Call UserService.likeProfile
      await UserService.likeProfile(currentUserId, targetUserId);

      setState(() {
        _isLiked = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You liked $name"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error in _likeProfile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error liking profile: $e"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Unlike profile function
  Future<void> _unlikeProfile() async {
    try {
      if (_user == null) return;

      final currentUserId = UserService.currentUserId;
      if (currentUserId == null) return;

      final String targetUserId = widget.userId;
      final String name = _user!.name ?? 'User';
      print('💔 Unliking profile: $targetUserId');

      // Call UserService.unlikeProfile
      await UserService.unlikeProfile(currentUserId, targetUserId);

      setState(() {
        _isLiked = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You unliked $name"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('❌ Error in _unlikeProfile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error unliking profile: $e"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Toggle like functionality
  Future<void> _toggleLike() async {
    if (_isLiked) {
      await _unlikeProfile();
    } else {
      await _likeProfile();
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.more_horiz, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'More Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.report, color: Colors.red),
                  ),
                  title: const Text('Report User'),
                  subtitle: const Text('Report inappropriate behavior'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog();
                  },
                ),

                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.block, color: Colors.orange),
                  ),
                  title: const Text('Block User'),
                  subtitle: const Text('Block this user from contacting you'),
                  onTap: () {
                    Navigator.pop(context);
                    _showBlockDialog();
                  },
                ),

                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: const Text('Please select the reason for reporting this user.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final currentUserId = UserService.currentUserId;
                if (currentUserId != null) {
                  await UserService.submitProfileReport(
                    reporterId: currentUserId,
                    reportedUserId: widget.userId,
                    reason: 'Inappropriate behavior',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User reported successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error reporting user: $e')),
                );
              }
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text('Are you sure you want to block this user? You will no longer be able to see each other.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User blocked successfully')),
              );
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        "Profile",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: _showMoreOptions,
                    ),
                  ],
                ),
              ),

              // Scroll body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  children: [
                    _Header(
                      user: _user,
                      isLiked: _isLiked,
                      onLikeTap: _toggleLike,
                    ),
                    const SizedBox(height: 12),
                    _Segments(
                      current: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: 12),

                    if (_tab == 0)
                      _AboutTab(user: _user)
                    else if (_tab == 1)
                      _InterestsTab(user: _user)
                    else
                      _PhotosTab(user: _user),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- HEADER --------------------
class _Header extends StatelessWidget {
  const _Header({
    this.user,
    required this.isLiked,
    required this.onLikeTap,
  });

  final UserModel? user;
  final bool isLiked;
  final VoidCallback onLikeTap;

  @override
  Widget build(BuildContext context) {
    final age = user?.age ?? 0;
    final profilePhotoUrl = user != null ? UserService.getProfilePhotoUrl(user!) : null;

    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
                  ? NetworkImage(profilePhotoUrl)
                  : const NetworkImage("https://i.pravatar.cc/120?img=8") as ImageProvider,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${user?.name ?? 'User'}, $age",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (user?.bio != null && user!.bio!.isNotEmpty)
                    Text(
                      user!.bio!,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onLikeTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLiked ? AppColors.primary : Colors.white,
              foregroundColor: isLiked ? Colors.white : AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primary),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
            label: Text(isLiked ? 'Liked' : 'Like'),
          ),
        ),
      ],
    );
  }
}

// -------------------- SEGMENTS --------------------
class _Segments extends StatelessWidget {
  const _Segments({required this.current, required this.onChanged});
  final int current;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    List<String> items = ["About", "Interests", "Photos"];
    return Row(
      children: List.generate(items.length, (i) {
        final selected = i == current;
        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              alignment: Alignment.center,
              child: Text(
                items[i],
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// -------------------- TAB: ABOUT --------------------
class _AboutTab extends StatelessWidget {
  const _AboutTab({this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.location_on_outlined,
          title: "Location",
          value: user?.location ?? 'Not specified',
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.favorite_outline,
          title: "Relationship Goals",
          value: user?.preferences ?? 'Not specified',
        ),
        const SizedBox(height: 18),
        if (user?.bio != null && user!.bio!.isNotEmpty) ...[
          const Text(
            "About Me",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user!.bio!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// -------------------- TAB: INTERESTS --------------------
class _InterestsTab extends StatelessWidget {
  const _InterestsTab({this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final interests = _extractInterests(user);

    if (interests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tag_faces, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No interests added yet',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: interests.map((interest) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Text(
            interest,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  List<String> _extractInterests(UserModel? user) {
    if (user == null) return [];

    if (user.interests != null && user.interests!.isNotEmpty) {
      if (user.interests is List<String>) {
        return user.interests as List<String>;
      } else if (user.interests is String) {
        return (user.interests as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    return [];
  }
}

// -------------------- TAB: PHOTOS --------------------
class _PhotosTab extends StatelessWidget {
  const _PhotosTab({this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final photos = _getUserPhotos(user);

    if (photos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No photos available',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            _showImageFullScreen(context, photos[index]);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              photos[index],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.error, color: Colors.grey),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<String> _getUserPhotos(UserModel? user) {
    final photos = <String>[];

    if (user != null) {
      // Add profile photo
      final profilePhotoUrl = UserService.getProfilePhotoUrl(user);
      if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
        photos.add(profilePhotoUrl);
      }

      // Add additional photos from user model if available
      if (user.firstPhotos != null) {
        if (user.firstPhotos is List<String>) {
          photos.addAll(user.firstPhotos as List<String>);
        }
      }
    }

    // Add placeholder photos for demonstration if no photos available
    if (photos.isEmpty) {
      photos.addAll([
        "https://i.pravatar.cc/400?img=8",
        "https://i.pravatar.cc/400?img=15",
        "https://i.pravatar.cc/400?img=22",
      ]);
    }

    return photos;
  }

  void _showImageFullScreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 300,
                    height: 300,
                    color: Colors.grey[300],
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.grey, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- INFO CARD --------------------
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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