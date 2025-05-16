import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_dotenv/flutter_dotenv.dart';
// NOTE: Pastikan menggunakan livekit_client versi terbaru (minimal 1.4.0) untuk dukungan screen sharing yang lebih baik
// Jika masih terjadi crash, periksa pubspec.yaml dan pastikan menggunakan versi yang kompatibel
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart'
    show RoomContext, VideoTrackRenderer, MediaDeviceContext;
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Tambahkan import ini
import 'dart:io'; // Import untuk Platform
// import 'package:torch_light/torch_light.dart'; // Hapus import torch_light
import './widgets/control_bar.dart';
import './services/token_service.dart';
import 'widgets/agent_status.dart';
import './utils/screen_share_helper.dart'; // Import helper baru
import './utils/netrai_speech_helper.dart'; // Import NetraiSpeechHelper
import 'package:flutter_foreground_task/flutter_foreground_task.dart'; // Import foreground task
// Ganti impor dari HistoryScreen ke TranscriptionScreen
import './screens/transcription_screen.dart'; // Updated import
// Import layar lain yang diperlukan untuk routes
import './screens/splash_screen.dart'; // Asumsi path ini benar
import './screens/welcome_screen.dart'; // Asumsi path ini benar
import './screens/privacy_policy_screen.dart'; // Asumsi path ini benar
import './screens/contact_us_screen.dart'; // <-- Add import for ContactUsScreen
import './screens/account_screen.dart'; // <-- Add import for AccountScreen
import './screens/location_screen.dart'; // <-- Add import for LocationScreen
import './widgets/connection_indicator.dart'; // <-- Tambahkan import untuk ConnectionQualityIndicator

// Import Firebase Core
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Import firebase_options.dart
import 'package:firebase_auth/firebase_auth.dart'; // Tambahkan impor ini
import './utils/overlay_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

// Load environment variables before starting the app
// This is used to configure the LiveKit sandbox ID for development
void main() async {
  // Pastikan Flutter binding diinisialisasi sebelum memuat env atau menjalankan app
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // ---- INISIALISASI FOREGROUND TASK UNTUK SCREEN SHARING ----
  // Konfigurasi foreground task untuk media projection
  // Void function tidak perlu await
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'netrai_foreground_task',
      channelName: 'NetrAI Screen Sharing',
      channelDescription: 'Notification untuk berbagi layar',
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

  // ---- INISIALISASI OVERLAY SERVICE UNTUK FLOATING BUTTON ----
  await OverlayService.initialize();
  // ---------------------------------------------------------

  // ---- INISIALISASI FIREBASE MENGGUNAKAN FIREBASE OPTIONS ----
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print(
        "Firebase berhasil diinisialisasi menggunakan DefaultFirebaseOptions.");
  } catch (e) {
    print("Gagal inisialisasi Firebase: $e");
    // Handle error jika perlu (misalnya tampilkan pesan error)
  }
  // -----------------------------------------------

  runApp(const MyApp());
}

// Main app configuration with light/dark theme support
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Bungkus dengan WithForegroundTask untuk mendukung screen sharing di Android
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
        // home: const VoiceAssistant(), // Baris ini diganti
        home: const SplashScreen(), // Layar awal adalah SplashScreen
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/welcome': (context) => const WelcomeScreen(),
          '/privacy': (context) => const PrivacyPolicyScreen(),
          '/main': (context) =>
              const VoiceAssistant(), // Rute ke VoiceAssistant di main.dart
          '/location': (context) =>
              const LocationScreen(), // <-- Add route for LocationScreen
          // '/voice': (context) => const VoiceAssistant(), // Rute ini sekarang sama dengan /main
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

