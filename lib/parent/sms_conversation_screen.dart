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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contactName ?? contactAddress),
            if (contactName != null)
              Text(
                contactAddress,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          if (item is DateTime) {
            return Center(
              child: Chip(label: Text(DateFormat.yMMMMd().format(item))),
            );
          }

          final message = item as Map<String, dynamic>;
          final body = message['body'] ?? 'No content';
          final isSent = message['kind'] == 'sent';
          final date = (message['date'] as Timestamp?)?.toDate();

          return Align(
            alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: isSent
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSent ? Colors.blue[200] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(body),
                ),
                if (date != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      DateFormat.jm().format(date.toLocal()),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
