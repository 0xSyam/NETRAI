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
  int _selectedIndex = 0; // Index for the active screen

  // List of screens to be displayed
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(), // Added const
    const HistoryScreen(), // Added const
  ];

  // Function to change the screen when a nav item is pressed
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Colors from Figma design
    const Color primaryBlue = Color(0xFF3A58D0);
    const Color primaryWhite = Colors.white;
    const Color inactiveGrey = Color(0xFFB5C0ED);

    return Scaffold(
      // Body will display the screen according to _selectedIndex
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
        currentIndex: _selectedIndex, // Active item
        selectedItemColor: primaryWhite, // Active item text color
        unselectedItemColor: inactiveGrey, // Inactive item text color
        onTap: _onItemTapped, // Function when item is pressed
        backgroundColor: primaryBlue, // Nav background color
        type: BottomNavigationBarType.fixed, // Type so labels always appear
        selectedFontSize: 12, // Label font size
        unselectedFontSize: 12,
        elevation: 0, // No shadow
      ),
    );
  }
}
