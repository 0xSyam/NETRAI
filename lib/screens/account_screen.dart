import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Import google_sign_in
import 'package:firebase_auth/firebase_auth.dart'; // <-- Add this import
import 'settings_screen.dart'; // Import SettingsScreen (relative path)
import 'contact_us_screen.dart'; // <-- Import ContactUsScreen (relative path)
import 'welcome_screen.dart'; // <-- Add import for WelcomeScreen
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
// TODO: Replace with import to your login screen
// import 'login_screen.dart'; // Example login screen import

// // Simple model for account data (replace with your model) - NOT USED
// class Account {
//   final String name;
//   final String email;
//   final String? avatarUrl; // Can be null if using placeholder
//
//   Account({required this.name, required this.email, this.avatarUrl});
// }

class AccountScreen extends StatelessWidget {
  // Tambahkan field untuk data pengguna
  final String? displayName;
  final String? email;
  final String? photoURL;

  // Instance GoogleSignIn
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AccountScreen({
    super.key,
    this.displayName, // Jadikan opsional jika ada kemungkinan null
    this.email,
    this.photoURL,
  });

  // // Contoh data akun (gantilah dengan data asli dari aplikasi Anda) - TIDAK DIGUNAKAN
  // final List<Account> _accounts = [
  //   Account(
  //     name: 'Ghani Zulhusni Bahri',
  //     email: 'ghanizulhusnibahri@mail.ugm.ac.id',
  //   ),
  //   Account(name: 'NetrAI', email: 'netraiteam01@gmail.com'),
  //   Account(
  //     name: 'Adinda Zulfa Aulia',
  //     email: 'adindazulfaaulia@mail.ugm.ac.id',
  //   ),
  //   Account(
  //     name: 'M Iqbal Sinulingga',
  //     email: 'miqbalsinulingga@mail.ugm.ac.id',
  //   ),
  //   Account(
  //     name: 'Muhammad Hisyam Ardiansyah',
  //     email: 'muhammadhisyamardiansyah@mail.ugm.ac.id',
  //   ),
  // ];

  // // Helper widget untuk satu baris akun - TIDAK DIGUNAKAN
  // Widget _buildAccountItem(BuildContext context, Account account) {
  //   return ListTile(
  //     contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Padding item
  //     leading: CircleAvatar(
  //       radius: 20, // Sesuaikan radius jika perlu
  //       backgroundColor: Colors.grey.shade300, // Placeholder avatar (#D9D9D9)
  //       // TODO: Ganti dengan avatar asli jika ada
  //       // backgroundImage: account.avatarUrl != null ? NetworkImage(account.avatarUrl!) : null,
  //       child: account.avatarUrl == null
  //           ? Text(
  //               account.name.isNotEmpty ? account.name[0].toUpperCase() : '?', // Inisial
  //               style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
  //             )
  //           : null,
  //     ),
  //     title: Text(
  //       account.name,
  //       style: const TextStyle(
  //         fontSize: 13, // Sesuaikan dengan Figma jika berbeda
  //         fontWeight: FontWeight.w500, // Medium
  //         fontFamily: 'Inter',
  //         color: Colors.black, // Warna teks hitam
  //       ),
  //     ),
  //     subtitle: Text(
  //       account.email,
  //       style: const TextStyle(
  //         fontSize: 11, // Sesuaikan dengan Figma jika berbeda
  //         fontWeight: FontWeight.w400, // Regular
  //         fontFamily: 'Inter',
  //         color: Colors.black54, // Warna teks abu-abu
  //       ),
  //     ),
  //     onTap: () {
  //       // TODO: Implementasi aksi saat memilih akun
  //       print('Selected account: ${account.email}');
  //       Navigator.pop(context); // Tutup layar setelah memilih
  //     },
  //   );
  // }

