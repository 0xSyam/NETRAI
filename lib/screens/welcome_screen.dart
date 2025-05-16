import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart'; // Import SystemChrome
import 'login_screen.dart'; // Use relative path
// import 'package:netrai/screens/privacy_policy_screen.dart'; // Remove Privacy Policy Screen import
import '../services/auth_service.dart'; // Add AuthService import
import 'location_screen.dart'; // Add LocationScreen import
import 'package:cloud_firestore/cloud_firestore.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // Helper widget for descriptive list item according to Figma
  Widget _buildFeatureItem({
    required String iconPath,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 7.0,
      ), // Distance between items from Figma (gap: 7)
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center, // Align items vertically centered
        children: [
          SvgPicture.asset(
            iconPath,
            width: 32, // Icon size (adjust if needed, Figma not specific)
            height: 32,
            // Feature icon color (adjust if needed, Figma varies)
            // colorFilter: ColorFilter.mode(const Color(0xFF3A58D0), BlendMode.srcIn),
          ),
          const SizedBox(
            width: 19.0,
          ), // Distance between icon and text from Figma (gap: 19)
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: Colors.black, // Text color from Figma (#000000)
                fontSize: 12, // Text size from Figma
                fontWeight: FontWeight.w400, // Weight from Figma (Regular)
                fontFamily: 'Inter',
                height: 1.5, // Line height from Figma
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set system overlay style (status bar) - white icons
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF3A58D0), // Blue color matching AppBar
        statusBarIconBrightness: Brightness.light, // White status bar icons
        statusBarBrightness: Brightness.dark, // For iOS
      ),
    );

    const double horizontalPadding = 35.0; // Side padding
    const double buttonHeight = 51.0;
    const double imageSize = 200.0; // Size for placeholder icon

    // Get status bar height for manual padding
    // final double statusBarHeight = MediaQuery.of(context).padding.top; <<-- No longer needed

    return Scaffold(
      backgroundColor: Colors.white, // Default white body background
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A58D0), // Blue AppBar color
        elevation: 0, // Remove AppBar shadow
        automaticallyImplyLeading: false, // Don't show automatic back button
        title: const Text(
          'NetrAI',
          style: TextStyle(
            color: Colors.white, // White AppBar text color
            fontSize: 24, // Text size from Figma
            fontWeight: FontWeight.w600, // Weight from Figma (SemiBold)
            fontFamily: 'Inter',
            height: 1.33,
          ),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          // Ensure consistent overlay
          statusBarColor: Color(0xFF3A58D0),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20), // Distance from AppBar
                    // Subtitle/Description
                    const Text(
                      'Making everyday moments easier, one step at a time.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30), // Distance to feature list
                    // Feature List
                    _buildFeatureItem(
                      iconPath: 'assets/icons/camera_icon.svg',
                      description:
                          'With NetrAI, your camera becomes a smart assistant—reading text, finding objects, exploring spaces, and guiding you through your day with confidence.',
                    ),
                    _buildFeatureItem(
                      iconPath: 'assets/icons/mic_icon.svg',
                      description:
                          'Need help on the go? Just ask NetrAI, your voice-powered companion for independent living.',
                    ),
                    _buildFeatureItem(
                      iconPath: 'assets/icons/lamp_icon.svg',
                      description:
                          'Get real-time guidance! NetrAI provides helpful voice tips when using the camera—letting you know if you\\\'re too close, too shaky, or need to adjust your angle.',
                    ),
                    _buildFeatureItem(
                      iconPath: 'assets/icons/Pin_fill.svg',
                      description:
                          'NetrAI helps families stay connected by sharing live location, so loved ones can feel close and supported—wherever they are.',
                    ),
                    // Add some space at the end of the scrollable list if needed
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Fixed Buttons Section at the bottom
            Padding(
              padding: const EdgeInsets.only(
                  bottom: 30.0, top: 10.0), // Padding for buttons
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "I Need Visual Assistance" button
                  Container(
                    width: double.infinity,
                    height: buttonHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A58D0),
                      borderRadius: BorderRadius.circular(4.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        final authService = AuthService();
                        final user =
                            await authService.signInWithGoogle(context);
                        if (user != null) {
                          final email = user.email;
                          final usersWithSameEmail = await FirebaseFirestore
                              .instance
                              .collection('users')
                              .where('email', isEqualTo: email)
                              .get();

                          String? existingRole;
                          for (var doc in usersWithSameEmail.docs) {
                            if (doc['role'] != null) {
                              existingRole = doc['role'];
                              break;
                            }
                          }

                          if (existingRole == 'tunanetra') {
                            Navigator.pushReplacementNamed(context, '/main');
                          } else if (existingRole == 'keluarga') {
                            await authService.signOut();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'This account is a family account, it cannot be used to login as a visually impaired user.')),
                            );
                          } else if (existingRole == null) {
                            // New user, create visually impaired role
                            await authService.saveUserRole(
                              user.uid,
                              'tunanetra',
                              email: user.email,
                            );
                            Navigator.pushReplacementNamed(context, '/main');
                          } else {
                            await authService.signOut();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Invalid account role. Please contact the administrator.')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          height: 1.21,
                        ),
                        elevation: 0,
                      ),
                      child: const Text('I Need Visual Assistance'),
                    ),
                  ),
                  const SizedBox(height: 15), // Distance between buttons
                  // "I'm Supporting a Loved One" button
                  Container(
                    width: double.infinity,
                    height: buttonHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A58D0),
                      borderRadius: BorderRadius.circular(4.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        final authService = AuthService();
                        final user =
                            await authService.signInWithGoogle(context);
                        if (user != null) {
                          final email = user.email;
                          final usersWithSameEmail = await FirebaseFirestore
                              .instance
                              .collection('users')
                              .where('email', isEqualTo: email)
                              .get();

                          String? existingRole;
                          for (var doc in usersWithSameEmail.docs) {
                            if (doc['role'] != null) {
                              existingRole = doc['role'];
                              break;
                            }
                          }

                          if (existingRole == 'keluarga') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LocationScreen()),
                            );
                          } else if (existingRole == 'tunanetra') {
                            await authService.signOut();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'This account is a visually impaired user account, it cannot be used to login as a family member.')),
                            );
                          } else if (existingRole == null) {
                            // New user, create family role
                            await authService.saveUserRole(
                              user.uid,
                              'keluarga',
                              email: user.email,
                            );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LocationScreen()),
                            );
                          } else {
                            await authService.signOut();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Invalid account role. Please contact the administrator.')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          height: 1.21,
                        ),
                        elevation: 0,
                      ),
                      child: const Text('I\'m Supporting a Loved One'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
