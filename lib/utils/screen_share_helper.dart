import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'dart:io';
import './foreground_service_helper.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../widgets/screen_share_floating_button.dart'; // Import widget floating button
import './netrai_speech_helper.dart'; // Import helper untuk Speak to NetrAI
import './overlay_service.dart';

/// Helper class untuk mengelola screen sharing dengan penanganan error yang lebih baik
class ScreenShareHelper {
  // Instance overlay untuk floating button
  static final ScreenShareOverlay _overlay = ScreenShareOverlay();

  // Fungsi untuk log dengan lebih detail
  static void _logDetail(String message) {
    print('ScreenShareHelper: $message');
  }

  /// Membungkus foreground task
  static Future<T> _withForegroundTask<T>(Future<T> Function() callback) async {
    try {
      // Memastikan ada wrapper foreground task
      if (!await FlutterForegroundTask.isRunningService) {
        _logDetail('Foreground service belum berjalan, memulai service baru');

        // Jika ada foreground service yang sebelumnya berjalan tapi sudah tidak valid
        // Pastikan untuk menghentikan service tersebut
        try {
          await ForegroundServiceHelper.stopForegroundService();
          // Tunggu sebentar agar service benar-benar berhenti
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          _logDetail('Error saat menghentikan layanan lama: $e');
          // Lanjutkan meskipun ada error
        }

        // Mulai service baru
        final serviceStarted =
            await ForegroundServiceHelper.startForegroundService();
        _logDetail('Status mulai foreground service: $serviceStarted');

        // Jika service gagal dimulai, coba sekali lagi
        if (!serviceStarted) {
          _logDetail('Mencoba memulai foreground service lagi...');
          await Future.delayed(const Duration(milliseconds: 500));
          final secondAttempt =
              await ForegroundServiceHelper.startForegroundService();
          _logDetail(
              'Status mulai foreground service (percobaan ke-2): $secondAttempt');

          // Jika masih gagal, lempar exception untuk membatalkan operasi
          if (!secondAttempt) {
            _logDetail('Foreground service gagal dimulai.');
            throw Exception(
                'Tidak dapat memulai foreground service yang diperlukan untuk screen sharing');
          }
        }

        // Tunggu lebih lama agar service benar-benar aktif dan siap
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        _logDetail(
            'Foreground service sudah berjalan, tidak perlu dimulai lagi');
      }

      // Jalankan callback
      return await callback();
    } catch (e) {
      _logDetail('Error dalam _withForegroundTask: $e');

      // Jika error terkait media projection atau foreground service, jangan coba fallback
      if (e.toString().contains('FOREGROUND_SERVICE') ||
          e.toString().contains('media projection') ||
          e.toString().contains('SecurityException')) {
        _logDetail('Error terkait foreground service, tidak mencoba fallback');
        throw e; // lempar exception untuk menghentikan operasi
      }

      // Coba jalankan callback langsung tanpa foreground task sebagai fallback terakhir
      try {
        _logDetail('Mencoba fallback terakhir tanpa foreground service');
        return await callback();
      } catch (callbackError) {
        _logDetail('Error saat menjalankan callback langsung: $callbackError');
        rethrow;
      }
    }
  }

  /// Memeriksa apakah perangkat berjalan pada Android 12 atau lebih tinggi
  static bool _isAndroid12OrHigher() {
    if (Platform.isAndroid) {
      final String ver = Platform.operatingSystemVersion;
      // Android 12 adalah API level 31 atau lebih tinggi
      try {
        // Coba ekstrak versi Android dari string versi OS
        final versionMatch = RegExp(r'([0-9]+)').firstMatch(ver);
        if (versionMatch != null) {
          final versionNumber = int.tryParse(versionMatch.group(1) ?? '0') ?? 0;
          return versionNumber >= 12;
        }
      } catch (e) {
        _logDetail('Error saat memeriksa versi Android: $e');
      }
    }
    return false;
  }

