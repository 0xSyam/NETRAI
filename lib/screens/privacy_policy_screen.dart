import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart'; // Untuk SystemUiOverlayStyle di AppBar
import 'package:shared_preferences/shared_preferences.dart'; // Tambahkan impor ini

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  // Kunci untuk SharedPreferences
  static const String _policyAgreedKey = 'hasAgreedToPolicy';

  // Helper widget untuk item persetujuan sesuai Figma
  Widget _buildAgreementItem({
    required BuildContext context,
    required String iconPath,
    required String text,
    Color iconColor = Colors.black, // Default warna ikon di dalam lingkaran
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // Jarak vertikal antar item
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Align ikon dengan baris pertama teks
        children: [
          // Lingkaran dengan ikon di dalamnya
          Container(
            width: 28, // Sesuaikan ukuran lingkaran jika perlu
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFB5C0ED), // Warna lingkaran dari Figma
              shape: BoxShape.circle,
            ),
            margin: const EdgeInsets.only(
              right: 12.0,
            ), // Jarak lingkaran ke teks
            padding: const EdgeInsets.all(
              4,
            ), // Padding di dalam lingkaran untuk ikon
            child: SvgPicture.asset(
              iconPath,
              colorFilter: ColorFilter.mode(
                iconColor,
                BlendMode.srcIn,
              ), // Terapkan warna ikon
              // Ukuran ikon di dalam lingkaran akan mengikuti padding container
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black, // Warna teks dari Figma (#000000)
                fontSize: 14, // Ukuran dari Figma
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400, // Regular
                height: 1.5, // Line height dari Figma
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double horizontalPadding = 30.0; // Sesuaikan padding dari Figma
    const double buttonHeight = 51.0;

    // Atur status bar agar cocok dengan AppBar biru
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF3A58D0),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white, // Warna latar (#FFFFFF)
      appBar: AppBar(
        backgroundColor: const Color(
          0xFF3A58D0,
        ), // Warna AppBar biru dari Figma
        elevation: 0, // Hilangkan shadow
        leading: IconButton(
          // Tombol kembali manual
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ), // Ikon putih
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy and Terms', // Judul dari Figma
          style: TextStyle(
            color: Colors.white, // Warna judul putih
            fontSize: 20, // Ukuran dari Figma
            fontWeight: FontWeight.w500, // Medium
            fontFamily: 'Inter',
            height: 1.3,
          ),
        ),
        centerTitle: true, // Pusatkan judul jika diinginkan
        systemOverlayStyle: const SystemUiOverlayStyle(
          // Pastikan overlay AppBar konsisten
          statusBarColor: Color(0xFF3A58D0),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24), // Jarak dari AppBar
            const Text(
              'To use NetrAI, you agree to the following:', // Teks dari Figma
              style: TextStyle(
                color: Colors.black, // Warna teks hitam
                fontSize: 14, // Ukuran dari Figma
                fontWeight: FontWeight.w400, // Regular
                fontFamily: 'Inter',
                height: 1.21,
              ),
            ),
            const SizedBox(height: 24), // Jarak ke poin persetujuan
            // Poin-poin persetujuan dengan ikon baru
            _buildAgreementItem(
              context: context,
              iconPath: 'assets/icons/lock_icon.svg',
              text:
                  'I understand that NetrAI is not a mobility aid and should not replace my primary mobility device.',
            ),
            _buildAgreementItem(
              context: context,
              iconPath:
                  'assets/icons/camera_policy_icon.svg', // Ganti dengan ikon kamera yang sesuai
              text: 'NetrAI can record, review, and share videos for safety.',
            ),
            _buildAgreementItem(
              context: context,
              iconPath:
                  'assets/icons/data_icon.svg', // Ganti dengan ikon data yang sesuai
              text:
                  'The data, videos, and personal information I submit will be stored and processed in the NetrAI.',
            ),

            const Spacer(), // Dorong konten ke bawah
            // Teks penjelasan agreement
            const Text(
              'By clicking "I agree", I agree to everything above and accept the Terms of Service and Privacy Policy.', // Teks dari Figma
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black, // Warna teks hitam
                fontSize: 14, // Ukuran dari Figma
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400, // Regular
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Tombol "I agree"
            Container(
              width: double.infinity,
              height: buttonHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.0), // Radius dari Figma
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25), // Shadow dari Figma
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  // Jadikan async
                  // Simpan status persetujuan
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_policyAgreedKey, true);
                  print("Status persetujuan kebijakan privasi disimpan.");

                  // Navigasi ke MainScreen dan hapus rute sebelumnya menggunakan named route
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/main', (Route<dynamic> route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF3A58D0,
                  ), // Warna tombol biru dari Figma
                  foregroundColor: Colors.white, // Warna teks putih dari Figma
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      4.0,
                    ), // Radius dari Figma
                  ),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 14, // Ukuran dari Figma
                    fontWeight: FontWeight.w600, // SemiBold
                    fontFamily: 'Inter',
                    height: 1.21,
                  ),
                  elevation: 0, // Shadow dihandle oleh Container
                ),
                child: const Text('I agree'), // Teks tombol dari Figma
              ),
            ),
            const SizedBox(height: 30), // Jarak dari bawah
          ],
        ),
      ),
    );
  }
}
