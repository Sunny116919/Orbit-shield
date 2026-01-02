import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppBlockerScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const AppBlockerScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<AppBlockerScreen> createState() => _AppBlockerScreenState();
}

class _AppBlockerScreenState extends State<AppBlockerScreen> {
  late DocumentReference _installedAppsRef;
  late DocumentReference _blockedAppsRef;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _installedAppsRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(widget.deviceId)
        .collection('installed_apps')
        .doc('list');

    _blockedAppsRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(widget.deviceId)
        .collection('blocked_apps')
        .doc('list');
  }

  Future<void> _toggleBlockStatus(String packageName, bool isBlocked) async {
    try {
      if (isBlocked) {
        await _blockedAppsRef.set({
          'blocked_packages': FieldValue.arrayUnion([packageName])
        }, SetOptions(merge: true));
      } else {
        await _blockedAppsRef.update({
          'blocked_packages': FieldValue.arrayRemove([packageName])
        });
      }
    } catch (e) {
      print("Error toggling block status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating block status: $e')),
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
        title: const Text(
          'App Blocker',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search applications...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF5C6BC0)),
                filled: true,
                fillColor: const Color(0xFFF0F2F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _installedAppsRef.snapshots(),
        builder: (context, installedAppsSnapshot) {
          if (installedAppsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5C6BC0)),
            );
          }
          if (!installedAppsSnapshot.hasData || !installedAppsSnapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.app_blocking_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'No installed apps found.\nPlease refresh from the "Installed Apps" screen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          final appData = installedAppsSnapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> installedApps = appData['apps'] ?? [];

          installedApps.sort((a, b) => (a['appName'] as String)
              .toLowerCase()
              .compareTo((b['appName'] as String).toLowerCase()));

          final List<dynamic> filteredApps = installedApps.where((app) {
            final String appName = (app['appName'] ?? '').toLowerCase();
            return appName.contains(_searchQuery);
          }).toList();

          return StreamBuilder<DocumentSnapshot>(
            stream: _blockedAppsRef.snapshots(),
            builder: (context, blockedAppsSnapshot) {
              List<String> blockedPackages = [];
              if (blockedAppsSnapshot.hasData && blockedAppsSnapshot.data!.exists) {
                final blockedData = blockedAppsSnapshot.data!.data() as Map<String, dynamic>;
                blockedPackages = List<String>.from(blockedData['blocked_packages'] ?? []);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredApps.length,
                itemBuilder: (context, index) {
                  final app = filteredApps[index];
                  final String appName = app['appName'] ?? 'Unknown App';
                  final String packageName = app['packageName'] ?? '';

                  if (packageName.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final bool isBlocked = blockedPackages.contains(packageName);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: isBlocked 
                          ? Border.all(color: Colors.red.withOpacity(0.3), width: 1.5)
                          : Border.all(color: Colors.transparent),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isBlocked
                                    ? [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)]
                                    : [const Color(0xFFE8EAF6), const Color(0xFFC5CAE9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isBlocked ? Icons.block : Icons.android,
                              color: isBlocked ? Colors.red[400] : const Color(0xFF5C6BC0),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isBlocked ? Colors.red[900] : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  packageName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontFamily: 'Courier',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Switch.adaptive(
                                value: isBlocked,
                                activeColor: Colors.red,
                                activeTrackColor: Colors.red.withOpacity(0.2),
                                inactiveThumbColor: Colors.grey[400],
                                inactiveTrackColor: Colors.grey[200],
                                onChanged: (bool newValue) {
                                  _toggleBlockStatus(packageName, newValue);
                                },
                              ),
                              Text(
                                isBlocked ? "BLOCKED" : "ALLOWED",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isBlocked ? Colors.red : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}