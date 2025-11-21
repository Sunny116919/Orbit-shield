import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InstalledAppsScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const InstalledAppsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${deviceName} - Installed Apps'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .doc(deviceId)
            .collection('installed_apps')
            .doc('list')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No installed apps data found. Refresh from the previous screen to fetch it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final apps = List<Map<String, dynamic>>.from(data['apps'] ?? []);
          apps.sort(
            (a, b) => (a['appName'] ?? '').toLowerCase().compareTo(
              (b['appName'] ?? '').toLowerCase(),
            ),
          );
          final lastUpdated = (data['updatedAt'] as Timestamp?)?.toDate();

          return Column(
            children: [
              if (lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Last updated: ${DateFormat.yMd().add_jm().format(lastUpdated.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return ListTile(
                      leading: const Icon(Icons.android, color: Colors.grey),
                      title: Text(app['appName'] ?? 'Unknown App'),
                      subtitle: Text(
                        'Version: ${app['versionName'] ?? 'N/A'} (${app['versionCode'] ?? 'N/A'})\nPackage: ${app['packageName'] ?? 'N/A'}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}