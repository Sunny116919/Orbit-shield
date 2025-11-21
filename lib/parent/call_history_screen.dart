import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CallHistoryScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const CallHistoryScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  IconData _getCallTypeIcon(String? callType) {
    switch (callType) {
      case 'incoming':
        return Icons.call_received;
      case 'outgoing':
        return Icons.call_made;
      case 'missed':
        return Icons.call_missed;
      case 'rejected':
        return Icons.call_missed_outgoing;
      default:
        return Icons.call;
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '';
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else {
      return '${minutes}m ${secs}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${deviceName} - Call History'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .doc(deviceId)
            .collection('call_log')
            .doc('history')
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
                  'No call history data found. Data will appear here after the initial fetch is complete. Use the refresh button to request it again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final entries = List<Map<String, dynamic>>.from(
            data['entries'] ?? [],
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
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final name = entry['name'] ?? 'Unknown';
                    final number = entry['number'] ?? 'No number';
                    final callType = entry['callType'] as String?;
                    final timestamp =
                        (entry['timestamp'] as Timestamp?)?.toDate();
                    final duration = _formatDuration(entry['duration']);

                    return ListTile(
                      leading: Icon(
                        _getCallTypeIcon(callType),
                        color: callType == 'missed'
                            ? Colors.red
                            : (callType == 'incoming'
                                ? Colors.green
                                : Colors.blue),
                      ),
                      title: Text(name),
                      subtitle: Text(number),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (timestamp != null)
                            Text(
                              DateFormat.yMd()
                                  .add_jm()
                                  .format(timestamp.toLocal()),
                            ),
                          if (duration.isNotEmpty)
                            Text(
                              duration,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
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