import 'package:flutter/material.dart';
import 'logout_dialog.dart'; // Import the reusable dialog

class LogoutButton extends StatelessWidget {
  final ButtonStyle? style; // Allow custom styling
  final String text;
  final TextStyle? textStyle;
  final double? width;
  final double? height;

  const LogoutButton({
    super.key,
    this.style,
    this.text = 'Log Out',
    this.textStyle = const TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: Colors.white,
    ),
    this.width = 290,
    this.height = 51,
  });

  @override
  Widget build(BuildContext context) {
    // Default style similar to _buildLogoutButton in AccountScreen
    final defaultStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3A59D1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      fixedSize: (width != null && height != null) ? Size(width!, height!) : null,
      elevation: 4, // Default elevation
      shadowColor: Colors.black.withOpacity(0.25),
    ).copyWith(
      // Ensure box shadow is applied correctly on top of ElevatedButton's own shadow handling
      // This might require using a Container with BoxDecoration for precise shadow control if ElevatedButton's shadow is not sufficient
    );

    // For more precise shadow as in the original _buildLogoutButton,
    // we might need to wrap ElevatedButton in a Container with BoxDecoration.
    // However, ElevatedButton's `elevation` and `shadowColor` should be close.

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration( // Using Container for precise shadow from original design
        color: style?.backgroundColor?.resolve({}) ?? defaultStyle.backgroundColor?.resolve({}),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            spreadRadius: 0,
            blurRadius: 20, // This was the blur in original AccountScreen
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material( // Material for InkWell splash effect
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await showLogoutConfirmationDialog(context);
            // Navigation is handled within showLogoutConfirmationDialog currently.
            // If we want more flexibility, the dialog should return a bool,
            // and navigation handled here based on the result.
            // For now, it matches the behavior of _showLogoutDialog.
          },
          borderRadius: BorderRadius.circular(8.0),
          child: Center(
            child: Text(
              text,
              style: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}
