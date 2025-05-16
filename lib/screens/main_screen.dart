import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'home_screen.dart';
import 'history_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Indeks untuk layar yang aktif

  // Daftar layar yang akan ditampilkan
  static final List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    HistoryScreen(),
  ];

  // Fungsi untuk mengubah layar saat item nav ditekan
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Warna dari Figma
    const Color primaryBlue = Color(0xFF3A58D0);
    const Color primaryWhite = Colors.white;
    const Color inactiveGrey = Color(0xFFB5C0ED);

    return Scaffold(
      // Body akan menampilkan layar sesuai _selectedIndex
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              _selectedIndex == 0
                  ? 'assets/icons/view_icon_active.svg'
                  : 'assets/icons/view_icon_inactive.svg',
              width: 24,
              height: 24,
            ),
            label: 'View',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              _selectedIndex == 1
                  ? 'assets/icons/history_icon_active.svg'
                  : 'assets/icons/history_icon_inactive.svg',
              width: 24,
              height: 24,
            ),
            label: 'History',
          ),
        ],
        currentIndex: _selectedIndex, // Item yang aktif
        selectedItemColor: primaryWhite, // Warna teks item aktif
        unselectedItemColor: inactiveGrey, // Warna teks item tidak aktif
        onTap: _onItemTapped, // Fungsi saat item ditekan
        backgroundColor: primaryBlue, // Warna latar belakang nav
        type: BottomNavigationBarType.fixed, // Tipe agar label selalu tampil
        selectedFontSize: 12, // Ukuran font label
        unselectedFontSize: 12,
        elevation: 0, // Tidak ada shadow
      ),
    );
  }
}
