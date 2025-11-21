import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:orbit_shield/child/background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'linked_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _isProcessing = false;

  Future<void> _handleQrCode(String parentId) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('childDeviceUID');
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (deviceId == null) {
        throw Exception("Device ID not found. Please restart the app.");
      }

      await FirebaseFirestore.instance
          .collection('child_devices')
          .doc(deviceId)
          .set({
            'parentId': parentId,
            'linkedAt': FieldValue.serverTimestamp(),
            'deviceName': '${androidInfo.brand} ${androidInfo.model}',
          });

      await prefs.setBool('isLinked', true);

      await initializeService();
      FlutterBackgroundService().startService();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LinkedScreen()),
        );
      }
    } catch (e) {
      print("Error linking device: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            _handleQrCode(barcodes.first.rawValue!);
          }
        },
      ),
    );
  }
}