  /// Menampilkan atau menyembunyikan floating button
  static void _toggleFloatingButton(
    BuildContext context,
    LocalParticipant participant,
    bool show,
  ) {
    if (show) {
      // Mencoba menampilkan floating button di atas aplikasi lain menggunakan OverlayService
      OverlayService.showFloatingButton(
        context,
        participant,
        () => toggleScreenSharing(
            context, participant), // Stop sharing saat tombol stop ditekan
        () {
          // Callback untuk tombol "Speak to NetrAI"
          NetraiSpeechHelper.startSpeakToNetRAI(context, participant);
        },
      ).then((success) {
        if (!success) {
          // Jika gagal menggunakan OverlayService, gunakan fallback ke overlay internal
          if (!_overlay.isShowing) {
            _overlay.show(
              context,
              participant,
              () => toggleScreenSharing(context, participant),
              () => NetraiSpeechHelper.startSpeakToNetRAI(context, participant),
            );
          }
        }
      });
    } else {
      // Sembunyikan floating button
      if (_overlay.isShowing) {
        _overlay.hide();
      }

      // Sembunyikan juga overlay service jika aktif
      OverlayService.hideFloatingButton();
    }
  }

  /// Mencoba mengaktifkan atau menonaktifkan screen sharing dengan penanganan error yang tepat
  static Future<bool> toggleScreenSharing(
    BuildContext context,
    LocalParticipant participant,
  ) async {
    try {
      _logDetail('Memulai toggle screen sharing');
      _logDetail(
          'Platform: ${Platform.operatingSystem}, versi: ${Platform.operatingSystemVersion}');

      final bool isCurrentlyEnabled = participant.isScreenShareEnabled();
      _logDetail('Status screen sharing saat ini: $isCurrentlyEnabled');

      // Jika akan mengaktifkan, tampilkan dialog konfirmasi
      if (!isCurrentlyEnabled) {
        _logDetail('Meminta konfirmasi pengguna');
        final bool shouldProceed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Konfirmasi Berbagi Layar'),
                content: const Text('Anda akan membagikan layar. Lanjutkan?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Lanjutkan'),
                  ),
                ],
              ),
            ) ??
            false;

        if (!shouldProceed) {
          _logDetail('Pengguna membatalkan screen sharing');
          return false; // Dibatalkan oleh pengguna
        }

        // Periksa dan minta pengabaian optimasi baterai khusus untuk Android
        if (Platform.isAndroid) {
          _logDetail('Memeriksa dan meminta pengabaian optimasi baterai');

          // Cek status semua optimasi terlebih dahulu
          final allOptDisabled =
              await ForegroundServiceHelper.isAllOptimizationsDisabled();
          if (allOptDisabled) {
            _logDetail('Semua optimasi baterai sudah dinonaktifkan');
            // Tidak perlu melakukan apa-apa lagi
          } else {
            // Minta pengabaian optimasi baterai
            final batteryOptIgnored =
                await ForegroundServiceHelper.requestIgnoreBatteryOptimization(
                    context);
            _logDetail(
                'Status pengabaian optimasi baterai setelah permintaan: $batteryOptIgnored');

            // Jika pengabaian tidak diberikan, hentikan proses screen sharing untuk menghindari crash
            if (!batteryOptIgnored) {
              _logDetail(
                  'Pengabaian optimasi baterai ditolak, membatalkan screen sharing');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Screen sharing dibatalkan karena pengabaian optimasi baterai diperlukan.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              return false; // Hentikan proses screen sharing
            } else if (batteryOptIgnored && context.mounted) {
              // Pesan sukses jika pengabaian berhasil
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Optimasi baterai berhasil dinonaktifkan untuk kinerja screen sharing yang lebih baik.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      }

      // Tampilkan indikator loading jika akan mengaktifkan
      if (!isCurrentlyEnabled && context.mounted) {
        _logDetail('Menampilkan indikator loading');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mempersiapkan berbagi layar...')),
        );
      }

      // Toggle screen sharing berdasarkan platform
      if (Platform.isAndroid) {
        _logDetail('Menggunakan metode Android dengan foreground service');

        if (!isCurrentlyEnabled) {
          // Mulai berbagi layar dengan foreground service
          // Cek jika Android 12+ dan gunakan pendekatan berbeda jika perlu
          if (_isAndroid12OrHigher()) {
            _logDetail(
                'Menggunakan pendekatan Android 12+ untuk screen sharing');
            // Pendekatan versi baru: mulai layanan terlebih dahulu lalu aktifkan screen share
            final serviceStarted =
                await ForegroundServiceHelper.startForegroundService();
            if (serviceStarted) {
              _logDetail(
                  'Foreground service berhasil dimulai, mengaktifkan screen share');

              // Tambahkan delay kecil untuk memastikan foreground service sudah stabil
              await Future.delayed(const Duration(milliseconds: 300));

              try {
                await participant.setScreenShareEnabled(true);
                _logDetail('Screen sharing berhasil diaktifkan');

                // Tampilkan floating button setelah screen share aktif
                if (context.mounted) {
                  _toggleFloatingButton(context, participant, true);
                }
              } catch (e) {
                _logDetail('Error saat mengaktifkan screen share: $e');

                // Coba restart foreground service dengan tipe yang benar jika terjadi error
                await ForegroundServiceHelper.stopForegroundService();
                await Future.delayed(const Duration(milliseconds: 200));

                // Mulai ulang dengan fokus pada media projection
                await ForegroundServiceHelper.startForegroundService();
                await Future.delayed(const Duration(milliseconds: 300));
                await participant.setScreenShareEnabled(true);

                // Tampilkan floating button jika berhasil
                if (context.mounted) {
                  _toggleFloatingButton(context, participant, true);
                }
              }
            } else {
              _logDetail(
                  'Foreground service gagal dimulai, membatalkan screen sharing');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Gagal memulai layanan foreground yang diperlukan untuk berbagi layar'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              return false;
            }
          } else {
            // Pendekatan versi lama: menggunakan foreground task wrapper
            await _withForegroundTask(() async {
              _logDetail(
                  'Mencoba setScreenShareEnabled(true) dengan foreground');
              await participant.setScreenShareEnabled(true);

              // Tampilkan floating button setelah screen share aktif
              if (context.mounted) {
                _toggleFloatingButton(context, participant, true);
              }
            });
          }

          _logDetail(
              '[Android ENABLE] Status mikrofon: ${participant.isMicrophoneEnabled()}');
          _logDetail(
              '[Android ENABLE] Jumlah publikasi audio: ${participant.audioTrackPublications.length}');
          TrackPublication? micPubAndroidEnable;
          try {
            micPubAndroidEnable = participant.audioTrackPublications
                .firstWhere((pub) => pub.source == TrackSource.microphone);
          } catch (e) {
            micPubAndroidEnable = null;
          }
          if (micPubAndroidEnable != null) {
            final micTrack = micPubAndroidEnable.track as LocalAudioTrack?;
            _logDetail(
                '[Android ENABLE] Publikasi Mikrofon: SID=${micPubAndroidEnable.sid}, Muted=${micPubAndroidEnable.muted}, Name=${micPubAndroidEnable.name}, Kind=${micPubAndroidEnable.kind}, Track SID=${micTrack?.sid}, Track Muted=${micTrack?.muted}');
            // Pastikan mikrofon aktif dan tidak di-mute
            if (participant.isMicrophoneEnabled() == false) {
              _logDetail(
                  '[Android ENABLE] Mikrofon nonaktif, mencoba mengaktifkan ulang.');
              await participant.setMicrophoneEnabled(true);
              _logDetail(
                  '[Android ENABLE] Status mikrofon setelah diaktifkan ulang: ${participant.isMicrophoneEnabled()}');
            }
            if (micPubAndroidEnable.muted) {
              _logDetail('[Android ENABLE] Mikrofon di-mute, mencoba unmute.');
              // Coba unmute melalui LocalTrackPublication jika memungkinkan
              if (micPubAndroidEnable is LocalTrackPublication) {
                await (micPubAndroidEnable as LocalTrackPublication).unmute();
                _logDetail(
                    '[Android ENABLE] Status mute mikrofon setelah unmute (via LocalTrackPublication): ${participant.audioTrackPublications.firstWhere((pub) => pub.source == TrackSource.microphone).muted}');
              } else {
                _logDetail(
                    '[Android ENABLE] Publikasi mikrofon termute tetapi bukan LocalTrackPublication atau tidak ada SID, mengandalkan setMicrophoneEnabled.');
                // Jika bukan LocalTrackPublication, kita sudah mencoba setMicrophoneEnabled(true) sebelumnya.
                // Mungkin perlu intervensi manual atau pengecekan lebih lanjut jika audio masih bermasalah.
              }
            }
          } else {
            _logDetail(
                '[Android ENABLE] Publikasi mikrofon TIDAK DITEMUKAN. Mencoba mengaktifkan mikrofon.');
            await participant.setMicrophoneEnabled(true);
            _logDetail(
                '[Android ENABLE] Status mikrofon setelah coba aktifkan: ${participant.isMicrophoneEnabled()}');
          }
        } else {
          // Sembunyikan floating button saat screen sharing dimatikan
          _toggleFloatingButton(context, participant, false);

          // Hentikan berbagi layar
          _logDetail('Menghentikan screen sharing dan foreground service');
          await participant.setScreenShareEnabled(false);
          _logDetail(
              '[Android DISABLE] Status mikrofon: ${participant.isMicrophoneEnabled()}');
          _logDetail(
              '[Android DISABLE] Jumlah publikasi audio: ${participant.audioTrackPublications.length}');
          TrackPublication? micPubAndroidDisable;
          try {
            micPubAndroidDisable = participant.audioTrackPublications
                .firstWhere((pub) => pub.source == TrackSource.microphone);
          } catch (e) {
            micPubAndroidDisable = null;
          }
          if (micPubAndroidDisable != null) {
            final micTrack = micPubAndroidDisable.track as LocalAudioTrack?;
            _logDetail(
                '[Android DISABLE] Publikasi Mikrofon: SID=${micPubAndroidDisable.sid}, Muted=${micPubAndroidDisable.muted}, Name=${micPubAndroidDisable.name}, Kind=${micPubAndroidDisable.kind}, Track SID=${micTrack?.sid}, Track Muted=${micTrack?.muted}');
            // Pertimbangkan untuk mengaktifkan kembali mikrofon jika nonaktif
            if (participant.isMicrophoneEnabled() == false) {
              _logDetail(
                  '[Android DISABLE] Mikrofon nonaktif, mencoba mengaktifkan ulang.');
              await participant.setMicrophoneEnabled(true);
              _logDetail(
                  '[Android DISABLE] Status mikrofon setelah diaktifkan ulang: ${participant.isMicrophoneEnabled()}');
            }
          } else {
            _logDetail('[Android DISABLE] Publikasi mikrofon TIDAK DITEMUKAN.');
            // Tetap coba aktifkan mikrofon jika tidak ada publikasi (mungkin ter-unpublish?)
            if (participant.isMicrophoneEnabled() == false) {
              _logDetail(
                  '[Android DISABLE] Mikrofon nonaktif (tanpa publikasi), mencoba mengaktifkan ulang.');
              await participant.setMicrophoneEnabled(true);
              _logDetail(
                  '[Android DISABLE] Status mikrofon setelah diaktifkan ulang (tanpa publikasi): ${participant.isMicrophoneEnabled()}');
            }
          }
          await ForegroundServiceHelper.stopForegroundService();
        }
      } else {
        // Platform lain (iOS, Web, desktop) menggunakan metode standard
        _logDetail(
            'Menggunakan metode platform standard (Non-Android Desktop/iOS)');
        final bool willEnableScreenShare = !isCurrentlyEnabled;
        await participant.setScreenShareEnabled(willEnableScreenShare);

        // Toggle floating button pada platform lain
        if (context.mounted) {
          _toggleFloatingButton(context, participant, willEnableScreenShare);
        }

        _logDetail(
            '[Other Platforms TOGGLE: $willEnableScreenShare] Status mikrofon: ${participant.isMicrophoneEnabled()}');
        _logDetail(
            '[Other Platforms TOGGLE: $willEnableScreenShare] Jumlah publikasi audio: ${participant.audioTrackPublications.length}');
        TrackPublication? micPubOther;
        try {
          micPubOther = participant.audioTrackPublications
              .firstWhere((pub) => pub.source == TrackSource.microphone);
        } catch (e) {
          micPubOther = null;
        }

        if (willEnableScreenShare) {
          // Jika screen share baru saja diaktifkan
          if (micPubOther != null) {
            final micTrack = micPubOther.track as LocalAudioTrack?;
            _logDetail(
                '[Other Platforms ENABLE] Publikasi Mikrofon: SID=${micPubOther.sid}, Muted=${micPubOther.muted}, Name=${micPubOther.name}, Kind=${micPubOther.kind}, Track SID=${micTrack?.sid}, Track Muted=${micTrack?.muted}');
            if (participant.isMicrophoneEnabled() == false) {
              _logDetail(
                  '[Other Platforms ENABLE] Mikrofon nonaktif, mencoba mengaktifkan ulang.');
              await participant.setMicrophoneEnabled(true);
              _logDetail(
                  '[Other Platforms ENABLE] Status mikrofon setelah diaktifkan ulang: ${participant.isMicrophoneEnabled()}');
            }
            if (micPubOther.muted) {
              _logDetail(
                  '[Other Platforms ENABLE] Mikrofon di-mute, mencoba unmute.');
              // Coba unmute melalui LocalTrackPublication jika memungkinkan
              if (micPubOther is LocalTrackPublication) {
                await (micPubOther as LocalTrackPublication).unmute();
                _logDetail(
                    '[Other Platforms ENABLE] Status mute mikrofon setelah unmute (via LocalTrackPublication): ${participant.audioTrackPublications.firstWhere((pub) => pub.source == TrackSource.microphone).muted}');
              } else {
                _logDetail(
                    '[Other Platforms ENABLE] Publikasi mikrofon termute tetapi bukan LocalTrackPublication atau tidak ada SID, mengandalkan setMicrophoneEnabled.');
                // Jika bukan LocalTrackPublication, kita sudah mencoba setMicrophoneEnabled(true) sebelumnya.
              }
            }
          } else {
            _logDetail(
                '[Other Platforms ENABLE] Publikasi mikrofon TIDAK DITEMUKAN. Mencoba mengaktifkan mikrofon.');
            await participant.setMicrophoneEnabled(true);
            _logDetail(
                '[Other Platforms ENABLE] Status mikrofon setelah coba aktifkan: ${participant.isMicrophoneEnabled()}');
          }
        } else {
          // Jika screen share baru saja dinonaktifkan
          if (micPubOther != null) {
            final micTrack = micPubOther.track as LocalAudioTrack?;
            _logDetail(
                '[Other Platforms DISABLE] Publikasi Mikrofon: SID=${micPubOther.sid}, Muted=${micPubOther.muted}, Name=${micPubOther.name}, Kind=${micPubOther.kind}, Track SID=${micTrack?.sid}, Track Muted=${micTrack?.muted}');
            if (participant.isMicrophoneEnabled() == false) {
              _logDetail(
                  '[Other Platforms DISABLE] Mikrofon nonaktif, mencoba mengaktifkan ulang.');
              await participant.setMicrophoneEnabled(true);
              _logDetail(
                  '[Other Platforms DISABLE] Status mikrofon setelah diaktifkan ulang: ${participant.isMicrophoneEnabled()}');
            }
          } else {
            _logDetail(
                '[Other Platforms DISABLE] Publikasi mikrofon TIDAK DITEMUKAN.');
            if (participant.isMicrophoneEnabled() == false) {
              _logDetail(
                  '[Other Platforms DISABLE] Mikrofon nonaktif (tanpa publikasi), mencoba mengaktifkan ulang.');
              await participant.setMicrophoneEnabled(true);
              _logDetail(
                  '[Other Platforms DISABLE] Status mikrofon setelah diaktifkan ulang (tanpa publikasi): ${participant.isMicrophoneEnabled()}');
            }
          }
        }
      }

      // Verifikasi status baru setelah delay
      await Future.delayed(const Duration(milliseconds: 500));
      final bool newState = participant.isScreenShareEnabled();
      _logDetail('Status screen sharing setelah toggle: $newState');
      _logDetail(
          '[After Delay] Status mikrofon: ${participant.isMicrophoneEnabled()}');
      _logDetail(
          '[After Delay] Jumlah publikasi audio: ${participant.audioTrackPublications.length}');
      TrackPublication? micPubDelay;
      try {
        micPubDelay = participant.audioTrackPublications
            .firstWhere((pub) => pub.source == TrackSource.microphone);
      } catch (e) {
        micPubDelay = null;
      }
      if (micPubDelay != null) {
        final micTrack = micPubDelay.track as LocalAudioTrack?;
        _logDetail(
            '[After Delay] Publikasi Mikrofon: SID=${micPubDelay.sid}, Muted=${micPubDelay.muted}, Name=${micPubDelay.name}, Kind=${micPubDelay.kind}, Track SID=${micTrack?.sid}, Track Muted=${micTrack?.muted}');
      } else {
        _logDetail('[After Delay] Publikasi mikrofon TIDAK DITEMUKAN.');
      }

      // Tampilkan pesan sukses jika context masih valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Berbagi layar ${newState ? 'dimulai' : 'dihentikan'}.'),
          ),
        );
      }

      return true; // Berhasil mengubah status
    } catch (e) {
      // Pastikan floating button disembunyikan jika terjadi error
      if (context.mounted) {
        _toggleFloatingButton(context, participant, false);
      }

      _logDetail('Error saat toggle screen share: $e');
      _logDetail('Error detail: ${e.runtimeType}');

      // Deteksi jenis error dan berikan pesan yang sesuai
      String errorMessage;

      if (e.toString().contains("permission") ||
          e.toString().contains("izin") ||
          e.toString().contains("denied")) {
        errorMessage = 'Izin berbagi layar tidak diberikan.';
      } else if (e.toString().contains("cancelled") ||
          e.toString().contains("canceled") ||
          e.toString().contains("batal")) {
        errorMessage = 'Berbagi layar dibatalkan oleh pengguna.';
      } else if (e.toString().contains("not supported") ||
          e.toString().contains("tidak didukung")) {
        errorMessage = 'Perangkat tidak mendukung berbagi layar.';
      } else if (e.toString().contains("FOREGROUND_SERVICE") ||
          e.toString().contains("media projection") ||
          e.toString().contains("MediaProjection") ||
          e.toString().contains("SecurityException")) {
        errorMessage =
            'Error: Layanan foreground diperlukan untuk berbagi layar. Coba restart aplikasi.';

        // Coba membersihkan state layanan foreground
        try {
          await ForegroundServiceHelper.stopForegroundService();
        } catch (_) {}
      } else if (Platform.isAndroid &&
          (e.toString().contains("crash") ||
              e.toString().contains("process") ||
              e.toString().contains("process has died"))) {
        errorMessage =
            'Aplikasi mengalami crash saat berbagi layar. Restart aplikasi dan coba lagi.';
      } else {
        errorMessage =
            'Gagal mengubah status berbagi layar. Error: ${e.toString().split('\n').first}';
      }

      // Tampilkan pesan error jika context masih valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }

      return false; // Gagal mengubah status
    }
  }

  /// Menampilkan floating button secara publik (untuk bisa diakses dari kelas lain)
  static void showFloatingButton(
    BuildContext context,
    LocalParticipant participant,
  ) {
    // Inisialisasi OverlayService saat dibutuhkan
    OverlayService.initialize().then((_) {
      _toggleFloatingButton(context, participant, true);
    });
  }

  /// Menyembunyikan floating button secara publik (untuk bisa diakses dari kelas lain)
  static void hideFloatingButton(
    BuildContext context,
    LocalParticipant participant,
  ) {
    _toggleFloatingButton(context, participant, false);
  }
}
