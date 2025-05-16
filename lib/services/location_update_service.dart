import 'dart:async';
import 'location_Service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LocationUpdateService {
  static final LocationUpdateService _instance =
      LocationUpdateService._internal();
  factory LocationUpdateService() => _instance;
  LocationUpdateService._internal();

  Timer? _timer;
  bool _isRunning = false;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        await LocationService.updateLocationToFirestore();
        print('Location updated in background');
      } catch (e) {
        print('Failed to update location: $e');
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _isRunning = false;
  }

  bool get isRunning => _isRunning;

  // Function to get the latest location of visually impaired user
  static Future<Map<String, dynamic>?> getTunaNetraLocation() async {
    try {
      // Get current user
      final keluargaUid = FirebaseAuth.instance.currentUser?.uid;
      if (keluargaUid == null) {
        print('No user logged in');
        return null;
      }

      // Get user document
      final keluargaDocSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(keluargaUid)
          .get();

      // Check if document exists
      if (!keluargaDocSnapshot.exists) {
        print('User document not found for uid: $keluargaUid');
        return null;
      }

      // Get document data
      final keluargaDoc = keluargaDocSnapshot.data();
      if (keluargaDoc == null) {
        print('Document data is empty for uid: $keluargaUid');
        return null;
      }

      // Check if linkedTo field exists
      final linkedTo = keluargaDoc['linkedTo'];
      if (linkedTo == null || linkedTo.toString().isEmpty) {
        print(
            'User is not linked to a visually impaired user (linkedTo is empty)');
        return null;
      }

      // Get visually impaired user document
      final tunaNetraDocSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(linkedTo)
          .get();

      // Check if visually impaired user document exists
      if (!tunaNetraDocSnapshot.exists) {
        print('Visually impaired user document not found for id: $linkedTo');
        return null;
      }

      // Get visually impaired user document data
      final tunaNetraDoc = tunaNetraDocSnapshot.data();
      if (tunaNetraDoc == null) {
        print(
            'Visually impaired user document data is empty for id: $linkedTo');
        return null;
      }

      // Check if lastLocation exists
      final lastLocation = tunaNetraDoc['lastLocation'];
      if (lastLocation == null) {
        print('Visually impaired user location data not available');
        return null;
      }

      // Check if lat and lng exist
      if (lastLocation['lat'] == null || lastLocation['lng'] == null) {
        print('Visually impaired user location coordinates are incomplete');
        return null;
      }

      // Return complete data
      return {
        'position': LatLng(
          lastLocation['lat'],
          lastLocation['lng'],
        ),
        'timestamp': lastLocation['timestamp'],
        'email': tunaNetraDoc['email'] ??
            'Visually Impaired User', // Default if email doesn't exist
      };
    } catch (e) {
      print('Error getting visually impaired user location: $e');
      return null;
    }
  }

  // Function to format timestamp to string
  static String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';

    // Convert timestamp to DateTime
    final DateTime dateTime = timestamp.toDate();

    // Format DateTime to a readable string
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 30) {
      final DateFormat formatter = DateFormat('dd MMM yyyy, HH:mm');
      return formatter.format(dateTime);
    } else {
      // Full date format if more than 30 days
      final DateFormat formatter = DateFormat('dd MMM yyyy, HH:mm');
      return formatter.format(dateTime);
    }
  }

  // Function to open Google Maps with directions to visually impaired user
  static Future<Map<String, dynamic>> getGoogleMapsDirectionUrl(
      LatLng? currentPosition,
      {bool forceFetchTunaNetraLocation = true}) async {
    if (currentPosition == null) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        currentPosition = LatLng(position.latitude, position.longitude);
      } catch (e) {
        throw Exception('Cannot get your location: $e');
      }
    }

    Map<String, dynamic>? tunaNetraData;
    if (forceFetchTunaNetraLocation) {
      tunaNetraData = await getTunaNetraLocation();
    }

    if (tunaNetraData == null || tunaNetraData['position'] == null) {
      throw Exception('Visually impaired user location not available');
    }

    final LatLng tunaNetraPosition = tunaNetraData['position'];

    return {
      'url':
          'https://www.google.com/maps/dir/?api=1&origin=${currentPosition.latitude},${currentPosition.longitude}&destination=${tunaNetraPosition.latitude},${tunaNetraPosition.longitude}&travelmode=driving',
      'lastUpdateTime': tunaNetraData['timestamp'],
      'email': tunaNetraData['email'],
    };
  }
}
