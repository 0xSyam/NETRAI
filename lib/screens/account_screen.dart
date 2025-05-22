import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart'; // SvgPicture is now in ListActionItem
// import 'package:google_sign_in/google_sign_in.dart'; // No longer directly used
import 'package:firebase_auth/firebase_auth.dart'; // Needed for FirebaseAuth.instance.currentUser?.uid
import 'settings_screen.dart';
import 'contact_us_screen.dart';
// import 'welcome_screen.dart'; // Navigation handled by logout_dialog
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../widgets/common/user_profile_header.dart';
import '../widgets/common/list_action_item.dart';
import '../widgets/common/logout_button.dart'; // Import LogoutButton

class AccountScreen extends StatelessWidget {
  final String? displayName;
  final String? email;
  final String? photoURL;

  // final GoogleSignIn _googleSignIn = GoogleSignIn(); // Removed, AuthService handles this

  AccountScreen({
    super.key,
    this.displayName,
    this.email,
    this.photoURL,
  });

  // _signOut method removed, logic is now in AuthService and logout_dialog
  // _buildLogoutButton method removed, replaced by LogoutButton widget
  // _showLogoutDialog method removed, replaced by showLogoutConfirmationDialog function

  // Helper function to show the "Add family account" dialog
  void _showAddFamilyAccountDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 300, // Estimated width
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.white, // Figma: Frame 84
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8.0),
                      topRight: Radius.circular(8.0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your email', // Figma: Label
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600, // Semi-bold
                          fontSize: 14,
                          color: Color(0xFF575757), // Label text color
                        ),
                      ),
                      const SizedBox(height: 5.0),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'Input placeholder', // Figma: Placeholder
                          hintStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500, // Medium
                            fontSize: 14,
                            color: Color(0xFFD9D9D9), // Placeholder color
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0), // Figma: Frame 11941
                            borderSide: const BorderSide(
                              color: Color(0xFF222222), // Figma: Rectangle 1
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(
                              color: Color(0xFF222222),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(
                              color: Color(0xFF3A59D1), // Focused border color
                              width: 2.0,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 10.0),
                        ),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF575757), // Figma: Cancel button
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8.0)),
                          ),
                        ),
                        child: const Text(
                          'Cancel', // Figma: Text
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500, // Medium
                            fontSize: 16,
                            color: Colors.white, // Figma: Text color
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF3A59D1), // Figma: Okay button
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(8.0)),
                          ),
                        ),
                        child: const Text(
                          'Okay', // Figma: Text
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500, // Medium
                            fontSize: 16,
                            color: Colors.white, // Figma: Text color
                          ),
                        ),
                        onPressed: () async {
                          String email = emailController.text.trim();

                          if (email.isEmpty) {
                            Navigator.of(context).pop(); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email cannot be empty'),
                                backgroundColor: Color(0xFFFF6464), // Error color
                                duration: Duration(seconds: 3),
                              ),
                            );
                            return;
                          }

                          try {
                            final query = await FirebaseFirestore.instance
                                .collection('users')
                                .where('email', isEqualTo: email)
                                .get();

                            String? keluargaUid;
                            if (query.docs.isNotEmpty) {
                              keluargaUid = query.docs.first.id;
                            } else {
                              final docRef = await FirebaseFirestore.instance
                                  .collection('users')
                                  .add({'email': email});
                              keluargaUid = docRef.id;
                            }

                            final authService = AuthService();
                            await authService.saveUserRole(
                                keluargaUid, 'keluarga',
                                linkedTo: FirebaseAuth.instance.currentUser?.uid);

                            Navigator.of(context).pop(); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Family account $email successfully added'),
                                backgroundColor: const Color(0xFF3A59D1), // Primary app color
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } catch (e, st) { // Added stack trace to log
                            Navigator.of(context).pop(); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to add family account: ${e.toString()}'),
                                backgroundColor: const Color(0xFFFF6464), // Error color
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            print('Error adding family account: $e\nStack: $st'); // Log with stack trace
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Account',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        leading: IconButton(
          icon: Image.asset('assets/images/arrow_back.png', height: 24),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0, bottom: 100.0),
              child: Column(
                children: [
                  UserProfileHeader(
                    displayName: displayName,
                    email: email,
                    photoURL: photoURL,
                  ),
                  const SizedBox(height: 10.0),
                  ListActionItem(
                    iconPath: 'assets/images/add_family_account_icon.svg',
                    text: 'Add family account',
                    gap: 13.0,
                    onTap: () {
                      _showAddFamilyAccountDialog(context);
                      // print('Add family account tapped'); // Debug log, can be removed
                    },
                  ),
                  ListActionItem(
                    iconPath: 'assets/images/settings_icon.svg',
                    text: 'NetrAI settings',
                    gap: 14.0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  ListActionItem(
                    iconPath: 'assets/images/contact_us_icon.svg',
                    text: 'Contact us',
                    gap: 11.0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactUsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: LogoutButton(), // Use the LogoutButton widget
            ),
          ),
        ],
      ),
    );
  }
}
