// [New file: parent/clipboard_screen.dart]

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ClipboardScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const ClipboardScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${deviceName} - Clipboard'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_devices')
            .doc(deviceId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final clipboardText =
              data['clipboardText'] as String? ??
              "No data yet. Refresh from the previous screen.";
          final lastUpdated = (data['clipboardLastUpdated'] as Timestamp?)
              ?.toDate();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lastUpdated != null)
                  Text(
                    'Last updated: ${DateFormat.yMd().add_jm().format(lastUpdated.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SelectableText(
                      clipboardText,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy to My Clipboard'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: clipboardText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to your clipboard!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
