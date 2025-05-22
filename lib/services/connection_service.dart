import 'dart:async';
import 'dart:io'; // For SocketException
import 'dart:math'; // For random string generation

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

// Assuming TokenService will be in the same directory
import 'token_service.dart';

// Enums and Class for structured status updates
enum ConnectionStateUpdate {
  initial,
  connecting,
  connected,
  disconnected,
  error,
  permissionRequired,
  tokenFetching,
  reconnecting,
}

enum ErrorType {
  network,
  permissions,
  server, // For general server/API errors not related to LiveKit client
  token,
  timeout,
  general, // For other unexpected errors
  livekitClient, // For errors originating from LiveKit client operations
  configuration, // For missing URL/Token etc.
}

class ConnectionStatusUpdate {
  final ConnectionStateUpdate state;
  final String? message; // User-friendly message for general status or error summary
  final ErrorType? errorType;
  final String? errorMessageDetail; // For logging
  final Object? errorObject;        // For logging
  final StackTrace? stackTrace;     // For logging

  ConnectionStatusUpdate({
    required this.state,
    this.message,
    this.errorType,
    this.errorMessageDetail,
    this.errorObject,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'ConnectionStatusUpdate(state: $state, message: $message, errorType: $errorType, errorMessageDetail: $errorMessageDetail)';
  }
}

class ConnectionService {
  final Room _room;
  final TokenService _tokenService;

  // Connection State Properties
  bool _isConnecting = false;
  bool _isReadyToConnect = false;
  bool _permissionsGranted = false;
  String? _cachedToken;
  String? _cachedServerUrl;
  DateTime? _tokenExpiryTime;
  String? _lastRoomName;
  String? _lastParticipantName;
  Timer? _connectionTimeoutTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  // StreamSubscription<RoomDisconnectedEvent>? _roomDisconnectedSubscription; // Now handled by the general room events listener

  // Stream for connection status updates
  final _statusController = StreamController<ConnectionStatusUpdate>.broadcast();
  Stream<ConnectionStatusUpdate> get statusStream => _statusController.stream;
  // String _connectionStatus = 'Not connected'; // This is now replaced by ConnectionStatusUpdate

  // Constructor
  ConnectionService(this._room, this._tokenService, {String? initialServerUrl}) {
    _cachedServerUrl = initialServerUrl ?? const String.fromEnvironment('LIVEKIT_URL');
    if (_cachedServerUrl == null || _cachedServerUrl!.isEmpty) {
        // This is a critical configuration error. Log it prominently.
        // In a real app, this might throw an exception or prevent service instantiation.
        print("ConnectionService CRITICAL ERROR: LIVEKIT_URL is not set. Connection attempts will likely fail.");
    }
    _setupEventListeners();
    _setupConnectivityMonitor();
    _checkPermissionsEarly();
    _updateConnectionStatus(state: ConnectionStateUpdate.initial, message: "Service initialized");
  }

  // Public Getters
  bool get isConnecting => _isConnecting;
  bool get isReadyToConnect => _isReadyToConnect;
  bool get permissionsGranted => _permissionsGranted;
  String? get roomName => _lastRoomName;
  String? get participantName => _lastParticipantName;

  void _updateConnectionStatus({
    required ConnectionStateUpdate state,
    String? message,
    ErrorType? errorType,
    String? errorMessageDetail,
    Object? errorObject,
    StackTrace? stackTrace,
  }) {
    final update = ConnectionStatusUpdate(
      state: state,
      message: message,
      errorType: errorType,
      errorMessageDetail: errorMessageDetail,
      errorObject: errorObject,
      stackTrace: stackTrace,
    );
    _statusController.add(update);
    
    // Use a more structured logging approach in a real application (e.g., a logging package)
    // For now, keeping print statements for visibility during development.
    final logMessage = "ConnectionService: Status Update: ${update.state}, Message: ${update.message ?? 'N/A'}"
                       "${update.errorType != null ? ', ErrorType: ${update.errorType}' : ''}"
                       "${update.errorMessageDetail != null ? ', Detail: ${update.errorMessageDetail}' : ''}";
    print(logMessage);

    if (errorObject != null) {
      print("ConnectionService: Associated Error Object: ${errorObject.toString()}");
    }
    if (stackTrace != null) {
      print("ConnectionService: Associated Stack Trace: \n$stackTrace");
    }
  }

  Future<void> _generateRoomAndParticipantNames() async {
    // In a real app, these might come from user input, auth service, or secure storage
    _lastRoomName = 'my-test-room'; 
    _lastParticipantName = 'user-${Random().nextInt(1000)}';
    // print("ConnectionService: Generated Room: $_lastRoomName, Participant: $_lastParticipantName"); // Less critical log, can be removed
  }

