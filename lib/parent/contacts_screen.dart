import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ContactsScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const ContactsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${deviceName} - Contacts'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .doc(deviceId)
            .collection('contacts')
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
                  'No contacts data found. Data will appear here after the initial fetch is complete. Use the refresh button to request it again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final entries = List<Map<String, dynamic>>.from(data['entries'] ?? []);
          final lastUpdated = (data['updatedAt'] as Timestamp?)?.toDate();
          entries.sort((a, b) => (a['displayName'] ?? '').toLowerCase().compareTo((b['displayName'] ?? '').toLowerCase()));


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
                    final displayName = entry['displayName'] ?? 'No Name';
                    final phoneNumber = entry['phoneNumber'] ?? 'No Number';

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '#',
                        ),
                      ),
                      title: Text(displayName),
                      subtitle: Text(phoneNumber),
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