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
  static const LatLng _center = LatLng(-6.200000, 106.816666); // Default to Jakarta
  LatLng? _currentPosition;
  LatLng? _tunaNetraPosition; // Visually impaired user's position
  final Set<Marker> _markers = {};
  MapType _currentMapType = MapType.normal;
  Timer? _tunaNetraLocationTimer; // Timer for auto-refreshing visually impaired user's location
  Timer? _userLocationTimer; // Timer for updating this user's location
  StreamSubscription<DocumentSnapshot>? _tunaNetraLocationStream; // Stream for real-time location updates
  bool _autoFocusToTunaNetra = true; // Flag to control auto-focus on visually impaired user
  bool _isInitialLoad = true; // Flag to detect initial map load

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _setupUserLocationAutoUpdate();
    _setupTunaNetraLocationStream();
  }

  void _setupUserLocationAutoUpdate() {
    // Update this user's position every 30 seconds
    _userLocationTimer?.cancel();
    _userLocationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateUserLocation();
    });
  }

  Future<void> _updateUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _addMarkers();
        });
      }
    } catch (e, st) {
      // Handle error silently for background updates
      print('Error updating user location: $e\nStack: $st');
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled. Please enable them.')));
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permissions are permanently denied; we cannot request permissions.')));
      }
      return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _addMarkers();
        if (_tunaNetraPosition == null) { // Prioritize visually impaired user if their location is known
          _goToCurrentLocation();
        }
      });
    }
  }

  void _addMarkers() {
    _markers.clear();

    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _currentPosition!,
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    if (_tunaNetraPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('tunaNetraLocation'),
          position: _tunaNetraPosition!,
          infoWindow: const InfoWindow(title: 'Your Family Member'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentPosition == null) return;
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _currentPosition!, zoom: 14.0),
    ));
  }

  Future<void> _goToTunaNetraLocation() async {
    if (_tunaNetraPosition == null) return;
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _tunaNetraPosition!, zoom: 16.0), // Slightly more zoomed
    ));
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal ? MapType.satellite : MapType.normal;
    });
  }

  void _toggleAutoFocus() {
    setState(() {
      _autoFocusToTunaNetra = !_autoFocusToTunaNetra;
    });
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-focus to family member: ${_autoFocusToTunaNetra ? 'ON' : 'OFF'}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setupTunaNetraLocationStream() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!userDoc.exists || userDoc.data()?['role'] != 'keluarga') return;

      final linkedTo = userDoc['linkedTo'];
      if (linkedTo == null || linkedTo.toString().isEmpty) return;

      _tunaNetraLocationStream?.cancel(); // Cancel any existing stream

      _tunaNetraLocationStream = FirebaseFirestore.instance
          .collection('users')
          .doc(linkedTo)
          .snapshots()
          .listen((documentSnapshot) {
        if (documentSnapshot.exists) {
          final data = documentSnapshot.data();
          final lastLocation = data?['lastLocation'];
          if (lastLocation != null && lastLocation['lat'] != null && lastLocation['lng'] != null) {
            final lastKnownPosition = _tunaNetraPosition;
            final newPosition = LatLng(lastLocation['lat'], lastLocation['lng']);

            if (mounted) {
              setState(() {
                _tunaNetraPosition = newPosition;
                _addMarkers();
              });
            }

            bool positionChanged = lastKnownPosition == null ||
                                   lastKnownPosition.latitude != newPosition.latitude ||
                                   lastKnownPosition.longitude != newPosition.longitude;

            if (_isInitialLoad || (_autoFocusToTunaNetra && positionChanged)) {
              _goToTunaNetraLocation();
              if (_isInitialLoad) _isInitialLoad = false;
            }
          }
        }
      }, onError: (error, st) { // Added stack trace to log
        print('Error in visually impaired user location stream: $error\nStack: $st');
      });

      // Fallback timer, less frequent
      _tunaNetraLocationTimer?.cancel();
      _tunaNetraLocationTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
        getTunaNetraLocation(); // Only as a fallback
      });

      getTunaNetraLocation(); // Initial fetch
    } catch (e, st) { // Added stack trace to log
      print('Error setting up visually impaired user location stream: $e\nStack: $st');
    }
  }

  Future<void> getTunaNetraLocation() async {
    try {
      final keluargaUid = FirebaseAuth.instance.currentUser?.uid;
      if (keluargaUid == null) return;

      final keluargaDoc = await FirebaseFirestore.instance.collection('users').doc(keluargaUid).get();
      final linkedTo = keluargaDoc['linkedTo'];
      if (linkedTo == null) return;

      final tunaNetraDoc = await FirebaseFirestore.instance.collection('users').doc(linkedTo).get();
      final lastLocation = tunaNetraDoc['lastLocation'];

      if (lastLocation != null && lastLocation['lat'] != null && lastLocation['lng'] != null) {
        if (mounted) {
          setState(() {
            _tunaNetraPosition = LatLng(lastLocation['lat'], lastLocation['lng']);
            _addMarkers();
          });
        }
        if (_autoFocusToTunaNetra || _isInitialLoad) {
          _goToTunaNetraLocation();
          if (_isInitialLoad) _isInitialLoad = false;
        }
      }
    } catch (e, st) { // Added stack trace to log
      print("Error fetching visually impaired user's location: $e\nStack: $st");
    }
  }

  // _startTunaNetraLocationAutoRefresh is effectively replaced by _setupTunaNetraLocationStream and its fallback timer.

  @override
  void dispose() {
    _tunaNetraLocationTimer?.cancel();
    _userLocationTimer?.cancel();
    _tunaNetraLocationStream?.cancel();
    super.dispose();
  }

  Future<void> _openGoogleMapsDirections(LatLng origin, LatLng destination) async {
    try {
      final String url = 'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&travelmode=driving';
      final Uri uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final String webUrl = 'https://www.google.com/maps/dir/${origin.latitude},${origin.longitude}/${destination.latitude},${destination.longitude}';
        final Uri webUri = Uri.parse(webUrl);
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Cannot open Google Maps or browser.';
        }
      }
    } catch (e) {
      rethrow; 
    }
  }

  Future<void> _getDirectionToTunaNetra() async {
    try {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting direction to family member...')), // Translated
      );

      if (FirebaseAuth.instance.currentUser == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first.')), // Translated
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data not found. Please log in again.')), // Translated
        );
        return;
      }

      final userData = userDoc.data();
      if (userData == null || userData['linkedTo'] == null || userData['linkedTo'].toString().isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not linked to a family member\'s account.')), // Translated
        );
        return;
      }

      final Map<String, dynamic> result = await LocationUpdateService.getGoogleMapsDirectionUrl(_currentPosition);
      final String url = result['url'];
      final Uri uri = Uri.parse(url);
      final lastUpdateTime = result['lastUpdateTime'];
      final email = result['email'] ?? 'family member'; // Translated
      final formattedTime = LocationUpdateService.formatTimestamp(lastUpdateTime);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if(!mounted) return;

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Family Member Location Information'), // Translated
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: $email'),
                const SizedBox(height: 8),
                Text('Last updated: $formattedTime'),
                const SizedBox(height: 16),
                const Text( // Translated
                  'Please ensure the location is sufficiently accurate before navigating.',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A59D1)),
                child: const Text('Open Google Maps', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Cannot open Google Maps.'; // Translated
        }
      }
    } catch (e, st) { // Added stack trace to log
      if(mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      String errorMessage = 'Failed to get direction: ';
      if (e.toString().contains('linkedTo')) {
        errorMessage = 'You are not linked to a family member\'s account.'; // Translated
      } else if (e.toString().contains('lastLocation')) {
        errorMessage = 'Family member\'s location not available.'; // Translated
      } else if (e.toString().contains('Visually impaired user location not available')) { // Kept specific check just in case
        errorMessage = 'Family member\'s location not available.'; // Translated
      } else {
        errorMessage += e.toString();
      }
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
      print("Error in _getDirectionToTunaNetra: $e\nStack: $st"); // Log with stack trace
    }
  }

  @override
  Widget build(BuildContext context) {
    // final screenHeight = MediaQuery.of(context).size.height; // Example of unused variable
    // final screenWidth = MediaQuery.of(context).size.width; // Example of unused variable
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true, // Custom header means map draws behind it
      body: Stack(
        children: [
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
            mapType: _currentMapType,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Using custom FAB for this
            zoomControlsEnabled: false, // Using custom FABs for zoom potentially or other controls
          ),

          // Custom Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 56.0 + topPadding, // Standard AppBar height + status bar
              padding: EdgeInsets.only(
                top: topPadding,
                left: 16.0,
                right: 16.0,
              ),
              color: const Color(0xFF3A59D1), // Figma: Rectangle 13
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'View Location', // Updated title
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
                      IconButton(
                        icon: const Icon(Icons.help_outline, color: Colors.white, size: 24),
                        onPressed: () {
                          // TODO: Implement help action
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FamilyAccountWrapper()),
                          );
                        },
                        child: StreamBuilder<User?>(
                          stream: FirebaseAuth.instance.authStateChanges(),
                          builder: (context, snapshot) {
                            final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
                            final hasProfilePic = user?.photoURL != null && user!.photoURL!.isNotEmpty;
                            return CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              backgroundImage: hasProfilePic ? NetworkImage(user!.photoURL!) : null,
                              child: hasProfilePic ? null : const Icon(Icons.person, size: 18, color: Color(0xFF3A59D1)),
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

          // FABs
          Positioned(
            bottom: 90, 
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'fab_my_location',
                  mini: true,
                  onPressed: _goToCurrentLocation,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Color(0xFF3A59D1)),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'fab_tuna_netra_location',
                  mini: true,
                  onPressed: _goToTunaNetraLocation,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.person_pin_circle, color: Color(0xFF3A59D1)),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'fab_toggle_map_type',
                  mini: true,
                  onPressed: _toggleMapType,
                  backgroundColor: Colors.white,
                  child: Icon(
                      _currentMapType == MapType.normal ? Icons.satellite : Icons.map,
                      color: const Color(0xFF3A59D1)),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ElevatedButton.icon(
        icon: const Icon(Icons.directions, color: Colors.white), // Icon color white
        label: const Text(
          'Get Direction',
          style: TextStyle(
            color: Colors.white, // Text color white
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onPressed: _getDirectionToTunaNetra,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3A59D1), // Button color blue
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: 5,
        ),
      ),
    );
  }

  // Widget for location marker (Your Loved One) - This seems unused in the current build method
  // If it's intended for future use or was part of a previous design, it can be kept.
  // For now, it's not directly rendered by the main build method.
  // Consider removing if it's definitely not needed to reduce dead code.
  Widget _buildLocationMarker() {
    // ... (code for _buildLocationMarker - no translations needed here, comments are for understanding Figma)
    return SizedBox(
      width: 70, 
      height: 90, 
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            bottom: 20, 
            child: Container(
              width: 50, 
              height: 50, 
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3A59D1).withOpacity(0.0), 
                    const Color(0xFF3A59D1).withOpacity(0.3), 
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(25)),
              ),
            ),
          ),
          Positioned(
            bottom: 10, 
            child: Container(
              width: 36, 
              height: 36, 
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3A59D1).withOpacity(0.1), 
                border: Border.all(
                  color: const Color(0xFF8B9DE4), 
                  width: 0.5, 
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10 + (36 - 16) / 2,
            child: Container(
              width: 16, 
              height: 16, 
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white, 
                border: Border.all(
                  color: const Color(0xFF3A59D1), 
                  width: 3, 
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
