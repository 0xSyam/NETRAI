import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'family_account_wrapper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_update_service.dart';
import 'package:intl/intl.dart';
import 'account_screen_keluarga.dart'; // tetap impor untuk tipe

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  Completer<GoogleMapController> _controller = Completer();
  static const LatLng _center =
      LatLng(-6.200000, 106.816666); // Default Jakarta
  LatLng? _currentPosition;
  LatLng? _tunaNetraPosition; // Addition: visually impaired user position
  final Set<Marker> _markers = {};
  MapType _currentMapType = MapType.normal; // Add state for map type
  Timer? _tunaNetraLocationTimer; // Timer for auto-refresh
  Timer? _userLocationTimer; // Timer for updating user location
  StreamSubscription<DocumentSnapshot>?
      _tunaNetraLocationStream; // Stream for real-time location changes
  bool _autoFocusToTunaNetra = true; // Flag to control auto-focus
  bool _isInitialLoad = true; // Flag to detect initial load

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _setupUserLocationAutoUpdate(); // Update user position periodically
    _setupTunaNetraLocationStream(); // Switch to method that uses stream
  }

  // New method for periodically updating user position
  void _setupUserLocationAutoUpdate() {
    // Update user position every 30 seconds
    _userLocationTimer?.cancel();
    _userLocationTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _updateUserLocation();
    });
  }

  // Method to update user location without displaying error messages
  Future<void> _updateUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _addMarkers(); // Update markers
      });
    } catch (e) {
      // Handle error silently (no need to display message to user)
      print('Error updating user location: $e');
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services not enabled, don't proceed
      // or ask user to enable location services
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Location services are disabled. Please enable services')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location permissions permanently denied, we cannot request permissions.')));
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _addMarkers(); // Call again to update markers with current location

      // Only focus on user location if there's no visually impaired user location
      // We prioritize focusing on visually impaired user location
      if (_tunaNetraPosition == null) {
        _goToCurrentLocation(); // Move camera to current location
      }
    });
  }

  void _addMarkers() {
    _markers.clear(); // Clear old markers before adding new ones

    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _currentPosition!,
          infoWindow: const InfoWindow(title: 'You'), // Change label to "You"
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    // Add visually impaired user marker if available
    if (_tunaNetraPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('tunaNetraLocation'),
          position: _tunaNetraPosition!,
          infoWindow: const InfoWindow(
              title:
                  'Your Family Member'), // Change label to "Your Family Member"
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentPosition == null) return;
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: _currentPosition!,
        zoom: 14.0,
      ),
    ));
  }

  // New method to focus on visually impaired user location
  Future<void> _goToTunaNetraLocation() async {
    if (_tunaNetraPosition == null) return;
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: _tunaNetraPosition!,
        zoom: 16.0, // Slightly more zoomed to see details
      ),
    ));
  }

  // Replace _goToLovedOneLocation function with _toggleMapType
  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  // Toggle auto-focus to visually impaired user location
  void _toggleAutoFocus() {
    setState(() {
      _autoFocusToTunaNetra = !_autoFocusToTunaNetra;
    });

    // Show status message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_autoFocusToTunaNetra
            ? 'Auto-focus to visually impaired user location: ON'
            : 'Auto-focus to visually impaired user location: OFF'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // New method to set up stream that monitors visually impaired user location changes in real-time
  Future<void> _setupTunaNetraLocationStream() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Check if user is a family member and connected to visually impaired user
      if (!userDoc.exists ||
          !userDoc.data()!.containsKey('role') ||
          userDoc['role'] != 'keluarga') {
        return;
      }

      final linkedTo = userDoc['linkedTo'];
      if (linkedTo == null || linkedTo.toString().isEmpty) {
        return;
      }

      // Cancel existing stream if any
      _tunaNetraLocationStream?.cancel();

      // Register stream to listen for visually impaired user location changes
      _tunaNetraLocationStream = FirebaseFirestore.instance
          .collection('users')
          .doc(linkedTo)
          .snapshots()
          .listen((documentSnapshot) {
        if (documentSnapshot.exists) {
          final data = documentSnapshot.data();
          if (data != null && data.containsKey('lastLocation')) {
            final lastLocation = data['lastLocation'];
            if (lastLocation != null &&
                lastLocation['lat'] != null &&
                lastLocation['lng'] != null) {
              // Save last position for comparison if position changes
              final lastPosition = _tunaNetraPosition;
              final newPosition = LatLng(
                lastLocation['lat'],
                lastLocation['lng'],
              );

              setState(() {
                _tunaNetraPosition = newPosition;
                _addMarkers(); // Update markers
              });

              // Focus on visually impaired user location in 2 cases:
              // 1. If this is initial load
              // 2. If auto-focus active and position changes
              if (_isInitialLoad ||
                  (_autoFocusToTunaNetra &&
                      (lastPosition == null ||
                          lastPosition.latitude != newPosition.latitude ||
                          lastPosition.longitude != newPosition.longitude))) {
                _goToTunaNetraLocation();

                // After first focus, mark initial load as done
                if (_isInitialLoad) {
                  _isInitialLoad = false;
                }
              }
            }
          }
        }
      }, onError: (error) {
        print('Error in visually impaired user location stream: $error');
      });

      // Keep using timer as fallback, but reduce frequency
      _tunaNetraLocationTimer?.cancel();
      _tunaNetraLocationTimer = Timer.periodic(Duration(minutes: 2), (timer) {
        // Only as fallback if stream fails
        getTunaNetraLocation();
      });

      // Get initial location
      getTunaNetraLocation();
    } catch (e) {
      print('Error setting up visually impaired user location stream: $e');
    }
  }

  // Get visually impaired user location connected (specific to family role)
  Future<void> getTunaNetraLocation() async {
    final keluargaUid = FirebaseAuth.instance.currentUser?.uid;
    if (keluargaUid == null) return;

    final keluargaDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(keluargaUid)
        .get();

    final linkedTo = keluargaDoc['linkedTo'];
    if (linkedTo == null) return;

    final tunaNetraDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(linkedTo)
        .get();

    final lastLocation = tunaNetraDoc['lastLocation'];
    if (lastLocation != null &&
        lastLocation['lat'] != null &&
        lastLocation['lng'] != null) {
      setState(() {
        _tunaNetraPosition = LatLng(
          lastLocation['lat'],
          lastLocation['lng'],
        );
        _addMarkers();
      });

      // Focus on visually impaired user location if auto-focus is active
      // or if this is first time loading
      if (_autoFocusToTunaNetra || _isInitialLoad) {
        _goToTunaNetraLocation();

        // After first focus, mark initial load as done
        if (_isInitialLoad) {
          _isInitialLoad = false;
        }
      }
    }
  }

  // Auto-refresh visually impaired user location every 30 seconds (only if family role)
  // This method is no longer used, replaced by _setupTunaNetraLocationStream
  void _startTunaNetraLocationAutoRefresh() async {
    final keluargaUid = FirebaseAuth.instance.currentUser?.uid;
    if (keluargaUid == null) return;
    final keluargaDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(keluargaUid)
        .get();
    final role = keluargaDoc['role'];
    if (role == 'keluarga') {
      // Start auto-refresh timer
      _tunaNetraLocationTimer?.cancel();
      _tunaNetraLocationTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        getTunaNetraLocation();
      });
      // Get first time
      getTunaNetraLocation();
    }
  }

  @override
  void dispose() {
    _tunaNetraLocationTimer?.cancel();
    _userLocationTimer?.cancel(); // Cancel user location update timer
    _tunaNetraLocationStream?.cancel(); // Cancel stream when widget is disposed
    super.dispose();
  }

  // Add function to open Google Maps with navigation directions
  Future<void> _openGoogleMapsDirections(
      LatLng origin, LatLng destination) async {
    try {
      final String url =
          'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&travelmode=driving';
      final Uri uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // If cannot open Google Maps app, try opening in browser
        final String webUrl =
            'https://www.google.com/maps/dir/${origin.latitude},${origin.longitude}/${destination.latitude},${destination.longitude}';
        final Uri webUri = Uri.parse(webUrl);

        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Cannot open Google Maps or browser.';
        }
      }
    } catch (e) {
      rethrow; // Re-throw error for processing in calling function
    }
  }

  // New function to get direction to visually impaired user using service
  Future<void> _getDirectionToTunaNetra() async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Getting direction to visually impaired user...')),
      );

      // Check if there's a user logged in
      if (FirebaseAuth.instance.currentUser == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first')),
        );
        return;
      }

      // Check and get user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('User data not found, please logout and log in again')),
        );
        return;
      }

      final userData = userDoc.data();
      if (userData == null ||
          userData['linkedTo'] == null ||
          userData['linkedTo'].toString().isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You are not connected to visually impaired user')),
        );
        return;
      }

      // Use LocationUpdateService to get URL and timestamp information
      final Map<String, dynamic> result =
          await LocationUpdateService.getGoogleMapsDirectionUrl(
              _currentPosition);

      // Get URL from result
      final String url = result['url'];
      final Uri uri = Uri.parse(url);

      // Get last update timestamp
      final lastUpdateTime = result['lastUpdateTime'];
      final email = result['email'] ?? 'visually impaired user';

      // Format timestamp to readable string
      final formattedTime =
          LocationUpdateService.formatTimestamp(lastUpdateTime);

      // Close loading SnackBar if still open
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show confirmation dialog with last update timestamp information
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Visually Impaired User Location Information'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: $email'),
                const SizedBox(height: 8),
                Text('Last updated: $formattedTime'),
                const SizedBox(height: 16),
                Text(
                  'Please ensure location is sufficiently accurate before navigating.',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A59D1),
                ),
                child: Text('Open Google Maps',
                    style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      // If confirmed, open Google Maps
      if (confirm == true) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Cannot open Google Maps';
        }
      }
    } catch (e) {
      // Close loading SnackBar if still open
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Check error type for giving appropriate message
      String errorMessage = 'Failed to get direction: ';

      if (e.toString().contains('linkedTo')) {
        errorMessage = 'You are not connected to visually impaired user';
      } else if (e.toString().contains('lastLocation')) {
        errorMessage = 'Visually impaired user location not available';
      } else if (e
          .toString()
          .contains('Visually impaired user location not available')) {
        errorMessage = 'Visually impaired user location not available';
      } else {
        errorMessage += e.toString();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for adjustment
    // final screenHeight = MediaQuery.of(context).size.height;
    // final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      // Don't use default AppBar, we create custom header
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Layer 1: Google Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? _center,
              zoom: 11.0,
            ),
            markers: _markers,
            mapType: _currentMapType, // Use state map type
            myLocationEnabled: true, // Show my location button & blue dot
            myLocationButtonEnabled: false, // We will use custom FAB
            zoomControlsEnabled: false, // Disable default zoom buttons
          ),

          // Layer 2: Custom Header
          // Node: 268:1743 (Header Group)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 56.0 + topPadding, // kToolbarHeight + statusBarHeight
              padding: EdgeInsets.only(
                top: topPadding,
                left: 16.0,
                right: 16.0,
              ),
              // Background color from Figma (Rectangle 25 or Rectangle 13)
              // Rectangle 13 (268:1745) has fill #3A59D1
              color: const Color(0xFF3A59D1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Node: 268:1747 (Teks "View")
                  const Text(
                    'View Location', // Change title
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Node: 268:1748 (Ikon "Question_light")
                      IconButton(
                        icon: const Icon(
                          Icons.help_outline, // Use standard icon
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          // Action for help button
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // Avatar (Placeholder, take from design if more detail)
                      // Referring to Rectangle 15 (268:1746) which is circular
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const FamilyAccountWrapper(),
                            ),
                          );
                        },
                        child: StreamBuilder<User?>(
                          stream: FirebaseAuth.instance.authStateChanges(),
                          builder: (context, snapshot) {
                            final user = snapshot.data ??
                                FirebaseAuth.instance.currentUser;
                            final hasProfilePic = user != null &&
                                user.photoURL != null &&
                                user.photoURL!.isNotEmpty;

                            return CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              backgroundImage: hasProfilePic
                                  ? NetworkImage(user!.photoURL!)
                                  : null,
                              child: hasProfilePic
                                  ? null
                                  : const Icon(Icons.person,
                                      size: 18, color: Color(0xFF3A59D1)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Layer 4: FABs (Floating Action Buttons)
          // Node: 268:1783 (Group 38 - Top Right Button) -> arrow icon
          // Node: 316:625 (Group 39 - Fill Pin Button) -> pin fill icon
          // Node: 316:630 (Group 40 - Light Pin Button) -> pin light icon
          Positioned(
            bottom: 90, // Align with middle button
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top FAB (referring to Arrow_alt_ltop in Group 38 / 268:1785)
                // Change icon to be more suitable with image (my_location / gps_fixed)
                FloatingActionButton(
                  heroTag: 'fab_my_location',
                  mini: true,
                  onPressed: _goToCurrentLocation, // Move to user location
                  backgroundColor: Colors.white, // Changed from blue to white
                  child: const Icon(Icons.my_location,
                      color: Color(0xFF3A59D1)), // Changed from white to blue
                ),
                const SizedBox(height: 16),
                // Button to focus on visually impaired user location
                FloatingActionButton(
                  heroTag: 'fab_tuna_netra_location',
                  mini: true,
                  onPressed:
                      _goToTunaNetraLocation, // Move to visually impaired user location
                  backgroundColor: Colors.white, // Changed from blue to white
                  child: const Icon(Icons.person_pin_circle,
                      color: Color(0xFF3A59D1)), // Changed from white to blue
                ),
                const SizedBox(height: 16),
                // Middle FAB (referring to Pin_fill in Group 39 / 316:657)
                // Change icon and function for toggle map type
                FloatingActionButton(
                  heroTag: 'fab_toggle_map_type', // Different tag
                  mini: true,
                  onPressed: _toggleMapType, // Change map type
                  backgroundColor: Colors.white, // Changed from blue to white
                  child: Icon(
                      _currentMapType == MapType.normal
                          ? Icons.satellite // Icon for satellite mode
                          : Icons.map, // Icon for normal/street mode
                      color: const Color(
                          0xFF3A59D1)), // Changed from white to blue
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ElevatedButton.icon(
        icon: const Icon(Icons.directions,
            color: Colors.white), // Diubah dari biru ke putih
        label: const Text(
          'Get Direction',
          style: TextStyle(
            color: Colors.white, // Diubah dari biru ke putih
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onPressed: () async {
          // Use new function that utilizes LocationUpdateService
          _getDirectionToTunaNetra();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3A59D1), // Diubah dari putih ke biru
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: 5,
        ),
      ),
    );
  }

  // Widget for location marker (Your Loved One)
  // Node: 334:2027
  Widget _buildLocationMarker() {
    // Size based on Figma
    // point (circle inside): diameter around 10-12px (stroke 4px)
    // blur (circle outside): diameter around 30-35px
    // Vector 2 (pin shape): size around 50x70px
    return SizedBox(
      width: 70, // Approximate total width
      height: 90, // Approximate total height
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Bottom pin part (Vector 2 / I334:2027;1:712) - Gradient
          Positioned(
            bottom: 20, // Adjust to make pin end pass through center of circle
            child: Container(
              width: 50, // Pin base width
              height: 50, // Pin base height (before narrowing)
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3A59D1)
                        .withOpacity(0.0), // More transparent above
                    const Color(0xFF3A59D1)
                        .withOpacity(0.3), // Slightly more dense below
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                // Make shape more like pin end
                borderRadius: const BorderRadius.all(
                    Radius.circular(25)), // Full circle if width=height
                // If want more like inverted water drop, need CustomPaint or SVG image
              ),
            ),
          ),
          // Outer circle (blur / I334:2027;1:713)
          Positioned(
            bottom: 10, // Adjust position to make pin appear above
            child: Container(
              width: 36, // Diameter
              height: 36, // Diameter
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3A59D1).withOpacity(0.1), // fill_VCQS1G
                border: Border.all(
                  color: const Color(0xFF8B9DE4), // stroke_KIJ3F6
                  width: 0.5, // Slightly thicker than 0.3
                ),
              ),
            ),
          ),
          // Inner circle (point / I334:2027;1:714) - Adjusted to image
          Positioned(
            // Center in circle blur, bottom: 10 (blur_bottom_pos) + (blur_diameter - point_diameter)/2
            bottom: 10 + (36 - 16) / 2,
            child: Container(
              width: 16, // Diameter
              height: 16, // Diameter
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white, // ISI PUTIH (according to image)
                border: Border.all(
                  color: const Color(
                      0xFF3A59D1), // BIRU BORDER (according to image)
                  width:
                      3, // Border width adjusted to look like image (previously 4)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
