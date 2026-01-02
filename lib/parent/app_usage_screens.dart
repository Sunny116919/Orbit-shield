import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppUsageScreen extends StatefulWidget {
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
  late TabController _tabController;

  final Color _primaryColor = const Color(0xFF5C6BC0); 
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  Widget _buildUsageList(String firestoreDocName, String titlePrefix) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('child_devices')
          .doc(widget.deviceId)
          .collection('app_usage')
          .doc(firestoreDocName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: _primaryColor));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty_rounded,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'No usage data for "$titlePrefix".\nRefresh from device details.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final apps = List<Map<String, dynamic>>.from(data['apps'] ?? []);

        int totalMinutes = 0;
        for (var app in apps) {
          totalMinutes += (app['totalUsageMinutes'] as num? ?? 0).toInt();
        }
        final totalDuration = Duration(minutes: totalMinutes);
        final bool showTotal = firestoreDocName != 'last_30d_stats';

        apps.sort(
          (a, b) => (b['totalUsageMinutes'] ?? 0).compareTo(
            a['totalUsageMinutes'] ?? 0,
          ),
        );
        final lastUpdated = (data['updatedAt'] as Timestamp?)?.toDate();
        final startDateString = data['startDate'] as String?;
        final endDateString = data['endDate'] as String?;
        String dateRange = titlePrefix;
        
        if (startDateString != null && endDateString != null) {
          final start = DateTime.tryParse(startDateString)?.toLocal();
          final end = DateTime.tryParse(endDateString)?.toLocal();
          if (start != null && end != null) {
            if (firestoreDocName == 'today_stats') {
              dateRange = "Today, ${DateFormat.MMMd().format(start)}";
            } else if (firestoreDocName == 'last_24h_stats') {
              dateRange = "Last 24 Hours";
            } else {
              dateRange =
                  "${DateFormat.MMMd().format(start)} - ${DateFormat.MMMd().format(end)}";
            }
          }
        }

        return Column(
          children: [
            if (showTotal)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateRange.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Screen Time',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(totalDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.access_time_filled, color: Colors.white, size: 30),
                        )
                      ],
                    ),
                  ],
                ),
              ),

            if (lastUpdated != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sync, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Synced: ${DateFormat.jm().format(lastUpdated.toLocal())}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: apps.isEmpty
                  ? Center(
                      child: Text(
                        "No usage recorded.",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        final appUsageMinutes = (app['totalUsageMinutes'] as num? ?? 0).toInt();
                        final duration = Duration(minutes: appUsageMinutes);

                        double usagePercent = totalMinutes > 0 
                            ? (appUsageMinutes / totalMinutes) 
                            : 0.0;
                        if(usagePercent > 1.0) usagePercent = 1.0;

                        String usageString = _formatDuration(duration);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.android,
                                    color: _primaryColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app['appName'] ?? app['packageName'] ?? 'Unknown App',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: usagePercent,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor.withOpacity(0.7)),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                Text(
                                  usageString,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'App Usage',
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              widget.deviceName,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25.0),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(25.0),
                color: _primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: '24h'),
                Tab(text: '30d'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsageList('today_stats', "Today"),
          _buildUsageList('last_24h_stats', "Last 24h"),
          _buildUsageList('last_30d_stats', "Last 30d"),
        ],
      ),
    );
  }
}