// Copyright 2024 LiveKit, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:chat_bubbles/chat_bubbles.dart' show BubbleNormal;
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' show LocalParticipant;

import 'package:livekit_components/livekit_components.dart';

class TranscriptionWidget extends StatefulWidget {
  const TranscriptionWidget({
    super.key,
    required this.transcriptions,
    this.backgroundColor = Colors.white,
    this.textColor = Colors.black,
  });
  final Color backgroundColor;
  final Color textColor;
  final List<TranscriptionForParticipant> transcriptions;
  @override
  State<TranscriptionWidget> createState() => _TranscriptionWidgetState();
}

class _TranscriptionWidgetState extends State<TranscriptionWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant TranscriptionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Widget> _buildMessages(
      BuildContext context, List<TranscriptionForParticipant> transcriptions) {
    List<Widget> msgWidgets = [];
    var sortedTranscriptions = transcriptions
      ..sort((a, b) =>
          a.segment.firstReceivedTime.compareTo(b.segment.firstReceivedTime));

    final Color userBubbleColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.1);
    final Color aiBubbleColor =
        Theme.of(context).colorScheme.secondary.withOpacity(0.1);
    final Color userTextColor =
        Theme.of(context).colorScheme.onPrimaryContainer;
    final Color aiTextColor =
        Theme.of(context).colorScheme.onSecondaryContainer;

    for (var transcription in sortedTranscriptions) {
      var participant = transcription.participant;
      var segment = transcription.segment;
      bool isLocal = participant is LocalParticipant;

      msgWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: BubbleNormal(
            text: segment.text + (segment.isFinal ? '' : '...'),
            textStyle: TextStyle(
              color: isLocal ? userTextColor : aiTextColor,
              fontSize: 16,
            ),
            color: isLocal ? userBubbleColor : aiBubbleColor,
            tail: true,
            isSender: isLocal,
          ),
        ),
      );
    }
    return msgWidgets;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: widget.transcriptions.length,
      itemBuilder: (context, index) {
        if (widget.transcriptions.isEmpty) return const SizedBox.shrink();

        var sortedTranscriptions =
            List<TranscriptionForParticipant>.from(widget.transcriptions)
              ..sort((a, b) => a.segment.firstReceivedTime
                  .compareTo(b.segment.firstReceivedTime));

        if (index >= sortedTranscriptions.length)
          return const SizedBox.shrink();

        var transcription = sortedTranscriptions[index];
        var participant = transcription.participant;
        var segment = transcription.segment;
        bool isLocal = participant is LocalParticipant;

        final Color userBubbleColor =
            Theme.of(context).colorScheme.primary.withOpacity(0.2);
        final Color aiBubbleColor = Colors.grey[300]!;
        final Color userTextColor =
            Theme.of(context).colorScheme.onPrimaryContainer;
        final Color aiTextColor = Colors.black87;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: BubbleNormal(
            text: segment.text + (segment.isFinal ? '' : '...'),
            textStyle: TextStyle(
              color: isLocal ? userTextColor : aiTextColor,
              fontSize: 15,
            ),
            color: isLocal ? userBubbleColor : aiBubbleColor,
            tail: true,
            isSender: isLocal,
          ),
        );
      },
    );
  }
}
