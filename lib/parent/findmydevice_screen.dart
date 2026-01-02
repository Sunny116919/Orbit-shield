import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FindMyDeviceScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const FindMyDeviceScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<FindMyDeviceScreen> createState() => _FindMyDeviceScreenState();
}

class _FindMyDeviceScreenState extends State<FindMyDeviceScreen> {
  late DocumentReference _docRef;

  @override
  void initState() {
    super.initState();
    _docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(widget.deviceId);
  }

  void _requestFindDevice() {
    try {
      _docRef.update({'requestFindDevice': true});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Find My Device',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _docRef.snapshots(),
        builder: (context, snapshot) {
          bool isFinding = false;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            isFinding = data['requestFindDevice'] ?? false;
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFinding
                          ? const Color(0xFF5C6BC0).withOpacity(0.1)
                          : Colors.white,
                      border: Border.all(
                        color: isFinding
                            ? const Color(0xFF5C6BC0).withOpacity(0.3)
                            : Colors.transparent,
                        width: 1,
                      ),
                      boxShadow: [
                        if (!isFinding)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        if (isFinding)
                          BoxShadow(
                            color: const Color(0xFF5C6BC0).withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFinding ? const Color(0xFF5C6BC0) : Colors.grey[50],
                        ),
                        child: Icon(
                          isFinding ? Icons.notifications_active : Icons.notifications_none,
                          size: 80,
                          color: isFinding ? Colors.white : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    isFinding ? 'Ringing ${widget.deviceName}...' : 'Find ${widget.deviceName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'This will make the child\'s device ring at full volume for 15 seconds, even if it is on silent.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isFinding ? null : _requestFindDevice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C6BC0),
                        disabledBackgroundColor: Colors.grey[300],
                        foregroundColor: Colors.white,
                        elevation: isFinding ? 0 : 4,
                        shadowColor: const Color(0xFF5C6BC0).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isFinding
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'SENDING ALERT...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'PLAY SOUND',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}