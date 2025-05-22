import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:netrai/screens/welcome_screen.dart'; // <-- WelcomeScreen import removed
// import 'package:netrai/screens/main_screen.dart'; // MainScreen import removed

// Import Firebase Auth and AuthService
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart'; // Path corrected

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatusAndNavigate();
  }

  Future<void> _checkLoginStatusAndNavigate() async {
    // Allow a brief moment for Flutter to initialize if needed,
    // and for the context to be ready.
    await Future.delayed(Duration.zero);

    final authService = AuthService();

    // Use authStateChanges to get the latest status
    final User? currentUser = await authService.authStateChanges.first;

    if (currentUser != null) {
      // print("[SplashScreen] User is logged in (${currentUser.uid}). Checking user role..."); // Debug log, can be removed
      // Get user role from Firestore
      final role = await authService.getUserRole(currentUser.uid);
      // print("[SplashScreen] User role: $role"); // Debug log, can be removed
      if (!mounted) return;
      if (role == 'keluarga') { // 'keluarga' means family
        Navigator.pushReplacementNamed(context, '/location');
      } else if (role == 'tunanetra') { // 'tunanetra' means visually impaired
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        // Unknown role, sign out and return to welcome
        await authService.signOut();
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    } else {
      // print("[SplashScreen] User not logged in. Proceeding to /welcome after delay."); // Debug log, can be removed
      // Navigate to the next page after a few seconds if not logged in
      Future.delayed(const Duration(seconds: 3), () {
        // Ensure the widget is still mounted before navigation
        if (mounted) {
          // Replace navigation using pushReplacementNamed
          Navigator.pushReplacementNamed(context, '/welcome'); // <-- Use named route
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size
    // final screenSize = MediaQuery.of(context).size; // Can be removed if not used

    // TODO: Adjust hardcoded values based on more detailed Figma layout if needed
    // These values might need to be calculated dynamically or adjusted
    // const double logoTopMargin = 150; // Removed, use Column alignment
    // const double logoWidth = 290; // Use intrinsic image size or adjust if needed
    // const double textBottomMargin = 50; // Removed, use SizedBox
    // const double indicatorBottomMargin = 20; // Removed, not in this Figma design

    return Scaffold(
      backgroundColor: const Color(0xFF3A59D1), // Background color updated as per Figma (#3A59D1)
      body: Center(
        // Use Center to ensure Column is horizontally centered
        child: Padding(
          // Add overall horizontal padding if needed
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center items within Column
            crossAxisAlignment: CrossAxisAlignment.center, // Center items horizontally
            children: [
              // Logo
              // Ensure 'assets/images/logo.png' is the correct representation from Figma
              SvgPicture.asset('assets/images/logo.svg',
                  semanticsLabel: 'NetrAI Logo'),
              const SizedBox(
                height: 24, // Spacing between logo and text (adjust if needed based on Figma)
              ),
              // Text
              Text(
                'Helping you navigate daily life with confidence.',
                textAlign: TextAlign.center, // As per Figma
                style: TextStyle(
                  color: Colors.white, // As per Figma (#FFFFFF)
                  fontSize: 16, // As per Figma
                  fontWeight: FontWeight.w500, // As per Figma
                  fontFamily: 'Inter', // As per Figma
                  // letterSpacing: -0.3, // Removed, not in this Figma node's specs
                  height: 1.5, // As per Figma (lineHeight 1.5em)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
