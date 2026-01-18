import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meet9ja/db_functions/user_service.dart';
import 'package:meet9ja/models/post_model.dart';
import 'package:meet9ja/models/user_model.dart';
import 'package:meet9ja/models/travel_history_model.dart';
import 'package:meet9ja/db_functions/image_service.dart';
import 'package:meet9ja/screens/dating_profile.dart';
import 'package:meet9ja/screens/subscription_screen.dart';
import 'package:meet9ja/screens/travel_partners_screen.dart';
import '../constants/app_colors.dart';
import 'MatchedUserScreen.dart';
import 'activity_screen.dart';
import 'explore_live_screen.dart';
import 'home_screen_filters.dart';
import 'home_screen.dart';
import 'messages_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final Set<String> liked = {};
  bool _travelAlertsOn = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Location and travel history
  List<TravelHistory> _travelHistory = [];
  bool _isLoadingTravelHistory = false;
  bool _isTrackingLocation = false;
  Position? _currentPosition;
  Placemark? _currentPlacemark;

  // Firebase streams
  late Stream<List<UserModel>> _recommendedUsersStream;
  late Stream<List<UserModel>> _popularUsersStream;
  late Stream<List<PostModel>> _trendingPostsStream;
  late Stream<List<UserModel>> _similarInterestsStream;
  late Stream<List<UserModel>> _sameGoalsStream;

  @override
  void initState() {
    super.initState();
    _loadFirebaseData();
    _searchController.addListener(_onSearchChanged);
    _checkLocationPermission();
    _loadTravelHistory();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  // Add this method to your _DiscoverScreenState class:
  Future<bool> _checkIfUserCanAccessTravelMode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    return await UserService.canAccessTravelMode(user.uid);
  }

  void _loadFirebaseData() {
    _recommendedUsersStream = UserService.getRecommendedUsers();
    _popularUsersStream = UserService.getPopularUsers();
    _trendingPostsStream = UserService.getTrendingPosts();
    _similarInterestsStream = UserService.getSimilarInterestsUsers();
    _sameGoalsStream = UserService.getSameGoalsUsers();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  Future<void> _checkLocationPermission() async {
    try {
      // First, check if service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationPermissionDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog();
        return;
      }

      // Get current location for display
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await _getCurrentLocationForDisplay();
      }

    } on MissingPluginException catch (e) {
      print('MissingPluginException: $e');

      // Check if we're in debug mode and show appropriate message
      bool isDebug = false;
      assert(() {
        isDebug = true;
        return true;
      }());

      if (isDebug) {
        // Debug mode - guide developer to fix
        _showToast('Geolocator plugin not found. Please run:\n'
            '1. flutter clean\n'
            '2. flutter pub get\n'
            '3. flutter run\n\n'
            'If error persists, try:\n'
            'cd ios && pod install && cd ..');
      } else {
        // Release mode - show user-friendly message
        _showToast('Location features are currently unavailable. Please restart the app.');
      }

      // Set location tracking to false to prevent UI from showing loading
      if (mounted) {
        setState(() {
          _isTrackingLocation = false;
        });
      }

    } catch (e) {
      print('Error checking location permission: $e');
      _showToast('Error accessing location: ${e.toString()}');

      if (mounted) {
        setState(() {
          _isTrackingLocation = false;
        });
      }
    }
  }
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Service Disabled'),
        content: Text('Please enable location services to use travel features.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  Future<void> _getCurrentLocationForDisplay() async {
    try {
      setState(() {
        _isTrackingLocation = true;
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        setState(() {
          _currentPosition = position;
          _currentPlacemark = placemarks.first;
        });
      }

    } catch (e) {
      print('Error getting current location: $e');
    } finally {
      setState(() {
        _isTrackingLocation = false;
      });
    }
  }

  // MANUAL METHOD: Add current location to travel history
  Future<void> _addCurrentLocationToTravelHistory() async {
    try {
      setState(() {
        _isTrackingLocation = true;
      });

      // Check permission again
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _showLocationPermissionDialog();
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final city = placemark.locality ?? placemark.subAdministrativeArea ?? 'Unknown City';
        final country = placemark.country ?? 'Unknown Country';

        // Show confirmation dialog
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Add Travel Location'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add this location to your travel history?'),
                SizedBox(height: 8),
                Text(
                  '$city, $country',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Add Location'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _saveTravelLocation(placemark, position);
        }
      }

    } catch (e) {
      print('Error adding current location: $e');
      _showToast('Failed to get location: $e');
    } finally {
      setState(() {
        _isTrackingLocation = false;
      });
    }
  }

  // MANUAL METHOD: Add custom location (user can type)
  Future<void> _addCustomLocation() async {
    final TextEditingController cityController = TextEditingController();
    final TextEditingController countryController = TextEditingController();

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Custom Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cityController,
              decoration: InputDecoration(
                labelText: 'City',
                hintText: 'e.g., Lagos, London, New York',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: countryController,
              decoration: InputDecoration(
                labelText: 'Country',
                hintText: 'e.g., Nigeria, United Kingdom, USA',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (cityController.text.trim().isNotEmpty &&
                  countryController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              } else {
                _showToast('Please enter both city and country');
              }
            },
            child: Text('Add Location'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _saveCustomLocation(
        cityController.text.trim(),
        countryController.text.trim(),
      );
    }
  }

  Future<void> _saveCustomLocation(String city, String country) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if location already exists
      final existingLocation = await FirebaseFirestore.instance
          .collection('travel_history')
          .where('userId', isEqualTo: user.uid)
          .where('city', isEqualTo: city)
          .where('country', isEqualTo: country)
          .limit(1)
          .get();

      if (existingLocation.docs.isNotEmpty) {
        _showToast('This location is already in your travel history');
        return;
      }

      // Ask for location picture
      final locationImageUrl = await _askForLocationPicture(city);

      // Save travel history
      final travelData = {
        'userId': user.uid,
        'city': city,
        'country': country,
        'countryCode': '',
        'latitude': 0.0,
        'longitude': 0.0,
        'address': '',
        'locationImageUrl': locationImageUrl ?? '',
        'visitedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('travel_history')
          .add(travelData);

      _showToast('✓ $city, $country added to travel history');

      // Reload travel history
      _loadTravelHistory();

    } catch (e) {
      print('Error saving custom location: $e');
      _showToast('Failed to save location: $e');
    }
  }

  Future<void> _saveTravelLocation(Placemark placemark, Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final city = placemark.locality ?? placemark.subAdministrativeArea ?? 'Unknown City';
      final country = placemark.country ?? 'Unknown Country';
      final countryCode = placemark.isoCountryCode ?? '';

      // Check if this location already exists
      final existingLocation = await FirebaseFirestore.instance
          .collection('travel_history')
          .where('userId', isEqualTo: user.uid)
          .where('city', isEqualTo: city)
          .where('country', isEqualTo: country)
          .limit(1)
          .get();

      if (existingLocation.docs.isNotEmpty) {
        _showToast('This location is already in your travel history');
        return;
      }

      // Ask user to add location picture
      final locationImageUrl = await _askForLocationPicture(city);

      // Save travel history
      final travelData = {
        'userId': user.uid,
        'city': city,
        'country': country,
        'countryCode': countryCode,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': placemark.street ?? '',
        'locationImageUrl': locationImageUrl ?? '',
        'visitedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('travel_history')
          .add(travelData);

      _showToast('✓ $city, $country added to travel history');

      // Update current placemark
      setState(() {
        _currentPlacemark = placemark;
      });

      // Reload travel history
      _loadTravelHistory();

    } catch (e) {
      print('Error saving travel location: $e');
      _showToast('Failed to save location: $e');
    }
  }

  Future<String?> _askForLocationPicture(String locationName) async {
    // Show dialog to ask for location picture
    bool? takePicture = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Location Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Would you like to add a picture of $locationName to your travel history?'),
            SizedBox(height: 8),
            Text(
              '(Optional)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Add Picture'),
          ),
        ],
      ),
    );

    if (takePicture == true) {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
        );

        if (pickedFile != null) {
          File imageFile = File(pickedFile.path);
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            final imageUrl = await ImageService.uploadTravelLocationImage(
              userId: userId,
              imageFile: imageFile,
              locationName: locationName,
            );
            return imageUrl;
          }
        }
      } catch (e) {
        print('Error picking location picture: $e');
        _showToast('Failed to upload picture');
      }
    }

    return null;
  }

  Future<void> _loadTravelHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() {
        _isLoadingTravelHistory = true;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('travel_history')
          .where('userId', isEqualTo: user.uid)
          .orderBy('visitedAt', descending: true)
          .limit(6)
          .get();

      final history = snapshot.docs.map((doc) {
        return TravelHistory.fromFirestore(doc);
      }).toList();

      setState(() {
        _travelHistory = history;
        _isLoadingTravelHistory = false;
      });

    } catch (e) {
      print('Error loading travel history: $e');
      setState(() {
        _isLoadingTravelHistory = false;
      });
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Access Required'),
        content: Text(
          'Meet9ja needs access to your location to add places to your travel history. '
              'Please enable location access in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _navigateToTravelPartners(TravelHistory travel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelPartnersScreen(
          city: travel.city,
          country: travel.country,
          travelHistoryId: travel.id,
        ),
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
              // Top bar (centered title + filter)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    const Expanded(
                      child: Text(
                        "Discover",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Feed
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  children: [
                    // Search Bar
                    _SearchBar(controller: _searchController),
                    const SizedBox(height: 18),

                    // Show search results if query exists, otherwise show normal content
                    if (_searchQuery.isNotEmpty)
                      _SearchResults(searchQuery: _searchQuery)
                    else
                      FutureBuilder<bool>(
                        future: _checkIfUserCanAccessTravelMode(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          final canAccessTravelMode = snapshot.data ?? false;

                          return _DiscoverContent(
                            travelAlertsOn: _travelAlertsOn,
                            onTravelAlertsChanged: (value) {
                              setState(() {
                                _travelAlertsOn = value;
                              });
                            },
                            liked: liked,
                            onLikeToggle: _toggleLike,
                            travelHistory: _travelHistory,
                            isLoadingTravelHistory: _isLoadingTravelHistory,
                            isTrackingLocation: _isTrackingLocation,
                            currentPlacemark: _currentPlacemark,
                            onTravelLocationTap: _navigateToTravelPartners,
                            onAddCurrentLocation: canAccessTravelMode
                                ? _addCurrentLocationToTravelHistory
                                : null,
                            onAddCustomLocation: canAccessTravelMode
                                ? _addCustomLocation
                                : null,
                            canAccessTravelMode: canAccessTravelMode,
                          );
                        },
                      ),
                  ],
                ),
              ),


              // Bottom nav — Discover selected
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: _BottomNav(current: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleLike(String id) {
    setState(() {
      if (liked.contains(id)) {
        liked.remove(id);
      } else {
        liked.add(id);
      }
    });
  }
}

