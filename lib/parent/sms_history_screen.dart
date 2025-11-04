import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'sms_conversation_screen.dart';

class SmsHistoryScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const SmsHistoryScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,

  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${deviceName} - SMS History')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .doc(deviceId)
            .collection('sms_log')
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
                  'No SMS history data found. Data will appear here after the initial fetch is complete. Use the refresh button to request it again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final entries = List<Map<String, dynamic>>.from(data['entries'] ?? []);
          final lastUpdated = (data['updatedAt'] as Timestamp?)?.toDate();

          final Map<String, List<Map<String, dynamic>>> conversations = {};
          for (var message in entries) {
            final address = message['address'] ?? 'Unknown';
            conversations.putIfAbsent(address, () => []).add(message);
          }

          final sortedThreads = conversations.entries.toList()
            ..sort((a, b) {
              final lastMsgA = (a.value.first['date'] as Timestamp?)?.toDate() ?? DateTime(1970);
              final lastMsgB = (b.value.first['date'] as Timestamp?)?.toDate() ?? DateTime(1970);
              return lastMsgB.compareTo(lastMsgA);
            });

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
                  itemCount: sortedThreads.length,
                  itemBuilder: (context, index) {
                    final thread = sortedThreads[index];
                    final messages = thread.value;
                    final lastMessage = messages.first;

                    final contactAddress = thread.key;
                    final contactName = messages.firstWhere(
                          (m) => m['name'] != null,
                          orElse: () => {'name': null},
                        )['name'] as String?;

                    final lastMessageBody = lastMessage['body'] ?? 'No content';
                    final lastMessageDate = (lastMessage['date'] as Timestamp?)?.toDate();
                    final isSentByChild = lastMessage['kind'] == 'sent';

                    return ListTile(
                      leading: CircleAvatar(child: Text((contactName ?? contactAddress).isNotEmpty ? (contactName ?? contactAddress)[0].toUpperCase() : '#')),
                      title: Text(contactName ?? contactAddress),
                      subtitle: Row(
                        children: [
                          if (isSentByChild)
                            const Icon(Icons.done_all, size: 16, color: Colors.blue),
                          if (isSentByChild) const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              lastMessageBody,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      trailing: lastMessageDate != null
                          ? Text(DateFormat('dd MMM').format(lastMessageDate.toLocal()))
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SmsConversationScreen(
                              contactName: contactName,
                              contactAddress: contactAddress,
                              messages: messages,
                            ),
                          ),
                        );
                      },
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