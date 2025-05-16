import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'account_screen_keluarga.dart';

class FamilyAccountWrapper extends StatelessWidget {
  const FamilyAccountWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    // Jika user telah login, tampilkan halaman dengan data user
    if (user != null) {
      return AccountScreenKeluarga(
        displayName: user.displayName,
        email: user.email,
        photoURL: user.photoURL,
      );
    }
    // Jika user belum login, tampilkan halaman tanpa data
    else {
      return const AccountScreenKeluarga();
    }
  }
}