// Jadikan _VoiceAssistantState sebagai WidgetsBindingObserver
class _VoiceAssistantState extends State<VoiceAssistant>
    with WidgetsBindingObserver {
  // Track current camera position
  CameraPosition _currentCameraPosition = CameraPosition.back;
  // State untuk melacak proses koneksi otomatis
  bool _isConnecting = false;
  // State untuk menandai bahwa widget siap memulai koneksi (setelah frame pertama)
  bool _isReadyToConnect = false;
  // Flag untuk menyimpan status izin
  bool _permissionsGranted = false;
  // Cache untuk token dan URL server
  String? _cachedToken;
  String? _cachedServerUrl;
  DateTime? _tokenExpiryTime;
  // Variabel untuk menyimpan nama room dan participant terakhir
  String? _lastRoomName;
  String? _lastParticipantName;

  // TAMBAH: Variabel untuk animasi fade transisi
  bool _showAgentVisualizer = false;
  bool _showLoadingIndicator = false;
  double _agentVisualizerOpacity = 0.0;

  // TAMBAH: Variabel untuk status koneksi yang informatif
  String _connectionStatus = 'Mempersiapkan koneksi...';
  // TAMBAH: Timer untuk timeout koneksi
  Timer? _connectionTimeoutTimer;

  // Tambahkan semaphore untuk mencegah permintaan izin bersamaan
  bool _isRequestingPermissions = false;
  // Flag untuk melacak apakah sudah mencoba meminta izin
  bool _hasTriedRequestingPermissions = false;

  // Tambahkan variabel-variabel baru untuk monitoring koneksi
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _wasConnectedBefore = false;
  bool _isInternetAvailable = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  // Tambahkan EventsListener untuk RoomEvent
  late EventsListener<RoomEvent> _listener;

  // Create a LiveKit Room instance with audio visualization enabled and optimized options
  // This is the main object that manages the connection to LiveKit
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

    // Inisialisasi komunikasi foreground task
    _initForegroundTaskHandler();

    // Set callback untuk NetraiSpeechHelper
    _initNetRAISpeechHelper();

    // Pre-initialize media devices and check permissions early
    _checkPermissionsEarly();
    _preconfigureMediaDevices();

    // Pra-inisialisasi visualizer audio
    _preInitializeVisualizer();

    // Generate room and participant names once and reuse them
    _generateRoomAndParticipantNames();

    // TAMBAH: Pre-fetch token jika memungkinkan
    _preFetchConnectionToken();

    // Panggil auto connect setelah frame pertama selesai dibangun
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("[addPostFrameCallback] Memulai callback setelah frame pertama");
      print("[addPostFrameCallback] Menandai siap untuk koneksi...");
      if (mounted) {
        setState(() {
          _isReadyToConnect = true;
        });
      }
    });

    // Inisialisasi koneksi monitoring
    _setupConnectivityMonitor();

    // Inisialisasi event listener
    _listener = room.createListener();
    // Setup event listeners
    _setupEventListeners();

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

      // Logika untuk mengaktifkan fitur NetrAI
      print("[_initNetRAISpeechHelper] Memulai Speak to NetrAI");

      // Aktifkan kamera dan mikrofon
      if (roomCtx.room.localParticipant != null) {
        // Pastikan mikrofon aktif
        roomCtx.room.localParticipant?.setMicrophoneEnabled(true);

        // Bisa menambahkan logika lain sesuai kebutuhan fitur NetrAI
        // Misalnya mengirimkan sinyal ke server bahwa pengguna ingin berbicara ke NetrAI

        // Tunjukkan pesan untuk pengguna
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NetrAI mendengarkan...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  // Generate random room and participant names once
  void _generateRoomAndParticipantNames() {
    _lastRoomName =
        'room-${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}';
    _lastParticipantName =
        'user-${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}';
    print(
        "[_generateRoomAndParticipantNames] Generated Room: $_lastRoomName, Participant: $_lastParticipantName");
  }

  // Pre-check permissions early to avoid delay during connect
  Future<void> _checkPermissionsEarly() async {
    print("[_checkPermissionsEarly] Memeriksa izin di awal aplikasi...");

    // Cek apakah sudah pernah meminta izin sebelumnya
    if (_hasTriedRequestingPermissions) {
      print(
          "[_checkPermissionsEarly] Sudah pernah meminta izin sebelumnya, melewati permintaan ulang");
      return;
    }

    _permissionsGranted = await _requestPermissions();
    print(
        "[_checkPermissionsEarly] Hasil pemeriksaan izin awal: $_permissionsGranted");
  }

  // Preconfigure media devices to "warm up" WebRTC subsystem
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

      // Get and release media stream to "warm up" the subsystem
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      // Langsung lepaskan stream setelah inisialisasi
      stream.getTracks().forEach((track) => track.stop());

      print(
          "[_preconfigureMediaDevices] Perangkat media berhasil dikonfigurasi untuk koneksi lebih cepat");
    } catch (e) {
      print(
          "[_preconfigureMediaDevices] Error saat prekonfigurasi perangkat media: $e");
      // Continue without preconfiguration - no need to show error
    }
  }

  // Metode baru untuk pra-inisialisasi visualizer
  Future<void> _preInitializeVisualizer() async {
    print(
        "[_preInitializeVisualizer] Memulai pra-inisialisasi visualizer audio");
    try {
      // Pastikan visualizer diaktifkan melalui RoomOptions
      // Opsi ini sudah diatur saat inisialisasi Room di bagian atas class ini:
      // RoomOptions(enableVisualizer: true)

      // Aktifkan audio level observers lebih awal
      // LiveKit menggunakan EventsListener internal untuk visualizer
      // Ciptakan dan tambahkan listener pada Room
      final preVisualListener = room.createListener();

      // Dengarkan event koneksi untuk memastikan visualizer bekerja saat terhubung
      preVisualListener.on<RoomConnectedEvent>((event) {
        print(
            "[_preInitializeVisualizer] Room terhubung, memastikan visualizer aktif");
        // LiveKit akan otomatis memulai visualizer setelah terhubung
      });

      print(
          "[_preInitializeVisualizer] Visualizer audio listener diinisialisasi awal");
    } catch (e) {
      print(
          "[_preInitializeVisualizer] Error saat pra-inisialisasi visualizer: $e");
      // Lanjutkan meskipun ada error pada pra-inisialisasi
    }
  }

  void _setupEventListeners() {
    _listener
      ..on<RoomDisconnectedEvent>((event) {
        print('[RoomListener] Room disconnected: ${event.reason}');
        if (_wasConnectedBefore && _isInternetAvailable) {
          print(
              '[RoomListener] Terdeteksi koneksi terputus, akan mencoba reconnect otomatis');
          _wasConnectedBefore = true;
        }
      })
      ..on<RoomAttemptReconnectEvent>((event) {
        print(
            '[RoomListener] Mencoba reconnect ${event.attempt}/${event.maxAttemptsRetry}, '
            '(${event.nextRetryDelaysInMs}ms delay sampai percobaan berikutnya)');

        // Reset timer reconnect jika ada
        if (_reconnectTimer != null && _reconnectTimer!.isActive) {
          _reconnectTimer!.cancel();
        }

        // Jika sudah mencapai batas percobaan, berhenti mencoba
        if (event.attempt >= _maxReconnectAttempts) {
          print("[RoomListener] Mencapai batas maksimum percobaan reconnect");
          _resetReconnectState();
          return;
        }

        // Jika masih bisa mencoba dan internet tersedia
        if (_isInternetAvailable && mounted) {
          setState(() {
            _reconnectAttempts = event.attempt;
          });

          // Jika koneksi gagal setelah beberapa detik, coba manual reconnect
          _reconnectTimer =
              Timer(Duration(milliseconds: event.nextRetryDelaysInMs), () {
            if (mounted && room.connectionState != ConnectionState.connected) {
              print(
                  "[RoomListener] Timer reconnect triggered, mencoba manual reconnect");
              _attemptManualReconnect();
            }
          });
        }
      })
      ..on<RoomConnectedEvent>((event) {
        print('[RoomListener] Room connected');
        _wasConnectedBefore = true;
        _resetReconnectState();
      })
      // TAMBAH: Event listener untuk update koneksi
      ..on<TrackSubscriptionPermissionChangedEvent>((event) {
        // Update status koneksi berdasarkan status subscription
        if (_isConnecting && mounted) {
          setState(() {
            _connectionStatus = "Menyiapkan video...";
          });
        }
      })
      // PERBAIKAN: Monitor perubahan data room untuk update status koneksi
      ..on<ParticipantConnectedEvent>((event) {
        if (_isConnecting && mounted) {
          // Jika participant terhubung, periksa kualitas koneksi
          final quality = event.participant.connectionQuality;
          setState(() {
            _updateConnectionStatus(quality);
          });
        }
      });

    // Tambahkan timer untuk polling status koneksi
    if (mounted) {
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isConnecting && room.localParticipant != null) {
          final quality = room.localParticipant!.connectionQuality;
          setState(() {
            _updateConnectionStatus(quality);
          });
        } else if (!_isConnecting) {
          timer.cancel();
        }
      });
    }
  }

  // Helper untuk memperbarui status koneksi berdasarkan quality
  void _updateConnectionStatus(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.unknown:
        _connectionStatus = "Menghubungkan...";
        break;
      case ConnectionQuality.poor:
        _connectionStatus = "Koneksi lambat...";
        break;
      case ConnectionQuality.good:
      case ConnectionQuality.excellent:
        _connectionStatus = "Hampir siap...";
        break;
      default: // Menangani case ConnectionQuality.lost dan nilai baru yang mungkin ditambahkan
        _connectionStatus = "Koneksi tidak stabil...";
        break;
    }
  }

  // Metode untuk mencoba manual reconnect jika auto reconnect LiveKit gagal
  void _attemptManualReconnect() {
    if (mounted &&
        !_isConnecting &&
        room.connectionState != ConnectionState.connected) {
      final roomCtx = Provider.of<RoomContext>(context, listen: false);
      final tkService = Provider.of<TokenService>(context, listen: false);

      print("[RoomListener] Mencoba manual reconnect");
      _autoConnect(roomCtx, tkService);
    }
  }

  // Tambahkan metode ini untuk monitoring koneksi
  void _setupConnectivityMonitor() {
    print("[_setupConnectivityMonitor] Memulai monitoring koneksi internet");

    // Cek status koneksi awal
    Connectivity().checkConnectivity().then((results) {
      final bool isConnected = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);
      if (mounted) {
        setState(() {
          _isInternetAvailable = isConnected;
        });
      }
      print(
          "[_setupConnectivityMonitor] Status koneksi awal: $_isInternetAvailable (results: $results)");
    });

    // Monitor perubahan koneksi
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final bool isConnected = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      print(
          "[Connectivity] Status koneksi berubah: $results (Internet ${isConnected ? 'tersedia' : 'tidak tersedia'})");

      if (mounted) {
        setState(() {
          _isInternetAvailable = isConnected;
        });
      }

      // Jika internet terputus, catat status koneksi sebelumnya
      if (!isConnected) {
        print(
            "[Connectivity] Internet terputus, mencatat bahwa sebelumnya terhubung");
        // Catat bahwa sebelumnya terhubung jika room memang terhubung
        _wasConnectedBefore = room.connectionState == ConnectionState.connected;
      }
      // Jika internet kembali tersedia dan sebelumnya terhubung, perlu mencoba reconnect
      else if (_wasConnectedBefore &&
          room.connectionState != ConnectionState.connected) {
        print(
            "[Connectivity] Internet kembali tersedia dan sebelumnya terhubung");
        // LiveKit akan mencoba reconnect otomatis melalui RoomAttemptReconnectEvent
      }
    });
  }

  // Metode untuk reset status reconnect
  void _resetReconnectState() {
    _reconnectAttempts = 0;
    _wasConnectedBefore = room.connectionState == ConnectionState.connected;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      _reconnectTimer!.cancel();
    }
  }

  @override
  void dispose() {
    print("[dispose] VoiceAssistant disposing.");
    WidgetsBinding.instance.removeObserver(this); // Hapus observer siklus hidup

    // Hapus callback foreground task
    FlutterForegroundTask.removeTaskDataCallback((data) {});

    // Dispose room dan listener
    _listener.dispose();
    room.dispose();

    // Batalkan subscription connectivity
    _connectivitySubscription.cancel();

    // Batalkan timer reconnect jika aktif
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      _reconnectTimer!.cancel();
    }

    // TAMBAH: Batalkan timer timeout koneksi jika aktif
    if (_connectionTimeoutTimer != null && _connectionTimeoutTimer!.isActive) {
      _connectionTimeoutTimer!.cancel();
    }

    super.dispose();
  }

  // TAMBAH: Method untuk pre-fetch token koneksi
  Future<void> _preFetchConnectionToken() async {
    print("[_preFetchConnectionToken] Mencoba pre-fetch token...");
    if (_lastRoomName != null && _lastParticipantName != null) {
      try {
        // Kita tidak bisa langsung menggunakan Provider di initState,
        // jadi kita jadwalkan dengan Future.microtask
        Future.microtask(() async {
          if (!mounted) return;
          final tkService = Provider.of<TokenService>(context, listen: false);
          final connectionDetails = await tkService.fetchConnectionDetails(
            roomName: _lastRoomName!,
            participantName: _lastParticipantName!,
          );

          if (connectionDetails != null && mounted) {
            // Cache token dan URL server
            _cachedToken = connectionDetails.participantToken;
            _cachedServerUrl = connectionDetails.serverUrl;
            // Set waktu kedaluwarsa token (misalnya 1 jam)
            _tokenExpiryTime = DateTime.now().add(const Duration(hours: 1));
            print("[_preFetchConnectionToken] Token berhasil di-cache");
          }
        });
      } catch (e) {
        print("[_preFetchConnectionToken] Error saat pre-fetch token: $e");
        // Lanjutkan tanpa token cache - akan diambil saat connect
      }
    }
  }

  /// Meminta izin yang diperlukan (Kamera & Mikrofon) - Dioptimasi untuk kecepatan
  Future<bool> _requestPermissions() async {
    print("[_requestPermissions] Meminta izin...");

    // Cek apakah sudah pernah meminta izin sebelumnya dan diberikan
    if (_permissionsGranted) {
      print("[_requestPermissions] Izin sudah diberikan sebelumnya");
      return true;
    }

    // Cek apakah ada permintaan izin yang sedang berjalan
    if (_isRequestingPermissions) {
      print(
          "[_requestPermissions] Ada permintaan izin yang sedang berjalan. Membatalkan permintaan baru.");

      // Tunggu sebentar lalu cek lagi status izin
      await Future.delayed(const Duration(milliseconds: 500));
      return _permissionsGranted;
    }

    // Set flag untuk menandai sedang meminta izin
    _isRequestingPermissions = true;
    _hasTriedRequestingPermissions = true;

    try {
      // Untuk Android, minta izin foreground service untuk screen sharing
      if (Platform.isAndroid) {
        // Android 13+, izin notifikasi diperlukan untuk menampilkan notifikasi foreground service
        final NotificationPermission notificationPermission =
            await FlutterForegroundTask.checkNotificationPermission();
        if (notificationPermission != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }

        // Android 12+, ada pembatasan untuk memulai foreground service
        if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          // Fungsi ini memerlukan izin 'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      }

      // PERBAIKAN: Minta izin secara paralel untuk lebih cepat
      final List<Future<PermissionStatus>> permissionFutures = [
        Permission.camera.request(),
        Permission.microphone.request(),
      ];

      final results = await Future.wait(permissionFutures);
      final cameraGranted = results[0].isGranted;
      final micGranted = results[1].isGranted;

      print(
          "[_requestPermissions] Hasil: Kamera=$cameraGranted, Mikrofon=$micGranted");

      if (!cameraGranted || !micGranted) {
        debugPrint(
            'Izin tidak diberikan: Kamera=$cameraGranted, Mikrofon=$micGranted');
        // Gunakan context jika widget masih ter-mount (hati-hati jika dipanggil dari initState)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Izin kamera dan mikrofon diperlukan.')),
          );
        }
      }

      return cameraGranted && micGranted;
    } finally {
      // Pastikan untuk mengatur flag ke false bahkan jika terjadi error
      _isRequestingPermissions = false;
    }
  }

  /// Connects to a LiveKit room automatically - Optimized for faster connection
  Future<void> _autoConnect(RoomContext roomCtx, TokenService tkService) async {
    // Skip if already connecting
    if (_isConnecting) {
      print("[_autoConnect] Proses koneksi sudah berjalan. Membatalkan.");
      return;
    }

    // Mark connection as in progress
    if (mounted) {
      print("[_autoConnect] Memulai proses, mengatur _isConnecting = true");
      setState(() {
        _isConnecting = true;
        _showLoadingIndicator = true; // TAMBAH: Tampilkan loading indicator
        _showAgentVisualizer = false; // TAMBAH: Sembunyikan visualizer dulu
        _agentVisualizerOpacity = 0.0; // TAMBAH: Reset opacity
        _connectionStatus = "Mempersiapkan koneksi..."; // Reset status koneksi
      });
    } else {
      print("[_autoConnect] Widget tidak terpasang saat memulai. Membatalkan.");
      return;
    }

    // Set timeout untuk koneksi
    _setConnectionTimeout(roomCtx);

    try {
      // Only check permissions again if not already granted in initState
      if (!_permissionsGranted) {
        print(
            "[_autoConnect] Izin belum diperiksa, memanggil _requestPermissions...");
        setState(() {
          _connectionStatus = "Meminta izin kamera dan mikrofon...";
        });
        _permissionsGranted = await _requestPermissions();
        if (!_permissionsGranted) {
          print("[_autoConnect] Izin tidak diberikan, koneksi dibatalkan.");
          // Set _isConnecting to false if failed due to permissions
          if (mounted) {
            setState(() {
              _isConnecting = false;
              _showLoadingIndicator =
                  false; // TAMBAH: Sembunyikan loading indicator
            });
          }
          return;
        }
      } else {
        print(
            "[_autoConnect] Izin sudah diperiksa sebelumnya: $_permissionsGranted");
      }

      // Inisialisasi perangkat media hanya ketika yakin izin sudah diberikan
      if (_permissionsGranted) {
        // Check if still mounted after permissions
        if (!mounted) {
          print(
              "[_autoConnect] Widget tidak terpasang setelah cek izin. Membatalkan.");
          return;
        }

        // Use cached room and participant names
        final roomName = _lastRoomName ??
            'room-${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}';
        final participantName = _lastParticipantName ??
            'user-${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}';

        // PERBAIKAN: Gunakan token yang sudah di-cache jika masih valid
        ConnectionDetails? connectionDetails;
        if (_cachedToken != null &&
            _cachedServerUrl != null &&
            _tokenExpiryTime != null &&
            DateTime.now().isBefore(_tokenExpiryTime!)) {
          print("[_autoConnect] Menggunakan token yang sudah di-cache");
          connectionDetails = ConnectionDetails(
            serverUrl: _cachedServerUrl!,
            roomName: roomName,
            participantName: participantName,
            participantToken: _cachedToken!,
          );

          // Update status
          if (mounted) {
            setState(() {
              _connectionStatus = "Menghubungkan ke server...";
            });
          }
        } else {
          // Get connection details - menggunakan caching yang telah diimplementasi di TokenService
          print("[_autoConnect] Mengambil detail koneksi dari TokenService...");
          if (mounted) {
            setState(() {
              _connectionStatus = "Meminta token koneksi...";
            });
          }

          connectionDetails = await tkService.fetchConnectionDetails(
            roomName: roomName,
            participantName: participantName,
          );

          // Cache token untuk penggunaan berikutnya
          if (connectionDetails != null) {
            _cachedToken = connectionDetails.participantToken;
            _cachedServerUrl = connectionDetails.serverUrl;
            // Set waktu kedaluwarsa token (misalnya 1 jam)
            _tokenExpiryTime = DateTime.now().add(const Duration(hours: 1));
          }
        }

        if (connectionDetails == null) {
          print("[_autoConnect] Gagal mendapatkan detail koneksi.");
          throw Exception('Gagal mendapatkan detail koneksi');
        }

        print(
            "[_autoConnect] Detail koneksi didapatkan: Server=${connectionDetails.serverUrl}");

        // PERBAIKAN: Jika reconnect, pastikan room dalam keadaan bersih
        if (room.connectionState != ConnectionState.disconnected) {
          print(
              "[_autoConnect] Room dalam state ${room.connectionState}, mencoba disconnect terlebih dahulu");
          // Disconnect untuk memastikan semua track dibersihkan
          await roomCtx.disconnect();
          // Tunggu sebentar untuk memastikan pembersihan selesai
          await Future.delayed(
              const Duration(milliseconds: 200)); // Kurangi delay dari 300ms
        }

        // Inisialisasi perangkat media terlebih dahulu secara paralel untuk mempercepat koneksi
        print("[_autoConnect] Melakukan pre-inisialisasi perangkat media...");
        if (mounted) {
          setState(() {
            _connectionStatus = "Menyiapkan kamera dan mikrofon...";
          });
        }

        MediaStream? preInitTrack;
        try {
          // PERBAIKAN: Gunakan opsi media yang lebih ringan
          preInitTrack = await navigator.mediaDevices.getUserMedia({
            'audio': true,
            'video': {
              'width': {'ideal': 640},
              'height': {'ideal': 480},
              'frameRate': {'ideal': 20},
            },
          });
        } catch (e) {
          print("[_autoConnect] Error saat pre-inisialisasi media: $e");
          // Lanjutkan meskipun ada error pada pre-inisialisasi
        }

        // Check if still mounted before connect
        if (!mounted) {
          print(
              "[_autoConnect] Widget tidak terpasang sebelum connect. Membatalkan.");
          // Pastikan untuk melepaskan track pre-inisialisasi
          preInitTrack?.getTracks().forEach((track) => track.stop());
          return;
        }

        // Connect to the LiveKit room
        print(
            '[autoConnect] Mencoba menghubungkan ke ${connectionDetails.serverUrl}...');
        if (mounted) {
          setState(() {
            _connectionStatus = "Menghubungkan ke room...";
          });
        }

        await roomCtx.connect(
          url: connectionDetails.serverUrl,
          token: connectionDetails.participantToken,
        );

        // Lepaskan track pre-inisialisasi karena tidak lagi diperlukan
        preInitTrack?.getTracks().forEach((track) => track.stop());

        print(
            '[autoConnect] Koneksi otomatis BERHASIL. Partisipan lokal: ${roomCtx.room.localParticipant?.identity}');

        // Check if still mounted before enabling media
        if (!mounted) {
          print(
              "[_autoConnect] Widget tidak terpasang setelah connect. Membatalkan.");
          return;
        }

        // PERBAIKAN: Tambahkan delay lebih pendek sebelum mengaktifkan media
        await Future.delayed(
            const Duration(milliseconds: 100)); // Kurangi dari 200ms

        // PERBAIKAN: Aktifkan kamera dan mikrofon secara paralel
        if (mounted) {
          setState(() {
            _connectionStatus = "Mengaktifkan kamera dan mikrofon...";
          });
        }

        try {
          // Aktifkan kamera dan mikrofon secara paralel untuk kecepatan
          final futures = <Future>[];
          if (roomCtx.localParticipant != null) {
            futures.add(roomCtx.localParticipant!.setMicrophoneEnabled(true));
            futures.add(roomCtx.localParticipant!.setCameraEnabled(true));
          }
          await Future.wait(futures);
          print(
              '[autoConnect] Kamera dan mikrofon berhasil diaktifkan secara paralel');
        } catch (e) {
          print(
              '[autoConnect] Error saat mengaktifkan perangkat secara paralel: $e');
          // Jika gagal, coba aktifkan satu per satu
          if (mounted) {
            try {
              await roomCtx.localParticipant?.setMicrophoneEnabled(true);
              print('[autoConnect] Mikrofon berhasil diaktifkan');

              await roomCtx.localParticipant?.setCameraEnabled(true);
              print('[autoConnect] Kamera berhasil diaktifkan');
            } catch (retryError) {
              print(
                  '[autoConnect] Error saat retry perangkat media: $retryError');
            }
          }
        }

        if (!mounted) return;
        print(
            '[autoConnect] Status perangkat - Mikrofon: ${roomCtx.localParticipant?.isMicrophoneEnabled()}, Kamera: ${roomCtx.localParticipant?.isCameraEnabled()}');

        // Lebih singkat delay stabilisasi
        await Future.delayed(
            const Duration(milliseconds: 50)); // Kurangi dari 100ms
        if (!mounted) return;

        // Koneksi berhasil, tampilkan visualizer dengan fade in lebih cepat
        if (mounted) {
          setState(() {
            _showAgentVisualizer = true;
            _connectionStatus = "Koneksi berhasil!";
          });

          // Mulai animasi fade in untuk visualizer lebih cepat
          Future.delayed(const Duration(milliseconds: 50), () {
            // Kurangi dari 100ms
            if (mounted) {
              setState(() {
                _agentVisualizerOpacity = 1.0;
              });
              // Sembunyikan loading indicator setelah visualizer mulai muncul
              Future.delayed(const Duration(milliseconds: 100), () {
                // Kurangi dari 200ms
                if (mounted) {
                  setState(() {
                    _showLoadingIndicator = false;
                  });
                }
              });
            }
          });
        }

        print('[autoConnect] Proses koneksi otomatis SELESAI.');

        // TAMBAH: Cancel timeout timer karena koneksi berhasil
        if (_connectionTimeoutTimer != null &&
            _connectionTimeoutTimer!.isActive) {
          _connectionTimeoutTimer!.cancel();
        }
      }
    } catch (error) {
      print('[autoConnect] KESALAHAN koneksi otomatis: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kesalahan Koneksi: ${error.toString()}')),
        );

        // PERBAIKAN: Coba melakukan disconnect jika terjadi error untuk membersihkan status
        try {
          await roomCtx.disconnect();
        } catch (disconnectError) {
          print(
              '[autoConnect] Error saat disconnect setelah error: $disconnectError');
        }

        // TAMBAH: Reset state animasi jika error
        setState(() {
          _showAgentVisualizer = false;
          _showLoadingIndicator = false;
          _agentVisualizerOpacity = 0.0;
        });
      }
    } finally {
      print("[_autoConnect] Blok finally dieksekusi.");
      if (mounted) {
        print("[_autoConnect] Mengatur _isConnecting = false di finally.");
        setState(() {
          _isConnecting = false;
          // Catatan: Tidak mengubah _showLoadingIndicator di sini karena kita mengelola
          // loading indicator dan visualizer secara terpisah dengan animasi fade
        });
      }

      // TAMBAH: Cancel timeout timer
      if (_connectionTimeoutTimer != null &&
          _connectionTimeoutTimer!.isActive) {
        _connectionTimeoutTimer!.cancel();
      }
    }
  }

  // Metode untuk set timeout koneksi
  void _setConnectionTimeout(RoomContext roomCtx) {
    // Batalkan timer sebelumnya jika ada
    _connectionTimeoutTimer?.cancel();

    // Buat timer baru 12 detik
    _connectionTimeoutTimer = Timer(const Duration(seconds: 12), () {
      if (_isConnecting && mounted) {
        print("[_autoConnect] Timeout - koneksi terlalu lama");
        setState(() {
          _isConnecting = false;
          _showLoadingIndicator = false;
          _connectionStatus = "Koneksi timeout. Coba lagi.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Koneksi terlalu lama. Silakan coba lagi.')),
        );

        // Coba disconnect jika masih dalam proses koneksi
        try {
          roomCtx.disconnect();
        } catch (e) {
          print("[_autoConnect] Error saat disconnect setelah timeout: $e");
        }
      }
    });
  }

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
        // --- Logika Panggil Auto Connect --- -> Pindahkan ke dalam Builder
        // Panggil hanya SEKALI setelah build pertama selesai DAN belum dipanggil sebelumnya
        // DAN belum sedang connecting DAN belum terhubung
        if (_isReadyToConnect &&
            !_isConnecting &&
            room.connectionState == ConnectionState.disconnected) {
          print(
              "[build] Kondisi terpenuhi, menjadwalkan pemanggilan _autoConnect()...");
          // Tandai bahwa pemanggilan akan dilakukan untuk mencegah pemanggilan ganda
          // Set ini SEGERA untuk menghindari race condition jika build terpanggil lagi cepat
          // Meskipun _isConnecting juga akan mencegahnya nanti
          // Ambil provider di sini menggunakan context dari Builder
          final roomCtxForCall = context.read<RoomContext>();
          final tkServiceForCall = context.read<TokenService>();
          print(
              "[build] Menjadwalkan _autoConnect dengan instance provider...");
          // Gunakan Future.microtask dan lewati instance provider
          Future.microtask(
              () => _autoConnect(roomCtxForCall, tkServiceForCall));
        }
        // ------------------------------------

        // Tambahkan listener untuk perubahan connection state
        room.addListener(() {
          if (room.connectionState != ConnectionState.connected &&
              _wasConnectedBefore) {
            print(
                "[RoomListener] Terdeteksi koneksi terputus dari state connected");
            // Jika room terputus tapi sebelumnya terhubung dan internet tersedia, coba reconnect
            if (_isInternetAvailable) {
              print("[RoomListener] Internet tersedia, mencoba reconnect");
              _attemptManualReconnect();
            } else {
              print(
                  "[RoomListener] Internet tidak tersedia, menunggu koneksi internet");
            }
          } else if (room.connectionState == ConnectionState.connected) {
            _wasConnectedBefore = true;
            _resetReconnectState(); // Reset reconnect state jika berhasil terhubung
          }
        });

        // Pindahkan logika akses RoomContext ke sini
        final roomContext = context.watch<RoomContext>();
        final participant = roomContext.room.localParticipant;
        final connectionState =
            roomContext.room.connectionState; // Dapatkan state koneksi

        // Mendapatkan kualitas koneksi dari participant
        final connectionQuality =
            participant?.connectionQuality ?? ConnectionQuality.unknown;

        // --- AWAL PERUBAHAN (Revisi untuk Linter Errors) ---
        // Prioritaskan screen share track jika ada dan sedang aktif
        LocalVideoTrack? displayTrack;
        LocalTrackPublication<LocalVideoTrack>? screenSharePub;
        LocalTrackPublication<LocalVideoTrack>? cameraPub;

        if (participant != null) {
          // Coba cari publikasi screen share video yang aktif (tidak di-mute dan track ada)
          try {
            screenSharePub = participant.videoTrackPublications.firstWhere(
              (pub) =>
                  pub.source == TrackSource.screenShareVideo &&
                  pub.track != null &&
                  !pub.muted,
            );
            displayTrack = screenSharePub.track as LocalVideoTrack?;
            print(
                '[build] Menggunakan track screen share: ${displayTrack?.sid}');
          } catch (e) {
            // Tidak ada screen share track yang aktif, coba kamera
            print(
                '[build] Tidak ada track screen share aktif, mencari track kamera.');
            screenSharePub = null;
          }

          // Jika tidak ada screen share track, gunakan track kamera
          if (displayTrack == null) {
            try {
              cameraPub = participant.videoTrackPublications.firstWhere(
                (pub) =>
                    pub.source == TrackSource.camera &&
                    pub.track != null &&
                    !pub.muted, // Tambahkan cek !pub.muted
              );
              displayTrack = cameraPub.track as LocalVideoTrack?;
              print('[build] Menggunakan track kamera: ${displayTrack?.sid}');
            } catch (e) {
              cameraPub = null;
              displayTrack = null;
              print('[build] Tidak ada track kamera aktif.');
            }
          }
        }
        // --- AKHIR PERUBAHAN ---

        // Tambahkan logging build
        print('[build] State Koneksi: $connectionState');
        print('[build] Participant: ${participant?.identity}');
        print(
            '[build] Connection Quality: $connectionQuality'); // Log kualitas koneksi
        print(
            '[build] Video Publications: ${participant?.videoTrackPublications.length}');
        print(
            '[build] Camera Pub: ${cameraPub?.sid}, ScreenShare Pub: ${screenSharePub?.sid}');
        print(
            '[build] Display Video Track: ${displayTrack?.sid} (Label: ${displayTrack?.mediaStreamTrack.label})');
        print('[build] Is Display Track Null: ${displayTrack == null}');
        print('[build] Is Connecting State: $_isConnecting');

        return Scaffold(
          // Ensure the body extends behind the floating header and bottom bar
          extendBody: true,
          // extendBodyBehindAppBar: true, // Not needed as we removed AppBar

          // Keep background transparent or set as needed for the base layer
          backgroundColor: Colors
              .black, // Example: Set base background if video doesn't load

          body: Stack(
            // Use Stack for layering
            children: [
              // Layer 1: Video Background (Fill the screen)
              if (displayTrack != null)
                Positioned.fill(
                  child: VideoTrackRenderer(
                    displayTrack!,
                    fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
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
                          _connectionStatus,
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
                              // Dapatkan pengguna yang sedang login
                              final User? currentUser =
                                  FirebaseAuth.instance.currentUser;

                              // Navigate to AccountScreen
                              print(
                                  "[Header] Avatar pressed - Navigating to Account Screen");
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AccountScreen(
                                    displayName: currentUser?.displayName,
                                    email: currentUser?.email,
                                    photoURL: currentUser?.photoURL,
                                  ), // Pastikan AccountScreen dapat menerima argumen null jika perlu
                                ),
                              );
                            },
                            child: CircleAvatar(
                              // Pertimbangkan untuk menampilkan foto profil pengguna di sini juga
                              radius: 16, // Adjust size as needed
                              backgroundImage:
                                  FirebaseAuth.instance.currentUser?.photoURL !=
                                              null &&
                                          FirebaseAuth.instance.currentUser!
                                              .photoURL!.isNotEmpty
                                      ? NetworkImage(FirebaseAuth
                                          .instance.currentUser!.photoURL!)
                                      : null,
                              child:
                                  FirebaseAuth.instance.currentUser?.photoURL ==
                                              null ||
                                          FirebaseAuth.instance.currentUser!
                                              .photoURL!.isEmpty
                                      ? const Icon(Icons.person,
                                          size: 18) // Placeholder icon
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
                    final bool isButtonEnabled = isConnected &&
                        !_isConnecting; // Check connection and not auto-connecting

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
                    FloatingActionButton(
                      heroTag: 'camera_fab',
                      mini: true,
                      onPressed: (displayTrack != null &&
                              screenSharePub == null &&
                              !_isConnecting) // Hanya aktif jika kamera yang tampil dan bukan screen share
                          ? () async {
                              print(
                                  "[FAB Camera] Tombol ganti kamera ditekan.");
                              final roomCtx = context.read<RoomContext>();
                              final participant = roomCtx.room.localParticipant;
                              print(
                                  "[FAB Camera] Participant: ${participant?.sid}");
                              print(
                                  "[FAB Camera] Video Publications Count: ${participant?.videoTrackPublications.length}");

                              LocalVideoTrack? cameraTrackToRestart;
                              LocalTrackPublication<LocalVideoTrack>?
                                  currentCameraPub;

                              if (participant != null) {
                                try {
                                  currentCameraPub = participant
                                      .videoTrackPublications
                                      .firstWhere(
                                    (pub) =>
                                        pub.source == TrackSource.camera &&
                                        pub.track is LocalVideoTrack &&
                                        pub.track?.mediaStreamTrack.enabled ==
                                            true && // Pastikan track-nya enabled
                                        !pub.muted, // Dan publikasinya tidak di-mute
                                  );
                                  cameraTrackToRestart = currentCameraPub.track
                                      as LocalVideoTrack?;
                                } catch (e) {
                                  print(
                                      "[FAB Camera] Tidak menemukan track kamera aktif untuk di-restart: $e");
                                  cameraTrackToRestart = null;
                                }
                              }

                              print(
                                  "[FAB Camera] Camera Track to Restart Found: ${cameraTrackToRestart?.sid}");

                              if (cameraTrackToRestart != null) {
                                try {
                                  final newPosition = (_currentCameraPosition ==
                                          CameraPosition.front)
                                      ? CameraPosition.back
                                      : CameraPosition.front;
                                  print(
                                      '[FAB Camera] Mencoba mengganti kamera ke: $newPosition');
                                  final newOptions = CameraCaptureOptions(
                                      cameraPosition: newPosition);
                                  await cameraTrackToRestart.restartTrack(
                                      newOptions); // Gunakan cameraTrackToRestart
                                  print('[FAB Camera] restartTrack selesai.');
                                  if (mounted) {
                                    setState(() {
                                      _currentCameraPosition = newPosition;
                                      print(
                                          '[FAB Camera] State kamera diperbarui ke: $newPosition');
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Mengganti kamera ke ${newPosition.name}')),
                                    );
                                  }
                                } catch (e) {
                                  print(
                                      "[FAB Camera] Error saat restartTrack untuk ganti kamera: $e");
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Tidak dapat mengganti kamera.')),
                                    );
                                  }
                                }
                              } else {
                                print(
                                    "[FAB Camera] Track kamera aktif tidak ditemukan atau tidak dapat di-restart saat tombol ditekan.");
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Track kamera tidak ditemukan atau belum siap untuk diganti.')),
                                  );
                                }
                              }
                            }
                          : null,
                      backgroundColor: (displayTrack != null &&
                              screenSharePub == null &&
                              !_isConnecting)
                          ? const Color(0xFF324EFF)
                          : Colors.grey,
                      child: const Icon(Icons.camera_alt_outlined,
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