  Future<void> _preFetchConnectionToken() async {
    if (_lastRoomName == null || _lastParticipantName == null) {
      await _generateRoomAndParticipantNames();
    }
    if (_cachedServerUrl == null || _cachedServerUrl!.isEmpty) {
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'Server URL is not configured.', // User-friendly message
          errorType: ErrorType.configuration,
          errorMessageDetail: 'Server URL is null or empty during token pre-fetch.');
      return;
    }

    _updateConnectionStatus(state: ConnectionStateUpdate.tokenFetching, message: 'Preparing connection...'); // User-friendly
    try {
      _cachedToken = await _tokenService.fetchToken(_lastRoomName!, _lastParticipantName!);
      _tokenExpiryTime = DateTime.now().add(const Duration(minutes: 55)); // Simulate token expiry
      _isReadyToConnect = true;
      _updateConnectionStatus(state: ConnectionStateUpdate.tokenFetching, message: 'Ready to connect.'); // User-friendly
      // print("ConnectionService: Token fetched successfully for room: $_lastRoomName"); // Debug log, can be removed
    } on SocketException catch (e, st) {
      _isReadyToConnect = false;
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'Network error. Please check your connection.', // User-friendly
          errorType: ErrorType.network,
          errorMessageDetail: "SocketException: ${e.message}",
          errorObject: e,
          stackTrace: st);
    } on TimeoutException catch (e, st) {
      _isReadyToConnect = false;
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'Connection timed out. Please try again.', // User-friendly
          errorType: ErrorType.timeout,
          errorMessageDetail: "TimeoutException: ${e.message}",
          errorObject: e,
          stackTrace: st);
    } on PlatformException catch (e, st) {
       _isReadyToConnect = false;
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'A platform error occurred.', // User-friendly
          errorType: ErrorType.server, // Or a more specific type if identifiable
          errorMessageDetail: "PlatformException: ${e.message}, Details: ${e.details}",
          errorObject: e,
          stackTrace: st);
    }
    // Example for a custom exception from TokenService, if it were defined:
    // on TokenServiceException catch (e, st) { 
    //   _isReadyToConnect = false;
    //   _updateConnectionStatus(
    //       state: ConnectionStateUpdate.error,
    //       message: e.userFriendlyMessage, // Use user-friendly message from custom exception
    //       errorType: ErrorType.token,
    //       errorMessageDetail: e.toString(), // Full error for logging
    //       errorObject: e,
    //       stackTrace: st);
    // }
     catch (e, st) { // General catch-all for other errors during token fetching
      _isReadyToConnect = false;
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'Could not prepare connection. Please try again.', // User-friendly
          errorType: ErrorType.token,
          errorMessageDetail: "Unknown error during token fetch: ${e.toString()}",
          errorObject: e,
          stackTrace: st);
    }
  }

  void _setConnectionTimeout() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_isConnecting) {
        _isConnecting = false;
        _updateConnectionStatus(
            state: ConnectionStateUpdate.error,
            message: 'Connection attempt timed out. Please try again.', // User-friendly
            errorType: ErrorType.timeout,
            errorMessageDetail: 'Connection to LiveKit server timed out after 15 seconds.');
        disconnect(); 
      }
    });
  }

  Future<void> _requestPermissions() async {
    _updateConnectionStatus(state: ConnectionStateUpdate.permissionRequired, message: 'Requesting microphone permission...');
    var status = await Permission.microphone.request(); // Also consider camera permission if video is used
    if (status.isGranted) {
      _permissionsGranted = true;
      _updateConnectionStatus(state: ConnectionStateUpdate.permissionRequired, message: 'Microphone permission granted.');
      // print("ConnectionService: Microphone permission granted."); // Debug log
    } else {
      _permissionsGranted = false;
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'Microphone permission denied. Please grant permission in settings.', // User-friendly
          errorType: ErrorType.permissions,
          errorMessageDetail: 'Microphone permission was denied by the user.');
      // print("ConnectionService: Microphone permission denied."); // Debug log
    }
  }

  Future<void> _checkPermissionsEarly() async {
    var status = await Permission.microphone.status;
    _permissionsGranted = status.isGranted;
    if (_permissionsGranted) {
      // print("ConnectionService: Microphone permission already granted (checked early)."); // Debug log
      _updateConnectionStatus(state: ConnectionStateUpdate.initial, message: 'Permissions checked.');
    } else {
      // print("ConnectionService: Microphone permission not yet granted (checked early)."); // Debug log
      _updateConnectionStatus(state: ConnectionStateUpdate.permissionRequired, message: 'Microphone permission needed.'); // User-friendly
    }
  }

  void _setupEventListeners() {
    _room.events.listen((event) {
      // print("ConnectionService: Room event received: ${event.runtimeType}"); // Debug log for all events
      if (event is RoomDisconnectedEvent) {
        _isConnecting = false;
        _updateConnectionStatus(
            state: ConnectionStateUpdate.disconnected,
            message: 'Disconnected: ${event.reason?.toString() ?? "No reason given"}', // User-friendly, but can be generic
            errorMessageDetail: "RoomDisconnectedEvent: Reason: ${event.reason?.toString()}");
        _resetReconnectState();
      } else if (event is RoomConnectEvent) {
        _isConnecting = false;
        _connectionTimeoutTimer?.cancel();
        _updateConnectionStatus(state: ConnectionStateUpdate.connected, message: 'Connected!'); // User-friendly
      } else if (event is RoomReconnectEvent) {
        _isConnecting = true;
        _updateConnectionStatus(
            state: ConnectionStateUpdate.reconnecting,
            message: 'Connection lost, attempting to reconnect...', // User-friendly
            errorMessageDetail: 'RoomReconnectEvent: Attempting to reconnect (attempt ${event.attempt})');
      } else if (event is RoomReconnectedEvent) {
        _isConnecting = false;
        _connectionTimeoutTimer?.cancel();
        _updateConnectionStatus(state: ConnectionStateUpdate.connected, message: 'Reconnected successfully!'); // User-friendly
      }
      // Consider handling other events like ParticipantDisconnected, TrackSubscribedFailed, etc.
      // For example, if a remote participant disconnects:
      // else if (event is ParticipantDisconnectedEvent) {
      //   print("ConnectionService: Participant ${event.participant.identity} disconnected.");
      // }
    });
    // print("ConnectionService: Room event listeners set up."); // Debug log
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'No internet connection. Please check your network.', // User-friendly
          errorType: ErrorType.network,
          errorMessageDetail: 'Connectivity changed to none.');
    } else {
      _updateConnectionStatus(
          state: ConnectionStateUpdate.initial, // This might need context (e.g. if it was previously error, maybe reconnecting)
          message: 'Internet connection restored.', // User-friendly
          errorMessageDetail: 'Connectivity changed to ${result.toString()}');
      // Attempt to reconnect if was previously trying or connected
      if (!_room.isConnected && (_lastRoomName != null || _isConnecting)) {
        // print("ConnectionService: Attempting to reconnect after connectivity restored."); // Debug log
        _attemptManualReconnect();
      }
    }
  }

  void _setupConnectivityMonitor() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
    // print("ConnectionService: Connectivity monitor set up."); // Debug log
  }

  Future<void> _autoConnect() async {
    if (!_permissionsGranted) {
      await _requestPermissions(); 
      if (!_permissionsGranted) {
        // Status already updated by _requestPermissions if denied
        return;
      }
    }

    if (!_isReadyToConnect || _cachedToken == null || _cachedServerUrl == null) {
      await _preFetchConnectionToken(); 
      if (!_isReadyToConnect || _cachedToken == null || _cachedServerUrl == null) {
        // Status already updated by _preFetchConnectionToken if fails or config missing
        // Add a specific check here just in case for configuration error not caught by preFetch
        if (_cachedServerUrl == null || _cachedServerUrl!.isEmpty) {
             _updateConnectionStatus(
                state: ConnectionStateUpdate.error,
                message: 'Cannot connect: Server URL is missing.', // User-friendly
                errorType: ErrorType.configuration,
                errorMessageDetail: 'Server URL is null or empty before connect attempt.');
        } else if (_cachedToken == null) { // Only token is missing, URL was okay
            _updateConnectionStatus(
                state: ConnectionStateUpdate.error,
                message: 'Cannot connect: Connection token missing.', // User-friendly
                errorType: ErrorType.token,
                errorMessageDetail: 'Token is null before connect attempt.');
        }
        return;
      }
    }

    if (_isConnecting || _room.isConnected) {
      _updateConnectionStatus(
          state: _room.isConnected ? ConnectionStateUpdate.connected : ConnectionStateUpdate.connecting,
          message: _room.isConnected ? 'Already connected.' : 'Connection attempt in progress.'); // User-friendly
      return;
    }

    _isConnecting = true;
    _updateConnectionStatus(state: ConnectionStateUpdate.connecting, message: 'Connecting to room...'); // User-friendly
    _setConnectionTimeout();

    try {
      await _room.connect(
        _cachedServerUrl!,
        _cachedToken!,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: VideoPublishOptions(simulcast: true),
        ),
        connectOptions: const ConnectOptions(autoSubscribe: true),
      );
      // Success is handled by RoomConnectEvent listener
      // print("ConnectionService: room.connect() called successfully."); // Debug log
    } on LiveKitClientException catch (e, st) {
      _isConnecting = false;
      _connectionTimeoutTimer?.cancel();
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'Failed to connect. Please try again.', // User-friendly
          errorType: ErrorType.livekitClient,
          errorMessageDetail: "LiveKitClientException: ${e.message}",
          errorObject: e,
          stackTrace: st);
    } on SocketException catch (e, st) {
      _isConnecting = false;
      _connectionTimeoutTimer?.cancel();
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'Network error. Please check your connection.', // User-friendly
          errorType: ErrorType.network,
          errorMessageDetail: "SocketException: ${e.message}",
          errorObject: e,
          stackTrace: st);
    } on PlatformException catch (e, st) {
       _isConnecting = false;
      _connectionTimeoutTimer?.cancel();
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'A platform error occurred during connection.', // User-friendly
          errorType: ErrorType.general, 
          errorMessageDetail: "PlatformException: ${e.message}, Details: ${e.details}",
          errorObject: e,
          stackTrace: st);
    }
    catch (e, st) { // General catch-all for other errors during connection
      _isConnecting = false;
      _connectionTimeoutTimer?.cancel();
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'An unexpected error occurred. Please try again.', // User-friendly
          errorType: ErrorType.general,
          errorMessageDetail: "Unknown error during room.connect(): ${e.toString()}",
          errorObject: e,
          stackTrace: st);
    }
  }

  Future<void> connect({String? roomName, String? participantName}) async {
    if (roomName != null) _lastRoomName = roomName;
    if (participantName != null) _lastParticipantName = participantName;

    if (_lastRoomName == null || _lastParticipantName == null) {
      await _generateRoomAndParticipantNames();
    }

    _cachedToken = null; // Force re-fetch of token if names change or it's a new connect call
    _isReadyToConnect = false;
    await _autoConnect();
  }

  Future<void> disconnect() async {
    _connectionTimeoutTimer?.cancel();
    if (_room.isConnected || _isConnecting) {
      _updateConnectionStatus(state: ConnectionStateUpdate.disconnected, message: 'Disconnecting...'); // User-friendly
      await _room.disconnect(); 
      _isConnecting = false;
      _isReadyToConnect = false; 
      _cachedToken = null; 
      // The RoomDisconnectedEvent listener will handle the final disconnected status update
      // print("ConnectionService: Disconnected successfully via disconnect()."); // Debug log
    } else {
      _updateConnectionStatus(state: ConnectionStateUpdate.disconnected, message: 'Already disconnected.'); // User-friendly
    }
  }

  Future<void> _attemptManualReconnect() async {
    if (_isConnecting || _room.isConnected) {
      // print("ConnectionService: Manual reconnect skipped, already connecting or connected."); // Debug log
      return;
    }
    if (_cachedServerUrl != null && _lastRoomName != null && _lastParticipantName != null) {
      _updateConnectionStatus(state: ConnectionStateUpdate.reconnecting, message: 'Attempting to reconnect...'); // User-friendly
      _cachedToken = null; 
      _isReadyToConnect = false;
      await _autoConnect();
    } else {
      _updateConnectionStatus(
          state: ConnectionStateUpdate.error,
          message: 'Cannot reconnect: missing details.', // User-friendly
          errorType: ErrorType.configuration,
          errorMessageDetail: 'Cannot attempt manual reconnect due to missing server URL, room name, or participant name.');
    }
  }

  void _resetReconnectState() {
    _isConnecting = false;
    _connectionTimeoutTimer?.cancel();
    // print("ConnectionService: Reconnect state has been reset."); // Debug log
  }

  void dispose() {
    _connectionTimeoutTimer?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
    // print("ConnectionService: Disposed."); // Debug log
  }
}

// Example of what a TokenServiceException might look like (if you were to define one)
// This helps in catching specific errors from the TokenService.
// class TokenServiceException implements Exception {
//   final String message; // Technical message for logging
//   final String userFriendlyMessage; // Message suitable for showing to the user
//
//   TokenServiceException(this.message, {this.userFriendlyMessage = "Could not retrieve connection token."});
//
//   @override
//   String toString() => 'TokenServiceException: $message';
// }
