import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker {
  static Future<void> checkForUpdate(
    BuildContext context,
    String jsonUrl,
  ) async {
    try {
      // 1. Check the JSON file on your Firebase Hosting
      final response = await http.get(Uri.parse(jsonUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 2. Get current app version from the phone
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        String currentVersion = packageInfo.version.replaceAll("v", "").trim();
        String latestVersion = data['version']
            .toString()
            .replaceAll("v", "")
            .trim();
        String apkUrl = data['url'];
        String notes = data['notes'] ?? "Security updates and bug fixes.";

        // 3. Compare: If server version is different, prompt update
        if (currentVersion != latestVersion) {
          if (context.mounted) {
            _showUpdateDialog(context, apkUrl, notes, latestVersion);
          }
        }
      }
    } catch (e) {
      print("Update check failed (App might be offline): $e");
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String url,
    String notes,
    String version,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Update Available ($version)"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "A new version is available. Please update to continue.",
              ),
              const SizedBox(height: 10),
              const Text(
                "What's New:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(notes),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startUpdate(context, url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
            ),
            child: const Text("Update Now"),
          ),
        ],
      ),
    );
  }

  static Future<void> _startUpdate(BuildContext context, String url) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Downloading update... check notification bar"),
        ),
      );

      // This triggers the Android native downloader
      OtaUpdate().execute(url, destinationFilename: 'orbit_update.apk').listen((
        OtaEvent event,
      ) {
        // Status updates (Downloading, Installing, etc)
      });
    } catch (e) {
      print('Update Error: $e');
    }
  }
}
