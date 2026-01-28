// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:shared_preferences/shared_preferences.dart'; 
// import 'package:orbit_shield/firebase_options.dart';
// import 'package:orbit_shield/parent/auth_wrapper.dart';
// import 'package:orbit_shield/parent/parent_onboarding_screen.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.parent);

//   final prefs = await SharedPreferences.getInstance();
//   final bool hasSeenOnboarding = prefs.getBool('parent_onboarding_seen') ?? false;

//   runApp(ParentApp(showOnboarding: !hasSeenOnboarding));
// }

// class ParentApp extends StatelessWidget {
//   final bool showOnboarding;

//   const ParentApp({super.key, required this.showOnboarding});
  
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Orbit Shield Parent',
//       home: showOnboarding ? const ParentOnboardingScreen() : const AuthWrapper(),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:orbit_shield/firebase_options.dart';
import 'package:orbit_shield/parent/auth_wrapper.dart';
import 'package:orbit_shield/parent/parent_onboarding_screen.dart';

// ✅ IMPORT THE UPDATE CHECKER
// (Adjust path if your file is in a different folder)
import 'package:orbit_shield/services/update_checker.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
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
      
      // ✅ WRAP THE HOME SCREEN WITH THE UPDATE CHECKER
      home: UpdateListenerWrapper(
        child: showOnboarding ? const ParentOnboardingScreen() : const AuthWrapper(),
      ),
    );
  }
}

/// ✅ NEW WIDGET: Runs the update check automatically when app starts
class UpdateListenerWrapper extends StatefulWidget {
  final Widget child;
  const UpdateListenerWrapper({super.key, required this.child});

  @override
  State<UpdateListenerWrapper> createState() => _UpdateListenerWrapperState();
}

class _UpdateListenerWrapperState extends State<UpdateListenerWrapper> {
  @override
  void initState() {
    super.initState();
    
    // 🔍 CHECK FOR UPDATES IMMEDIATELY
    // This looks at your 'version_parent.json' file on Firebase
    UpdateChecker.checkForUpdate(
      context, 
      'https://orbit-shield.web.app/version_parent.json' 
    );
  }

  @override
  Widget build(BuildContext context) {
    // Just show the screen (Onboarding or Auth) normally
    return widget.child;
  }
}