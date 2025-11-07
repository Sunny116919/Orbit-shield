import 'package:flutter/material.dart';
import 'package:orbit_shield/child/linked_screen.dart';
import 'package:orbit_shield/child/permission_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ChildAuthWrapper extends StatelessWidget {
  const ChildAuthWrapper({super.key});

  // This function now handles both ID creation and checking the linked status
  Future<bool> _initializeDeviceState() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if a unique ID already exists for this installation
    String? deviceId = prefs.getString('childDeviceUID');

    // If no ID exists, it's a fresh install
    if (deviceId == null) {
      // Create a new, random, unique ID
      deviceId = const Uuid().v4();
      // Save this new ID so we can use it for this installation's lifetime
      await prefs.setString('childDeviceUID', deviceId);
      // It's a fresh install, so it's definitely not linked yet
      return false;
    }

    // If an ID exists, we just check the 'isLinked' flag as before
    return prefs.getBool('isLinked') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initializeDeviceState(),
      builder: (context, snapshot) {
        // While we're checking, show a loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If the check is done and the result is true, show the LinkedScreen
        if (snapshot.hasData && snapshot.data == true) {
          return const LinkedScreen();
        }

        // Otherwise (if it's false or there's an error), show the QrScannerScreen
        return const PermissionScreen();
      },
    );
  }
}
