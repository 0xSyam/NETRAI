import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // To check web platform
import 'package:flutter/material.dart'; // Import Material for BuildContext
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import '../screens/privacy_policy_screen.dart'; // Add this import
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Use client ID value according to firebase_options.dart
    // Note: Android doesn't need an explicit clientId because it uses google-services.json,
    // but iOS and web require it
    scopes: <String>[
      'email',
      'profile',
    ],
  );

  // Stream to monitor authentication status changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      // Initial log
      print("===== STARTING GOOGLE LOGIN PROCESS =====");
      print("Platform: ${kIsWeb ? 'Web' : 'Mobile'}");

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Trigger Google Sign In authentication flow.
      GoogleSignInAccount? googleUser;

      if (kIsWeb) {
        // For Web, use signInWithPopup
        print("Starting login popup for web...");
        UserCredential userCredential = await _auth.signInWithPopup(
          GoogleAuthProvider(),
        );
        print("Web login successful: ${userCredential.user?.displayName}");
        return userCredential.user;
      } else {
        // For Mobile (Android/iOS)
        print("Starting GoogleSignIn.signIn() for mobile...");
        googleUser = await _googleSignIn.signIn();
        print(
            "GoogleSignIn.signIn() result: ${googleUser?.displayName ?? 'null'}");
      }

      // If user cancels login (mobile)
      if (googleUser == null && !kIsWeb) {
        // Close loading dialog
        Navigator.pop(context);
        print('Google login canceled by user.');
        return null;
      }

      if (!kIsWeb) {
        // Get authentication details from request (for mobile)
        print("Getting authentication from googleUser...");
        final GoogleSignInAuthentication googleAuth =
            await googleUser!.authentication;
        print(
            "Access token received: ${googleAuth.accessToken?.substring(0, 10)}...");
        print("ID token received: ${googleAuth.idToken?.substring(0, 10)}...");

        // Create new credential.
        print("Creating Firebase credential...");
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // After user signs in, get UserCredential
        print("Running signInWithCredential...");
        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        final User? user = userCredential.user;
        print("signInWithCredential result: ${user?.displayName ?? 'null'}");

        // Close loading dialog
        Navigator.pop(context);

        // Check if user successfully logged in
        if (user != null) {
          print('Successfully logged in with Google: ${user.displayName}');
          print('Email: ${user.email}');
          print('User ID: ${user.uid}');
          // Check privacy policy agreement status
          final prefs = await SharedPreferences.getInstance();
          final bool hasAgreed = prefs.getBool('hasAgreedToPolicy') ?? false;
          print(
              "Privacy policy agreement status from SharedPreferences: $hasAgreed");
          // Add log of user role from Firestore
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            final role = doc.data()?['role'];
            print('User role from Firestore: $role');
          } catch (e) {
            print('Failed to get user role from Firestore: $e');
          }
          return user;
        }
      }
    } on FirebaseAuthException catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Handle Firebase Auth error
      print('===== FIREBASE AUTH ERROR =====');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('StackTrace: ${e.stackTrace}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed: ${e.message}')),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Handle other errors
      print('===== GENERAL GOOGLE LOGIN ERROR =====');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('StackTrace: ${StackTrace.current}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: ${e.toString()}')),
        );
      }
    }
    return null; // Return null if error or cancellation
  }

  Future<void> signOut() async {
    try {
      // Logout from Google Sign-In
      await _googleSignIn.signOut();
      print("Google Sign-Out successful");

      // Logout from Firebase Authentication
      await _auth.signOut();
      print("Firebase Auth Sign-Out successful");

      // Make sure authentication state changes
      await _auth.authStateChanges().first;
      print("AuthState successfully updated");
    } catch (e) {
      print("Error during logout: $e");
      rethrow; // Throw the exception back to be handled by the caller
    }
  }

  Future<void> saveUserRole(String uid, String role,
      {String? linkedTo, String? email}) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'role': role,
      if (linkedTo != null) 'linkedTo': linkedTo,
      if (email != null) 'email': email,
    }, SetOptions(merge: true));
  }

  Future<String?> getUserRole(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      return doc['role'] as String?;
    }
    return null;
  }
}