// Discover Content with Travel History Section
class _DiscoverContent extends StatelessWidget {
  final bool travelAlertsOn;
  final ValueChanged<bool> onTravelAlertsChanged;
  final Set<String> liked;
  final void Function(String id) onLikeToggle;
  final List<TravelHistory> travelHistory;
  final bool isLoadingTravelHistory;
  final bool isTrackingLocation;
  final Placemark? currentPlacemark;
  final Function(TravelHistory) onTravelLocationTap;
  final VoidCallback? onAddCurrentLocation;  // Make nullable
  final VoidCallback? onAddCustomLocation;   // Make nullable
  final bool canAccessTravelMode;

  const _DiscoverContent({
    required this.travelAlertsOn,
    required this.onTravelAlertsChanged,
    required this.liked,
    required this.onLikeToggle,
    required this.travelHistory,
    required this.isLoadingTravelHistory,
    required this.isTrackingLocation,
    this.currentPlacemark,
    required this.onTravelLocationTap,
    this.onAddCurrentLocation,
    this.onAddCustomLocation,
    required this.canAccessTravelMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Location tracking status
        // In _DiscoverContent widget, update the location tracking section:
        if (isTrackingLocation)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Getting your location...',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

// Current location (if available)
        if (currentPlacemark != null && !isTrackingLocation && canAccessTravelMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are in ${currentPlacemark!.locality ?? 'Unknown'}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (currentPlacemark!.country != null)
                        Text(
                          currentPlacemark!.country!,
                          style: TextStyle(
                            color: Colors.green.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (canAccessTravelMode)
                  IconButton(
                    icon: Icon(Icons.add, size: 18, color: Colors.green),
                    onPressed: onAddCurrentLocation,
                    tooltip: 'Add to travel history',
                  ),
              ],
            ),
          ),
        // Trending Clips
        const _SectionHeader("Trending Clips 🎬"),
        const SizedBox(height: 10),
        _TrendingClipsStrip(),
        const SizedBox(height: 22),

        // Popular Profiles
        const _SectionHeader("Popular Profiles ⭐"),
        const SizedBox(height: 10),
        _PopularProfilesStrip(),
        const SizedBox(height: 24),

        // Travel History Section - Only show if user can access travel mode
        if (canAccessTravelMode)
          _TravelHistorySection(
            travelHistory: travelHistory,
            isLoading: isLoadingTravelHistory,
            onTravelLocationTap: onTravelLocationTap,
            travelAlertsOn: travelAlertsOn,
            onTravelAlertsChanged: onTravelAlertsChanged,
            onAddCurrentLocation: onAddCurrentLocation ?? () {},
            onAddCustomLocation: onAddCustomLocation ?? () {},
          )
        else
          _PremiumTravelModePromotion(),  // Show promotion for non-premium users

        const SizedBox(height: 22),

        // Timer pill + subtext
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 212, 45, 137),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              "See new people in 6 hours",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Connect over common ground with people who match your vibe, refreshed every day.",
          style: TextStyle(fontSize: 14.5, color: Colors.black87),
        ),
        const SizedBox(height: 18),

