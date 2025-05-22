import 'package:flutter/material.dart';
import 'package:livekit_components/livekit_components.dart';
// import 'package:provider/provider.dart'; // Provider is not directly used here, TranscriptionBuilder handles it
import '../widgets/transcription_widget.dart' as local;

class TranscriptionScreen extends StatelessWidget {
  // RoomContext parameter removed from constructor
  // final RoomContext roomContext;

  const TranscriptionScreen({super.key}); //, required this.roomContext});

  @override
  Widget build(BuildContext context) {
    // RoomContext will be obtained by TranscriptionBuilder from Provider
    // final roomContext = context.watch<RoomContext>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF3A59D1),
        elevation: 0,
        centerTitle: false, // Title not centered
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              // TODO: Implement history deletion functionality
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        // Use TranscriptionBuilder to get transcription data
        child: TranscriptionBuilder(
          // Let TranscriptionBuilder get RoomContext on its own
          builder: (context, roomCtx, transcriptions) {
            // roomCtx here is obtained from the builder, not from a widget parameter
            // Display local TranscriptionWidget with the received data
            return local.TranscriptionWidget(
              // Get color from the current theme
              textColor: Theme.of(context).colorScheme.primary,
              backgroundColor: const Color(0xFFBBD8F1), // Using fixed color BBD8F1
              transcriptions: transcriptions,
            );
          },
        ),
      ),
      // Add bottomNavigationBar according to the image and main.dart
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF3A59D1),
        elevation: 8.0,
        height: 70.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            // View Item (inactive)
            GestureDetector(
              onTap: () {
                // Return to the main screen (VoiceAssistant)
                Navigator.pop(context);
              },
              child: Container(
                color: Colors.transparent, // For hit testing
                child: _buildNavItem(Icons.visibility_outlined, 'View', false),
              ),
            ),
            // History Item (active)
            _buildNavItem(Icons.history_outlined, 'History', true),
          ],
        ),
      ),
    );
  }

  // Helper to create navigation items
  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final color = isActive ? Colors.white : const Color(0xFFB5C0ED);
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
