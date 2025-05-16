import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart'; // Untuk SystemUiOverlayStyle
// import 'package:netrai/screens/settings_screen.dart'; // <-- Komentari impor SettingsScreen
// import 'package:netrai/screens/account_screen.dart'; // <-- Komentari impor AccountScreen

// Stateless Widget untuk tampilan Home (fokus pada tab View)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Warna dari Figma
    const Color primaryBlue = Color(0xFF3A58D0);
    const Color primaryWhite = Colors.white;
    const Color inactiveGrey = Color(0xFFB5C0ED); // Warna teks nav tidak aktif
    const Color bodyBackground = Colors.black; // Asumsi BG gelap untuk kamera

    // Atur status bar agar cocok dengan AppBar biru
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: primaryBlue,
        statusBarIconBrightness: Brightness.light, // Ikon putih di status bar
      ),
    );

    return Scaffold(
      backgroundColor: bodyBackground, // Latar belakang body gelap
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        automaticallyImplyLeading: false, // Tidak ada tombol back
        title: const Text(
          'View',
          style: TextStyle(
            color: primaryWhite,
            fontSize: 18, // Sesuaikan ukuran jika perlu
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
              // TODO: Ganti dengan navigasi ke HelpScreen jika sudah ada
              print('Tombol Bantuan ditekan - Navigasi belum diatur');
            },
            tooltip: 'Help',
          ),
          IconButton(
            icon: const Icon(
              Icons.account_circle, // Placeholder ikon profil
              color: primaryWhite, // Warna putih
              size: 28, // Sesuaikan ukuran jika perlu
            ),
            onPressed: () {
              // Navigasi ke halaman akun
              print(
                  'Tombol Akun ditekan - Navigasi ke AccountScreen (DIKOMENTARI SEMENTARA)');
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder:
              //         (context) =>
              //             AccountScreen(), // << Komentari Navigasi ke AccountScreen
              //   ),
              // );
            },
            tooltip: 'Account',
          ),
          const SizedBox(width: 8), // Jarak di ujung kanan
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: primaryBlue,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Stack(
        // Gunakan Stack untuk menumpuk elemen
        alignment: Alignment.center,
        children: [
          // --- Placeholder untuk Kamera View ---
          // Ini bisa diganti dengan widget CameraPreview nanti
          Container(
            color: bodyBackground, // Warna latar belakang hitam/gelap
            // Mungkin tambahkan ikon video di tengah sebagai placeholder awal
            // child: Center(
            //   child: SvgPicture.asset(
            //     'assets/icons/video_placeholder.svg', // Ganti dengan ikon video jika ada
            //     width: 100,
            //     colorFilter: ColorFilter.mode(Colors.grey.shade800, BlendMode.srcIn),
            //   ),
            // ),
          ),

          // --- Tombol Aksi di Bawah ---
          // Gunakan Align untuk menempatkan grup tombol
          Align(
            alignment: Alignment
                .bottomCenter, // Align ke bawah tengah secara keseluruhan
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 30.0,
                left: 20,
                right: 20,
              ), // Padding dari tepi bawah dan samping
              child: Stack(
                // Stack untuk menumpuk tombol tengah dan tombol kanan
                alignment: Alignment
                    .bottomCenter, // Align item dalam stack ke bawah tengah
                children: [
                  // Tombol "Speak to NetrAI" (di tengah)
                  Padding(
                    // Beri sedikit padding bawah agar tidak tertutup tombol bulat jika overlap
                    padding: const EdgeInsets.only(bottom: 0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        print('Tombol Speak to NetrAI ditekan');
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

                  // Tombol Bulat di Kanan Bawah
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min, // Ukuran column sesuai isi
                      children: [
                        _buildCircularButton(
                          iconPath:
                              'assets/icons/switch_camera_icon_white.svg', // Switch di atas
                          onPressed: () {
                            print('Tombol Switch Kamera ditekan');
                          },
                          buttonColor: primaryBlue,
                        ),
                        const SizedBox(
                          height: 15,
                        ), // Jarak vertikal antar tombol bulat
                        _buildCircularButton(
                          iconPath:
                              'assets/icons/camera_icon_white.svg', // Kamera di bawah
                          onPressed: () {
                            print('Tombol Kamera ditekan');
                          },
                          buttonColor: primaryBlue,
                        ),
                        // Tambahkan SizedBox kecil di bawah jika perlu agar sejajar dgn tombol Speak
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

  // Helper widget untuk tombol bulat
  Widget _buildCircularButton({
    required String iconPath,
    required VoidCallback onPressed,
    required Color buttonColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: buttonColor.withOpacity(0.8), // Gunakan parameter warna
        shape: BoxShape.circle,
        boxShadow: [
          // Opsi shadow jika diperlukan
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
          width: 24, // Ukuran ikon di dalam tombol
          height: 24,
          colorFilter: const ColorFilter.mode(
            Colors.white,
            BlendMode.srcIn,
          ), // Pastikan ikon putih
        ),
        onPressed: onPressed,
        padding: const EdgeInsets.all(
          15,
        ), // Padding untuk memperbesar area tekan
        visualDensity: VisualDensity.compact, // Rapatkan padding internal
        color: Colors.white, // Warna ripple effect (opsional)
      ),
    );
  }
}
