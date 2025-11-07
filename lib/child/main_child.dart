import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- 1. IMPORT ADDED
import 'package:orbit_shield/child/child_auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart'; // <-- 2. IMPORT ADDED
import '../firebase_options.dart';

// 3. All notification and shared_prefs imports removed

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.child);

  // vvv --- 4. ADDED CLIPBOARD LISTENER --- vvv
  final service = FlutterBackgroundService();

  // This listener runs on the MAIN (UI) isolate
  service.on('getClipboard').listen((event) async {
    print("MAIN THREAD: Received 'getClipboard' request from service.");
    String? clipboardText;
    try {
      // This is now safe to call from the main thread
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      clipboardText = clipboardData?.text;
    } catch (e) {
      clipboardText = "Error reading clipboard: $e";
    }
    // Send the result back to the background service
    service.invoke('clipboardResult', {"text": clipboardText});
    print("MAIN THREAD: Sent clipboard text back to service.");
  });
  // ^^^ ------------------------------------- ^^^

  runApp(const ChildApp());
}

class ChildApp extends StatelessWidget {
  const ChildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orbit Shield Child',
      home: ChildAuthWrapper(),
    );
  }
}
