// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:orbit_shield/services/update_checker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:orbit_shield/child/child_auth_wrapper.dart';
// import 'package:orbit_shield/child/child_onboarding_screen.dart';
// import '../firebase_options.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:workmanager/workmanager.dart';
// // 1. ADD THIS IMPORT
// import 'package:permission_handler/permission_handler.dart';

// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     print("⏰ WORKMANAGER: Checking if service is alive...");
//     final service = FlutterBackgroundService();
//     bool isRunning = await service.isRunning();
//     if (!isRunning) {
//       print("💀 Service was dead. Reviving it now...");
//       await service.startService();
//     } else {
//       print("✅ Service is still running.");
//     }
//     return Future.value(true);
//   });
// }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.child);
//   await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

//   await Workmanager().registerPeriodicTask(
//     "1",
//     "simplePeriodicTask",
//     frequency: const Duration(minutes: 15),
//     constraints: Constraints(networkType: NetworkType.connected),
//   );
//   final prefs = await SharedPreferences.getInstance();
//   final bool hasSeenOnboarding =
//       prefs.getBool('child_onboarding_seen') ?? false;

//   runApp(ChildApp(showOnboarding: !hasSeenOnboarding));
// }

// // 2. CHANGE TO STATEFUL WIDGET
// class ChildApp extends StatefulWidget {
//   final bool showOnboarding;
//   const ChildApp({super.key, required this.showOnboarding});

//   @override
//   State<ChildApp> createState() => _ChildAppState();
// }

// class _ChildAppState extends State<ChildApp> {
//   @override
//   void initState() {
//     super.initState();

//     // This tells the Child App to look for the CHILD JSON file
//     UpdateChecker.checkForUpdate(
//       context,
//       'https://orbit-shield.web.app/version_child.json',
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Orbit Shield Child',
//       // Note: access widget.showOnboarding since we are now in a State class
//       home: widget.showOnboarding
//           ? const ChildOnboardingScreen()
//           : const ChildAuthWrapper(),
//     );
//   }
// }





import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:orbit_shield/services/update_checker.dart'; // Ensure this path is correct
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orbit_shield/child/child_auth_wrapper.dart';
import 'package:orbit_shield/child/child_onboarding_screen.dart';
import '../firebase_options.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("⏰ WORKMANAGER: Checking if service is alive...");
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (!isRunning) {
      print("💀 Service was dead. Reviving it now...");
      await service.startService();
    } else {
      print("✅ Service is still running.");
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.child);
  
  // Initialize Workmanager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    "1",
    "simplePeriodicTask",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('child_onboarding_seen') ?? false;

  runApp(ChildApp(showOnboarding: !hasSeenOnboarding));
}

class ChildApp extends StatelessWidget {
  final bool showOnboarding;

  const ChildApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orbit Shield Child',
      // ✅ WRAP HERE: Now the context inside UpdateListenerWrapper has a Navigator
      home: UpdateListenerWrapper(
        child: showOnboarding ? const ChildOnboardingScreen() : const ChildAuthWrapper(),
      ),
    );
  }
}

/// ✅ HELPER WIDGET: Checks for updates when the screen loads
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
    
    // 🔍 CHECK FOR UPDATES
    UpdateChecker.checkForUpdate(
      context,
      'https://orbit-shield.web.app/version_child.json', // Your Live Link
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}