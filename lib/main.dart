import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_dotenv/flutter_dotenv.dart';
// NOTE: Ensure using the latest livekit_client version (at least 1.4.0) for better screen sharing support.
// If crashes still occur, check pubspec.yaml and ensure a compatible version is used.
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart'
    show RoomContext, VideoTrackRenderer, MediaDeviceContext;
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import 'dart:io'; // Import for Platform
// import 'package:torch_light/torch_light.dart'; // Remove torch_light import
import './widgets/control_bar.dart';
import './services/token_service.dart';
import 'widgets/agent_status.dart';
import './utils/screen_share_helper.dart'; // Import new helper
import './utils/netrai_speech_helper.dart'; // Import NetraiSpeechHelper
import 'package:flutter_foreground_task/flutter_foreground_task.dart'; // Import foreground task
import 'services/connection_service.dart'; // Import ConnectionService
// Replace import from HistoryScreen to TranscriptionScreen
import './screens/transcription_screen.dart'; // Updated import
// Import other screens needed for routes
import './screens/splash_screen.dart'; // Assuming this path is correct
import './screens/welcome_screen.dart'; // Assuming this path is correct
import './screens/privacy_policy_screen.dart'; // Assuming this path is correct
import './screens/contact_us_screen.dart'; // <-- Add import for ContactUsScreen
import './screens/account_screen.dart'; // <-- Add import for AccountScreen
import './screens/location_screen.dart'; // <-- Add import for LocationScreen
import './widgets/connection_indicator.dart'; // <-- Add import for ConnectionQualityIndicator

// Import Firebase Core
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Import firebase_options.dart
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import './utils/overlay_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

// Load environment variables before starting the app
// This is used to configure the LiveKit sandbox ID for development
void main() async {
  // Ensure Flutter binding is initialized before loading env or running app
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // ---- INITIALIZE FOREGROUND TASK FOR SCREEN SHARING ----
  // Configure foreground task for media projection
  // Void function does not need await
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'netrai_foreground_task',
      channelName: 'NetrAI Screen Sharing',
      channelDescription: 'Notification for screen sharing', // Translated
      channelImportance: NotificationChannelImportance.HIGH,
      priority: NotificationPriority.HIGH,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  // ---------------------------------------------------------

  // ---- INITIALIZE OVERLAY SERVICE FOR FLOATING BUTTON ----
  await OverlayService.initialize();
  // ---------------------------------------------------------

  // ---- INITIALIZE FIREBASE USING FIREBASE OPTIONS ----
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // print("Firebase successfully initialized using DefaultFirebaseOptions."); // Removed less critical log
  } catch (e, st) { // Added stack trace to log
    print("Failed to initialize Firebase: $e\nStack: $st"); // Keep error log
    // Handle error if needed (e.g., show error message)
  }
  // -----------------------------------------------

  runApp(const MyApp());
}

// Main app configuration with light/dark theme support
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap with WithForegroundTask to support screen sharing on Android
    return WithForegroundTask(
      child: MaterialApp(
        title: 'AI Assistant',
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            secondary: Colors.black,
            surface: Colors.white,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            secondary: Colors.white,
            surface: Colors.black,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        // home: const VoiceAssistant(), // This line is replaced
        home: const SplashScreen(), // Initial screen is SplashScreen
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/welcome': (context) => const WelcomeScreen(),
          '/privacy': (context) => const PrivacyPolicyScreen(),
          '/main': (context) =>
              const VoiceAssistant(), // Route to VoiceAssistant in main.dart
          '/location': (context) =>
              const LocationScreen(), // <-- Add route for LocationScreen
          // '/voice': (context) => const VoiceAssistant(), // This route is now the same as /main
        },
      ),
    );
  }
}

/// The main voice assistant screen that manages the LiveKit room connection
/// and displays the status visualizer and control bar
class VoiceAssistant extends StatefulWidget {
  const VoiceAssistant({super.key});
  @override
  State<VoiceAssistant> createState() => _VoiceAssistantState();
}

