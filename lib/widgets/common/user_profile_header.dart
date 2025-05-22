import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For network images with caching & placeholder

class UserProfileHeader extends StatelessWidget {
  final String? displayName;
  final String? email;
  final String? photoURL;
  final double avatarRadius;
  final TextStyle? nameStyle;
  final TextStyle? emailStyle;
  final Color avatarBackgroundColor;
  final Color initialTextColor;
  final IconData placeholderIcon;
  final double placeholderIconSize;

  const UserProfileHeader({
    super.key,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.avatarRadius = 28.0,
    this.nameStyle = const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500, // Medium
      fontFamily: 'Inter',
      color: Colors.black,
    ),
    this.emailStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400, // Regular
      fontFamily: 'Inter',
      color: Color(0xFF828282),
    ),
    this.avatarBackgroundColor = const Color(0xFFD9D9D9),
    this.initialTextColor = Colors.black54,
    this.placeholderIcon = Icons.person,
    this.placeholderIconSize = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarChild;
    bool hasPhoto = photoURL != null && photoURL!.isNotEmpty;
    bool hasDisplayName = displayName != null && displayName!.isNotEmpty;

    if (hasPhoto) {
      avatarChild = CachedNetworkImage(
        imageUrl: photoURL!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: avatarRadius,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: avatarRadius,
          backgroundColor: avatarBackgroundColor,
          child: Icon(
            placeholderIcon,
            size: placeholderIconSize,
            color: initialTextColor,
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: avatarRadius,
          backgroundColor: avatarBackgroundColor,
          child: Icon(
            placeholderIcon,
            size: placeholderIconSize,
            color: initialTextColor,
          ),
        ),
      );
    } else if (hasDisplayName) {
      avatarChild = CircleAvatar(
        radius: avatarRadius,
        backgroundColor: avatarBackgroundColor,
        child: Text(
          displayName![0].toUpperCase(),
          style: TextStyle(
            fontSize: avatarRadius * 0.8, // Adjust initial size based on radius
            color: initialTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      avatarChild = CircleAvatar(
        radius: avatarRadius,
        backgroundColor: avatarBackgroundColor,
        child: Icon(
          placeholderIcon,
          size: placeholderIconSize,
          color: initialTextColor,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Row(
        children: [
          avatarChild,
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName ?? 'User Name',
                  style: nameStyle,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Text(
                  email ?? 'email@example.com',
                  style: emailStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