  // Helper widget for action item - Updated with SVG icon
  Widget _buildActionItem({
    required BuildContext context,
    required String iconPath, // Path to SVG icon
    required String text,
    required VoidCallback onTap,
    double iconWidth = 24.0, // Default icon width
    double iconHeight = 24.0, // Default icon height
    double gap = 12.0, // Distance between icon and text (adjust from Figma)
  }) {
    return InkWell(
      // Use InkWell for ripple effect
      onTap: onTap,
      child: Padding(
        // Horizontal padding set here, vertical set by Column
        padding: const EdgeInsets.symmetric(
            horizontal: 16.0, vertical: 12.0), // Return/adjust vertical padding
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: iconWidth,
              height: iconHeight,
              // Make sure color filter is not applied if icon is already colored - RESTORED
              colorFilter:
                  const ColorFilter.mode(Colors.black, BlendMode.srcIn),
            ),
            SizedBox(width: gap), // Gap between icon and text
            Text(
              text,
              style: const TextStyle(
                fontSize: 12, // As per Figma
                fontWeight: FontWeight.w500, // Medium
                fontFamily: 'Inter',
                color: Colors.black, // Black text color
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function for logout
  Future<void> _signOut(BuildContext context) async {
    try {
      // Logout from Google Sign-In
      await _googleSignIn.signOut();
      print("Google Sign-Out successful");

      // Logout from Firebase Authentication
      await FirebaseAuth.instance.signOut();
      print("Firebase Auth Sign-Out successful");

      // Make sure all credentials are cleared
      await FirebaseAuth.instance.authStateChanges().first;

      // Navigate to WelcomeScreen after logout and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Error signing out: $e");
      // Optional: show SnackBar or dialog if error occurs
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  // New helper widget for Logout Button as per Figma
  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: 290,
      height: 51,
      decoration: BoxDecoration(
        color: const Color(0xFF3A59D1), // Background color from Figma
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25), // Shadow from Figma
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _showLogoutDialog(context), // Panggil fungsi _showLogoutDialog
          borderRadius: BorderRadius.circular(8.0),
          child: const Center(
            child: Text(
              'Log Out',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600, // Semi-bold (600)
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Fungsi untuk menampilkan dialog konfirmasi logout
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Pengguna harus menekan tombol untuk menutup
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(6.0), // Sesuai dengan Frame 82 di Figma
          ),
          contentPadding: EdgeInsets.zero, // Hapus padding default
          content: Container(
            width: 300, // Perkiraan lebar, bisa disesuaikan agar konsisten
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  // Frame 77 di Figma
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 24.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFB5C0EE), // Warna latar dari Figma
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6.0),
                      topRight: Radius.circular(6.0),
                    ),
                  ),
                  child: const Center(
                    // Center widget ditambahkan
                    child: Text(
                      'Are you sure you want to log out?',
                      textAlign: TextAlign.center, // Teks di tengah
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500, // Medium
                        fontSize: 16,
                        color: Colors.black, // Warna teks dari Figma
                      ),
                    ),
                  ),
                ),
                Row(
                  // Frame 81 di Figma
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(
                              0xFF575757), // Warna tombol Cancel dari Figma
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomLeft:
                                    Radius.circular(6.0)), // Sesuai Frame 82
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500, // Medium
                            fontSize: 16,
                            color: Colors.white, // Warna teks dari Figma
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(); // Tutup dialog
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(
                              0xFF3A59D1), // Warna tombol Log Out dari Figma
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomRight:
                                    Radius.circular(6.0)), // Sesuai Frame 82
                          ),
                        ),
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500, // Medium
                            fontSize: 16,
                            color: Colors.white, // Warna teks dari Figma
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext)
                              .pop(); // Tutup dialog dulu
                          _signOut(
                              context); // Panggil fungsi signOut dari context utama
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
          contentPadding: EdgeInsets.zero, // Remove default padding
          content: Container(
            width: 300, // Estimated width from Figma, can be adjusted
            child: Column(
              mainAxisSize:
                  MainAxisSize.min, // So dialog doesn't take full height
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.white, // Color from Figma (Frame 84)
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8.0),
                      topRight: Radius.circular(8.0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your email', // Label from Figma
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
                          hintText:
                              'Input placeholder', // Placeholder from Figma
                          hintStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500, // Medium
                            fontSize: 14,
                            color: Color(0xFFD9D9D9), // Placeholder color
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                8.0), // Border radius from Figma (Frame 11941)
                            borderSide: const BorderSide(
                              color: Color(
                                  0xFF222222), // Border color from Figma (Rectangle 1)
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
                              color: Color(
                                  0xFF3A59D1), // Border color when focused (optional, can be adjusted)
                              width: 2.0,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 10.0), // Input field padding
                        ),
                        style: const TextStyle(
                          // Style for user input text
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
                          backgroundColor: const Color(
                              0xFF575757), // Color from Figma (Add fam acc button - Cancel)
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8.0)),
                          ),
                        ),
                        child: const Text(
                          'Cancel', // Text from Figma
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500, // Medium
                            fontSize: 16,
                            color: Colors.white, // Text color from Figma
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
                          backgroundColor: const Color(
                              0xFF3A59D1), // Color from Figma (Add fam acc button - Okay)
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(8.0)),
                          ),
                        ),
                        child: const Text(
                          'Okay', // Text from Figma
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500, // Medium
                            fontSize: 16,
                            color: Colors.white, // Text color from Figma
                          ),
                        ),
                        onPressed: () async {
                          String email = emailController.text.trim();

                          // Validasi email kosong
                          if (email.isEmpty) {
                            // Tutup dialog
                            Navigator.of(context).pop();

                            // Tampilkan pesan error email kosong
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email cannot be empty'),
                                backgroundColor: Color(
                                    0xFFFF6464), // Warna merah untuk error
                                duration: Duration(seconds: 3),
                              ),
                            );
                            return;
                          }

                          try {
                            // Find family user by email
                            final query = await FirebaseFirestore.instance
                                .collection('users')
                                .where('email', isEqualTo: email)
                                .get();

                            String? keluargaUid;
                            if (query.docs.isNotEmpty) {
                              keluargaUid = query.docs.first.id;
                            } else {
                              // If doesn't exist, create new document with email as ID
                              final docRef = await FirebaseFirestore.instance
                                  .collection('users')
                                  .add({
                                'email': email,
                              });
                              keluargaUid = docRef.id;
                            }

                            // Save family role and link to visually impaired user
                            final authService = AuthService();
                            await authService.saveUserRole(
                                keluargaUid, 'keluarga',
                                linkedTo:
                                    FirebaseAuth.instance.currentUser?.uid);

                            // Tutup dialog
                            Navigator.of(context).pop();

                            // Tampilkan notifikasi berhasil
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Family account $email successfully added'),
                                backgroundColor: const Color(
                                    0xFF3A59D1), // Warna primary app
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } catch (e) {
                            // Tutup dialog
                            Navigator.of(context).pop();

                            // Tampilkan notifikasi gagal
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Failed to add family account: ${e.toString()}'),
                                backgroundColor: const Color(
                                    0xFFFF6464), // Warna merah untuk error
                                duration: const Duration(seconds: 3),
                              ),
                            );

                            print('Error menambahkan akun keluarga: $e');
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
      backgroundColor: Colors.white, // White background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, // No shadow
        title: const Text(
          // AppBar title can be adjusted if needed
          'Account', // Title as per Figma (or 'Choose an account' if more appropriate)
          style: TextStyle(
            color: Colors.black,
            fontSize: 16, // Adjust font size if needed
            fontWeight: FontWeight.w500, // Medium
            fontFamily: 'Inter',
          ),
        ),
        leading: IconButton(
          // Replace with back icon from Figma if needed
          icon: Image.asset('assets/images/arrow_back.png', height: 24),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        centerTitle: true, // Center title
      ),
      body: Stack(
        // Use Stack to place logout button at the bottom
        children: [
          SingleChildScrollView(
            // Make main content scrollable
            child: Padding(
              // Top padding for space from AppBar, and bottom padding to make room for logout button
              padding: const EdgeInsets.only(
                  top: 10.0,
                  bottom:
                      100.0), // bottom: button height + top & bottom margins
              child: Column(
                children: [
                  // Widget to display user profile
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 20.0), // Adjust padding
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius:
                              28, // Adjust radius to match Figma (e.g. 56px diameter / 2)
                          backgroundColor: const Color(
                              0xFFD9D9D9), // Placeholder avatar color
                          backgroundImage:
                              photoURL != null && photoURL!.isNotEmpty
                                  ? NetworkImage(photoURL!)
                                  : null,
                          child: (photoURL == null || photoURL!.isEmpty) &&
                                  (displayName != null &&
                                      displayName!.isNotEmpty)
                              ? Text(
                                  displayName![0]
                                      .toUpperCase(), // Initial from user name
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.black54, // Initial text color
                                  ),
                                )
                              : (photoURL == null ||
                                      photoURL!
                                          .isEmpty) // If photo and name don't exist, show default icon
                                  ? const Icon(Icons.person,
                                      size: 28, color: Colors.black54)
                                  : null,
                        ),
                        const SizedBox(
                            width: 16.0), // Gap between avatar and text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName ??
                                    'User Name', // Show name or placeholder
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500, // Medium
                                  fontFamily: 'Inter',
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(
                                  height:
                                      2.0), // Gap between name and email (adjust from Figma)
                              Text(
                                email ??
                                    'email@example.com', // Show email or placeholder
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400, // Regular
                                  fontFamily: 'Inter',
                                  color: Color(
                                      0xFF828282), // Email color as per Figma (#828282)
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                      height:
                          10.0), // Gap between profile and first action item

                  // Daftar aksi menggunakan _buildActionItem
                  _buildActionItem(
                    context: context,
                    iconPath: 'assets/images/add_family_account_icon.svg',
                    text: 'Add family account',
                    gap: 13.0, // Sesuaikan gap dari Figma
                    onTap: () {
                      _showAddFamilyAccountDialog(context);
                      print('Add family account tapped');
                    },
                  ),
                  _buildActionItem(
                    context: context,
                    iconPath: 'assets/images/settings_icon.svg',
                    text: 'NetrAI settings',
                    gap: 14.0, // Sesuaikan gap dari Figma
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionItem(
                    context: context,
                    iconPath: 'assets/images/contact_us_icon.svg',
                    text: 'Contact us',
                    gap: 11.0, // Sesuaikan gap dari Figma
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactUsScreen(),
                        ),
                      );
                    },
                  ),
                  // Tombol Logout dan SizedBox di sekitarnya telah dipindahkan ke Align di bawah
                ],
              ),
            ),
          ),
          Align(
            // Widget untuk memposisikan tombol logout di bagian bawah
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                  bottom:
                      15.0), // Jarak tombol logout dari tepi bawah layar (DIUBAH menjadi 0.0)
              child: _buildLogoutButton(
                  context), // Tombol Logout Baru sesuai Figma
            ),
          ),
        ],
      ),
    );
  }
}