        // Recommended for you
        const _SectionHeader("Recommended for you"),
        const SizedBox(height: 10),
        _RecommendedStrip(liked: liked, onLikeToggle: onLikeToggle),
        const SizedBox(height: 24),

        // Similar interests section
        _SurfaceBlock(
          title: "Similar interests",
          child: _SimilarInterestsGrid(liked: liked, onLikeToggle: onLikeToggle),
        ),
        const SizedBox(height: 18),

        // Same dating goals section
        _SurfaceBlock(
          title: "Same dating goals",
          child: _SameGoalsGrid(liked: liked, onLikeToggle: onLikeToggle),
        ),
      ],
    );
  }
}

class _PremiumTravelModePromotion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FontAwesomeIcons.plane,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Travel Mode",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "PREMIUM",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Track your travels and connect with people in locations you've visited. Upgrade to Premium to unlock Travel Mode features:",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _FeatureItem(icon: Icons.location_on, text: "Add travel locations"),
              _FeatureItem(icon: Icons.people, text: "Find travel partners"),
              _FeatureItem(icon: Icons.travel_explore, text: "View travel history"),
              _FeatureItem(icon: Icons.notifications, text: "Travel alerts"),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {

              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SubscriptionPage()),
              );
            },
            icon: Icon(FontAwesomeIcons.crown),
            label: Text("Upgrade to Premium"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// Travel History Section
class _TravelHistorySection extends StatelessWidget {
  final List<TravelHistory> travelHistory;
  final bool isLoading;
  final Function(TravelHistory) onTravelLocationTap;
  final bool travelAlertsOn;
  final ValueChanged<bool> onTravelAlertsChanged;
  final VoidCallback onAddCurrentLocation;
  final VoidCallback onAddCustomLocation;

  const _TravelHistorySection({
    required this.travelHistory,
    required this.isLoading,
    required this.onTravelLocationTap,
    required this.travelAlertsOn,
    required this.onTravelAlertsChanged,
    required this.onAddCurrentLocation,
    required this.onAddCustomLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with alerts toggle
        Row(
          children: [
            const _SectionHeader("Your Travel History ✈️"),
            const Spacer(),
            Icon(
              travelAlertsOn
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              size: 18,
              color: travelAlertsOn ? AppColors.primary : Colors.black45,
            ),
            const SizedBox(width: 6),
            Switch.adaptive(
              value: travelAlertsOn,
              activeColor: AppColors.primary,
              onChanged: (v) {
                onTravelAlertsChanged(v);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      v
                          ? "Travel alerts enabled"
                          : "Travel alerts turned off.",
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(milliseconds: 1200),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Places you've visited recently",
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12),

        if (isLoading)
          SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else
          Column(
            children: [
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: travelHistory.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, index) {
                    final travel = travelHistory[index];
                    return _TravelLocationCard(
                      travel: travel,
                      onTap: () => onTravelLocationTap(travel),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.my_location, size: 18),
                    onPressed: onAddCurrentLocation,
                    tooltip: 'Add current location',
                  ),
                  IconButton(
                    icon: Icon(Icons.add_location_alt, size: 18),
                    onPressed: onAddCustomLocation,
                    tooltip: 'Add custom location',
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onAddCurrentLocation,
                    icon: Icon(Icons.add, size: 16),
                    label: Text('Add more locations'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
// ... [Rest of the widgets remain the same as before] ...
//

// Travel Location Card
class _TravelLocationCard extends StatelessWidget {
  final TravelHistory travel;
  final VoidCallback onTap;

  const _TravelLocationCard({
    required this.travel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Image
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                color: Colors.grey.shade200,
                image: travel.locationImageUrl.isNotEmpty
                    ? DecorationImage(
                  image: NetworkImage(travel.locationImageUrl),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: travel.locationImageUrl.isEmpty
                  ? Center(
                child: Icon(
                  FontAwesomeIcons.locationDot,
                  size: 40,
                  color: Colors.grey.shade400,
                ),
              )
                  : null,
            ),

            // Location Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    travel.city,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    travel.country,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(travel.visitedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays ~/ 7}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Rest of your existing widgets remain the same...
class _SearchResults extends StatelessWidget {
  final String searchQuery;

  const _SearchResults({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.searchUsers(searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return const Column(
            children: [
              Icon(FontAwesomeIcons.search, size: 60, color: Colors.black26),
              SizedBox(height: 16),
              Text(
                'No users found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Results (${users.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserCard(user: user);
              },
            ),
          ],
        );
      },
    );
  }
}

// User Card Widget
class _UserCard extends StatelessWidget {
  final UserModel user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = UserService.getProfilePhotoUrl(user);
    final tags = user.interests?.take(2).toList() ?? [];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // User Image
          Positioned.fill(
            child: Image.network(
              profilePhotoUrl ?? "https://i.pravatar.cc/300",
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(FontAwesomeIcons.user, color: Colors.black38),
              ),
            ),
          ),
          // Bottom overlay
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 48, 10, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black54,
                    Colors.black87,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tags.isNotEmpty) _darkPill(tags.first),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${user.name.split(' ').first}, ${user.age}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (user.type == 'premium')
                        const Icon(
                          FontAwesomeIcons.certificate,
                          size: 14,
                          color: Colors.white,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(FontAwesomeIcons.magnifyingGlass, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "Search by name, tags, or location...",
                hintStyle: TextStyle(color: Colors.black54),
                border: InputBorder.none,
              ),
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(FontAwesomeIcons.times, size: 16),
              onPressed: () => controller.clear(),
            ),
        ],
      ),
    );
  }
}

// ... (Rest of your existing widgets remain exactly as they were)
// Keep all the other widget classes (_TrendingClipsStrip, _PopularProfilesStrip, etc.)
// They remain unchanged from your original code

class _TrendingClipsStrip extends StatelessWidget {
  const _TrendingClipsStrip();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PostModel>>(
      stream: UserService.getTrendingPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox(
            height: 180,
            child: Center(child: Text('Error loading trending clips')),
          );
        }

        final posts = snapshot.data!;

        if (posts.isEmpty) {
          return SizedBox(
            height: 180,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.video, size: 40, color: Colors.black26),
                  const SizedBox(height: 8),
                  Text(
                    'No trending clips',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final post = posts[i];
              return _TrendingClipCard(post: post, index: i);
            },
          ),
        );
      },
    );
  }
}

class _TrendingClipCard extends StatelessWidget {
  final PostModel post;
  final int index;

  const _TrendingClipCard({required this.post, required this.index});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Clip Thumbnail
          Container(
            width: 120,
            height: 180,
            color: Colors.grey.shade200,
            child: Image.network(
              post.mediaUrl,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.35),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(FontAwesomeIcons.video, color: Colors.black38),
              ),
            ),
          ),
          // Play Icon
          const Positioned.fill(
            child: Center(
              child: Icon(
                FontAwesomeIcons.solidCirclePlay,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          // Trending Text
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "#${index + 1} Trending",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularProfilesStrip extends StatelessWidget {
  const _PopularProfilesStrip();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.getPopularUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) => const _UserCircleSkeleton(),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return SizedBox(
            height: 120,
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final users = snapshot.data!;

        if (users.isEmpty) {
          return SizedBox(
            height: 120,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.users, size: 40, color: Colors.black26),
                  const SizedBox(height: 8),
                  Text(
                    'No popular profiles',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final user = users[i];
              return _UserCircle(user: user);
            },
          ),
        );
      },
    );
  }
}

