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
      final response = await http.get(Uri.parse(jsonUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        PackageInfo packageInfo = await PackageInfo.fromPlatform();

        // 1. Get raw strings
        String currentRaw = packageInfo.version;
        String latestRaw = data['version'].toString();

        // 2. CLEAN them (Remove 'v', remove spaces)
        String currentVersion = currentRaw
            .replaceAll(RegExp(r'[vV]'), '')
            .trim();
        String latestVersion = latestRaw.replaceAll(RegExp(r'[vV]'), '').trim();

        // 3. DEBUG PRINT (Check your "Run" tab in Android Studio!)
        print("🔎 UPDATE CHECK:");
        print("   Installed App: '$currentVersion' (Raw: '$currentRaw')");
        print("   Online JSON:   '$latestVersion' (Raw: '$latestRaw')");

        // 4. Compare
        if (currentVersion != latestVersion) {
          if (context.mounted) {
            _showUpdateDialog(
              context,
              data['url'],
              data['notes'],
              latestVersion,
            );
          }
        } else {
          print("✅ App is up to date.");
        }
      }
    } catch (e) {
      print("❌ Update check failed: $e");
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
