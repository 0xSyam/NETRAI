import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Widget floating button yang muncul saat berbagi layar sesuai dengan desain Figma
class ScreenShareFloatingButton extends StatelessWidget {
  final LocalParticipant participant;
  final VoidCallback onStopShare;
  final VoidCallback onSpeakToNetrai;

  const ScreenShareFloatingButton({
    Key? key,
    required this.participant,
    required this.onStopShare,
    required this.onSpeakToNetrai,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Definisikan lebar tetap untuk floating button
    final double floatingButtonWidth = 280.0;

    return Container(
      margin: const EdgeInsets.all(16),
      width: floatingButtonWidth, // Tambahkan lebar tetap
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.center, // Gunakan center alih-alih stretch
        children: [
          // Bagian atas dengan tombol-tombol (Frame 11940)
          Container(
            width: floatingButtonWidth, // Tambahkan lebar tetap
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tombol "Speak to NetrAI"
                Container(
                  height: 35,
                  width: 128,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A59D1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onSpeakToNetrai,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Ikon Mikrofon
                            const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            // Teks "Speak to NetrAI"
                            const Text(
                              'Speak to NetrAI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 22),
                // Tombol "Stop Share"
                Container(
                  height: 35,
                  width: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFED0101),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onStopShare,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Ikon persegi kecil (bisa dibuat dengan Container)
                            Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            // Teks "Stop Share"
                            Text(
                              'Stop Share',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bagian bawah dengan teks status (Frame 11939)
          Container(
            width: floatingButtonWidth, // Tambahkan lebar tetap
            decoration: const BoxDecoration(
              color: Color(0xFF53F88B),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'You are screen sharing now.',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget overlay container yang muncul di atas aplikasi lain
class ScreenShareOverlay {
  OverlayEntry? _overlayEntry;

  /// Menampilkan floating button pada overlay system
  void show(
    BuildContext context,
    LocalParticipant participant,
    VoidCallback onStopShare,
    VoidCallback onSpeakToNetrai,
  ) {
    if (_overlayEntry != null) {
      return; // Jangan buat overlay baru jika sudah ada
    }

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.of(context).padding.bottom +
            16, // Posisi di bagian bawah dengan padding
        child: Align(
          alignment: Alignment.bottomCenter, // Posisi di bawah tengah
          child: Material(
            type: MaterialType.transparency,
            child: ScreenShareFloatingButton(
              participant: participant,
              onStopShare: () {
                onStopShare();
                hide(); // Sembunyikan overlay setelah tombol stop ditekan
              },
              onSpeakToNetrai: onSpeakToNetrai,
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  /// Menyembunyikan floating button
  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Memeriksa apakah overlay sedang ditampilkan
  bool get isShowing => _overlayEntry != null;
}
