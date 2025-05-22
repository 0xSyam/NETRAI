import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_Service.dart'; // Assuming LocationService is correctly implemented
import 'dart:async';
import 'package:app_settings/app_settings.dart';
import '../services/location_update_service.dart'; // Assuming LocationUpdateService is correctly implemented

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Keys for shared preferences
  static const String _hapticFeedbackKey = 'haptic_feedback_preference';
  static const String _automaticFlashlightKey = 'automatic_flashlight_preference'; // Currently unused due to commented out UI
  static const String _cameraGuidanceKey = 'camera_guidance_preference'; // Currently unused due to commented out UI
  static const String _showToolbarKey = 'show_toolbar_preference'; // Currently unused due to commented out UI
  static const String _shareLocationKey = 'share_location_preference';
  static const String _selectedVoiceKey = 'selected_voice_preference'; // New key for voice preference

  // State for main toggle switches
  // bool _automaticFlashlight = false; // Currently unused
  // bool _cameraGuidance = false; // Currently unused
  bool _hapticFeedback = false;
  bool _shareLocation = false;

  // State for AI Voice Settings
  bool _isAiVoiceExpanded = false; // Expansion control
  // bool _showToolbar = true; // Currently unused
  // bool _resetToDefault = false; // Currently unused
  // double _speechRate = 0.5; // Value 0.0 - 1.0, currently unused
  // double _pitch = 0.5; // Value 0.0 - 1.0, currently unused
  String _selectedVoice = 'Kore'; // Default voice

  Timer? _locationTimer; // Potentially for location related tasks, seems unused in current visible logic

  // Helper widget for settings items with a toggle switch
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
                    color: Colors.black.withOpacity(0.6), // Subtitle dimmer
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF3A59D1), // Active toggle color (#3A59D1)
            inactiveTrackColor: const Color(0xFFD9D9D9), // Inactive track color (#D9D9D9)
          ),
        ],
      ),
    );
  }

  // Helper for Slider (currently unused as related UI is commented out)
  // Widget _buildSliderSettingItem({
  //   required String label,
  //   required double value,
  //   required ValueChanged<double> onChanged,
  // }) { ... }

  // Widget for voice selection dropdown - replaces _buildGenderOptions
  Widget _buildVoiceOptions() {
    // Available Google voices
    final List<String> voices = [
      'Puck', 'Charon', 'Kore', 'Fenrir',
      'Aoede', 'Leda', 'Orus', 'Zephyr'
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Voice Selection', // Translated
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
              underline: Container(), // Removes the default underline
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
    _loadPreferences(); // Load all preferences during initState
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hapticFeedback = prefs.getBool(_hapticFeedbackKey) ?? false;
      // _automaticFlashlight = prefs.getBool(_automaticFlashlightKey) ?? false; // For commented out UI
      // _cameraGuidance = prefs.getBool(_cameraGuidanceKey) ?? false; // For commented out UI
      // _showToolbar = prefs.getBool(_showToolbarKey) ?? true; // For commented out UI
      _shareLocation = prefs.getBool(_shareLocationKey) ?? false;
      _selectedVoice = prefs.getString(_selectedVoiceKey) ?? 'Kore'; // Load voice preference
    });
  }

  // Generic function to save boolean preferences
  Future<void> _saveBoolPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Function to save string preferences
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
          // REMOVE: Automatic flashlight (Commented out UI)
          // _buildToggleSettingItem( ... )
          // REMOVE: Camera guidance (Commented out UI)
          // _buildToggleSettingItem( ... )
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
            key: const PageStorageKey('ai_voice_settings'), // Added const
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
              'Manage AI speech options', // Simplified subtitle as toolbar option is removed
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
              // REMOVE: Show toolbar for playback and display option (Commented out UI)
              // _buildToggleSettingItem( ... )
              // REMOVE: Reset to default (Commented out UI)
              // _buildToggleSettingItem( ... )
              // REMOVE: Speech rate (Commented out UI)
              // _buildSliderSettingItem( ... )
              // REMOVE: Pitch (Commented out UI)
              // _buildSliderSettingItem( ... )
              _buildVoiceOptions(), // Using voice dropdown widget
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
                  LocationUpdateService().start(); // Start global service
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Location shared successfully!')), // Translated
                    );
                  }
                } catch (e) {
                  // If fails (e.g., GPS inactive or permission denied)
                  if (mounted) {
                    String msg = e.toString().contains('GPS tidak aktif') // GPS inactive (Indonesian)
                        ? 'GPS is inactive. Please enable GPS to share location.' // Translated
                        : e.toString().contains('Izin lokasi') // Location permission (Indonesian)
                            ? 'Location permission not granted. Enable location permission in settings.' // Translated
                            : 'Failed to share location: $e'; // Translated
                    if (e.toString().contains('GPS tidak aktif')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          action: SnackBarAction(
                            label: 'Enable GPS', // Translated
                            onPressed: () {
                              AppSettings.openAppSettings(type: AppSettingsType.location);
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
                  // Revert toggle to false
                  setState(() {
                    _shareLocation = false;
                  });
                  _saveBoolPreference(_shareLocationKey, false);
                  LocationUpdateService().stop(); // Stop global service
                }
              } else {
                LocationUpdateService().stop(); // Stop global service
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stopped sharing location.')), // Translated
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