class _UserCircle extends StatelessWidget {
  final UserModel user;

  const _UserCircle({required this.user});

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = UserService.getProfilePhotoUrl(user);

    return Column(
      children: [
        // Circular Profile Image
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
            image: DecorationImage(
              image: profilePhotoUrl != null
                  ? NetworkImage(profilePhotoUrl)
                  : const NetworkImage("https://i.pravatar.cc/300") as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Name
        Text(
          user.name.split(' ').first, // Show only first name
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _UserCircleSkeleton extends StatelessWidget {
  const _UserCircleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 12,
          color: Colors.grey.shade300,
        ),
      ],
    );
  }
}

class _RecommendedStrip extends StatelessWidget {
  final Set<String> liked;
  final void Function(String id) onLikeToggle;

  const _RecommendedStrip({
    required this.liked,
    required this.onLikeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.getRecommendedUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          final w = MediaQuery.of(context).size.width;
          final cardW = w * 0.78;
          final cardH = cardW * 1.2;

          return SizedBox(
            height: cardH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => Container(
                width: cardW,
                height: cardH,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return SizedBox(
            height: 200,
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final users = snapshot.data!;

        if (users.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.users, size: 60, color: Colors.black26),
                  const SizedBox(height: 16),
                  Text(
                    "No recommendations yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final w = MediaQuery.of(context).size.width;
        final cardW = w * 0.78;
        final cardH = cardW * 1.2;

        return SizedBox(
          height: cardH,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _BigCard(
              user: users[i],
              width: cardW,
              height: cardH,
              liked: liked.contains(users[i].uid),
              onLike: () => onLikeToggle(users[i].uid),
            ),
          ),
        );
      },
    );
  }
}

class _SimilarInterestsGrid extends StatelessWidget {
  final Set<String> liked;
  final void Function(String id) onLikeToggle;

  const _SimilarInterestsGrid({
    required this.liked,
    required this.onLikeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.getSimilarInterestsUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _GridSkeleton();
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data!;

        if (users.isEmpty) {
          return const Center(
            child: Text('No users with similar interests'),
          );
        }

        return GridView.builder(
          itemCount: users.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (_, i) {
            final user = users[i];
            return _GridUserCard(
              user: user,
              liked: liked.contains(user.uid),
              onLikeToggle: () => onLikeToggle(user.uid),
            );
          },
        );
      },
    );
  }
}

class _SameGoalsGrid extends StatelessWidget {
  final Set<String> liked;
  final void Function(String id) onLikeToggle;

