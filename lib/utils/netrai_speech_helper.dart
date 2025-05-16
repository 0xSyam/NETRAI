import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Helper class for managing "Speak to NetrAI" feature
class NetraiSpeechHelper {
  // Callback for event when user wants to speak to NetrAI
  static Function(BuildContext)? _onSpeakToNetRAICallback;

  /// Set callback for "Speak to NetrAI" function
  /// Must be called once during app initialization
  static void setOnSpeakToNetRAICallback(Function(BuildContext) callback) {
    _onSpeakToNetRAICallback = callback;
  }

  /// Start speaking session with NetrAI
  /// Called when "Speak to NetrAI" button is pressed
  static Future<void> startSpeakToNetRAI(
    BuildContext context,
    LocalParticipant participant,
  ) async {
    try {
      // Make sure microphone is enabled
      if (!participant.isMicrophoneEnabled()) {
        await participant.setMicrophoneEnabled(true);
        print('NetraiSpeechHelper: Microphone enabled');
      }

      // Make sure microphone is not muted
      TrackPublication? micPub;
      try {
        micPub = participant.audioTrackPublications
            .firstWhere((pub) => pub.source == TrackSource.microphone);

        if (micPub.muted && micPub is LocalTrackPublication) {
          await (micPub as LocalTrackPublication).unmute();
          print('NetraiSpeechHelper: Microphone unmuted');
        }
      } catch (e) {
        print('NetraiSpeechHelper: Error finding microphone publication: $e');
      }

      // Show indicator that NetrAI is ready to listen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NetrAI is listening...'),
          duration: Duration(seconds: 2),
        ),
      );

      // If there's a callback set, call it to handle main logic
      if (_onSpeakToNetRAICallback != null) {
        _onSpeakToNetRAICallback!(context);
      } else {
        print('NetraiSpeechHelper: No callback set for Speak to NetrAI');
      }
    } catch (e) {
      print('NetraiSpeechHelper: Error starting Speak to NetrAI: $e');

      // Show error message if failed
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start NetrAI: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Method to stop speaking session with NetrAI
  static Future<void> stopSpeakToNetRAI(
    BuildContext context,
    LocalParticipant participant,
  ) async {
    // Additional implementation if needed
  }
}
