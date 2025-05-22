import 'package:flutter/material.dart';
import '../../services/auth_service.dart'; // Adjusted path
import '../../screens/welcome_screen.dart'; // Adjusted path

Future<bool?> showLogoutConfirmationDialog(BuildContext context) async {
  final AuthService authService = AuthService();

  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // User must tap a button
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6.0),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                decoration: const BoxDecoration(
                  color: Color(0xFFB5C0EE),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(6.0),
                    topRight: Radius.circular(6.0),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Are you sure you want to log out?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF575757),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6.0)),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(dialogContext).pop(false); // User cancelled
                      },
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF3A59D1),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(6.0)),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop(true); // Dialog confirmed, now attempt logout
                        try {
                          await authService.signOut();
                          // Navigation should happen in the widget that called this dialog,
                          // based on the returned value.
                          // Example: if (confirmed == true) { Navigator.pushAndRemoveUntil... }
                          // For now, for direct compatibility with AccountScreen's _signOut,
                          // we can do the navigation here, but it's less flexible.
                          // Let's make it flexible by relying on the return value.
                          //
                          // To maintain closer behavior to original for now, and then refactor UI:
                           if (context.mounted) { // Use original context for navigation
                             Navigator.of(context).pushAndRemoveUntil(
                               MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                               (Route<dynamic> route) => false,
                             );
                           }
                        } catch (e) {
                          print("Error signing out from dialog: $e");
                           if (context.mounted) { // Use original context for SnackBar
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Error signing out: ${e.toString()}')),
                             );
                           }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
