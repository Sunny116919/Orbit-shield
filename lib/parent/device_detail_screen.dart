import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:orbit_shield/parent/app_blocker_screen.dart';
import 'dart:async';
import 'package:orbit_shield/parent/app_usage_screens.dart';
import 'package:orbit_shield/parent/findmydevice_screen.dart';
import 'package:orbit_shield/parent/installed_app_screen.dart';
import 'package:orbit_shield/parent/location_screen.dart';
import 'package:orbit_shield/parent/sos_alert_history_screen.dart';
import 'package:orbit_shield/parent/volume_control_screen.dart';
import 'call_history_screen.dart';
import 'sms_history_screen.dart';
import 'contacts_screen.dart';
import 'notification_history_screen.dart';
import 'web_history_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  const DeviceDetailScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _requestData(String requestFlag) async {
    try {
      await FirebaseFirestore.instance
          .collection('child_devices')
          .doc(widget.deviceId)
          .update({requestFlag: true});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request Error: $e")),
        );
      }
    }
  }

  Future<void> _sendLockCommand() async {
    try {
      await FirebaseFirestore.instance
          .collection('child_devices')
          .doc(widget.deviceId)
          .update({'requestLock': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lock command sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Column(
          children: [
            const Text(
              "Managing Device",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              widget.deviceName,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .doc(widget.deviceId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final bool isFetchingAppUsage = data['requestAppUsage'] ?? false;
          final bool isFetchingCallLog = data['requestCallLog'] ?? false;
          final bool isFetchingSmsLog = data['requestSmsLog'] ?? false;
          final bool isFetchingContacts = data['requestContacts'] ?? false;
          final bool isFetchingInstalledApps =
              data['requestInstalledApps'] ?? false;
          final bool isFinding = data['requestFindDevice'] ?? false;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader("Applications & Usage"),
              _FeatureTile(
                title: 'Installed Apps',
                subtitle: 'View all applications',
                icon: Icons.grid_view_rounded,
                iconColor: Colors.blueAccent,
                isLoading: isFetchingInstalledApps,
                onRefresh: () => _requestData('requestInstalledApps'),
                onTap: () => _navTo(
                  InstalledAppsScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),
              _FeatureTile(
                title: 'App Usage Stats',
                subtitle: 'Screen time & activity',
                icon: Icons.bar_chart_rounded,
                iconColor: Colors.purpleAccent,
                isLoading: isFetchingAppUsage,
                onRefresh: () => _requestData('requestAppUsage'),
                onTap: () => _navTo(
                  AppUsageScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),
              _FeatureTile(
                title: 'App Blocker',
                subtitle: 'Restrict access to apps',
                icon: Icons.block_flipped,
                iconColor: Colors.redAccent,
                isLoading: false, 
                onRefresh: null,
                onTap: () => _navTo(
                  AppBlockerScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader("Communication"),
              _FeatureTile(
                title: 'Call History',
                subtitle: 'Incoming & outgoing calls',
                icon: Icons.phone_in_talk_rounded,
                iconColor: Colors.green,
                isLoading: isFetchingCallLog,
                onRefresh: () => _requestData('requestCallLog'),
                onTap: () => _navTo(
                  CallHistoryScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),
              _FeatureTile(
                title: 'SMS History',
                subtitle: 'Text messages log',
                icon: Icons.chat_bubble_rounded,
                iconColor: Colors.orange,
                isLoading: isFetchingSmsLog,
                onRefresh: () => _requestData('requestSmsLog'),
                onTap: () => _navTo(
                  SmsHistoryScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),
              _FeatureTile(
                title: 'Contacts',
                subtitle: 'Saved address book',
                icon: Icons.contacts_rounded,
                iconColor: Colors.teal,
                isLoading: isFetchingContacts,
                onRefresh: () => _requestData('requestContacts'),
                onTap: () => _navTo(
                  ContactsScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader("Tracking & Security"),
              _FeatureTile(
                title: 'Location Tracking',
                subtitle: 'Real-time GPS location',
                icon: Icons.map_rounded,
                iconColor: Colors.blue,
                isLoading: false,
                onRefresh: null,
                onTap: () => _navTo(
                  LocationScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),
              _FeatureTile(
                title: 'Find My Device',
                subtitle: 'Play loud ringtone',
                icon: Icons.spatial_audio_rounded,
                iconColor: Colors.indigo,
                isLoading: isFinding,
                onRefresh: null, 
                onTap: isFinding
                    ? () {} 
                    : () => _navTo(
                          FindMyDeviceScreen(
                            deviceId: widget.deviceId,
                            deviceName: widget.deviceName,
                          ),
                        ),
              ),
              _FeatureTile(
                title: 'Web History',
                subtitle: 'Browser activity',
                icon: Icons.public,
                iconColor: Colors.cyan,
                isLoading: false,
                onRefresh: null,
                onTap: () => _navTo(
                  WebHistoryScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),
              _FeatureTile(
                title: 'Notification History',
                subtitle: 'Past system alerts',
                icon: Icons.notifications_active_rounded,
                iconColor: Colors.deepOrange,
                isLoading: false,
                onRefresh: null,
                onTap: () => _navTo(
                  NotificationHistoryScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader("Controls & Alerts"),
              _FeatureTile(
                title: 'Volume Control',
                subtitle: 'Ringer, Alarm & Media',
                icon: Icons.volume_up_rounded,
                iconColor: Colors.pink,
                isLoading: false,
                onRefresh: null,
                onTap: () => _navTo(
                  VolumeControlScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),
              _FeatureTile(
                title: 'SOS Alert History',
                subtitle: 'Panic button logs',
                icon: Icons.emergency_rounded,
                iconColor: Colors.red,
                isLoading: false,
                onRefresh: null,
                onTap: () => _navTo(
                  SosAlertHistoryScreen(
                    deviceId: widget.deviceId,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.red),
                  ),
                  title: const Text(
                    "Remote Lock",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: const Text(
                    "Instantly lock child's screen",
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.red),
                  onTap: _sendLockCommand,
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  void _navTo(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _FeatureTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor; 

  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onRefresh;

  const _FeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor = Colors.blue, 
    required this.isLoading,
    required this.onTap,
    this.onRefresh,
  });

  @override
  State<_FeatureTile> createState() => __FeatureTileState();
}

class __FeatureTileState extends State<_FeatureTile> {
  double _progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) {
      _startLoadingSimulation();
    }
  }

  @override
  void didUpdateWidget(covariant _FeatureTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _startLoadingSimulation();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _stopLoadingSimulation();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLoadingSimulation() {
    _timer?.cancel();
    setState(() {
      _progress = 0.0;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_progress < 0.95) {
          _progress += 0.02;
        }
      });
    });
  }

  void _stopLoadingSimulation() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _progress = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.isLoading 
                            ? Colors.grey.shade100
                            : widget.iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.isLoading 
                            ? Colors.grey 
                            : widget.iconColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: widget.isLoading 
                                    ? Colors.grey 
                                    : const Color(0xFF2D3436),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isLoading 
                                  ? "Syncing data..." 
                                  : widget.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (widget.isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else ...[
                        if (widget.onRefresh != null)
                          IconButton(
                            icon: const Icon(Icons.sync, color: Colors.blueGrey),
                            onPressed: widget.onRefresh,
                            tooltip: 'Refresh',
                            visualDensity: VisualDensity.compact,
                          ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                        ),
                      ],
                    ],
                  ),

                  if (widget.isLoading) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.grey[100],
                        color: widget.iconColor,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}