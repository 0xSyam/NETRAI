import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk show ConnectionState;
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:livekit_components/livekit_components.dart';

/// The main control interface for the voice assistant
/// Handles:
/// - Connecting to LiveKit rooms (Now handled automatically in main.dart)
/// - Disconnecting from rooms
/// - Toggling microphone
/// - Displaying audio visualization
class ControlBar extends StatefulWidget {
  const ControlBar({super.key});

  @override
  State<ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<ControlBar> {
  bool isDisconnecting = false;

  /// Disconnects from the current LiveKit room
  Future<void> disconnect() async {
    final roomContext = context.read<RoomContext>();

    if (mounted) {
      setState(() {
        isDisconnecting = true;
      });
    }

    try {
      await roomContext.disconnect();
    } catch (e) {
      debugPrint("Error disconnecting: $e");
    } finally {
      if (mounted) {
        setState(() {
          isDisconnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomContext = context.watch<RoomContext>();
    final connectionState = roomContext.room.connectionState;

    Widget buttonToShow;

    if (isDisconnecting || connectionState == lk.ConnectionState.connecting) {
      buttonToShow = TransitionButton(isConnecting: !isDisconnecting);
    } else if (connectionState == lk.ConnectionState.connected) {
      buttonToShow = DisconnectButton(onPressed: disconnect);
    } else {
      buttonToShow = const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [buttonToShow],
    );
  }
}

/// Button shown when connected to end the conversation
class DisconnectButton extends StatelessWidget {
  final VoidCallback onPressed;

  const DisconnectButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.call_end),
      onPressed: onPressed,
      tooltip: 'Disconnect',
      color: Colors.red,
      style: IconButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.1),
      ),
    );
  }
}

/// button shown during connection state transitions
class TransitionButton extends StatelessWidget {
  final bool isConnecting;

  const TransitionButton({super.key, required this.isConnecting});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: null, // Disabled
      icon: SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
            strokeWidth: 2,
          )),
      label: Text(isConnecting ? 'Menghubungkan...' : 'Memutuskan...'),
      style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.primary,
          disabledForegroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.5)),
    );
  }
}

/// Audio controls shown when connected
class AudioControls extends StatelessWidget {
  const AudioControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomContext>(
      builder: (context, room, _) => MediaDeviceContextBuilder(
        builder: (context, roomCtx, mediaDeviceCtx) {
          // Dapatkan status kamera dan mikrofon dari partisipan lokal
          final isCameraEnabled =
              room.localParticipant?.isCameraEnabled() ?? false;
          final isMicEnabled =
              room.localParticipant?.isMicrophoneEnabled() ?? false;

          return SizedBox(
            height: 42,
            child: Row(
              children: [
                MicrophoneSelectButton(
                  selectedColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  selectedOverlayColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  iconColor: Theme.of(context).colorScheme.primary,
                  titleWidget: ParticipantSelector(
                    filter: (identifier) =>
                        identifier.isAudio && identifier.isLocal,
                    builder: (context, identifier) {
                      return AudioVisualizerWidget(
                        options: AudioVisualizerWidgetOptions(
                          width: 3,
                          spacing: 3,
                          minHeight: 3,
                          maxHeight: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ),
                // Tambahkan tombol untuk toggle kamera
                IconButton(
                  onPressed: () async {
                    await room.localParticipant
                        ?.setCameraEnabled(!isCameraEnabled);
                  },
                  icon: Icon(
                      isCameraEnabled ? Icons.videocam : Icons.videocam_off),
                  tooltip:
                      isCameraEnabled ? 'Matikan Kamera' : 'Nyalakan Kamera',
                  color: Theme.of(context).colorScheme.primary,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
