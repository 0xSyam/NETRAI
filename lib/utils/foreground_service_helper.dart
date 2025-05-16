import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:isolate'; // Ditambahkan untuk SendPort
import 'package:flutter/material.dart'; // Import untuk BuildContext
import 'dart:io'; // Untuk platform checking
import 'package:app_settings/app_settings.dart'; // Gunakan app_settings yang sudah ada
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

/// Helper class untuk mengelola foreground service untuk screen sharing
class ForegroundServiceHelper {
  // Konfigurasi untuk foreground service
  static const _notificationChannelId = 'netrai_foreground_task';
  static const _notificationChannelName = 'NetrAI Screen Sharing';
  static const _notificationTitle = 'NetrAI Screen Sharing Aktif';
  static const _notificationMessage = 'Berbagi layar sedang berjalan';
  static const _batteryOptimizationKey = 'battery_optimization_ignored';

  // Command untuk komunikasi dengan service
  static const String updateStatusCommand = 'updateStatus';

  // Callback untuk menerima data dari task handler
  static Function(Object)? _taskDataCallback;

  /// Log untuk debugging
  static void _log(String message) {
    print('ForegroundServiceHelper: $message');
  }

  /// Memeriksa status pengabaian optimasi baterai menggunakan SharedPreferences
  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_batteryOptimizationKey) ?? false;
    } catch (e) {
      _log('Error saat memeriksa status optimasi baterai: $e');
      return false;
    }
  }

  /// Menyimpan status pengabaian optimasi baterai ke SharedPreferences
  static Future<void> setBatteryOptimizationIgnored(bool ignored) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_batteryOptimizationKey, ignored);
      _log('Status optimasi baterai disimpan: $ignored');
    } catch (e) {
      _log('Error saat menyimpan status optimasi baterai: $e');
    }
  }

  /// Memeriksa apakah semua optimasi dinonaktifkan
  static Future<bool> isAllOptimizationsDisabled() async {
    // Implementasi menggunakan SharedPreferences bisa ditambahkan di sini
    return false;
  }

  /// Inisialisasi service dan pengaturan
  static void initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _notificationChannelId,
        channelName: _notificationChannelName,
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
  }

  /// Menambahkan callback untuk menerima data dari task handler
  static void addTaskDataCallback(Function(Object) callback) {
    _taskDataCallback = callback;
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  /// Menghapus callback
  static void removeTaskDataCallback() {
    if (_taskDataCallback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_taskDataCallback!);
      _taskDataCallback = null;
    }
  }

  /// Meminta izin yang diperlukan untuk foreground service
  static Future<void> requestPermissions() async {
    try {
      // Android 13+, diperlukan izin notifikasi untuk menampilkan foreground service notification
      final NotificationPermission notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      if (Platform.isAndroid) {
        // Android 12+, ada pembatasan untuk memulai foreground service
        // Untuk restart service saat perangkat di-reboot, izin di bawah ini diperlukan
        if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          // Fungsi ini memerlukan izin 'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }

        // Untuk beberapa kasus khusus yang memerlukan alarm tepat waktu
        // Ini diperlukan jika aplikasi perlu bertahan lama di background
        if (!await FlutterForegroundTask.canScheduleExactAlarms) {
          // Ketika memanggil fungsi ini, pengguna akan diarahkan ke halaman pengaturan
          // Jadi perlu menjelaskan kepada pengguna mengapa set itu diperlukan
          await FlutterForegroundTask.openAlarmsAndRemindersSettings();
        }
      }
    } catch (e) {
      _log('Error saat meminta izin: $e');
    }
  }

  /// Meminta pengabaian optimasi baterai untuk screen sharing menggunakan app_settings
  static Future<bool> requestIgnoreBatteryOptimization(
      BuildContext? context) async {
    if (!Platform.isAndroid) {
      _log(
          'Bukan platform Android, tidak perlu meminta pengabaian optimasi baterai');
      return true; // iOS tidak perlu optimasi
    }

    try {
      // Menggunakan implementasi baru dari FlutterForegroundTask
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        _log('Meminta pengabaian optimasi baterai dengan dialog sistem');
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();

        // Simpan status bahwa pengabaian baterai telah diminta
        await setBatteryOptimizationIgnored(true);
        return true;
      } else {
        _log('Pengabaian optimasi baterai sudah diaktifkan');
        return true;
      }
    } catch (e) {
      _log('Error saat meminta pengabaian optimasi baterai: $e');

      // Jika gagal, gunakan metode fallback dengan app_settings
      try {
        // Periksa apakah optimasi baterai sudah dinonaktifkan sebelumnya
        bool isIgnored = await isBatteryOptimizationIgnored();
        if (isIgnored) {
          _log('Optimasi baterai sudah dinonaktifkan sebelumnya (fallback)');
          return true; // Sudah dinonaktifkan, tidak perlu dialog
        }

        // Tunjukkan dialog konfirmasi jika context tersedia dan optimasi belum dinonaktifkan
        if (context != null && context.mounted) {
          final shouldOpenSettings = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Optimasi Baterai'),
                  content: const Text(
                      'Untuk performa screen sharing yang lebih baik, aplikasi perlu diizinkan mengabaikan optimasi baterai.\n\n'
                      'Pada layar berikutnya:\n'
                      '1. Temukan "NetrAI" dalam daftar aplikasi\n'
                      '2. Pilih "Tidak dibatasi" atau "Tidak dioptimalkan"\n\n'
                      'Hal ini membantu kualitas video screen sharing.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Nanti Saja'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Buka Pengaturan'),
                    ),
                  ],
                ),
              ) ??
              false;

          if (shouldOpenSettings) {
            _log('Membuka pengaturan baterai (fallback)...');
            // Gunakan AppSettings.openAppSettings dengan tipe batteryOptimization
            await AppSettings.openAppSettings(
                type: AppSettingsType.batteryOptimization);

            // Tunggu sebentar untuk memberikan waktu pengaturan dibuka
            await Future.delayed(const Duration(seconds: 1));

            // Anggap pengguna telah mengubah pengaturan dan simpan statusnya
            await setBatteryOptimizationIgnored(true);
            return true;
          } else {
            _log('Pengguna memilih untuk tidak membuka pengaturan baterai');
            return false;
          }
        } else {
          _log('Context tidak tersedia untuk menampilkan dialog');
          return false;
        }
      } catch (fallbackError) {
        _log('Error pada fallback: $fallbackError');
        return false;
      }
    }
  }

  /// Memulai foreground service untuk screen sharing
  static Future<bool> startForegroundService() async {
    try {
      // Inisialisasi port komunikasi jika belum dilakukan
      FlutterForegroundTask.initCommunicationPort();

      // Inisialisasi service terlebih dahulu
      initService();

      // Cek apakah sudah berjalan
      if (await FlutterForegroundTask.isRunningService) {
        _log('Foreground service sudah berjalan, mencoba restart');
        final ServiceRequestResult result =
            await FlutterForegroundTask.restartService();
        _log('Hasil restart service: ${result.toString()}');
        return true;
      }

      // Periksa izin yang diperlukan
      await requestPermissions();

      // Luncurkan foreground service dengan try-catch yang lebih baik
      _log('Memulai foreground service untuk screen sharing...');

      try {
        // Mulai service dengan tipe mediaProjection
        final ServiceRequestResult result =
            await FlutterForegroundTask.startService(
          notificationTitle: _notificationTitle,
          notificationText: _notificationMessage,
          serviceId: 256, // Gunakan ID unik
          notificationIcon: null, // Gunakan icon default
          notificationButtons: [
            const NotificationButton(id: 'stopTask', text: 'Hentikan'),
          ],
          serviceTypes: [
            ForegroundServiceTypes.mediaProjection,
            ForegroundServiceTypes.microphone,
          ],
          callback: startCallback,
        );

        _log('Hasil start service: ${result.toString()}');
        return true;
      } catch (e) {
        _log('Error saat memulai foreground service: $e');
        // Coba lagi dengan delay
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          final ServiceRequestResult result =
              await FlutterForegroundTask.startService(
            notificationTitle: _notificationTitle,
            notificationText: _notificationMessage,
            serviceId: 256,
            notificationIcon: null,
            serviceTypes: [
              ForegroundServiceTypes.mediaProjection,
              ForegroundServiceTypes.microphone,
            ],
            callback: startCallback,
          );

          _log('Hasil start service (percobaan ke-2): ${result.toString()}');
          return true;
        } catch (fallbackError) {
          _log('Fallback error: $fallbackError');
          return false;
        }
      }
    } catch (e) {
      _log('Error saat memulai foreground service: $e');
      return false;
    }
  }

  /// Menghentikan foreground service
  static Future<bool> stopForegroundService() async {
    try {
      _log('Menghentikan foreground service...');

      // Cek dulu apakah service sedang berjalan
      if (!await FlutterForegroundTask.isRunningService) {
        _log('Foreground service tidak sedang berjalan');
        return true; // Anggap berhasil karena memang sudah tidak berjalan
      }

      final ServiceRequestResult result =
          await FlutterForegroundTask.stopService();
      _log('Hasil stop service: ${result.toString()}');

      // Tambahkan delay singkat untuk memastikan service benar-benar berhenti
      await Future.delayed(const Duration(milliseconds: 200));
      return true;
    } catch (e) {
      _log('Error saat menghentikan foreground service: $e');
      // Mencoba dengan cara alternatif jika terjadi error
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        final ServiceRequestResult result =
            await FlutterForegroundTask.stopService();
        _log('Berhasil menghentikan service dengan alternatif');
        return true;
      } catch (fallbackError) {
        _log('Error pada alternatif penghentian service: $fallbackError');
        return false;
      }
    }
  }

  /// Memperbarui teks notifikasi saat service sedang berjalan
  static Future<void> updateNotification(String title, String message) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: message,
        );
        _log('Notifikasi diperbarui: $title - $message');
      }
    } catch (e) {
      _log('Error saat memperbarui notifikasi: $e');
    }
  }

  /// Mengirim data ke task handler
  static void sendDataToTask(Object data) {
    try {
      FlutterForegroundTask.sendDataToTask(data);
    } catch (e) {
      _log('Error saat mengirim data ke task: $e');
    }
  }

  /// Mendapatkan widget WithForegroundTask untuk membungkus aplikasi
  static Widget wrapWithForegroundTask(Widget child) {
    return WithForegroundTask(child: child);
  }
}

