import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:netrai/screens/welcome_screen.dart'; // <-- Hapus impor ini
// import 'package:netrai/screens/main_screen.dart'; // Hapus impor MainScreen

// Import Firebase Auth dan AuthService
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart'; // Path diperbaiki

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
    // Beri sedikit waktu agar Flutter selesai inisialisasi jika diperlukan
    // dan context siap digunakan.
    await Future.delayed(Duration.zero);

    final authService = AuthService();

    // Gunakan authStateChanges untuk mendapatkan status terakhir
    final User? currentUser = await authService.authStateChanges.first;

    if (currentUser != null) {
      print(
          "[SplashScreen] Pengguna sudah login (${currentUser.uid}). Mengecek role user...");
      // Ambil role user dari Firestore
      final role = await authService.getUserRole(currentUser.uid);
      print("[SplashScreen] Role user: $role");
      if (!mounted) return;
      if (role == 'keluarga') {
        Navigator.pushReplacementNamed(context, '/location');
      } else if (role == 'tunanetra') {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        // Role tidak dikenal, sign out dan kembali ke welcome
        await authService.signOut();
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    } else {
      print(
          "[SplashScreen] Pengguna belum login. Lanjutkan ke /welcome setelah delay.");
      // Navigasi ke halaman berikutnya setelah beberapa detik jika belum login
      Future.delayed(const Duration(seconds: 3), () {
        // Pastikan widget masih ter-mount sebelum navigasi
        if (mounted) {
          // Ganti navigasi menggunakan pushReplacementNamed
          Navigator.pushReplacementNamed(
              context, '/welcome'); // <-- Gunakan named route
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mendapatkan ukuran layar
    // final screenSize = MediaQuery.of(context).size; // Bisa dihapus jika tidak digunakan

    // TODO: Sesuaikan nilai-nilai hardcoded berdasarkan layout Figma yang lebih detail jika diperlukan
    // Nilai-nilai ini mungkin perlu dihitung secara dinamis atau disesuaikan
    // const double logoTopMargin = 150; // Dihapus, gunakan Column alignment
    // const double logoWidth = 290; // Gunakan ukuran intrinsik gambar atau sesuaikan jika perlu
    // const double textBottomMargin = 50; // Dihapus, gunakan SizedBox
    // const double indicatorBottomMargin = 20; // Dihapus, tidak ada di Figma ini

    return Scaffold(
      backgroundColor: const Color(
        0xFF3A59D1, // Warna latar belakang diperbarui sesuai Figma (#3A59D1)
      ),
      body: Center(
        // Gunakan Center untuk memastikan Column berada di tengah secara horizontal
        child: Padding(
          // Beri padding horizontal keseluruhan jika diperlukan
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Pusatkan item di dalam Column
            crossAxisAlignment:
                CrossAxisAlignment.center, // Pusatkan item secara horizontal
            children: [
              // Logo
              // Pastikan 'assets/images/logo.png' adalah representasi yang benar dari logo Figma
              SvgPicture.asset('assets/images/logo.svg',
                  semanticsLabel: 'NetrAI Logo'),
              const SizedBox(
                height:
                    24, // Jarak antara logo dan teks (sesuaikan jika perlu berdasarkan Figma)
              ),
              // Teks
              Text(
                'Helping you navigate daily life with confidence.',
                textAlign: TextAlign.center, // Sesuai Figma
                style: TextStyle(
                  color: Colors.white, // Sesuai Figma (#FFFFFF)
                  fontSize: 16, // Sesuai Figma
                  fontWeight: FontWeight.w500, // Sesuai Figma
                  fontFamily: 'Inter', // Sesuai Figma
                  // letterSpacing: -0.3, // Dihapus, tidak ada di spesifikasi Figma node ini
                  height: 1.5, // Sesuai Figma (lineHeight 1.5em)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
