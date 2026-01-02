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

  Color _getAvatarColor(String name) {
    final List<Color> colors = [
      const Color(0xFF5C6BC0),
      const Color(0xFFAB47BC),
      const Color(0xFFEF5350),
      const Color(0xFF26A69A),
      const Color(0xFFFFA726),
      const Color(0xFF78909C),
      const Color(0xFF42A5F5),
    ];
    return colors[name.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Column(
          children: [
            const Text(
              'SMS History',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              deviceName,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('child_devices')
              .doc(deviceId)
              .collection('sms_log')
              .doc('history')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF5C6BC0),
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_chat_unread_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'No SMS history found.\nRefresh to fetch data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final entries = List<Map<String, dynamic>>.from(
              data['entries'] ?? [],
            );
            final lastUpdated = (data['updatedAt'] as Timestamp?)?.toDate();

            final Map<String, List<Map<String, dynamic>>> conversations = {};
            for (var message in entries) {
              final address = message['address'] ?? 'Unknown';
              conversations.putIfAbsent(address, () => []).add(message);
            }

            final sortedThreads = conversations.entries.toList()
              ..sort((a, b) {
                final lastMsgA =
                    (a.value.first['date'] as Timestamp?)?.toDate() ??
                        DateTime(1970);
                final lastMsgB =
                    (b.value.first['date'] as Timestamp?)?.toDate() ??
                        DateTime(1970);
                return lastMsgB.compareTo(lastMsgA);
              });

            return Column(
              children: [
                if (lastUpdated != null)
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 16.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sync, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Synced: ${DateFormat.yMd().add_jm().format(lastUpdated.toLocal())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
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

                      final lastMessageBody =
                          lastMessage['body'] ?? 'No content';
                      final lastMessageDate =
                          (lastMessage['date'] as Timestamp?)?.toDate();
                      final isSentByChild = lastMessage['kind'] == 'sent';

                      final displayName = contactName ?? contactAddress;
                      final initial = displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '#';
                      final avatarColor = _getAvatarColor(displayName);

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
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
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
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: avatarColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          color: avatarColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (lastMessageDate != null)
                                              Text(
                                                DateFormat('MMM d')
                                                    .format(lastMessageDate
                                                        .toLocal())
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[400],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (isSentByChild) ...[
                                              const Icon(
                                                Icons.done_all,
                                                size: 16,
                                                color: Color(0xFF42A5F5),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Expanded(
                                              child: Text(
                                                lastMessageBody,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                  height: 1.2,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}