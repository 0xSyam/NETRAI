import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ListActionItem extends StatelessWidget {
  final String iconPath;
  final String text;
  final VoidCallback onTap;
  final double iconWidth;
  final double iconHeight;
  final double gap;
  final TextStyle? textStyle;
  final Color? iconColor; // Added to allow icon color customization

  const ListActionItem({
    super.key,
    required this.iconPath,
    required this.text,
    required this.onTap,
    this.iconWidth = 24.0,
    this.iconHeight = 24.0,
    this.gap = 12.0, // Default gap consistent with previous analysis
    this.textStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500, // Medium
      fontFamily: 'Inter',
      color: Colors.black,
    ),
    this.iconColor = Colors.black, // Default icon color
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: iconWidth,
              height: iconHeight,
              colorFilter: iconColor != null
                  ? ColorFilter.mode(iconColor!, BlendMode.srcIn)
                  : null, // Apply color filter if iconColor is provided
            ),
            SizedBox(width: gap),
            Expanded( // Added Expanded to allow text to take available space and wrap if needed
              child: Text(
                text,
                style: textStyle,
                overflow: TextOverflow.ellipsis, // Handle long text
              ),
            ),
          ],
        ),
      ),
    );
  }
}
