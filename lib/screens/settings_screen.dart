import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_Service.dart';
import 'dart:async';
import 'package:app_settings/app_settings.dart';
import '../services/location_update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Kunci untuk shared preferences
  static const String _hapticFeedbackKey = 'haptic_feedback_preference';
  static const String _automaticFlashlightKey =
      'automatic_flashlight_preference';
  static const String _cameraGuidanceKey = 'camera_guidance_preference';
  static const String _showToolbarKey = 'show_toolbar_preference';
  static const String _shareLocationKey = 'share_location_preference';
  static const String _selectedVoiceKey =
      'selected_voice_preference'; // Kunci baru untuk preferensi suara

  // State untuk toggle switches utama
  bool _automaticFlashlight = false;
  bool _cameraGuidance = false;
  bool _hapticFeedback = false;
  bool _shareLocation = false;

  // State untuk AI Voice Settings
  bool _isAiVoiceExpanded = false; // Kontrol ekspansi
  bool _showToolbar = true;
  bool _resetToDefault = false; // State untuk toggle reset
  double _speechRate = 0.5; // Nilai 0.0 - 1.0
  double _pitch = 0.5; // Nilai 0.0 - 1.0
  String _selectedVoice = 'Kore'; // Default suara

  Timer? _locationTimer;

  // Helper widget untuk item pengaturan dengan toggle
  Widget _buildToggleSettingItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                    color: Colors.black.withOpacity(
                      0.6,
                    ), // Subtitle lebih redup
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor:
                const Color(0xFF3A59D1), // Warna toggle aktif (#3A59D1)
            inactiveTrackColor:
                const Color(0xFFD9D9D9), // Warna track non-aktif (#D9D9D9)
          ),
        ],
      ),
    );
  }

  // Helper untuk Slider
  Widget _buildSliderSettingItem({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.black.withOpacity(0.8),
            ),
          ),
          Slider(
            value: value,
            onChanged: onChanged,
            min: 0.0,
            max: 1.0,
            activeColor: Colors.grey.shade600,
            inactiveColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  // Widget untuk dropdown pilihan suara - menggantikan _buildGenderOptions
  Widget _buildVoiceOptions() {
    // Daftar suara Google yang tersedia
    final List<String> voices = [
      'Puck',
      'Charon',
      'Kore',
      'Fenrir',
      'Aoede',
      'Leda',
      'Orus',
      'Zephyr'
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilihan suara AI',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.black.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _selectedVoice,
              isExpanded: true,
              underline: Container(), // Menghilangkan underline
              icon: const Icon(Icons.keyboard_arrow_down),
              items: voices.map((String voice) {
                return DropdownMenuItem<String>(
                  value: voice,
                  child: Text(voice),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedVoice = newValue;
                  });
                  _saveStringPreference(_selectedVoiceKey, newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences(); // Muat semua preferensi saat initState
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hapticFeedback = prefs.getBool(_hapticFeedbackKey) ?? false;
      _automaticFlashlight = prefs.getBool(_automaticFlashlightKey) ?? false;
      _cameraGuidance = prefs.getBool(_cameraGuidanceKey) ?? false;
      _showToolbar = prefs.getBool(_showToolbarKey) ??
          true; // Default ke true untuk showToolbar
      _shareLocation = prefs.getBool(_shareLocationKey) ?? false;
      _selectedVoice = prefs.getString(_selectedVoiceKey) ??
          'Kore'; // Memuat preferensi suara
    });
  }

  // Fungsi generik untuk menyimpan preferensi boolean
  Future<void> _saveBoolPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Fungsi untuk menyimpan preferensi string
  Future<void> _saveStringPreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.shade200,
        leading: IconButton(
          icon: Image.asset('assets/images/arrow_back.png', height: 24),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text(
          'Reading Tools Settings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // HAPUS: Automatic flashlight
          // _buildToggleSettingItem(
          //   title: 'Automatic flashlight',
          //   subtitle:
          //       'Automatically use your flashlight to improve object identification',
          //   value: _automaticFlashlight,
          //   onChanged: (bool value) {
          //     setState(() {
          //       _automaticFlashlight = value;
          //     });
          //     _saveBoolPreference(_automaticFlashlightKey, value);
          //   },
          // ),
          // const Divider(height: 1, indent: 16, endIndent: 16),
          // HAPUS: Camera guidance
          // _buildToggleSettingItem(
          //   title: 'Camera guidance',
          //   subtitle:
          //       'Get voice tips and distance information in positioning your phone',
          //   value: _cameraGuidance,
          //   onChanged: (bool value) {
          //     setState(() {
          //       _cameraGuidance = value;
          //     });
          //     _saveBoolPreference(_cameraGuidanceKey, value);
          //   },
          // ),
          // const Divider(height: 1, indent: 16, endIndent: 16),
          _buildToggleSettingItem(
            title: 'Haptic feedback',
            subtitle: 'Subtle vibration feedback during use',
            value: _hapticFeedback,
            onChanged: (bool value) async {
              setState(() {
                _hapticFeedback = value;
              });
              await _saveBoolPreference(_hapticFeedbackKey, value);
              if (value) {
                final canVibrate = await Haptics.canVibrate();
                if (canVibrate) {
                  await Haptics.vibrate(HapticsType.light);
                }
              }
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // AI Voice Settings - ExpansionTile
          ExpansionTile(
            key: PageStorageKey('ai_voice_settings'),
            title: const Text(
              'AI voice settings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
                color: Colors.black,
              ),
            ),
            subtitle: Text(
              'Manage toolbar and AI speech options',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                color: Colors.black.withOpacity(0.6),
              ),
            ),
            trailing: SvgPicture.asset(
              'assets/images/chevron_down_icon.svg',
              height: 18,
              colorFilter: ColorFilter.mode(
                Colors.grey.shade500,
                BlendMode.srcIn,
              ),
            ),
            onExpansionChanged: (bool expanded) {
              setState(() {
                _isAiVoiceExpanded = expanded;
              });
            },
            initiallyExpanded: _isAiVoiceExpanded,
            tilePadding: const EdgeInsets.symmetric(
              vertical: 0.0,
              horizontal: 16.0,
            ),
            childrenPadding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 10.0,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              // HAPUS: Show toolbar for playback and display option
              // _buildToggleSettingItem(
              //   title: 'Show toolbar for playback and display option',
              //   subtitle: '',
              //   value: _showToolbar,
              //   onChanged: (bool value) {
              //     setState(() {
              //       _showToolbar = value;
              //     });
              //     _saveBoolPreference(_showToolbarKey, value);
              //   },
              // ),
              // HAPUS: Reset to default
              // _buildToggleSettingItem(
              //   title: 'Reset to default',
              //   subtitle: '',
              //   value: _resetToDefault,
              //   onChanged: (bool value) {
              //     setState(() {
              //       _resetToDefault = value;
              //       if (value) {
              //         _speechRate = 0.5;
              //         _pitch = 0.5;
              //         _selectedGender = 'male';
              //       }
              //     });
              //   },
              // ),
              // HAPUS: Speech rate
              // _buildSliderSettingItem(
              //   label: 'Speech rate',
              //   value: _speechRate,
              //   onChanged: (double value) {
              //     setState(() {
              //       _speechRate = value;
              //     });
              //   },
              // ),
              // HAPUS: Pitch
              // _buildSliderSettingItem(
              //   label: 'Pitch',
              //   value: _pitch,
              //   onChanged: (double value) {
              //     setState(() {
              //       _pitch = value;
              //     });
              //   },
              // ),
              _buildVoiceOptions(), // Menggunakan widget dropdown suara
            ],
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildToggleSettingItem(
            title: 'Share location',
            subtitle: 'Allow the app to share your location for assistance',
            value: _shareLocation,
            onChanged: (bool value) async {
              setState(() {
                _shareLocation = value;
              });
              _saveBoolPreference(_shareLocationKey, value);

              if (value) {
                try {
                  await LocationService.updateLocationToFirestore();
                  LocationUpdateService().start(); // Mulai service global
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Lokasi berhasil dibagikan!')),
                    );
                  }
                } catch (e) {
                  // Jika gagal (misal: GPS tidak aktif atau permission ditolak)
                  if (mounted) {
                    String msg = e.toString().contains('GPS tidak aktif')
                        ? 'GPS tidak aktif. Silakan aktifkan GPS untuk membagikan lokasi.'
                        : e.toString().contains('Izin lokasi')
                            ? 'Izin lokasi tidak diberikan. Aktifkan izin lokasi di pengaturan.'
                            : 'Gagal membagikan lokasi: $e';
                    if (e.toString().contains('GPS tidak aktif')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          action: SnackBarAction(
                            label: 'Aktifkan GPS',
                            onPressed: () {
                              AppSettings.openAppSettings(
                                  type: AppSettingsType.location);
                            },
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    }
                  }
                  // Kembalikan toggle ke false
                  setState(() {
                    _shareLocation = false;
                  });
                  _saveBoolPreference(_shareLocationKey, false);
                  LocationUpdateService().stop(); // Hentikan service global
                }
              } else {
                LocationUpdateService().stop(); // Hentikan service global
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Berhenti membagikan lokasi.')),
                  );
                }
              }
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }
}
