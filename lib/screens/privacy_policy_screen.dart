import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle in AppBar
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  // Key for SharedPreferences
  static const String _policyAgreedKey = 'hasAgreedToPolicy';

  // Helper widget for agreement items according to Figma
  Widget _buildAgreementItem({
    required BuildContext context,
    required String iconPath,
    required String text,
    Color iconColor = Colors.black, // Default icon color inside the circle
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // Vertical spacing between items
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align icon with the first line of text
        children: [
          // Circle with icon inside
          Container(
            width: 28, // Adjust circle size if needed
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFB5C0ED), // Circle color from Figma
              shape: BoxShape.circle,
            ),
            margin: const EdgeInsets.only(right: 12.0), // Spacing from circle to text
            padding: const EdgeInsets.all(4), // Padding inside circle for icon
            child: SvgPicture.asset(
              iconPath,
              colorFilter: ColorFilter.mode(
                iconColor,
                BlendMode.srcIn,
              ), // Apply icon color
              // Icon size inside the circle will adapt to container padding
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black, // Text color from Figma (#000000)
                fontSize: 14, // Size from Figma
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400, // Regular
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
    const double horizontalPadding = 30.0; // Adjust padding from Figma
    const double buttonHeight = 51.0;

    // Set status bar to match blue AppBar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF3A58D0),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // For iOS
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white, // Background color (#FFFFFF)
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A58D0), // Blue AppBar color from Figma
        elevation: 0, // Remove shadow
        leading: IconButton(
          // Manual back button
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white), // White icon
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy and Terms', // Title from Figma
          style: TextStyle(
            color: Colors.white, // White title color
            fontSize: 20, // Size from Figma
            fontWeight: FontWeight.w500, // Medium
            fontFamily: 'Inter',
            height: 1.3,
          ),
        ),
        centerTitle: true, // Center title if desired
        systemOverlayStyle: const SystemUiOverlayStyle(
          // Ensure AppBar overlay is consistent
          statusBarColor: Color(0xFF3A58D0),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark, // For iOS
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24), // Spacing from AppBar
            const Text(
              'To use NetrAI, you agree to the following:', // Text from Figma
              style: TextStyle(
                color: Colors.black, // Black text color
                fontSize: 14, // Size from Figma
                fontWeight: FontWeight.w400, // Regular
                fontFamily: 'Inter',
                height: 1.21,
              ),
            ),
            const SizedBox(height: 24), // Spacing to agreement points
            // Agreement points with new icons
            _buildAgreementItem(
              context: context,
              iconPath: 'assets/icons/lock_icon.svg',
              text:
                  'I understand that NetrAI is not a mobility aid and should not replace my primary mobility device.',
            ),
            _buildAgreementItem(
              context: context,
              iconPath: 'assets/icons/camera_policy_icon.svg', // Replace with appropriate camera icon
              text: 'NetrAI can record, review, and share videos for safety.',
            ),
            _buildAgreementItem(
              context: context,
              iconPath: 'assets/icons/data_icon.svg', // Replace with appropriate data icon
              text:
                  'The data, videos, and personal information I submit will be stored and processed in the NetrAI.',
            ),

            const Spacer(), // Push content to the bottom
            // Agreement explanation text
            const Text(
              'By clicking "I agree", I agree to everything above and accept the Terms of Service and Privacy Policy.', // Text from Figma
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black, // Black text color
                fontSize: 14, // Size from Figma
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400, // Regular
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // "I agree" button
            Container(
              width: double.infinity,
              height: buttonHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.0), // Radius from Figma
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25), // Shadow from Figma
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  // Make async
                  // Save agreement status
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_policyAgreedKey, true);
                  // print("Privacy policy agreement status saved."); // Debug log, can be removed

                  // Navigate to MainScreen and remove previous routes using named route
                  if (context.mounted) { // Check if widget is still in tree
                    Navigator.pushNamedAndRemoveUntil(context, '/main', (Route<dynamic> route) => false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A58D0), // Blue button color from Figma
                  foregroundColor: Colors.white, // White text color from Figma
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0), // Radius from Figma
                  ),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 14, // Size from Figma
                    fontWeight: FontWeight.w600, // SemiBold
                    fontFamily: 'Inter',
                    height: 1.21,
                  ),
                  elevation: 0, // Shadow handled by Container
                ),
                child: const Text('I agree'), // Button text from Figma
              ),
            ),
            const SizedBox(height: 30), // Spacing from bottom
          ],
        ),
      ),
    );
  }
}