// Callback yang diperlukan oleh foreground_task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MediaProjectionTaskHandler());
}

// Task handler untuk foreground service
class MediaProjectionTaskHandler extends TaskHandler {
  String _status = "aktif";

  // Update status dan kirimkan ke UI
  void _updateStatus(String newStatus) {
    _status = newStatus;

    // Update notifikasi
    FlutterForegroundTask.updateService(
      notificationTitle: 'NetrAI Screen Sharing',
      notificationText: 'Status: $_status',
    );

    // Kirim data ke main isolate
    final Map<String, dynamic> data = {
      "status": _status,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    };
    FlutterForegroundTask.sendDataToMain(data);
  }

  // Called when the task is started.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      print('Foreground task dimulai (starter: ${starter.name})');
      _updateStatus("dimulai");
    } catch (e) {
      print('Error saat onStart: $e');
    }
  }

  // Called based on the eventAction set in ForegroundTaskOptions.
  @override
  void onRepeatEvent(DateTime timestamp) {
    try {
      // Update status setiap interval
      _updateStatus("aktif");
    } catch (e) {
      print('Error saat onRepeatEvent: $e');
    }
  }

  // Called when the task is destroyed.
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    try {
      print('Foreground task dihentikan (isTimeout: $isTimeout)');
      _updateStatus("dihentikan");
    } catch (e) {
      print('Error saat onDestroy: $e');
    }
  }

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.
  @override
  void onReceiveData(Object data) {
    try {
      print('Foreground task menerima data: $data');

      // Handle command dari UI
      if (data == ForegroundServiceHelper.updateStatusCommand) {
        _updateStatus("diperbarui");
      }
    } catch (e) {
      print('Error saat onReceiveData: $e');
    }
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    try {
      if (id == 'stopTask') {
        FlutterForegroundTask.stopService();
      }
    } catch (e) {
      print('Error saat onNotificationButtonPressed: $e');
    }
  }

  // Called when the notification itself is pressed.
  @override
  void onNotificationPressed() {
    try {
      print('Notifikasi ditekan');
    } catch (e) {
      print('Error saat onNotificationPressed: $e');
    }
  }

  // Called when the notification is dismissed.
  @override
  void onNotificationDismissed() {
    try {
      print('Notifikasi dibuang');
    } catch (e) {
      print('Error saat onNotificationDismissed: $e');
    }
  }
}
