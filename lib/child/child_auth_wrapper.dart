import 'package:flutter/material.dart';
import 'package:orbit_shield/child/linked_screen.dart';
import 'package:orbit_shield/child/permission_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ChildAuthWrapper extends StatelessWidget {
  const ChildAuthWrapper({super.key});

  Future<bool> _initializeDeviceState() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('childDeviceUID');

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('childDeviceUID', deviceId);
      return false;
    }

    return prefs.getBool('isLinked') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initializeDeviceState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return const LinkedScreen();
        }

        return const PermissionScreen();
      },
    );
  }
}
