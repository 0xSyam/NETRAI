import 'package:flutter/material.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:provider/provider.dart';
import '../widgets/transcription_widget.dart' as local;

class TranscriptionScreen extends StatelessWidget {
  // Hapus parameter RoomContext dari constructor
  // final RoomContext roomContext;

  const TranscriptionScreen({super.key}); //, required this.roomContext});

  @override
  Widget build(BuildContext context) {
    // RoomContext akan didapatkan oleh TranscriptionBuilder dari Provider
    // final roomContext = context.watch<RoomContext>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF3A59D1),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              // Implementasi fungsi hapus history
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        // Gunakan TranscriptionBuilder untuk mendapatkan data transkripsi
        child: TranscriptionBuilder(
          // Biarkan TranscriptionBuilder mengambil RoomContext sendiri
          builder: (context, roomCtx, transcriptions) {
            // roomCtx di sini didapatkan dari builder, bukan dari parameter widget
            // Tampilkan TranscriptionWidget lokal dengan data yang diterima
            return local.TranscriptionWidget(
              // Ambil warna dari tema saat ini
              textColor: Theme.of(context).colorScheme.primary,
              backgroundColor: const Color(
                  0xFFBBD8F1), // Menggunakan warna BBD8F1 yang tetap
              transcriptions: transcriptions,
            );
          },
        ),
      ),
      // Tambahkan bottomNavigationBar sesuai dengan gambar dan main.dart
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF3A59D1),
        elevation: 8.0,
        height: 70.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            // Item View (tidak aktif)
            GestureDetector(
              onTap: () {
                // Kembali ke layar utama (VoiceAssistant)
                Navigator.pop(context);
              },
              child: Container(
                color: Colors.transparent,
                child: _buildNavItem(Icons.visibility_outlined, 'View', false),
              ),
            ),
            // Item History (aktif)
            _buildNavItem(Icons.history_outlined, 'History', true),
          ],
        ),
      ),
    );
  }

  // Helper untuk membuat item navigasi
  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final color = isActive ? Colors.white : const Color(0xFFB5C0ED);
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
