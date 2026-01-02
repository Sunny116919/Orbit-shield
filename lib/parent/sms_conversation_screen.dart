import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SmsConversationScreen extends StatelessWidget {
  final String? contactName;
  final String contactAddress;
  final List<Map<String, dynamic>> messages;

  const SmsConversationScreen({
    super.key,
    this.contactName,
    required this.contactAddress,
    required this.messages,
  });

  bool _isSameDay(DateTime dateA, DateTime dateB) {
    return dateA.year == dateB.year &&
        dateA.month == dateB.month &&
        dateA.day == dateB.day;
  }

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
    messages.sort((a, b) {
      final dateA = (a['date'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final dateB = (b['date'] as Timestamp?)?.toDate() ?? DateTime(1970);
      return dateA.compareTo(dateB);
    });

    final List<dynamic> items = [];
    DateTime? lastDate;
    for (var message in messages) {
      final currentDate = (message['date'] as Timestamp?)?.toDate();
      if (currentDate != null) {
        if (lastDate == null || !_isSameDay(lastDate, currentDate)) {
          items.add(currentDate);
          lastDate = currentDate;
        }
      }
      items.add(message);
    }

    final displayName = contactName ?? contactAddress;
    final avatarColor = _getAvatarColor(displayName);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '#';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: avatarColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (contactName != null)
                    Text(
                      contactAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          if (item is DateTime) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 24),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  DateFormat.yMMMMd().format(item),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }

          final message = item as Map<String, dynamic>;
          final body = message['body'] ?? 'No content';
          final isSent = message['kind'] == 'sent';
          final date = (message['date'] as Timestamp?)?.toDate();

          return Align(
            alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment:
                  isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSent ? const Color(0xFF42A5F5) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isSent
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      bottomRight: isSent
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    body,
                    style: TextStyle(
                      color: isSent ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ),
                if (date != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSent) ...[
                          Icon(
                            Icons.done_all,
                            size: 14,
                            color: Colors.blue[300],
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          DateFormat.jm().format(date.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}