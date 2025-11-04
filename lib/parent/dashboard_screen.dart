// [Full file: parent/dashboard_screen.dart]

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'device_detail_screen.dart'; // Ensure these imports are correct
import 'sos_alert_screen.dart'; // for your project structure

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Function to show the QR code dialog (unchanged)
  void _showQrCodeDialog(BuildContext context, User? user) {
    if (user == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link a New Device'),
        content: SizedBox(
          width: 250,
          height: 250,
          child: QrImageView(
            data: user.uid,
            version: QrVersions.auto,
            size: 250.0,
            backgroundColor: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Add Device',
            onPressed: () => _showQrCodeDialog(context, user),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .where('parentId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // --- Loading, Error, No Devices states (unchanged) ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Error fetching devices: ${snapshot.error}'); // Add logging
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No devices connected.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          // --- End of states ---

          final devices = snapshot.data!.docs;

          // --- SOS and Normal device separation (unchanged) ---
          final sosDevices = devices.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data.containsKey('sos_trigger') &&
                data['sos_trigger'] == true;
          }).toList();
          final normalDevices = devices.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return !data.containsKey('sos_trigger') ||
                data['sos_trigger'] == false;
          }).toList();
          // --- End of separation ---

          return Column(
            children: [
              // --- SOS Banner list (unchanged) ---
              if (sosDevices.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sosDevices.length,
                  itemBuilder: (context, index) {
                    final deviceDoc = sosDevices[index];
                    return _SosAlertBanner(
                      deviceId: deviceDoc.id,
                      deviceData: deviceDoc.data() as Map<String, dynamic>,
                    );
                  },
                ),
              // --- Normal Device list (unchanged structure) ---
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      await Future.delayed(const Duration(seconds: 1)),
                  child: ListView.builder(
                    itemCount: normalDevices.length,
                    itemBuilder: (context, index) {
                      final deviceDoc = normalDevices[index];
                      // Ensure data is correctly cast
                      final deviceDataMap =
                          deviceDoc.data() as Map<String, dynamic>?;
                      if (deviceDataMap == null) {
                        // Handle cases where data might be unexpectedly null
                        return ListTile(
                          title: Text('Error loading data for ${deviceDoc.id}'),
                        );
                      }
                      return _DeviceListItem(
                        deviceId: deviceDoc.id,
                        deviceData: deviceDataMap, // Pass the verified map
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- _SosAlertBanner Widget (unchanged) ---
class _SosAlertBanner extends StatelessWidget {
  final String deviceId;
  final Map<String, dynamic> deviceData;

  const _SosAlertBanner({required this.deviceId, required this.deviceData});

  @override
  Widget build(BuildContext context) {
    final deviceName = deviceData['deviceName'] ?? 'Unknown Device';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SosAlertScreen(deviceId: deviceId, deviceName: deviceName),
          ),
        );
      },
      child: Container(
        color: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'SOS ALERT FROM ${deviceName.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
// --- End of _SosAlertBanner ---

// --- Widget for Each Device Item in the List ---
class _DeviceListItem extends StatelessWidget {
  final String deviceId;
  final Map<String, dynamic> deviceData;
  const _DeviceListItem({required this.deviceId, required this.deviceData});

  // --- Icon Helpers (unchanged) ---
  IconData getRingerIcon(String? ringerMode) {
    switch (ringerMode) {
      case 'normal':
        return Icons.volume_up;
      case 'vibrate':
        return Icons.vibration;
      case 'silent':
        return Icons.volume_off;
      default:
        return Icons.volume_mute_outlined;
    }
  }

  IconData getInternetIcon(String? internetStatus) {
    switch (internetStatus) {
      case 'WiFi':
        return Icons.wifi;
      case 'Mobile':
        return Icons.signal_cellular_alt;
      default:
        return Icons.signal_wifi_off_outlined;
    }
  }
  // --- End of Icon Helpers ---

  // --- Delete Confirmation Dialog (unchanged) ---
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      /* ... unchanged ... */
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Remove Device'),
          content: const Text(
            'Are you sure you want to remove this device? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('child_devices')
                    .doc(deviceId)
                    .delete();
                Navigator.of(ctx).pop();
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Extract data (existing fields) ---
    final deviceName = deviceData['deviceName'] ?? 'Unknown';
    final batteryLevel = deviceData['batteryLevel'];
    final lastUpdated = deviceData['lastUpdated'] as Timestamp?;
    final internetStatus = deviceData['internetStatus'] as String?;
    final ringerMode = deviceData['ringerMode'] as String?;
    final wifiSsid = deviceData['wifiSsid'] as String?;
    bool isOnline =
        (internetStatus == 'WiFi' || internetStatus == 'Mobile') &&
        lastUpdated != null &&
        DateTime.now().difference(lastUpdated.toDate()).inMinutes < 30;

    // --- Build ListTile ---
    return ListTile(
      leading: Icon(
        Icons.phone_android,
        size: 40,
        color: isOnline ? Colors.blue : Colors.grey,
      ),
      title: Text(
        deviceName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      // vvv ---- THIS SUBTITLE IS MODIFIED ---- vvv
      subtitle: !isOnline
          ? const Text('Offline', style: TextStyle(color: Colors.grey))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  // Row for icons
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      getInternetIcon(internetStatus),
                      color: Colors.black54,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      getRingerIcon(ringerMode),
                      color: Colors.black54,
                      size: 18,
                    ),
                  ],
                ),
                // Network Name (from previous step)
                if (internetStatus == 'WiFi' &&
                    wifiSsid != null &&
                    wifiSsid.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'WiFi: $wifiSsid',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else if (internetStatus == 'Mobile') ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Mobile Data',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ],
            ),
      trailing: Row(
        // Trailing section (unchanged)
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isOnline && batteryLevel != null ? '$batteryLevel%' : '--',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Remove Device',
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      onTap: () {
        // Navigation (unchanged)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DeviceDetailScreen(deviceId: deviceId, deviceName: deviceName),
          ),
        );
      },
    );
  }
}