// Make _VoiceAssistantState a WidgetsBindingObserver
class _VoiceAssistantState extends State<VoiceAssistant>
    with WidgetsBindingObserver {
  // Track current camera position
  CameraPosition _currentCameraPosition = CameraPosition.back;
  // ConnectionService instance
  late ConnectionService _connectionService;
  StreamSubscription? _connectionServiceStatusSubscription;

  // UI specific state
  bool _showAgentVisualizer = false;
  bool _showLoadingIndicator = false;
  double _agentVisualizerOpacity = 0.0;
  String _uiConnectionStatus = 'Initializing...'; // For UI display

  // Flag untuk menyimpan status izin (mungkin masih berguna untuk UI/UX di luar koneksi)
  bool _permissionsGranted = false;
  // Tambahkan semaphore untuk mencegah permintaan izin bersamaan (jika masih ada logika izin di UI)
  bool _isRequestingPermissions = false;
  // Flag untuk melacak apakah sudah mencoba meminta izin (jika masih ada logika izin di UI)
  bool _hasTriedRequestingPermissions = false;

  // Firebase User
  User? _currentUser;
  StreamSubscription<User?>? _authSubscription;

  // Tambahkan EventsListener untuk RoomEvent (untuk event yang tidak ditangani ConnectionService)
  late EventsListener<RoomEvent> _listener;

  // Create a LiveKit Room instance with audio visualization enabled and optimized options
  // This is the main object that manages the connection to LiveKit
  // ConnectionService will manage the room's connection state.
  final room = Room(
    roomOptions: const RoomOptions(
      enableVisualizer: true,
      // Optimize camera options for faster initialization
      defaultCameraCaptureOptions: CameraCaptureOptions(
        cameraPosition: CameraPosition.back,
        maxFrameRate: 20, // Reduced from 24 to 20 for faster initial load
      ),
      // Enable adaptive streaming untuk performa lebih baik
      adaptiveStream: true,
      // Enable dynacast untuk optimasi bandwidth
      dynacast: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    print("[initState] Memulai initState");
    WidgetsBinding.instance
        .addObserver(this); // Tambahkan observer siklus hidup

    // Initialize TokenService (assuming it's available via Provider or direct instantiation)
    // We'll get it from context later if using Provider
    final tokenService = TokenService(); // Or context.read<TokenService>() if already provided higher up

    _connectionService = ConnectionService(
        room,
        tokenService,
        initialServerUrl: dotenv.env['LIVEKIT_URL'] // Pass initial URL if available
    );

    _connectionServiceStatusSubscription = _connectionService.statusStream.listen((statusUpdate) { // Updated to ConnectionStatusUpdate
      if (mounted) {
        setState(() {
          _uiConnectionStatus = statusUpdate.message ?? statusUpdate.state.toString(); // Default message or state name

          switch (statusUpdate.state) {
            case ConnectionStateUpdate.connecting:
            case ConnectionStateUpdate.tokenFetching:
            case ConnectionStateUpdate.reconnecting:
            case ConnectionStateUpdate.permissionRequired:
              _showLoadingIndicator = true;
              break;
            case ConnectionStateUpdate.connected:
              _showAgentVisualizer = true;
              _agentVisualizerOpacity = 1.0;
              _showLoadingIndicator = false;
              break;
            case ConnectionStateUpdate.disconnected:
            case ConnectionStateUpdate.initial: // Or handle as needed
              _showAgentVisualizer = false;
              _agentVisualizerOpacity = 0.0;
              _showLoadingIndicator = false;
              break;
            case ConnectionStateUpdate.error:
              _showAgentVisualizer = false;
              _agentVisualizerOpacity = 0.0;
              _showLoadingIndicator = false;
              _showErrorSnackBar(statusUpdate.errorType, statusUpdate.message);
              break;
          }
        });
      }
    });

    // Firebase Auth User
    _currentUser = FirebaseAuth.instance.currentUser;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });

    // Inisialisasi komunikasi foreground task
    _initForegroundTaskHandler();

    // Set callback untuk NetraiSpeechHelper
    _initNetRAISpeechHelper();

    // Pre-initialize media devices (permissions are handled by ConnectionService initially)
    // _checkPermissionsEarly(); // ConnectionService will handle initial permission checks.
                             // UI might still need a way to re-request if denied.
    _preconfigureMediaDevices();

    // Pra-inisialisasi visualizer audio
    _preInitializeVisualizer();

    // Generate room and participant names (ConnectionService will use them or generate its own)
    // _generateRoomAndParticipantNames(); // ConnectionService handles this if names are passed to connect()

    // Panggil auto connect setelah frame pertama selesai dibangun
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("[addPostFrameCallback] Memulai callback setelah frame pertama");
      // Initiate connection through ConnectionService
      // You can pass specific room/participant names or let ConnectionService use its defaults/generation
      _connectionService.connect(roomName: "default-room", participantName: "default-user");
    });

    // _setupConnectivityMonitor(); // ConnectionService has its own.

    // Inisialisasi event listener FOR UI/non-connection events if any
    _listener = room.createListener();
    _setupUIEventListeners(); // Renamed to reflect it's for UI specific event handling now

    print("[initState] Selesai initState");
  }

  // Inisialisasi foreground task handler untuk screen sharing
  void _initForegroundTaskHandler() {
    // Inisialisasi port komunikasi
    FlutterForegroundTask.initCommunicationPort();

    // Tambahkan callback untuk menerima data dari foreground task
    FlutterForegroundTask.addTaskDataCallback((data) {
      print("[ForegroundTask] Data diterima: $data");
      return;
    });
  }

  // Inisialisasi callback untuk fitur Speak to NetrAI
  void _initNetRAISpeechHelper() {
    NetraiSpeechHelper.setOnSpeakToNetRAICallback((BuildContext context) {
      // Ambil RoomContext dari provider
      final roomCtx = Provider.of<RoomContext>(context, listen: false);

      print("[_initNetRAISpeechHelper] Memulai Speak to NetrAI");
      try {
        // Aktifkan kamera dan mikrofon
        if (roomCtx.room.localParticipant != null) {
          roomCtx.room.localParticipant?.setMicrophoneEnabled(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('NetrAI mendengarkan...'),
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          print("[_initNetRAISpeechHelper] Local participant is null.");
           _showErrorSnackBar(null, "Could not activate microphone: participant not available.");
        }
      } on ProviderNotFoundException catch (e, st) {
        print("[_initNetRAISpeechHelper] Error: ProviderNotFoundException - $e\nStack: $st");
        _showErrorSnackBar(null, "Error setting up NetrAI feature.");
      } catch (e, st) {
        print("[_initNetRAISpeechHelper] Error enabling microphone for NetrAI: $e\nStack: $st");
        _showErrorSnackBar(null, "Could not activate microphone for NetrAI.");
      }
    });
  }

  // _generateRoomAndParticipantNames() // MOVED to ConnectionService or handled by passing params to connect()

  // _checkPermissionsEarly() // MOVED/HANDLED by ConnectionService.
  // UI might need its own _requestPermissions if user needs to trigger it manually.
  // For now, assuming ConnectionService handles initial permission request.

  // Preconfigure media devices to "warm up" WebRTC subsystem
  // This can remain if it's generic and not tied to connection state specifically.
  Future<void> _preconfigureMediaDevices() async {
    print(
        "[_preconfigureMediaDevices] Memulai prekonfigurasi perangkat media...");

    // Hanya lakukan prekonfigurasi jika izin sudah diberikan
    if (!_permissionsGranted) {
      print(
          "[_preconfigureMediaDevices] Izin belum diberikan, melewati prekonfigurasi");
      return;
    }

    try {
      // PERBAIKAN: Gunakan opsi lebih ringan untuk inisialisasi lebih cepat
      final Map<String, dynamic> constraints = {
        'audio': true,
        'video': {
          'facingMode': 'environment', // Start with back camera
          'width': {'ideal': 640}, // Resolusi lebih rendah
          'height': {'ideal': 480},
          'frameRate': {'ideal': 20}, // Frame rate lebih rendah
        }
      };

      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      stream.getTracks().forEach((track) => track.stop());
      print("[_preconfigureMediaDevices] Perangkat media berhasil dikonfigurasi.");
    } on PlatformException catch (e, st) {
      print("[_preconfigureMediaDevices] PlatformException saat prekonfigurasi perangkat media: ${e.message}\nStack: $st");
      // Optionally show a subtle error or log, as this is non-critical.
      // _showErrorSnackBar(ErrorType.mediaInitialization, "Could not pre-initialize media devices.");
    } catch (e, st) {
      print("[_preconfigureMediaDevices] Error saat prekonfigurasi perangkat media: $e\nStack: $st");
      // _showErrorSnackBar(ErrorType.mediaInitialization, "Could not pre-initialize media devices.");
    }
  }

  Future<void> _preInitializeVisualizer() async {
    print("[_preInitializeVisualizer] Memulai pra-inisialisasi visualizer audio");
    try {
      final preVisualListener = room.createListener();
      preVisualListener.on<RoomConnectedEvent>((event) {
        print("[_preInitializeVisualizer] Room terhubung (via service), memastikan visualizer aktif");
      });
      print("[_preInitializeVisualizer] Visualizer audio listener diinisialisasi awal.");
    } catch (e, st) {
      print("[_preInitializeVisualizer] Error saat pra-inisialisasi visualizer: $e\nStack: $st");
      // This is likely non-critical, so logging might be sufficient.
    }
  }

  // Renamed from _setupEventListeners to _setupUIEventListeners
  // This should now only handle UI-specific LiveKit events or other UI events.
  // Connection-related events (connect, disconnect, reconnect attempts) are handled by ConnectionService.
  void _setupUIEventListeners() {
    _listener
      // Example: Listen for local track publication events if UI needs to react
      .on<LocalTrackPublishedEvent>((event) {
        print('[UIEventListener] Local track published: ${event.publication.source}');
        // Update UI if necessary based on track publications
        if (mounted) setState(() {});
      })
      .on<LocalTrackUnpublishedEvent>((event) {
        print('[UIEventListener] Local track unpublished: ${event.publication.source}');
        if (mounted) setState(() {});
      })
      // TAMBAH: Event listener untuk update koneksi (jika masih relevan untuk UI selain status string)
      // .on<TrackSubscriptionPermissionChangedEvent>((event) {
      //   // Update status koneksi berdasarkan status subscription
      //   if (_connectionService.isConnecting && mounted) { // Check against ConnectionService state
      //     // setState(() {
      //     //   _uiConnectionStatus = "Menyiapkan video..."; // Or let ConnectionService handle this
      //     // });
      //   }
      // })
      // PERBAIKAN: Monitor perubahan data room untuk update status koneksi (jika masih relevan untuk UI)
      // .on<ParticipantConnectedEvent>((event) {
      //   // if (_connectionService.isConnecting && mounted) { // Check against ConnectionService state
      //   //   final quality = event.participant.connectionQuality;
      //   //   // setState(() {
      //   //   //   _updateConnectionStatus(quality); // This method was removed
      //   //   // });
      //   // }
      // });
      ; // Add other UI relevant listeners here

    // Timer for polling status that ConnectionService might not cover, if any.
    // For example, if UI needs to react to participant quality independently of general connection status.
    // if (mounted) {
    //   Timer.periodic(const Duration(seconds: 1), (timer) {
    //     if (mounted && room.isConnected && room.localParticipant != null) { // Check room.isConnected directly
    //       final quality = room.localParticipant!.connectionQuality;
    //       // Potentially update some UI element based on quality, if not covered by _uiConnectionStatus
    //     }
    //   });
    // }
  }

  // _updateConnectionStatus // REMOVED (handled by ConnectionService statusStream)
  // _attemptManualReconnect // REMOVED (use _connectionService.connect() or specific reconnect method if added to service)
  // _setupConnectivityMonitor // REMOVED (handled by ConnectionService)
  // _resetReconnectState // REMOVED (handled by ConnectionService)

  @override
  void dispose() {
    print("[dispose] VoiceAssistant disposing.");
    WidgetsBinding.instance.removeObserver(this);

    FlutterForegroundTask.removeTaskDataCallback((data) {});

    _listener.dispose();
    // room.dispose(); // ConnectionService might handle room disposal or it might be here.
                     // For now, assume ConnectionService does not dispose the room passed to it.
                     // If ConnectionService creates the room, it should dispose it.
                     // If room is created here and passed, it should be disposed here.
    room.dispose(); // Keeping room disposal here as it's created in this class.

    _connectionServiceStatusSubscription?.cancel();
    _connectionService.dispose();
    _authSubscription?.cancel();

    // _connectivitySubscription.cancel(); // REMOVED
    // _reconnectTimer?.cancel(); // REMOVED
    // _connectionTimeoutTimer?.cancel(); // REMOVED

    super.dispose();
  }

  // _preFetchConnectionToken // REMOVED (handled by ConnectionService)

  /// Meminta izin yang diperlukan (Kamera & Mikrofon) - Dioptimasi untuk kecepatan
  /// This method might still be useful if the UI wants to allow users to manually trigger permission requests
  /// outside of the initial connection flow managed by ConnectionService.
  Future<bool> _requestPermissions() async {
    print("[_requestPermissions UI] Meminta izin...");

    // Cek apakah sudah pernah meminta izin sebelumnya dan diberikan
    // _permissionsGranted here refers to the local state in _VoiceAssistantState,
    // which might be used to gate UI features, distinct from ConnectionService's internal permission state.
    if (_permissionsGranted) {
      print("[_requestPermissions UI] Izin sudah diberikan sebelumnya (menurut UI state)");
      // return true; // Or re-check with Permission.microphone.status if needed
    }

    if (_isRequestingPermissions) {
      print("[_requestPermissions UI] Ada permintaan izin yang sedang berjalan. Membatalkan permintaan baru.");
      await Future.delayed(const Duration(milliseconds: 500));
      return _permissionsGranted; // Return current UI state for permissions
    }

    _isRequestingPermissions = true;
    _hasTriedRequestingPermissions = true;

    try {
      if (Platform.isAndroid) {
        final NotificationPermission notificationPermission =
            await FlutterForegroundTask.checkNotificationPermission();
        if (notificationPermission != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
        if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      }

      final List<Future<PermissionStatus>> permissionFutures = [
        Permission.camera.request(),
        Permission.microphone.request(),
      ];
      final results = await Future.wait(permissionFutures);
      final cameraGranted = results[0].isGranted;
      final micGranted = results[1].isGranted;

      print("[_requestPermissions UI] Hasil: Kamera=$cameraGranted, Mikrofon=$micGranted");
      
      if (mounted) {
        setState(() {
          _permissionsGranted = cameraGranted && micGranted;
        });
      }

      if (!cameraGranted || !micGranted) {
        debugPrint('[UI] Izin tidak diberikan: Kamera=$cameraGranted, Mikrofon=$micGranted');
        if (mounted) {
          _showErrorSnackBar(ErrorType.permissions, 'Camera and microphone permissions are required.');
        }
      }
      return _permissionsGranted;
    } on PlatformException catch (e, st) {
      print("[_requestPermissions UI] PlatformException: ${e.message}\nStack: $st");
      if (mounted) {
        _showErrorSnackBar(ErrorType.permissions, "Error requesting permissions.");
        setState(() { _permissionsGranted = false; });
      }
      return false;
    }
    catch (e, st) {
      print("[_requestPermissions UI] General Exception: $e\nStack: $st");
      if (mounted) {
        _showErrorSnackBar(ErrorType.general, "An error occurred while requesting permissions.");
        setState(() { _permissionsGranted = false; });
      }
      return false;
    }
    finally {
      _isRequestingPermissions = false;
    }
  }

  void _showErrorSnackBar(ErrorType? errorType, String? defaultMessage) {
    if (!mounted) return;
    String message = defaultMessage ?? "An unknown error occurred.";

    switch (errorType) {
      case ErrorType.network:
        message = "Network error. Please check your internet connection.";
        break;
      case ErrorType.permissions:
        message = defaultMessage ?? "Permissions denied. Please grant necessary permissions in settings.";
        break;
      case ErrorType.server:
        message = "Server error. Please try again later.";
        break;
      case ErrorType.token:
        message = "Failed to retrieve connection token. Please try again.";
        break;
      case ErrorType.timeout:
        message = "The operation timed out. Please try again.";
        break;
      case ErrorType.livekitClient:
        message = "Connection error. Could not connect to the service.";
        break;
      case ErrorType.configuration:
        message = "Configuration error. Please contact support.";
        break;
      case ErrorType.general:
      default: // Handles ErrorType.general and any null errorType
        message = defaultMessage ?? "An unexpected error occurred. Please try again.";
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }


  // _autoConnect // REMOVED (use _connectionService.connect())
  // _setConnectionTimeout // REMOVED (handled by ConnectionService)

  @override
  Widget build(BuildContext context) {
    print("[build] Memulai build UI VoiceAssistant");
    return MultiProvider(
      // Provide the TokenService, RoomContext, and MediaDeviceContext
      providers: [
        ChangeNotifierProvider(create: (context) => TokenService()),
        ChangeNotifierProvider(create: (context) => RoomContext(room: room)),
        // Removed MediaDeviceContext provider for now due to initialization error
        // ChangeNotifierProvider(create: (context) => MediaDeviceContext()),
      ],
      child: Builder(builder: (context) {
        // --- Logika Panggil Auto Connect --- -> MOVED to initState's addPostFrameCallback using _connectionService.connect()
        
        // Listener untuk perubahan connection state (room.addListener)
        // This might be partially handled by ConnectionService's own listeners.
        // If UI needs to react to room.connectionState directly for things not covered by statusStream, keep specific parts.
        // For now, assuming statusStream is comprehensive for UI state.
        // room.addListener(() {
        //   if (mounted) setState(() {}); // Generic update if needed
        // });

        // REMOVE: final roomContext = context.watch<RoomContext>();
        // We will use Consumer/Selector where needed.

        // print('[build] Is Connecting State: $_isConnecting'); // Use _connectionService.isConnecting
        print('[build] Is Connecting State (from service): ${_connectionService.isConnecting}');
        print('[build] UI Connection Status: $_uiConnectionStatus');


        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Layer 1: Video Background (Fill the screen)
              Consumer<RoomContext>(
                builder: (context, roomCtx, _) {
                  final participant = roomCtx.room.localParticipant;
                  LocalVideoTrack? displayTrack;
                  if (participant != null) {
                    try {
                      final screenSharePub = participant.videoTrackPublications.firstWhere(
                        (pub) => pub.source == TrackSource.screenShareVideo && pub.track != null && !pub.muted,
                      );
                      displayTrack = screenSharePub.track as LocalVideoTrack?;
                    } catch (e) {
                      // No active screen share, try camera
                    }
                    if (displayTrack == null) {
                      try {
                        final cameraPub = participant.videoTrackPublications.firstWhere(
                          (pub) => pub.source == TrackSource.camera && pub.track != null && !pub.muted,
                        );
                        displayTrack = cameraPub.track as LocalVideoTrack?;
                      } catch (e) {
                        // No active camera track
                      }
                    }
                  }
                  if (displayTrack != null) {
                    return Positioned.fill(
                      child: VideoTrackRenderer(
                        displayTrack,
                        fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    );
                  }
                  return const SizedBox.shrink(); // Return empty if no track
                },
              ),

              // Layer 1.5: Agent Status dengan AnimatedOpacity (Centered)
              AnimatedOpacity(
                opacity: _agentVisualizerOpacity,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                child: Visibility(
                  visible: _showAgentVisualizer,
                  child: const Align(
                    alignment: Alignment.center,
                    child: AgentStatusWidget(),
                  ),
                ),
              ),

              // Tambahkan Indikator Loading dengan AnimatedOpacity yang lebih informatif
              AnimatedOpacity(
                opacity: _showLoadingIndicator ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Visibility(
                  visible: _showLoadingIndicator,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _uiConnectionStatus, // Use status from ConnectionService
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Layer 2: Custom Header (Positioned at the top, respects SafeArea for content)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                // Remove SafeArea to allow drawing behind status bar
                // child: SafeArea(
                // Apply SafeArea *only* to the header content area -> Now applied via padding
                child: Container(
                  // Add blue background color
                  color: const Color(0xFF3A59D1),
                  // Set explicit height matching AppBar + status bar
                  height: 56.0 +
                      MediaQuery.of(context)
                          .padding
                          .top, // kToolbarHeight + statusBarHeight
                  // Adjust padding: only top for status bar, left/right for content spacing
                  padding: EdgeInsets.only(
                    top:
                        MediaQuery.of(context).padding.top, // Status bar height
                    left: 16.0, // Original horizontal padding
                    right: 16.0, // Original horizontal padding
                    // Remove bottom padding, rely on Container height and Row alignment
                  ),
                  child: Row(
                    // Use spaceBetween to push items to ends
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    // Ensure content is vertically centered within the Row
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left side: Text "View"
                      const Text(
                        'View',
                        style: TextStyle(
                          fontFamily: 'Inter', // Font from Figma
                          color: Colors.white, // Color from Figma
                          fontSize: 18, // Font size from Figma
                          fontWeight: FontWeight.w500, // Weight from Figma
                        ),
                      ),

                      // Right side: Grouped Icons (Help and Avatar)
                      Row(
                        mainAxisSize:
                            MainAxisSize.min, // Keep icons close together
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.help_outline, // Using a standard help icon
                              color: Colors.white, // Color from Figma
                              size: 24, // Adjust size as needed
                            ),
                            onPressed: () {
                              // Navigate to ContactUsScreen
                              print(
                                  "[Header] Question button pressed - Navigating to Contact Us");
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ContactUsScreen(),
                                ),
                              );
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8), // Spacing between icons
                          // Wrap CircleAvatar with GestureDetector (remove const)
                          GestureDetector(
                            onTap: () {
                              // Navigate to AccountScreen
                              print(
                                  "[Header] Avatar pressed - Navigating to Account Screen");
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AccountScreen( // Use _currentUser from state
                                    displayName: _currentUser?.displayName,
                                    email: _currentUser?.email,
                                    photoURL: _currentUser?.photoURL,
                                  ),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 16,
                              backgroundImage: _currentUser?.photoURL != null && _currentUser!.photoURL!.isNotEmpty
                                  ? NetworkImage(_currentUser!.photoURL!)
                                  : null,
                              child: _currentUser?.photoURL == null || _currentUser!.photoURL!.isEmpty
                                  ? const Icon(Icons.person, size: 18)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // )
                ),
              ),

              // Layer 3: Control Bar (Wrapped with Opacity based on connection state)
              Consumer<RoomContext>(
                builder: (context, roomCtx, child) {
                  print(
                      "[build] Building ControlBar wrapper. Connection state: ${roomCtx.room.connectionState}");
                  final isConnected =
                      roomCtx.room.connectionState == ConnectionState.connected;
                  // Use lower opacity when connected, full opacity otherwise
                  final double opacityValue = isConnected ? 0.5 : 1.0;

                  // Return the original Align widget wrapped in Opacity
                  return Opacity(
                    opacity: opacityValue,
                    // The child is the original Align widget structure
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 90.0),
                        // Pastikan ControlBar() dibuat di sini
                        child: ControlBar(),
                      ),
                    ),
                  );
                },
                // child: Align( // Hapus child ini, ControlBar dibuat di dalam builder
                //   alignment: Alignment.bottomCenter,
                //   child: Padding(
                //     padding: const EdgeInsets.only(bottom: 90.0),
                //     child: ControlBar(), // ControlBar instance
                //   ),
                // ),
              ),

              // Layer 4: New Bottom Center Button ("Speak to NetrAI")
              Positioned(
                bottom: 90, // Adjust position relative to BottomAppBar
                left: 0,
                right: 0,
                child: Consumer<RoomContext>(
                  // Wrap with Consumer
                  builder: (context, roomCtx, child) {
                    // Get connection and mic state from roomCtx
                    final isConnected = roomCtx.room.connectionState ==
                        ConnectionState.connected;
                    final isMicEnabled =
                        roomCtx.localParticipant?.isMicrophoneEnabled() ??
                            false;
                    // Use ConnectionService's state for enabling button
                    final bool isButtonEnabled = roomCtx.room.connectionState == ConnectionState.connected &&
                                                 !_connectionService.isConnecting; 

                    // Return the Center containing the ElevatedButton
                    return Center(
                      child: ElevatedButton.icon(
                        // Change icon based on mic state when connected
                        icon: Icon(
                          (isButtonEnabled && isMicEnabled)
                              ? Icons.mic_off
                              : Icons.mic,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Speak to NetrAI',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500),
                        ),
                        // Enable button only when connected and not auto-connecting
                        onPressed: isButtonEnabled
                            ? () async {
                                print(
                                    "[Center Button Mic] Tombol mic ditekan.");
                                final participant =
                                    roomCtx.room.localParticipant;
                                if (participant != null) {
                                  try {
                                    final newMicState = !isMicEnabled;
                                    await participant
                                        .setMicrophoneEnabled(newMicState);
                                    print(
                                        "[Center Button Mic] Mikrofon di-toggle ke: $newMicState");
                                  } catch (e) {
                                    print(
                                        "[Center Button Mic] Error saat toggle mikrofon: $e");
                                    // Ensure mounted check before showing SnackBar
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Tidak dapat toggle mikrofon.')),
                                      );
                                    }
                                  }
                                } else {
                                  print(
                                      "[Center Button Mic] Partisipan lokal null saat tombol ditekan.");
                                }
                              }
                            : null, // Disable button if not connected or auto-connecting
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isButtonEnabled
                              ? const Color(0xFF406AFF) // Original blue
                              : Colors.grey, // Grey when disabled
                          shape: const StadiumBorder(), // Pill shape
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Layer 5: New Right FABs (Arrow Up and Document/Chat)
              Positioned(
                bottom: 90, // Align with the new center button
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'arrow_up_fab',
                      mini: true, // Smaller FABs if desired
                      onPressed: () async {
                        // Jadikan async
                        print("[FAB ArrowUp] Tombol Screen Share ditekan.");
                        // Dapatkan RoomContext
                        final roomCtx = context.read<RoomContext>();
                        final participant = roomCtx.room.localParticipant;

                        if (participant != null) {
                          // Gunakan ScreenShareHelper untuk menangani screen sharing
                          await ScreenShareHelper.toggleScreenSharing(
                              context, participant);
                        } else {
                          print(
                              "[FAB ArrowUp] Partisipan lokal null saat tombol ditekan.");
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Partisipan tidak ditemukan.')),
                            );
                          }
                        }
                      },
                      backgroundColor: const Color(0xFF324EFF),
                      child: const Icon(Icons.screen_share_outlined,
                          color: Colors.white), // Ganti ikon ke screen share
                    ),
                    const SizedBox(height: 16),
                    Consumer<RoomContext>( // Wrap FAB with Consumer for displayTrack and screenSharePub
                      builder: (context, roomCtx, _) {
                        final participant = roomCtx.room.localParticipant;
                        LocalVideoTrack? displayTrack;
                        LocalTrackPublication<LocalVideoTrack>? screenSharePub;

                        if (participant != null) {
                          try {
                            screenSharePub = participant.videoTrackPublications.firstWhere(
                              (pub) => pub.source == TrackSource.screenShareVideo && pub.track != null && !pub.muted,
                            );
                            displayTrack = screenSharePub.track as LocalVideoTrack?;
                          } catch (e) { /* No screen share */ }
                          if (displayTrack == null) {
                            try {
                              final cameraPub = participant.videoTrackPublications.firstWhere(
                                (pub) => pub.source == TrackSource.camera && pub.track != null && !pub.muted,
                              );
                              displayTrack = cameraPub.track as LocalVideoTrack?;
                            } catch (e) { /* No camera */ }
                          }
                        }

                        return FloatingActionButton(
                          heroTag: 'camera_fab',
                          mini: true,
                          onPressed: (displayTrack != null &&
                                  screenSharePub == null &&
                                  !_connectionService.isConnecting)
                              ? () async {
                                  print("[FAB Camera] Tombol ganti kamera ditekan.");
                                  // Use context.read<RoomContext>() for actions if needed, or pass participant
                                  final currentParticipant = context.read<RoomContext>().room.localParticipant;
                                  if (currentParticipant == null) return;

                                  LocalVideoTrack? cameraTrackToRestart;
                                  try {
                                    final currentCameraPub = currentParticipant.videoTrackPublications.firstWhere(
                                      (pub) => pub.source == TrackSource.camera && pub.track is LocalVideoTrack && pub.track?.mediaStreamTrack.enabled == true && !pub.muted,
                                    );
                                    cameraTrackToRestart = currentCameraPub.track as LocalVideoTrack?;
                                  } catch (e) {
                                    print("[FAB Camera] Tidak menemukan track kamera aktif untuk di-restart: $e");
                                  }

                                  if (cameraTrackToRestart != null) {
                                    try {
                                      final newPosition = (_currentCameraPosition == CameraPosition.front)
                                          ? CameraPosition.back
                                          : CameraPosition.front;
                                      final newOptions = CameraCaptureOptions(cameraPosition: newPosition);
                                      await cameraTrackToRestart.restartTrack(newOptions);
                                      if (mounted) {
                                        setState(() { _currentCameraPosition = newPosition; });
                                      final newOptions = CameraCaptureOptions(cameraPosition: newPosition);
                                      await cameraTrackToRestart.restartTrack(newOptions);
                                      if (mounted) {
                                        setState(() { _currentCameraPosition = newPosition; });
                                        ScaffoldMessenger.of(context).showSnackBar( // Keep specific SnackBar for success
                                          SnackBar(content: Text('Mengganti kamera ke ${newPosition.name}')),
                                        );
                                      }
                                    } catch (e, st) {
                                      print("[FAB Camera] Error restarting track: $e\nStack: $st");
                                      if (mounted) {
                                        _showErrorSnackBar(ErrorType.general, 'Could not switch camera.');
                                      }
                                    }
                                  } else {
                                     if (mounted) {
                                        _showErrorSnackBar(ErrorType.general, 'Camera track not found or not ready.');
                                      }
                                  }
                                }
                              : null,
                          backgroundColor: (displayTrack != null &&
                                  screenSharePub == null &&
                                  !_connectionService.isConnecting)
                              ? const Color(0xFF324EFF)
                              : Colors.grey,
                          child: const Icon(Icons.camera_alt_outlined,
                        );
                      }
                    ),
                  ],
                ),
              ),

              // TAMBAHKAN: Indikator Kualitas Koneksi di pojok kiri bawah
              Positioned(
                bottom: 80, // Posisikan di atas BottomAppBar
                left: 16, // Posisikan di sisi kiri dengan jarak 16
                child: Consumer<RoomContext>(
                  builder: (context, roomCtx, child) {
                    // Dapatkan kualitas koneksi dari participant
                    final connectionQuality =
                        roomCtx.localParticipant?.connectionQuality ??
                            ConnectionQuality.unknown;

                    // Tampilkan indikator koneksi
                    return ConnectionQualityIndicator(
                      connectionQuality: connectionQuality,
                    );
                  },
                ),
              ),
            ],
          ),

          // Keep BottomAppBar
          bottomNavigationBar: BottomAppBar(
            color: const Color(0xFF3A59D1), // Changed color to Figma blue
            elevation: 8.0,
            // Removed shape and notchMargin
            height: 70.0,
            child: Row(
              // Change mainAxisAlignment to spaceEvenly for better distribution
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                // Keep 'View' item (using visibility icon, marked as active)
                _buildNavItem(Icons.visibility_outlined, 'View', true),
                // Add 'History' item (using history icon, marked as inactive)
                // Wrap with GestureDetector for tap functionality
                GestureDetector(
                  onTap: () {
                    print("[BottomNav] Tombol History ditekan.");
                    // Get RoomContext before navigating, similar to FAB
                    final roomCtx = context.read<RoomContext>();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // Provide the existing RoomContext to the new route
                        builder: (_) =>
                            ChangeNotifierProvider<RoomContext>.value(
                          value: roomCtx,
                          child: const TranscriptionScreen(),
                        ),
                      ),
                    );
                  },
                  // Make the container transparent for hit testing
                  child: Container(
                    color: Colors
                        .transparent, // Ensures the tap area covers the SizedBox
                    child:
                        _buildNavItem(Icons.history_outlined, 'History', false),
                  ),
                ),
                // Removed other items
              ],
            ),
          ),
        );
      }),
    );
  }

  // Helper widget to build navigation items
  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    // Updated colors based on Figma active/inactive states
    final color = isActive ? Colors.white : const Color(0xFFB5C0ED);
    // Wrap with Padding for better spacing control if needed, but SizedBox width might be enough
    return SizedBox(
      // Use SizedBox for consistent width
      // Consider adjusting width if needed based on screen size or design specifics
      width: 80, // Slightly reduced width to give more space
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center, // Center content vertically
        // Ensure minimum size to prevent text overflow issues
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reduce icon size
          Icon(icon, color: color, size: 24),
          // Reduce space between icon and text
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12, // Keep font size
              fontWeight: FontWeight
                  .w500, // Changed font weight to 500 (medium) for all states
            ),
            overflow: TextOverflow.ellipsis, // Prevent overflow
          ),
        ],
      ),
    );
  }

  // Override didChangeAppLifecycleState untuk merespons saat app kembali dari background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print("[didChangeAppLifecycleState] State berubah: $state");

    // Periksa apakah screen sharing aktif ketika aplikasi kembali ke foreground
    if (state == AppLifecycleState.resumed) {
      _checkAndRestoreScreenSharing();
    }
  }

  // Memeriksa dan mengembalikan floating button jika screen sharing aktif
  void _checkAndRestoreScreenSharing() {
    print("[_checkAndRestoreScreenSharing] Memeriksa status screen sharing...");

    // Dapatkan RoomContext
    try {
      final roomCtx = Provider.of<RoomContext>(context, listen: false);

      // Cek apakah room terhubung dan participant tersedia
      if (roomCtx.room.connectionState == ConnectionState.connected &&
          roomCtx.room.localParticipant != null) {
        // Cek apakah screen share aktif
        final isScreenShareActive =
            roomCtx.room.localParticipant!.isScreenShareEnabled();
        print(
            "[_checkAndRestoreScreenSharing] Status screen sharing: $isScreenShareActive");

        if (isScreenShareActive) {
          // Tampilkan kembali floating button jika screen sharing masih aktif
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print(
                  "[_checkAndRestoreScreenSharing] Menampilkan kembali floating button");
              // Gunakan helper untuk menampilkan floating button
              ScreenShareHelper.showFloatingButton(
                  context, roomCtx.room.localParticipant!);
            }
          });
        }
      }
    } catch (e) {
      print("[_checkAndRestoreScreenSharing] Error: $e");
    }
  }
}

