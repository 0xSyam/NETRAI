import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'screen_share_helper.dart';

class ControlsWidget extends StatefulWidget {
  final Room room;
  final LocalParticipant participant;

  const ControlsWidget({
    super.key,
    required this.room,
    required this.participant,
  });

  @override
  State<ControlsWidget> createState() => _ControlsWidgetState();
}

class _ControlsWidgetState extends State<ControlsWidget> {
  void _enableVideo() async {
    await widget.participant.setCameraEnabled(true);
  }

  void _selectAudioOutput(MediaDevice device) async {
    await widget.room.setAudioOutputDevice(device);
    setState(() {});
  }

  void _enableScreenShare() async {
    await ScreenShareHelper.toggleScreenSharing(context, widget.participant);
  }

  void _disableScreenShare() async {
    await ScreenShareHelper.toggleScreenSharing(context, widget.participant);
  }

  void _onTapDisconnect() async {
    try {
      await widget.room.disconnect();
    } catch (e) {
      if (kDebugMode) {
        print('Error disconnecting: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ElevatedButton(
            onPressed: _enableVideo, child: const Text('Enable Video')),
        ElevatedButton(
            onPressed: _enableScreenShare, child: const Text('Share Screen')),
        ElevatedButton(
            onPressed: _disableScreenShare, child: const Text('Stop Sharing')),
        ElevatedButton(
            onPressed: _onTapDisconnect, child: const Text('Disconnect')),
      ],
    );
  }
}
