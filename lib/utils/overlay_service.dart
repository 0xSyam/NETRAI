import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/screen_share_floating_button.dart';

/// Service to manage overlays that can appear over other applications
class OverlayService {
  static const MethodChannel _channel = MethodChannel('com.netrai/overlay');
  static bool _overlayActive = false;

  /// Initialize overlay service
  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initializeOverlay');
      print('OverlayService: Service successfully initialized');
    } catch (e) {
      print('OverlayService: Error initializing overlay service: $e');
    }
  }

  /// Display message in SnackBar
  static void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.black87,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Check if the application has permission to display overlay
  static Future<bool> checkOverlayPermission() async {
    try {
      // Check permission through platform channel for Android
      // and through permission_handler for failover
      bool hasPermission = false;
      try {
        // Try to check permission through platform channel for accurate Android permission status
        hasPermission = await _channel.invokeMethod('checkOverlayPermission');
      } catch (e) {
        // Fallback to permission_handler if platform channel fails
        hasPermission = await Permission.systemAlertWindow.isGranted;
      }

      print('OverlayService: Overlay permission: $hasPermission');
      return hasPermission;
    } catch (e) {
      print('OverlayService: Error checking overlay permission: $e');
      return false;
    }
  }

  /// Request permission to display overlay
  static Future<bool> requestOverlayPermission(BuildContext context) async {
    try {
      // Request permission only if not already granted
      if (!await checkOverlayPermission()) {
        // Display message that permission is required
        _showSnackBar(
          context,
          "Permission 'Display over other apps' is required",
        );

        // Open overlay settings directly through platform channel
        try {
          await _channel.invokeMethod('openOverlaySettings');

          // Wait a few seconds to give user time to set permission
          await Future.delayed(const Duration(seconds: 3));

          // Check again if permission has been granted
          bool granted = await checkOverlayPermission();
          if (!granted && context.mounted) {
            // Display message if permission not given after a few seconds
            _showSnackBar(
              context,
              "Please enable 'Display over other apps' to continue",
              isError: true,
            );
          }
          return granted;
        } catch (e) {
          print('OverlayService: Error opening overlay settings: $e');

          // Fallback to standard method if failed
          await openAppSettings();
          return false;
        }
      }
      return await checkOverlayPermission();
    } catch (e) {
      print('OverlayService: Error requesting overlay permission: $e');
      return false;
    }
  }

  /// Display floating button in system overlay
  static Future<bool> showFloatingButton(
    BuildContext context,
    LocalParticipant participant,
    VoidCallback onStopShare,
    VoidCallback onSpeakToNetrai,
  ) async {
    try {
      // Check and request overlay permission if not granted
      if (!await checkOverlayPermission()) {
        // Display notification that permission is required
        _showSnackBar(
          context,
          "Overlay display permission is required for this feature",
        );

        bool granted = await requestOverlayPermission(context);
        if (!granted) {
          print('OverlayService: Overlay permission not granted.');

          // Display notification that feature cannot be used without permission
          _showSnackBar(
            context,
            "This feature requires overlay display permission",
            isError: true,
          );

          return false;
        }
      }

      // If overlay is already active, don't create a new one
      if (_overlayActive) {
        print(
            'OverlayService: Overlay already active, no need to display again.');
        return true;
      }

      // Display widget through platform channel
      final Map<String, dynamic> args = {
        'width': 320, // Widget width
        'height': 120, // Widget height
        'gravity': 'bottom', // Position at bottom of screen (center horizontal)
      };

      // Save callbacks for platform channel
      try {
        await _channel.invokeMethod('onStopSharePressed');
        onStopShare();
      } catch (e) {
        print('OverlayService: Error saving stopShare callback: $e');
      }

      try {
        await _channel.invokeMethod('onSpeakToNetraiPressed');
        onSpeakToNetrai();
      } catch (e) {
        print('OverlayService: Error saving speakToNetrai callback: $e');
      }

      final bool success = await _channel.invokeMethod('showOverlay', args);
      _overlayActive = success;

      print(
          'OverlayService: Floating button ${success ? 'successfully' : 'failed to be'} displayed');
      return success;
    } catch (e) {
      print('OverlayService: Error displaying floating button: $e');
      return false;
    }
  }

  /// Hide floating button
  static Future<bool> hideFloatingButton() async {
    try {
      if (!_overlayActive) {
        return true; // Already inactive
      }

      final bool success = await _channel.invokeMethod('hideOverlay');
      _overlayActive = !success;

      print(
          'OverlayService: Floating button ${success ? 'successfully' : 'failed to be'} hidden');
      return success;
    } catch (e) {
      print('OverlayService: Error hiding floating button: $e');
      return false;
    }
  }

  /// Check if overlay is being displayed
  static bool get isOverlayActive => _overlayActive;
}
