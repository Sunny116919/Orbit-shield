import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SosAlertScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const SosAlertScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  Future<String> _getAddressFromGeoPoint(GeoPoint geoPoint) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        geoPoint.latitude,
        geoPoint.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.street ?? ''}, ${place.locality ?? ''}, ${place.postalCode ?? ''}";
      }
      return "Address not found";
    } catch (e) {
      return "Lat: ${geoPoint.latitude.toStringAsFixed(4)}, Lng: ${geoPoint.longitude.toStringAsFixed(4)}";
    }
  }

  void _launchMapsUrl(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _cancelSosAlert() {
    FirebaseFirestore.instance.collection('child_devices').doc(deviceId).update(
      {'sos_trigger': false},
    );
  }

  void _requestForceRing() {
    try {
      FirebaseFirestore.instance
          .collection('child_devices')
          .doc(deviceId)
          .update({'requestForceRing': true});
    } catch (e) {
      print("Failed to send Force Ring request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SOS EMERGENCY'),
        backgroundColor: Colors.red,
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
          final data = snapshot.data!.data() as Map<String, dynamic>;

          final isSosActive = data['sos_trigger'] == true;
          final geoPoint = data['currentLocation'] as GeoPoint?;
          final timestamp =
              (data['locationLastUpdated'] as Timestamp?)?.toDate();
          final bool isRinging = data['requestForceRing'] ?? false;

          if (!isSosActive) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('SOS alert has been cancelled.'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          if (geoPoint == null || timestamp == null) {
            return const Center(
              child: Text('Waiting for child\'s location data...'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 100,
                ),
                const SizedBox(height: 20),
                Text(
                  'EMERGENCY ALERT FROM',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.red),
                ),
                Text(
                  deviceName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Last known location updated at: ${DateFormat.yMd().add_jm().format(timestamp.toLocal())}',
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<String>(
                          future: _getAddressFromGeoPoint(geoPoint),
                          builder: (context, addressSnapshot) {
                            if (addressSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              );
                            }
                            return Text(
                              addressSnapshot.data ?? "Could not get address",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () =>
                      _launchMapsUrl(geoPoint.latitude, geoPoint.longitude),
                  icon: const Icon(Icons.map),
                  label: const Text('VIEW LOCATION ON MAP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: isRinging ? null : _requestForceRing,
                  icon: Icon(
                    isRinging
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                  label: Text(isRinging ? 'RINGING...' : 'FORCE RING PHONE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRinging ? Colors.grey : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    _cancelSosAlert();
                    Navigator.of(context).pop();
                  },
                  child: const Text('MARK AS SAFE'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
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
