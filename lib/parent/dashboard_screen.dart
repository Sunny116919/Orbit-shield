import 'dart:async'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'device_detail_screen.dart';
import 'sos_alert_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _showQrCodeDialog(BuildContext context, User? user) {
    if (user == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(
          child: Text(
            'Link New Device',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SizedBox(
                width: 220,
                height: 220,
                child: QrImageView(
                  data: user.uid,
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Scan this code on the child's device",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Orbit Shield',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: Color(0xFF4A90E2),
                size: 20,
              ),
            ),
            tooltip: 'Add Device',
            onPressed: () => _showQrCodeDialog(context, user),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .where('parentId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices_other, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No devices linked yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showQrCodeDialog(context, user),
                    icon: const Icon(Icons.add),
                    label: const Text("Link Device"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final devices = snapshot.data!.docs;
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

          return Column(
            children: [
              if (sosDevices.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: sosDevices.length,
                  itemBuilder: (context, index) {
                    final deviceDoc = sosDevices[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _SosAlertBanner(
                        deviceId: deviceDoc.id,
                        deviceData: deviceDoc.data() as Map<String, dynamic>,
                      ),
                    );
                  },
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      await Future.delayed(const Duration(seconds: 1)),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: normalDevices.length,
                    itemBuilder: (context, index) {
                      final deviceDoc = normalDevices[index];
                      final deviceDataMap =
                          deviceDoc.data() as Map<String, dynamic>?;

                      if (deviceDataMap == null) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _DeviceListItem(
                          deviceId: deviceDoc.id,
                          deviceData: deviceDataMap,
                        ),
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
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5252).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SOS EMERGENCY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Alert from ${deviceName.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _DeviceListItem extends StatefulWidget {
  final String deviceId;
  final Map<String, dynamic> deviceData;

  const _DeviceListItem({
    required this.deviceId,
    required this.deviceData,
  });

  @override
  State<_DeviceListItem> createState() => _DeviceListItemState();
}

class _DeviceListItemState extends State<_DeviceListItem> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  IconData getRingerIcon(String? ringerMode) {
    switch (ringerMode) {
      case 'normal':
        return Icons.notifications_active;
      case 'vibrate':
        return Icons.vibration;
      case 'silent':
        return Icons.notifications_off;
      default:
        return Icons.volume_mute;
    }
  }

  IconData getInternetIcon(String? internetStatus) {
    switch (internetStatus) {
      case 'WiFi':
        return Icons.wifi;
      case 'Mobile':
        return Icons.signal_cellular_alt;
      default:
        return Icons.signal_wifi_off;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Remove Device'),
          content: const Text(
            'Are you sure you want to remove this device? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('child_devices')
                    .doc(widget.deviceId)
                    .delete();
                Navigator.of(ctx).pop();
              },
              child: const Text(
                'Remove',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = widget.deviceData['deviceName'] ?? 'Unknown';
    final batteryLevel = widget.deviceData['batteryLevel'];
    final lastUpdated = widget.deviceData['lastUpdated'] as Timestamp?;
    final internetStatus = widget.deviceData['internetStatus'] as String?;
    final ringerMode = widget.deviceData['ringerMode'] as String?;
    final wifiSsid = widget.deviceData['wifiSsid'] as String?;

    bool isOnline = false;
    if (lastUpdated != null) {
      final diff = DateTime.now().difference(lastUpdated.toDate());
      
      if (diff.inSeconds < 15) {
        isOnline = true;
      }
    }
    if (internetStatus == 'Offline') {
      isOnline = false;
    }

    Color getBatteryColor() {
      if (batteryLevel == null) return Colors.grey;
      if (batteryLevel > 50) return Colors.green;
      if (batteryLevel > 20) return Colors.orange;
      return Colors.red;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeviceDetailScreen(
                  deviceId: widget.deviceId,
                  deviceName: deviceName,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF4A90E2).withOpacity(0.1)
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.phone_iphone_rounded,
                        color: isOnline ? const Color(0xFF4A90E2) : Colors.grey,
                        size: 28,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      if (isOnline)
                        Row(
                          children: [
                            Icon(
                              getInternetIcon(internetStatus),
                              size: 14,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                internetStatus == 'WiFi'
                                    ? "Online • ${wifiSsid ?? 'WiFi'}"
                                    : "Online • Mobile Data",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            const Icon(
                              Icons.history_toggle_off,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lastUpdated != null
                                    ? "Offline • ${_formatDate(lastUpdated.toDate())}"
                                    : "Offline • No Data",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                      if (isOnline) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              getRingerIcon(ringerMode),
                              size: 12,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (ringerMode ?? '').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (batteryLevel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: getBatteryColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$batteryLevel%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: getBatteryColor(),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.battery_std,
                              size: 16,
                              color: getBatteryColor(),
                            ),
                          ],
                        ),
                      )
                    else
                      const Text(
                        "--",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: () => _showDeleteConfirmation(context),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${date.day}/${date.month}";
  }
}