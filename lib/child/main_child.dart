import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:orbit_shield/child/child_auth_wrapper.dart';
import 'package:orbit_shield/child/child_onboarding_screen.dart';
import '../firebase_options.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:workmanager/workmanager.dart';

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
  await Workmanager().initialize(
    callbackDispatcher, 
    isInDebugMode: false 
  );
  
  await Workmanager().registerPeriodicTask(
    "1", 
    "simplePeriodicTask", 
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
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
      home: showOnboarding ? const ChildOnboardingScreen() : const ChildAuthWrapper(),
    );
  }
}