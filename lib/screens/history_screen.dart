import 'package:flutter/cupertino.dart'; // Import Cupertino for segmented control
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle
// import 'package:netrai/widgets/bottom_navbar.dart'; // <-- BottomNavBar import commented out for now

// StatefulWidget for History screen
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // int _selectedSegment = 0; // 0: All, 1: Images, 2: Videos

  // --- Placeholder Data for Conversation ---
  final List<Map<String, dynamic>> _conversationItems = [
    {
      'sender': 'user',
      'text': 'Please tell me, what is in front of me right now?', // Translated
    },
    {
      'sender': 'ai',
      'text':
          'In front of you is a shelf filled with many neatly arranged packaged foods. Is there anything else you would like to know?', // Translated
    },
    {
      'sender': 'user',
      'text': 'Are there any potato-based snacks on this shelf?', // Translated
    },
    {
      'sender': 'ai',
      'text':
          'There are no potato-based snacks on this shelf. Perhaps you could point the camera to the right. I will try to scan it.', // Translated
    },
    // Add other conversation examples if needed
    {
      'sender': 'user',
      'text': 'How much money is currently in front of me?', // Translated
    },
    {
      'sender': 'ai',
      'text':
          'Currently, there is one fifty thousand rupiah note and two two thousand rupiah notes. So, there are fifty-four thousand rupiahs in front of you.', // Translated
    },
  ];
  // --- End of Placeholder Data ---

  // Filter history items based on selected segment
  // List<Map<String, dynamic>> get _filteredHistoryItems {
  //   if (_selectedSegment == 1) {
  //     return _historyItems.where((item) => item['type'] == 'image').toList();
  //   } else if (_selectedSegment == 2) {
  //     return _historyItems.where((item) => item['type'] == 'video').toList();
  //   } else {
  //     return _historyItems; // Show all
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // Colors from Figma
    const Color primaryBlue = Color(0xFF3A58D0);
    const Color primaryWhite = Colors.white;
    // const Color bodyBackground = Color(0xFFF5F5F5); // Changed to White
    const Color bodyBackground = Colors.white; // Consistent with Figma Frame bg
    const Color textColorBlack = Colors.black; // Main text color
    const Color bubbleColor = Color(0xFFB5C0ED); // AI bubble color

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: primaryBlue,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // For iOS
      ),
    );

    return Scaffold(
      backgroundColor: bodyBackground, // White background
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        automaticallyImplyLeading: false, // Navigation handled by BottomNavBar
        title: const Text(
          'History', // Title from Figma
          style: TextStyle(
            color: primaryWhite,
            fontSize: 18, // Size from Figma
            fontWeight: FontWeight.w500, // Medium
            fontFamily: 'Inter',
            height: 1.27, // Adjust line height if needed
          ),
        ),
        centerTitle: true, // Center title
        // actions: [ // Removed
        //   IconButton(
        //     icon: SvgPicture.asset(
        //       'assets/icons/question_icon.svg',
        //       width: 24,
        //       height: 24,
        //     ),
        //     onPressed: () {
        //       print('Help button pressed');
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
          // Ensure AppBar overlay is consistent
          statusBarColor: primaryBlue,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark, // For iOS
        ),
      ),
      body: Padding(
        // Add horizontal padding
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // --- Description Text ---
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 16.0,
              ), // Top and bottom spacing
              child: Text(
                'Recent conversations are deleted every time you close NetrAI.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColorBlack,
                  fontSize: 9, // Size from Figma (node 123:1095)
                  fontWeight: FontWeight.w500, // Medium (from Figma)
                  fontFamily: 'Inter',
                  height: 1.05, // Line height from Figma
                ),
              ),
            ),

            // --- Conversation List (History List) ---
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20), // Bottom spacing for list
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
      //     const BottomNavBar(currentIndex: 1), // Index 1 for History -> Commented out for now
    );
  }

  // --- Helper Widget for Chat Bubble ---
  Widget _buildConversationBubble({
    required String text,
    required bool isUser,
    required Color bubbleColor,
    required Color textColor,
  }) {
    // Text style according to Figma (node 123:1656, 123:1677, etc.)
    const TextStyle chatTextStyle = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w500, // Medium
      fontSize: 9,
      color: Colors.black, // Black text color in bubble
      height: 1.5, // Line height from Figma
    );

    return Align(
      // Align left for AI, right for User (though Figma shows all left)
      // If all left is desired like Figma: alignment: Alignment.centerLeft,
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * 0.75, // Max bubble width
        ),
        decoration: BoxDecoration(
          // If AI, use bubbleColor, if User, can be another color or same
          color: isUser ? Colors.grey[300] : bubbleColor, // Example User color
          borderRadius: BorderRadius.circular(
            12.0,
          ), // Bubble radius (adjust if needed)
          boxShadow: const [
            // Shadow from Figma (effect_4AF1ZF)
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.25),
              offset: Offset(0, 4),
              blurRadius: 20, // Figma uses 20px
            ),
          ],
        ),
        child: Text(text, style: chatTextStyle),
      ),
    );
  }
  // --- End of Helper Widget ---

  // Helper widget to build each history list item
  // Widget _buildHistoryListItem(Map<String, dynamic> item) {
  //   const Color listTileSubtitleColor = Color(0xFF6B7280);
  //   // Date format (example: Jan 1, 10:30 AM)
  //   final String formattedDate =
  //       '${_formatMonth(item['timestamp'].month)} ${item['timestamp'].day}, ${_formatTime(item['timestamp'])}';
  //
  //   return ListTile(
  //     tileColor: Colors.white, // List item background
  //     leading: Container(
  //       width: 50, // Thumbnail size
  //       height: 50,
  //       color: Colors.grey[200], // Thumbnail placeholder color
  //       // Replace with Image.asset(item['thumbnail']) if image is available
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
  //       print('History Item ${item['title']} pressed');
  //       // TODO: Implement navigation to history detail
  //     },
  //     contentPadding: const EdgeInsets.symmetric(
  //       vertical: 8.0,
  //       horizontal: 16.0,
  //     ), // Internal padding
  //   );
  // }
  //
  // // Helper to format month
  // String _formatMonth(int month) {
  //   const months = [
  //     'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  //     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  //   ];
  //   return months[month - 1];
  // }
  //
  // // Helper to format time
  // String _formatTime(DateTime time) {
  //   final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  //   final minute = time.minute.toString().padLeft(2, '0');
  //   final period = time.hour < 12 ? 'AM' : 'PM';
  //   return '$hour:$minute $period';
  // }
}
