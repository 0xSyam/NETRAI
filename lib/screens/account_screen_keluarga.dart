import 'package:flutter/material.dart';
// import '../services/auth_service.dart'; // AuthService is used by LogoutButton/Dialog indirectly
// import 'welcome_screen.dart'; // Navigation is handled by the LogoutDialog
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_svg/flutter_svg.dart'; // SvgPicture is in ListActionItem
import 'contact_us_screen.dart';
import '../widgets/common/user_profile_header.dart';
import '../widgets/common/list_action_item.dart';
import '../widgets/common/logout_button.dart';

class AccountScreenKeluarga extends StatelessWidget {
  final String? displayName;
  final String? email;
  final String? photoURL;

  const AccountScreenKeluarga({
    super.key,
    this.displayName,
    this.email,
    this.photoURL,
  });

  // _signOut method was removed as its logic is now centralized in AuthService and triggered by LogoutButton/LogoutDialog.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Account'),
        backgroundColor: const Color(0xFF3A59D1), // Consider creating a common AppBar theme/widget
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          UserProfileHeader(
            displayName: displayName ?? 'Family User', // Translated placeholder
            email: email ?? 'email@example.com', // Generic placeholder
            photoURL: photoURL,
            // Default styles from UserProfileHeader will be used
          ),
          const SizedBox(height: 10.0),
          ListActionItem(
            iconPath: 'assets/images/contact_us_icon.svg',
            text: 'Contact us',
            gap: 11.0, // This specific gap can be customized if needed via ListActionItem params
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactUsScreen(),
                ),
              );
            },
          ),
          const Spacer(),
          // Logout button at the bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: LogoutButton(),
          ),
        ],
      ),
    );
  }
}
