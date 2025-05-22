import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle
// import 'package:netrai/screens/settings_screen.dart'; // <-- SettingsScreen import commented out
// import 'package:netrai/screens/account_screen.dart'; // <-- AccountScreen import commented out

// StatelessWidget for Home screen (focused on View tab)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Colors from Figma
    const Color primaryBlue = Color(0xFF3A58D0);
    const Color primaryWhite = Colors.white;
    // const Color inactiveGrey = Color(0xFFB5C0ED); // Unused: Inactive nav text color
    const Color bodyBackground = Colors.black; // Assuming dark background for camera view

    // Set status bar to match blue AppBar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: primaryBlue,
        statusBarIconBrightness: Brightness.light, // White icons on status bar
      ),
    );

    return Scaffold(
      backgroundColor: bodyBackground, // Dark body background
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        automaticallyImplyLeading: false, // No back button
        title: const Text(
          'View',
          style: TextStyle(
            color: primaryWhite,
            fontSize: 18, // Adjust size if needed
            fontWeight: FontWeight.w500, // Medium
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/question_icon.svg',
              width: 24,
              height: 24,
            ),
            onPressed: () {
              // TODO: Replace with navigation to HelpScreen if available
              print('Help button pressed - Navigation not set yet');
            },
            tooltip: 'Help',
          ),
          IconButton(
            icon: const Icon(
              Icons.account_circle, // Placeholder profile icon
              color: primaryWhite, // White color
              size: 28, // Adjust size if needed
            ),
            onPressed: () {
              // Navigate to account page
              print('Account button pressed - Navigation to AccountScreen (COMMENTED OUT)');
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder:
              //         (context) =>
              //             AccountScreen(), // << Commented out AccountScreen Navigation
              //   ),
              // );
            },
            tooltip: 'Account',
          ),
          const SizedBox(width: 8), // Spacing at the right end
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: primaryBlue,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Stack(
        // Use Stack to layer elements
        alignment: Alignment.center,
        children: [
          // --- Placeholder for Camera View ---
          // This can be replaced with CameraPreview widget later
          Container(
            color: bodyBackground, // Black/dark background color
            // Optional: Add a video icon in the center as an initial placeholder
            // child: Center(
            //   child: SvgPicture.asset(
            //     'assets/icons/video_placeholder.svg', // Replace with video icon if available
            //     width: 100,
            //     colorFilter: ColorFilter.mode(Colors.grey.shade800, BlendMode.srcIn),
            //   ),
            // ),
          ),

          // --- Action Buttons at the Bottom ---
          // Use Align to position the button group
          Align(
            alignment: Alignment.bottomCenter, // Align to bottom center overall
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 30.0,
                left: 20,
                right: 20,
              ), // Padding from bottom and sides
              child: Stack(
                // Stack to layer center button and right buttons
                alignment: Alignment.bottomCenter, // Align items in stack to bottom center
                children: [
                  // "Speak to NetrAI" button (center)
                  Padding(
                    // Add a little bottom padding so it's not obscured by circular buttons if they overlap
                    padding: const EdgeInsets.only(bottom: 0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // print('Speak to NetrAI button pressed'); // Debug log
                      },
                      icon: SvgPicture.asset(
                        'assets/icons/mic_icon_white.svg',
                        width: 20,
                        height: 20,
                      ),
                      label: const Text('Speak to NetrAI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: primaryWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                        elevation: 4,
                        shadowColor: Colors.black.withOpacity(0.25),
                      ),
                    ),
                  ),

                  // Circular Buttons on the Bottom Right
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Column size to fit content
                      children: [
                        _buildCircularButton(
                          iconPath: 'assets/icons/switch_camera_icon_white.svg', // Switch camera icon (top)
                          onPressed: () {
                            // print('Switch Camera button pressed'); // Debug log
                          },
                          buttonColor: primaryBlue,
                        ),
                        const SizedBox(height: 15), // Vertical spacing between circular buttons
                        _buildCircularButton(
                          iconPath: 'assets/icons/camera_icon_white.svg', // Camera icon (bottom)
                          onPressed: () {
                            // print('Camera button pressed'); // Debug log
                          },
                          buttonColor: primaryBlue,
                        ),
                        // Add a small SizedBox at the bottom if needed to align with Speak button
                        const SizedBox(height: 5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for circular buttons
  Widget _buildCircularButton({
    required String iconPath,
    required VoidCallback onPressed,
    required Color buttonColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: buttonColor.withOpacity(0.8), // Use buttonColor parameter
        shape: BoxShape.circle,
        boxShadow: [
          // Optional shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: SvgPicture.asset(
          iconPath,
          width: 24, // Icon size inside button
          height: 24,
          colorFilter: const ColorFilter.mode(
            Colors.white, // Ensure icon is white
            BlendMode.srcIn,
          ),
        ),
        onPressed: onPressed,
        padding: const EdgeInsets.all(15), // Padding to increase tap area
        visualDensity: VisualDensity.compact, // Compact internal padding
        color: Colors.white, // Ripple effect color (optional)
      ),
    );
  }
}
