import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const LocationScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.deviceName} - Location'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Current Location'),
            Tab(text: 'Location History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RealTimeLocationView(deviceId: widget.deviceId),
          _LocationHistoryView(deviceId: widget.deviceId),
        ],
      ),
    );
  }
}

// --- WIDGET FOR THE 'CURRENT LOCATION' TAB ---
class _RealTimeLocationView extends StatelessWidget {
  final String deviceId;
  const _RealTimeLocationView({required this.deviceId});

  Future<String> _getAddressFromGeoPoint(GeoPoint geoPoint) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        geoPoint.latitude,
        geoPoint.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // You can customize the address format here
        return "${place.street ?? ''}, ${place.locality ?? ''}, ${place.postalCode ?? ''}";
      }
      return "Address not found";
    } catch (e) {
      // If geocoding fails, return the coordinates instead as a fallback
      return "Lat: ${geoPoint.latitude.toStringAsFixed(4)}, Lng: ${geoPoint.longitude.toStringAsFixed(4)}";
    }
  }

  void _launchMapsUrl(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('child_devices')
          .doc(deviceId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final geoPoint = data?['currentLocation'] as GeoPoint?;
        final lastUpdated = (data?['locationLastUpdated'] as Timestamp?)
            ?.toDate();

        if (geoPoint == null) {
          return const Center(child: Text('No location data available yet.'));
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Last Known Location:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<String>(
                        future: _getAddressFromGeoPoint(geoPoint),
                        builder: (context, addressSnapshot) {
                          if (!addressSnapshot.hasData) {
                            return const CircularProgressIndicator();
                          }
                          return Text(
                            addressSnapshot.data!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      if (lastUpdated != null)
                        Text(
                          'Updated: ${DateFormat.yMd().add_jm().format(lastUpdated.toLocal())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    _launchMapsUrl(geoPoint.latitude, geoPoint.longitude),
                icon: const Icon(Icons.map),
                label: const Text('View on Map'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocationHistoryView extends StatelessWidget {
  final String deviceId;
  const _LocationHistoryView({required this.deviceId});

  Future<String> _getAddressFromGeoPoint(GeoPoint geoPoint) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        geoPoint.latitude,
        geoPoint.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.street}, ${place.locality}, ${place.postalCode}";
      }
    } catch (e) {
      return "Could not get address";
    }
    return "Address not found";
  }

  void _launchMapsDirectionsUrl(List<QueryDocumentSnapshot> historyDocs) async {
    if (historyDocs.length < 2) return;

    final origin = historyDocs.first['location'] as GeoPoint;
    final destination = historyDocs.last['location'] as GeoPoint;

    final waypoints = historyDocs
        .sublist(1, historyDocs.length - 1)
        .map((doc) {
          final point = doc['location'] as GeoPoint;
          return '${point.latitude},${point.longitude}';
        })
        .join('|');

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&waypoints=$waypoints',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('child_devices')
          .doc(deviceId)
          .collection('location_history')
          .orderBy('timestamp', descending: true)
          .limit(50) // Limit to the last 50 data points
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No location history recorded yet.'));
        }
        final historyDocs = snapshot.data!.docs;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => _launchMapsDirectionsUrl(
                  historyDocs.reversed.toList(),
                ), // Reverse to get chronological order for path
                child: const Text('Show Full Path in Google Maps'),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: historyDocs.length,
                itemBuilder: (context, index) {
                  final doc = historyDocs[index];
                  final geoPoint = doc['location'] as GeoPoint;
                  final timestamp = (doc['timestamp'] as Timestamp).toDate();

                  return ListTile(
                    leading: const Icon(Icons.location_pin),
                    title: FutureBuilder<String>(
                      future: _getAddressFromGeoPoint(geoPoint),
                      builder: (context, addressSnapshot) {
                        return Text(
                          addressSnapshot.data ?? 'Loading address...',
                        );
                      },
                    ),
                    subtitle: Text(
                      DateFormat.yMd().add_jm().format(timestamp.toLocal()),
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
}
