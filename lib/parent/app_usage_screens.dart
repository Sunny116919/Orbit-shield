import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppUsageScreen extends StatefulWidget {
  // Changed to StatefulWidget
  final String deviceId;
  final String deviceName;

  const AppUsageScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<AppUsageScreen> createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends State<AppUsageScreen>
    with SingleTickerProviderStateMixin {
  // Added TickerProvider
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // Initialize TabController
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose TabController
    super.dispose();
  }
  
  // --- ADDED HELPER FUNCTION ---
  String _formatDuration(Duration duration) {
    if (duration.inMinutes == 0) return '0m';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    String result = '';
    if (hours > 0) {
      result += '${hours}h ';
    }
    if (minutes > 0) {
      result += '${minutes}m';
    }
    return result.trim();
  }

  // Helper Widget to build the list view for each tab
  Widget _buildUsageList(String firestoreDocName, String titlePrefix) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('child_devices')
          .doc(widget.deviceId)
          .collection('app_usage')
          .doc(firestoreDocName) // Use the passed document name
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No app usage data found for "$titlePrefix". Refresh from the device details screen to fetch it.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final apps = List<Map<String, dynamic>>.from(data['apps'] ?? []);

        // --- ADDED TOTAL CALCULATION ---
        int totalMinutes = 0;
        for (var app in apps) {
          totalMinutes += (app['totalUsageMinutes'] as num? ?? 0).toInt();
        }
        final totalDuration = Duration(minutes: totalMinutes);
        // Only show total for Today and 24h, not 30d
        final bool showTotal = firestoreDocName != 'last_30d_stats';
        // --- END TOTAL CALCULATION ---
        
        apps.sort(
          (a, b) => (b['totalUsageMinutes'] ?? 0).compareTo(
            a['totalUsageMinutes'] ?? 0,
          ),
        );
        final lastUpdated = (data['updatedAt'] as Timestamp?)?.toDate();
        final startDateString = data['startDate'] as String?;
        final endDateString = data['endDate'] as String?;
        String dateRange = titlePrefix; // Default title
        if (startDateString != null && endDateString != null) {
          final start = DateTime.tryParse(startDateString)?.toLocal();
          final end = DateTime.tryParse(endDateString)?.toLocal();
          if (start != null && end != null) {
            // Be more specific for Today/24h
            if (firestoreDocName == 'today_stats') {
              dateRange = "Today (${DateFormat.yMd().format(start)})";
            } else if (firestoreDocName == 'last_24h_stats') {
              dateRange = "Last 24 Hours";
            } else {
              dateRange =
                  "${DateFormat.yMd().format(start)} - ${DateFormat.yMd().format(end)}";
            }
          }
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              child: Text(
                "Usage for: $dateRange",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            // --- ADDED TOTALS WIDGET ---
            if (showTotal)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Column(
                  children: [
                    Text(
                      'Total Screen Time',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(totalDuration),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            // --- END ADDED WIDGET ---

            if (lastUpdated != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Last updated: ${DateFormat.yMd().add_jm().format(lastUpdated.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: apps.isEmpty
                  ? const Center(
                      child: Text(
                        "No usage recorded for this period.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        final totalMinutes = app['totalUsageMinutes'] ?? 0;
                        final duration = Duration(minutes: totalMinutes);
                        String usageString;
                        if (duration.inHours > 0) {
                          usageString =
                              '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
                        } else {
                          usageString = '${duration.inMinutes}m';
                        }

                        return ListTile(
                          leading: const Icon(
                            Icons.android,
                            color: Colors.grey,
                          ),
                          title: Text(
                            app['appName'] ??
                                app['packageName'] ??
                                'Unknown App',
                          ), // Fallback to package name
                          trailing: Text(
                            usageString,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.deviceName} - App Usage'),
        bottom: TabBar(
          // Add TabBar here
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Last 24h'),
            Tab(text: 'Last 30d'),
          ],
        ),
      ),
      body: TabBarView(
        // Use TabBarView for the body
        controller: _tabController,
        children: [
          _buildUsageList('today_stats', "Today"), // Tab 1 content
          _buildUsageList('last_24h_stats', "Last 24h"), // Tab 2 content
          _buildUsageList('last_30d_stats', "Last 30d"), // Tab 3 content
        ],
      ),
    );
  }
}