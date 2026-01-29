import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:orbit_shield/firebase_options.dart';
import 'package:orbit_shield/parent/auth_wrapper.dart';
import 'package:orbit_shield/parent/parent_onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.parent);

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('parent_onboarding_seen') ?? false;

  runApp(ParentApp(showOnboarding: !hasSeenOnboarding));
}

class ParentApp extends StatelessWidget {
  final bool showOnboarding;

  const ParentApp({super.key, required this.showOnboarding});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orbit Shield Parent',
      home: showOnboarding ? const ParentOnboardingScreen() : const AuthWrapper(),
    );
  }
}