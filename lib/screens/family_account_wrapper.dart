import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'account_screen_keluarga.dart';

class FamilyAccountWrapper extends StatelessWidget {
  const FamilyAccountWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    // If the user is logged in, display the page with user data
    if (user != null) {
      return AccountScreenKeluarga(
        displayName: user.displayName,
        email: user.email,
        photoURL: user.photoURL,
      );
    }
    // If the user is not logged in, display the page without data
    else {
      return const AccountScreenKeluarga();
    }
  }
}
