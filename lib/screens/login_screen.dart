// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_svg/flutter_svg.dart'; // Import jika Anda menggunakan SVG untuk logo
// import '../services/auth_service.dart'; // Import AuthService
// import 'privacy_policy_screen.dart'; // Import PrivacyPolicyScreen

// class LoginScreen extends StatelessWidget {
//   const LoginScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     // Atur gaya overlay sistem (status bar) - ikon putih seperti WelcomeScreen
//     SystemChrome.setSystemUIOverlayStyle(
//       const SystemUiOverlayStyle(
//         statusBarColor: Color(0xFF3A59D1), // Warna biru dari Figma
//         statusBarIconBrightness: Brightness.light, // Ikon status bar putih
//         statusBarBrightness: Brightness.dark, // Untuk iOS
//       ),
//     );

//     const double horizontalPadding =
//         35.0; // Padding samping (sesuaikan jika perlu)
//     const double buttonHeight =
//         51.0; // Tinggi tombol dari WelcomeScreen (sesuaikan jika perlu)

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF3A59D1), // Warna AppBar biru
//         elevation: 0,
//         title: const Text(
//           'NetrAI', // Judul AppBar
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 24, // Ukuran teks dari Figma (sama dengan WelcomeScreen)
//             fontWeight: FontWeight.w600, // SemiBold
//             fontFamily: 'Inter',
//           ),
//         ),
//         systemOverlayStyle: const SystemUiOverlayStyle(
//           // Pastikan konsisten
//           statusBarColor: Color(0xFF3A59D1),
//           statusBarIconBrightness: Brightness.light,
//           statusBarBrightness: Brightness.dark,
//         ),
//         // Tambahkan tombol back jika diperlukan secara desain
//         // leading: IconButton(
//         //   icon: const Icon(Icons.arrow_back, color: Colors.white),
//         //   onPressed: () => Navigator.of(context).pop(),
//         // ),
//       ),
//       body: Padding(
//         // Padding horizontal untuk seluruh body
//         padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
//         child: Column(
//           // Kolom utama untuk mengatur bagian scroll dan tombol
//           children: [
//             Expanded(
//               // Agar SingleChildScrollView mengisi ruang yang tersedia
//               child: SingleChildScrollView(
//                 // Konten yang bisa di-scroll
//                 child: Column(
//                   // mainAxisAlignment: MainAxisAlignment.center, // Dihapus
//                   crossAxisAlignment: CrossAxisAlignment
//                       .center, // Pusatkan konten secara horizontal
//                   children: [
//                     const SizedBox(height: 40), // Jarak dari AppBar

//                     // Logo NetrAI dari Figma
//                     SvgPicture.asset(
//                       'assets/images/logo_netrai.svg',
//                       width: 150, // Sesuaikan ukuran jika perlu
//                       height: 150, // Sesuaikan ukuran jika perlu
//                     ),
//                     const SizedBox(height: 20), // Jarak dari Logo ke Judul

//                     // Judul "NetrAI" (Teks besar di body)
//                     const Text(
//                       'NetrAI',
//                       style: TextStyle(
//                         color: Colors.black,
//                         fontSize: 36, // Ukuran dari Figma
//                         fontWeight: FontWeight.w600, // SemiBold
//                         fontFamily: 'Inter',
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 15), // Jarak dari Judul ke Deskripsi

//                     // Deskripsi
//                     const Text(
//                       'Making everyday moments easier, one step at a time.',
//                       style: TextStyle(
//                         color: Colors.black, // Warna dari Figma
//                         fontSize: 18, // Ukuran dari Figma
//                         fontWeight: FontWeight.w500, // Medium
//                         fontFamily: 'Inter',
//                         height: 1.5,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     // const SizedBox(height: 50), // Dihapus, jarak diatur di luar scroll view
//                   ],
//                 ),
//               ),
//             ), // Akhir dari Expanded

//             // --- Bagian Tombol (di luar SingleChildScrollView) ---
//             const SizedBox(
//                 height: 30), // Jarak dari konten scroll ke tombol pertama

//             // Tombol "I've Used NetrAI before"
//             Container(
//               width: double.infinity,
//               height: buttonHeight,
//               decoration: BoxDecoration(
//                 color: const Color(0xFF3A59D1), // Warna tombol dari Figma
//                 borderRadius: BorderRadius.circular(4.0),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.25),
//                     spreadRadius: 0,
//                     blurRadius: 20,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: ElevatedButton(
//                 onPressed: () async {
//                   // Panggil fungsi sign in Google
//                   final authService = AuthService();
//                   // Tampilkan indikator loading jika perlu
//                   // (misalnya dengan mengubah LoginScreen menjadi StatefulWidget)
//                   await authService.signInWithGoogle(context);
//                   // Navigasi akan ditangani di dalam signInWithGoogle jika berhasil
//                   print(
//                       "Tombol 'I've Used NetrAI before' ditekan dan proses login Google dimulai");
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.transparent,
//                   shadowColor: Colors.transparent,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(4.0),
//                   ),
//                   padding: EdgeInsets.zero,
//                   textStyle: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600, // SemiBold
//                     fontFamily: 'Inter',
//                   ),
//                 ),
//                 child: const Text('I\'ve Used NetrAI before'),
//               ),
//             ),
//             const SizedBox(height: 13), // Jarak antar tombol (dari Figma: 13px)

//             // Tombol "I'm New to NetrAI"
//             Container(
//               width: double.infinity,
//               height: buttonHeight,
//               decoration: BoxDecoration(
//                 color: const Color(0xFF3A59D1), // Warna tombol dari Figma
//                 borderRadius: BorderRadius.circular(4.0),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.25),
//                     spreadRadius: 0,
//                     blurRadius: 20,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: ElevatedButton(
//                 onPressed: () {
//                   // Navigasi ke PrivacyPolicyScreen
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                         builder: (context) => const PrivacyPolicyScreen()),
//                   );
//                   print(
//                       "Tombol 'I'm New to NetrAI' ditekan dan navigasi ke Privacy Policy");
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.transparent,
//                   shadowColor: Colors.transparent,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(4.0),
//                   ),
//                   padding: EdgeInsets.zero,
//                   textStyle: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600, // SemiBold
//                     fontFamily: 'Inter',
//                   ),
//                 ),
//                 child: const Text('I\'m New to NetrAI'),
//               ),
//             ),

//             const SizedBox(
//                 height: 40), // Jarak dari tombol terakhir ke bawah layar
//           ],
//         ),
//       ),
//     );
//   }
// }