  const _SameGoalsGrid({
    required this.liked,
    required this.onLikeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.getSameGoalsUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _GridSkeleton();
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data!;

        if (users.isEmpty) {
          return const Center(
            child: Text('No users with same goals'),
          );
        }

        return GridView.builder(
          itemCount: users.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (_, i) {
            final user = users[i];
            return _GridUserCard(
              user: user,
              liked: liked.contains(user.uid),
              onLikeToggle: () => onLikeToggle(user.uid),
              showGoal: true,
            );
          },
        );
      },
    );
  }
}

class _GridUserCard extends StatelessWidget {
  final UserModel user;
  final bool liked;
  final VoidCallback? onLikeToggle;
  final bool showGoal;

  const _GridUserCard({
    required this.user,
    this.liked = false,
    this.onLikeToggle,
    this.showGoal = false,
  });

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = UserService.getProfilePhotoUrl(user);
    final tags = user.interests?.take(2).toList() ?? [];
    final goal = user.preferences.isNotEmpty ? user.preferences : 'Not specified';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // User Image
          Positioned.fill(
            child: Image.network(
              profilePhotoUrl ?? "https://i.pravatar.cc/300",
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(FontAwesomeIcons.user, color: Colors.black38),
              ),
            ),
          ),
          // Bottom overlay
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 48, 10, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black54,
                    Colors.black87,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showGoal && goal.isNotEmpty) _darkPill(goal),
                  if (tags.isNotEmpty && !showGoal) _darkPill(tags.first),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${user.name.split(' ').first}, ${user.age}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (user.type == 'premium')
                        const Icon(
                          FontAwesomeIcons.certificate,
                          size: 14,
                          color: Colors.white,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Like button
          if (onLikeToggle != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: _circleBtn(
                icon: liked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                color: liked ? AppColors.primary : Colors.white,
                onTap: onLikeToggle!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _darkPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final UserModel user;
  final double width;
  final double height;
  final bool liked;
  final VoidCallback onLike;

  const _BigCard({
    required this.user,
    required this.width,
    required this.height,
    required this.liked,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = UserService.getProfilePhotoUrl(user);
    final tags = user.interests?.take(2).toList() ?? [];
    final age = user.age;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.grey.shade200,
        image: DecorationImage(
          image: NetworkImage(profilePhotoUrl ?? "https://i.pravatar.cc/400"),
          fit: BoxFit.cover,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Stack(
        children: [
          // bottom info
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                "${user.name.split(' ').first}, $age",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (user.type == 'premium') ...[
                              const SizedBox(width: 6),
                              const Icon(
                                FontAwesomeIcons.certificate,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (tags.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tags.map((t) => _blackChip(t)).toList(),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onLike,
                    icon: Icon(
                      liked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                      color: liked ? AppColors.primary : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blackChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _SurfaceBlock extends StatelessWidget {
  const _SurfaceBlock({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, this.onTap});
  final int current;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final icons = const [
      FontAwesomeIcons.user,
      FontAwesomeIcons.compass,
      FontAwesomeIcons.userGroup,
      FontAwesomeIcons.heart,
      FontAwesomeIcons.solidCommentDots,
    ];
    final labels = const [
      "Profile",
      "Discover",
      "People",
      "Liked You",
      "Chats",
    ];

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: Row(
        children: List.generate(icons.length, (i) {
          final selected = i == current;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (onTap != null) {
                  onTap!(i);
                  return;
                }

                // Handle navigation based on tab index
                switch (i) {
                  case 0: // Profile
                    if (current != 0) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DatingProfileScreen()),
                      );
                    }
                    break;
                  case 1: // Discover (current screen)
                  // Already on Discover screen, do nothing
                    break;
                  case 2: // People (HomeScreen)
                    if (current != 2) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                    break;
                  case 3: // Live (ExploreLiveScreen)
                    if (current != 3) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ActivityScreen()),
                      );
                    }
                    break;
                  case 4: // Chats
                    if (current != 4) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MessagesScreen()),
                      );
                    }
                    break;
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[i],
                      size: selected ? 24 : 22,
                      color: selected ? AppColors.primary : Colors.black54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: TextStyle(
                        height: 1.0,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? AppColors.primary : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}