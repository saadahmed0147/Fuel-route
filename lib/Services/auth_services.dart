import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:fuel_route/Routes/route_names.dart';
import 'package:fuel_route/Screens/Home/home_screen.dart';
import 'package:fuel_route/Utils/utils.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Facebook Sign-In
  // Future<UserCredential?> signInWithFacebook({
  //   required BuildContext context,
  //   required VoidCallback onStart,
  //   required VoidCallback onComplete,
  // }) async {
  //   onStart();

  //   try {
  //     final LoginResult result = await FacebookAuth.instance.login();

  //     if (result.status == LoginStatus.success) {
  //       final accessToken = result.accessToken;
  //       final credential = FacebookAuthProvider.credential(accessToken!.token);

  //       final res = await _auth.signInWithCredential(credential);
  //       final user = res.user;

  //       if (user != null) {
  //         // ✅ Save user data to Realtime Database
  //         await _dbRef.child("users/${user.uid}").set({
  //           'uid': user.uid,
  //           'email': user.email ?? '',
  //           'name': user.displayName ?? '',
  //           'phone': user.phoneNumber ?? '',
  //         });

  //         Utils.flushBarErrorMessage(
  //           'Welcome, ${user.displayName}',
  //           context,
  //           success: true,
  //         );

  //         Navigator.pushReplacementNamed(context, RouteNames.homeScreen);
  //         return res;
  //       } else {
  //         Utils.flushBarErrorMessage("User data is null.", context);
  //         return null;
  //       }
  //     } else {
  //       Utils.flushBarErrorMessage('Facebook Sign-In canceled.', context);
  //       return null;
  //     }
  //   } catch (e) {
  //     debugPrint('🔥 Facebook Sign-In error: $e');
  //     Utils.flushBarErrorMessage('Facebook Sign-In failed.', context);
  //     return null;
  //   } finally {
  //     onComplete();
  //   }
  // }

  Future<UserCredential?> signInWithGoogle({
    required BuildContext context,
    required VoidCallback onStart,
    required VoidCallback onComplete,
  }) async {
    onStart();

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // Add web client ID for better Android compatibility
        serverClientId:
            '801099113858-li096tuqub4uql1fca6d0q94642ad09v.apps.googleusercontent.com',
        // Add iOS client ID for better iOS compatibility
        clientId: Platform.isIOS
            ? '801099113858-pnh35j34gcnnqn768no65g1f36j4du7q.apps.googleusercontent.com'
            : null,
      );

      // Ensure previous account is signed out to trigger chooser
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        Utils.flushBarErrorMessage('Google Sign-In cancelled.', context);
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final res = await _auth.signInWithCredential(credential);
      final user = res.user;

      if (user == null) {
        Utils.flushBarErrorMessage('User info is null.', context);
        return null;
      }

      // ✅ Save to Realtime Database
      await _dbRef.child("users/${user.uid}").set({
        'uid': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? '',
        'photoUrl': user.photoURL ?? '',
        'provider': 'google',
      });

      Utils.flushBarErrorMessage(
        'Welcome, ${user.displayName ?? 'User'}',
        context,
        success: true,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(),
        ), // Replace with your HomeScreen widget
        (route) => false, // This removes all previous routes
      );
      return res;
    } catch (e) {
      debugPrint('🔥 Google Sign-In Error: $e');

      if (Platform.isIOS && e.toString().contains('network_error')) {
        Utils.flushBarErrorMessage(
          'Network error on iOS. Please check your internet connection.',
          context,
        );
      } else if (Platform.isIOS && e.toString().contains('sign_in_failed')) {
        Utils.flushBarErrorMessage(
          'iOS Google Sign-In failed. Please check URL schemes in Info.plist.',
          context,
        );
      } else if (e.toString().contains('ApiException: 10')) {
        Utils.flushBarErrorMessage(
          'Google Sign-In configuration error. Please check SHA-1 fingerprint in Firebase Console.',
          context,
        );
      } else {
        Utils.flushBarErrorMessage('Google Sign-In failed: $e', context);
      }
      return null;
    } finally {
      onComplete();
    }
  }

  /// Sign Up Function
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required BuildContext context,
    required VoidCallback onStart,
    required VoidCallback onComplete,
  }) async {
    try {
      onStart();

      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(name).catchError((e) {
          debugPrint("🔥 Display name update error: $e");
          Utils.flushBarErrorMessage("Failed to update display name.", context);
        });

        await _dbRef
            .child("users/${user.uid}")
            .set({
              'uid': user.uid,
              'email': email,
              'name': name,
              'phone': phoneNumber,
            })
            .catchError((error) {
              debugPrint("🔥 Firebase DB Error: $error");
              Utils.flushBarErrorMessage(
                "Database write failed: $error",
                context,
              );
            });

        Utils.flushBarErrorMessage(
          'Sign Up Successful',
          context,
          success: true,
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(),
          ), // Replace with your HomeScreen widget
          (route) => false, // This removes all previous routes
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("🔥 FirebaseAuthException: ${e.code} - ${e.message}");

      if (e.code == 'email-already-in-use') {
        Utils.flushBarErrorMessage(
          "This email is already registered.",
          context,
        );
      } else if (e.code == 'invalid-email') {
        Utils.flushBarErrorMessage("Invalid email address.", context);
      } else if (e.code == 'weak-password') {
        Utils.flushBarErrorMessage("Password is too weak.", context);
      } else {
        Utils.flushBarErrorMessage(
          e.message ?? 'Something went wrong.',
          context,
        );
      }
    } catch (e) {
      debugPrint("🔥 General error: $e");
      Utils.flushBarErrorMessage("Error: $e", context);
    } finally {
      onComplete();
    }
  }

  /// Sign In Function
  Future<void> signInWithEmail({
    required String email,
    required String password,
    required BuildContext context,
    required VoidCallback onStart,
    required VoidCallback onComplete,
  }) async {
    try {
      onStart();

      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user != null) {
        Utils.flushBarErrorMessage(
          'Login Successfully',
          context,
          success: true,
        );
        Utils.flushBarErrorMessage(user.email ?? '', context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(),
          ), // Replace with your HomeScreen widget
          (route) => false, // This removes all previous routes
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        Utils.flushBarErrorMessage("No user found for this email.", context);
      } else if (e.code == 'wrong-password') {
        Utils.flushBarErrorMessage("Wrong password provided.", context);
      } else if (e.code == 'invalid-email') {
        Utils.flushBarErrorMessage("The email address is invalid.", context);
      } else {
        Utils.flushBarErrorMessage(
          e.message ?? 'Something went wrong.',
          context,
        );
      }
    } catch (e) {
      Utils.flushBarErrorMessage(e.toString(), context);
    } finally {
      onComplete();
    }
  }
}
