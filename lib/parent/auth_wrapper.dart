import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:orbit_shield/parent/dashboard_screen.dart';
import 'package:orbit_shield/parent/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the snapshot has data, a user is logged in
        if (snapshot.hasData) {
          return const DashboardScreen();
        }
        // Otherwise, no user is logged in
        else {
          return const LoginScreen();
        }
      },
    );
  }
}