class _CustomHeader extends StatelessWidget {
  final User? currentUser;

  const _CustomHeader({this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF3A59D1),
      height: 56.0 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16.0,
        right: 16.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'View',
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountScreen(
                        displayName: currentUser?.displayName,
                        email: currentUser?.email,
                        photoURL: currentUser?.photoURL,
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: currentUser?.photoURL != null && currentUser!.photoURL!.isNotEmpty
                      ? NetworkImage(currentUser!.photoURL!)
                      : null,
                  child: currentUser?.photoURL == null || currentUser!.photoURL!.isEmpty
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: const Color(0xFF3A59D1),
      elevation: 8.0,
      height: 70.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _buildNavItem(Icons.visibility_outlined, 'View', true, context), // Pass context
          GestureDetector(
            onTap: () {
              print("[BottomNav] Tombol History ditekan.");
              final roomCtx = context.read<RoomContext>();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider<RoomContext>.value(
                    value: roomCtx,
                    child: const TranscriptionScreen(),
                  ),
                ),
              );
            },
            child: Container(
              color: Colors.transparent,
              child: _buildNavItem(Icons.history_outlined, 'History', false, context), // Pass context
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, BuildContext context) { // Accept context
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
                          color: Colors.white),
                    ),
                  ],
                ),
              ),

              // TAMBAHKAN: Indikator Kualitas Koneksi di pojok kiri bawah
              Positioned(
                bottom: 80, // Posisikan di atas BottomAppBar
                left: 16, // Posisikan di sisi kiri dengan jarak 16
                child: Consumer<RoomContext>(
                  builder: (context, roomCtx, child) {
                    // Dapatkan kualitas koneksi dari participant
                    final connectionQuality =
                        roomCtx.localParticipant?.connectionQuality ??
                            ConnectionQuality.unknown;

                    // Tampilkan indikator koneksi
                    return ConnectionQualityIndicator(
                      connectionQuality: connectionQuality,
                    );
                  },
                ),
              ),
            ],
          ),

          // Keep BottomAppBar
          bottomNavigationBar: BottomAppBar(
            color: const Color(0xFF3A59D1), // Changed color to Figma blue
            elevation: 8.0,
            // Removed shape and notchMargin
            height: 70.0,
            child: Row(
              // Change mainAxisAlignment to spaceEvenly for better distribution
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                // Keep 'View' item (using visibility icon, marked as active)
                _buildNavItem(Icons.visibility_outlined, 'View', true),
                // Add 'History' item (using history icon, marked as inactive)
                // Wrap with GestureDetector for tap functionality
                GestureDetector(
                  onTap: () {
                    print("[BottomNav] Tombol History ditekan.");
                    // Get RoomContext before navigating, similar to FAB
                    final roomCtx = context.read<RoomContext>();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // Provide the existing RoomContext to the new route
                        builder: (_) =>
                            ChangeNotifierProvider<RoomContext>.value(
                          value: roomCtx,
                          child: const TranscriptionScreen(),
                        ),
                      ),
                    );
                  },
                  // Make the container transparent for hit testing
                  child: Container(
                    color: Colors
                        .transparent, // Ensures the tap area covers the SizedBox
                    child:
                        _buildNavItem(Icons.history_outlined, 'History', false),
                  ),
                ),
                // Removed other items
              ],
            ),
          ),
        );
      }),
    );
  }

  // Helper widget to build navigation items
  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    // Updated colors based on Figma active/inactive states
    final color = isActive ? Colors.white : const Color(0xFFB5C0ED);
    // Wrap with Padding for better spacing control if needed, but SizedBox width might be enough
    return SizedBox(
      // Use SizedBox for consistent width
      // Consider adjusting width if needed based on screen size or design specifics
      width: 80, // Slightly reduced width to give more space
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center, // Center content vertically
        // Ensure minimum size to prevent text overflow issues
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reduce icon size
          Icon(icon, color: color, size: 24),
          // Reduce space between icon and text
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12, // Keep font size
              fontWeight: FontWeight
                  .w500, // Changed font weight to 500 (medium) for all states
            ),
            overflow: TextOverflow.ellipsis, // Prevent overflow
          ),
        ],
      ),
    );
  }

  // Override didChangeAppLifecycleState untuk merespons saat app kembali dari background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print("[didChangeAppLifecycleState] State berubah: $state");

    // Periksa apakah screen sharing aktif ketika aplikasi kembali ke foreground
    if (state == AppLifecycleState.resumed) {
      _checkAndRestoreScreenSharing();
    }
  }

  // Memeriksa dan mengembalikan floating button jika screen sharing aktif
  void _checkAndRestoreScreenSharing() {
    print("[_checkAndRestoreScreenSharing] Memeriksa status screen sharing...");

    // Dapatkan RoomContext
    try {
      final roomCtx = Provider.of<RoomContext>(context, listen: false);

      // Cek apakah room terhubung dan participant tersedia
      if (roomCtx.room.connectionState == ConnectionState.connected &&
          roomCtx.room.localParticipant != null) {
        // Cek apakah screen share aktif
        final isScreenShareActive =
            roomCtx.room.localParticipant!.isScreenShareEnabled();
        print(
            "[_checkAndRestoreScreenSharing] Status screen sharing: $isScreenShareActive");

        if (isScreenShareActive) {
          // Tampilkan kembali floating button jika screen sharing masih aktif
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print(
                  "[_checkAndRestoreScreenSharing] Menampilkan kembali floating button");
              // Gunakan helper untuk menampilkan floating button
            ScreenShareHelper.showFloatingButton(context, roomCtx.room.localParticipant!);
            }
          });
        }
      }
    } on ProviderNotFoundException catch (e, st) {
        print("[_checkAndRestoreScreenSharing] ProviderNotFoundException: $e\nStack: $st");
        // This might happen if the widget is not in the tree, or RoomContext is not available.
        // Usually, this shouldn't show a user-facing error unless it's unexpected.
    }
    catch (e, st) {
      print("[_checkAndRestoreScreenSharing] Error: $e\nStack: $st");
      // Potentially show a generic error if this check is critical and fails unexpectedly.
      // _showErrorSnackBar(ErrorType.general, "Could not check screen sharing status.");
    }
  }
}
