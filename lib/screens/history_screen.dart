import 'package:flutter/cupertino.dart'; // Impor Cupertino untuk segmented control
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart'; // Untuk SystemUiOverlayStyle
// import 'package:netrai/widgets/bottom_navbar.dart'; // <-- Impor BottomNavBar -> Sementara dikomentari

// StatefulWidget untuk tampilan History
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // int _selectedSegment = 0; // 0: All, 1: Images, 2: Videos

  // --- Placeholder Data untuk Percakapan ---
  final List<Map<String, dynamic>> _conversationItems = [
    {
      'sender': 'user',
      'text': 'Tolong beri tahu, apa yang ada di depanku sekarang?',
    },
    {
      'sender': 'ai',
      'text':
          'Di depanmu ada sebuah rak berisi banyak makanan kemasan yang tersusun dengan sangat rapi. Apakah ada yang ingin kamu ketahui lagi?',
    },
    {
      'sender': 'user',
      'text': 'Apakah terdapat makanan ringan berbahan kentang di rak ini?',
    },
    {
      'sender': 'ai',
      'text':
          'Tidak ada makanan ringan berbahan kentang di rak ini. Mungkin kamu bisa mengarahkan kamera ke sebelah kanan. Aku akan coba memindainya.',
    },
    // Tambahkan contoh percakapan lain jika perlu
    {
      'sender': 'user',
      'text': 'Berapa jumlah uang yang saat ini ada di depanku?',
    },
    {
      'sender': 'ai',
      'text':
          'Saat ini ada selembar uang lima puluh ribu dan dua lembar uang dua ribu. Sehingga ada lima puluh empat ribu rupiah di depanmu.',
    },
  ];
  // --- Akhir Placeholder Data ---

  // Filter history items berdasarkan segmen yang dipilih
  // List<Map<String, dynamic>> get _filteredHistoryItems {
  //   if (_selectedSegment == 1) {
  //     return _historyItems.where((item) => item['type'] == 'image').toList();
  //   } else if (_selectedSegment == 2) {
  //     return _historyItems.where((item) => item['type'] == 'video').toList();
  //   } else {
  //     return _historyItems; // Tampilkan semua
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // Warna dari Figma
    const Color primaryBlue = Color(0xFF3A58D0);
    const Color primaryWhite = Colors.white;
    // const Color bodyBackground = Color(0xFFF5F5F5); -> Diubah ke Putih
    const Color bodyBackground = Colors.white; // Sesuai Figma Frame bg
    const Color textColorBlack = Colors.black; // Warna teks utama
    const Color bubbleColor = Color(0xFFB5C0ED); // Warna bubble AI

    // Atur status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: primaryBlue,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // Untuk iOS
      ),
    );

    return Scaffold(
      backgroundColor: bodyBackground, // Latar belakang putih
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        automaticallyImplyLeading:
            false, // Kita handle navigasi lewat BottomNavBar
        title: const Text(
          'History', // Judul dari Figma
          style: TextStyle(
            color: primaryWhite,
            fontSize: 18, // Ukuran dari Figma
            fontWeight: FontWeight.w500, // Medium
            fontFamily: 'Inter',
            height: 1.27, // Sesuaikan line height jika perlu
          ),
        ),
        centerTitle: true, // Pusatkan judul
        // actions: [ -> Dihapus
        //   IconButton(
        //     icon: SvgPicture.asset(
        //       'assets/icons/question_icon.svg',
        //       width: 24,
        //       height: 24,
        //     ),
        //     onPressed: () {
        //       print('Tombol Bantuan ditekan');
        //     },
        //     tooltip: 'Help',
        //   ),
        //   IconButton(
        //     icon: const Icon(
        //       Icons.account_circle,
        //       color: primaryWhite,
        //       size: 28,
        //     ),
        //     onPressed: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (context) => AccountScreen()),
        //       );
        //     },
        //     tooltip: 'Account',
        //   ),
        //   const SizedBox(width: 8),
        // ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          // Pastikan overlay AppBar konsisten
          statusBarColor: primaryBlue,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark, // Untuk iOS
        ),
      ),
      body: Padding(
        // Tambahkan padding horizontal
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // --- Teks Deskripsi ---
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 16.0,
              ), // Jarak atas dan bawah
              child: Text(
                'Recent conversations are deleted every time you close NetrAI.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColorBlack,
                  fontSize: 9, // Ukuran dari Figma (node 123:1095)
                  fontWeight: FontWeight.w500, // Medium (dari Figma)
                  fontFamily: 'Inter',
                  height: 1.05, // Line height dari Figma
                ),
              ),
            ),

            // --- Daftar Percakapan (History List) ---
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20), // Jarak bawah list
                itemCount: _conversationItems.length,
                itemBuilder: (context, index) {
                  final item = _conversationItems[index];
                  return _buildConversationBubble(
                    text: item['text'],
                    isUser: item['sender'] == 'user',
                    bubbleColor: bubbleColor,
                    textColor: textColorBlack,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // --- Bottom Navigation Bar ---
      // bottomNavigationBar:
      //     const BottomNavBar(currentIndex: 1), // Index 1 untuk History -> Sementara dikomentari
    );
  }

  // --- Helper Widget untuk Bubble Chat ---
  Widget _buildConversationBubble({
    required String text,
    required bool isUser,
    required Color bubbleColor,
    required Color textColor,
  }) {
    // Gaya teks sesuai Figma (node 123:1656, 123:1677, etc.)
    const TextStyle chatTextStyle = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w500, // Medium
      fontSize: 9,
      color: Colors.black, // Warna teks hitam di bubble
      height: 1.5, // Line height dari Figma
    );

    return Align(
      // Rata kiri untuk AI, rata kanan untuk User (meski di Figma semua kiri)
      // Jika ingin semua kiri seperti Figma: alignment: Alignment.centerLeft,
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * 0.75, // Maks lebar bubble
        ),
        decoration: BoxDecoration(
          // Jika AI, gunakan bubbleColor, jika User, bisa warna lain atau sama
          color: isUser ? Colors.grey[300] : bubbleColor, // Contoh warna User
          borderRadius: BorderRadius.circular(
            12.0,
          ), // Radius bubble (sesuaikan jika perlu)
          boxShadow: const [
            // Shadow dari Figma (effect_4AF1ZF)
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.25),
              offset: Offset(0, 4),
              blurRadius: 20, // Figma menggunakan 20px
            ),
          ],
        ),
        child: Text(text, style: chatTextStyle),
      ),
    );
  }
  // --- Akhir Helper Widget ---

  // Helper widget untuk membangun setiap item list history
  // Widget _buildHistoryListItem(Map<String, dynamic> item) {
  //   const Color listTileSubtitleColor = Color(0xFF6B7280);
  //   // Format tanggal (contoh: Jan 1, 10:30 AM)
  //   final String formattedDate =
  //       '${_formatMonth(item['timestamp'].month)} ${item['timestamp'].day}, ${_formatTime(item['timestamp'])}';
  //
  //   return ListTile(
  //     tileColor: Colors.white, // Latar belakang item list
  //     leading: Container(
  //       width: 50, // Ukuran thumbnail
  //       height: 50,
  //       color: Colors.grey[200], // Warna placeholder thumbnail
  //       // Ganti dengan Image.asset(item['thumbnail']) jika gambar tersedia
  //       child: Icon(
  //         item['type'] == 'video'
  //             ? Icons.videocam_outlined
  //             : Icons.image_outlined,
  //         color: Colors.grey[500],
  //       ),
  //     ),
  //     title: Text(
  //       item['title'],
  //       style: const TextStyle(
  //         fontWeight: FontWeight.w500, // Medium
  //         fontFamily: 'Inter',
  //         fontSize: 16,
  //       ),
  //     ),
  //     subtitle: Text(
  //       formattedDate,
  //       style: const TextStyle(
  //         color: listTileSubtitleColor,
  //         fontFamily: 'Inter',
  //         fontSize: 14,
  //       ),
  //     ),
  //     trailing: const Icon(Icons.chevron_right, color: Colors.grey),
  //     onTap: () {
  //       print('History Item ${item['title']} ditekan');
  //       // TODO: Implementasi navigasi ke detail history
  //     },
  //     contentPadding: const EdgeInsets.symmetric(
  //       vertical: 8.0,
  //       horizontal: 16.0,
  //     ), // Padding internal
  //   );
  // }
  //
  // // Helper untuk format bulan
  // String _formatMonth(int month) {
  //   const months = [
  //     'Jan',
  //     'Feb',
  //     'Mar',
  //     'Apr',
  //     'May',
  //     'Jun',
  //     'Jul',
  //     'Aug',
  //     'Sep',
  //     'Oct',
  //     'Nov',
  //     'Dec'
  //   ];
  //   return months[month - 1];
  // }
  //
  // // Helper untuk format waktu
  // String _formatTime(DateTime time) {
  //   final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  //   final minute = time.minute.toString().padLeft(2, '0');
  //   final period = time.hour < 12 ? 'AM' : 'PM';
  //   return '$hour:$minute $period';
  // }
}
