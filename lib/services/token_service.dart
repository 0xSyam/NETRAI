import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Data class representing the connection details needed to join a LiveKit room
/// This includes the server URL, room name, participant info, and auth token
class ConnectionDetails {
  final String serverUrl;
  final String roomName;
  final String participantName;
  final String participantToken;

  ConnectionDetails({
    required this.serverUrl,
    required this.roomName,
    required this.participantName,
    required this.participantToken,
  });

  factory ConnectionDetails.fromJson(Map<String, dynamic> json) {
    return ConnectionDetails(
      serverUrl: json['serverUrl'],
      roomName: json['roomName'],
      participantName: json['participantName'],
      participantToken: json['participantToken'],
    );
  }
}

/// An example service for fetching LiveKit authentication tokens
///
/// To use the LiveKit Cloud sandbox (development only)
/// - Enable your sandbox here https://cloud.livekit.io/projects/p_/sandbox/templates/token-server
/// - Create .env file with your LIVEKIT_SANDBOX_ID
///
/// To use a hardcoded token (development only)
/// - Generate a token: https://docs.livekit.io/home/cli/cli-setup/#generate-access-token
/// - Set `hardcodedServerUrl` and `hardcodedToken` below
///
/// To use your own server (production applications)
/// - Add a token endpoint to your server with a LiveKit Server SDK https://docs.livekit.io/home/server/generating-tokens/
/// - Modify or replace this class as needed to connect to your new token server
/// - Rejoice in your new production-ready LiveKit application!
///
/// See https://docs.livekit.io/home/get-started/authentication for more information
class TokenService extends ChangeNotifier {
  // For hardcoded token usage (development only)
  final String? hardcodedServerUrl = null;
  final String? hardcodedToken = null;

  // Get the sandbox ID from environment variables
  String? get sandboxId {
    final value = dotenv.env['LIVEKIT_SANDBOX_ID'];
    if (value != null) {
      // Remove unwanted double quotes if present
      return value.replaceAll('"', '');
    }
    return null;
  }

  // LiveKit Cloud sandbox API endpoint
  final String sandboxUrl =
      'https://cloud-api.livekit.io/api/sandbox/connection-details';

  // Tambahkan properti untuk caching token
  String? _cachedToken;
  String? _cachedServerUrl;
  DateTime? _tokenExpiryTime;

  /// Main method to get connection details
  /// First tries hardcoded credentials, then falls back to sandbox
  Future<ConnectionDetails?> fetchConnectionDetails({
    required String roomName,
    required String participantName,
  }) async {
    // Periksa apakah kita memiliki token yang masih valid
    if (_cachedToken != null &&
        _cachedServerUrl != null &&
        _tokenExpiryTime != null &&
        DateTime.now().isBefore(_tokenExpiryTime!)) {
      print("[TokenService] Menggunakan token yang telah di-cache");
      return ConnectionDetails(
        serverUrl: _cachedServerUrl!,
        roomName: roomName,
        participantName: participantName,
        participantToken: _cachedToken!,
      );
    }

    // Coba hardcoded first
    final hardcodedDetails = fetchHardcodedConnectionDetails(
      roomName: roomName,
      participantName: participantName,
    );

    if (hardcodedDetails != null) {
      // Cache hardcoded details juga
      _cachedToken = hardcodedDetails.participantToken;
      _cachedServerUrl = hardcodedDetails.serverUrl;
      _tokenExpiryTime = DateTime.now().add(const Duration(hours: 1));

      print(
          "[TokenService] Hardcoded token di-cache, expiry: $_tokenExpiryTime");
      return hardcodedDetails;
    }

    // Fallback to LiveKit Sandbox API
    var sandbox = await fetchConnectionDetailsFromSandbox(
      roomName: roomName,
      participantName: participantName,
    );

    if (sandbox != null) {
      // Cache token untuk penggunaan berikutnya (valid selama 1 jam)
      _cachedToken = sandbox.participantToken;
      _cachedServerUrl = sandbox.serverUrl;
      _tokenExpiryTime = DateTime.now().add(const Duration(hours: 1));

      print("[TokenService] Sandbox token di-cache, expiry: $_tokenExpiryTime");
      return sandbox;
    }

    // No connection details found
    return null;
  }

  Future<ConnectionDetails?> fetchConnectionDetailsFromSandbox({
    required String roomName,
    required String participantName,
  }) async {
    if (sandboxId == null) {
      return null;
    }

    final uri = Uri.parse(sandboxUrl).replace(queryParameters: {
      'roomName': roomName,
      'participantName': participantName,
    });

    try {
      final response = await http.post(
        uri,
        headers: {'X-Sandbox-ID': sandboxId!},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final data = jsonDecode(response.body);
          return ConnectionDetails.fromJson(data);
        } catch (e) {
          debugPrint(
              'Error parsing connection details from LiveKit Cloud sandbox, response: ${response.body}');
          return null;
        }
      } else {
        debugPrint(
            'Error from LiveKit Cloud sandbox: ${response.statusCode}, response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Failed to connect to LiveKit Cloud sandbox: $e');
      return null;
    }
  }

  ConnectionDetails? fetchHardcodedConnectionDetails({
    required String roomName,
    required String participantName,
  }) {
    if (hardcodedServerUrl == null || hardcodedToken == null) {
      return null;
    }

    return ConnectionDetails(
      serverUrl: hardcodedServerUrl!,
      roomName: roomName,
      participantName: participantName,
      participantToken: hardcodedToken!,
    );
  }

  // Metode untuk menghapus cache token ketika logout atau diperlukan
  void clearTokenCache() {
    _cachedToken = null;
    _cachedServerUrl = null;
    _tokenExpiryTime = null;
    print("[TokenService] Token cache dibersihkan");
  }
}
