import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'contact_us_screen.dart';

class AccountScreenKeluarga extends StatelessWidget {
  // Tambahkan field untuk data pengguna
  final String? displayName;
  final String? email;
  final String? photoURL;

  const AccountScreenKeluarga({
    Key? key,
    this.displayName,
    this.email,
    this.photoURL,
  }) : super(key: key);

  // Fungsi untuk proses logout
  Future<void> _signOut(BuildContext context) async {
    final authService = AuthService();
    try {
      await authService.signOut();
      // Navigate to WelcomeScreen and remove all previous routes
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal logout: ${e.toString()}')),
        );
      }
    }
  }

  // Helper widget for action item with SVG icon
  Widget _buildActionItem({
    required BuildContext context,
    required String iconPath,
    required String text,
    required VoidCallback onTap,
    double iconWidth = 24.0,
    double iconHeight = 24.0,
    double gap = 12.0,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: iconWidth,
              height: iconHeight,
              colorFilter:
                  const ColorFilter.mode(Colors.black, BlendMode.srcIn),
            ),
            SizedBox(width: gap),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Account'),
        backgroundColor: Color(0xFF3A59D1),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Widget untuk menampilkan profil pengguna
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFD9D9D9),
                  backgroundImage: photoURL != null && photoURL!.isNotEmpty
                      ? NetworkImage(photoURL!)
                      : null,
                  child: (photoURL == null || photoURL!.isEmpty) &&
                          (displayName != null && displayName!.isNotEmpty)
                      ? Text(
                          displayName![0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.black54,
                          ),
                        )
                      : (photoURL == null || photoURL!.isEmpty)
                          ? const Icon(Icons.person,
                              size: 28, color: Colors.black54)
                          : null,
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName ?? 'Pengguna Keluarga',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        email ?? 'email@contoh.com',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                          color: Color(0xFF828282),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10.0),

          // Tambahkan tombol Contact Us
          _buildActionItem(
            context: context,
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

          const Spacer(),
          // Tombol logout di bagian bawah
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SizedBox(
              width: 290,
              height: 51,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A59D1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 4,
                ),
                onPressed: () => _signOut(context),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
