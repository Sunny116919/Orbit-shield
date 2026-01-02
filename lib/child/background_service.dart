import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:geocoding/geocoding.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_usage/app_usage.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:call_log/call_log.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:intl/intl.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import '../../../firebase_options.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

StreamSubscription<DocumentSnapshot>? firestoreSubscription;
StreamSubscription<AccelerometerEvent>? accelerometerSubscription;
StreamSubscription<DocumentSnapshot>? blockedAppsSubscription;
StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
StreamSubscription<double>? volumeSubscription;

bool isSosTriggered = false;
bool isFindingDevice = false;
DateTime _lastVolumeUpdate = DateTime.now();
const int _volumeUpdateIntervalMs = 500;

String _normalizePhoneNumber(String number) {
  String digitsOnly = number.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length > 10) {
    return digitsOnly.substring(digitsOnly.length - 10);
  }
  return digitsOnly;
}

Future<String?> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('childDeviceUID');
}

Future<void> performSosAction() async {
  if (isSosTriggered) return;
  isSosTriggered = true;
  print('*** SOS TRIGGERED! ***');
  final deviceId = await getDeviceId();
  if (deviceId == null) {
    isSosTriggered = false;
    return;
  }

  GeoPoint? sosLocation;
  String? sosAddress;

  try {
    if (await Permission.location.isGranted ||
        await Permission.locationAlways.isGranted) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 1),
      );
      sosLocation = GeoPoint(pos.latitude, pos.longitude);

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          sosAddress = "${p.name}, ${p.locality}, ${p.country}";
        }
      } catch (_) {}
    }
  } catch (_) {}

  try {
    final docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(deviceId);
    await docRef.update({
      'sos_trigger': true,
      'lastSosTime': FieldValue.serverTimestamp(),
      if (sosLocation != null) 'lastSosLocation': sosLocation,
      if (sosAddress != null) 'lastSosAddress': sosAddress,
    });
    await docRef.collection('sos_alerts').add({
      'timestamp': FieldValue.serverTimestamp(),
      'location': sosLocation,
      'address': sosAddress,
    });
  } catch (e) {
    print('*** FIRESTORE SOS UPDATE FAILED: $e ***');
  }
  Future.delayed(const Duration(seconds: 3), () => isSosTriggered = false);
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.child);

  try {
    await FlutterVolumeController.updateShowSystemUI(false);
  } catch (e) {
    print('Failed to init volume controller: $e');
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.setForegroundNotificationInfo(
      title: "Orbit Shield Active",
      content: "Monitoring device safety...",
    );
  }

  final deviceId = await getDeviceId();
  if (deviceId == null) {
    service.invoke('stopSelf');
    return;
  }

  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);

  volumeSubscription?.cancel();
  volumeSubscription = FlutterVolumeController.addListener((volume) {
    final now = DateTime.now();
    if (now.difference(_lastVolumeUpdate).inMilliseconds >
        _volumeUpdateIntervalMs) {
      _lastVolumeUpdate = now;
      print("🔊 Physical Volume Changed on Device - Syncing to Parent...");
      _pushVolumeAndRingerStatus(deviceId);
    }
  });

  connectivitySubscription?.cancel();
  connectivitySubscription = Connectivity().onConnectivityChanged.listen((
    List<ConnectivityResult> results,
  ) async {
    bool isConnected = results.any((r) => r != ConnectivityResult.none);

    if (isConnected) {
      print("🌐 INTERNET RESTORED: Triggering Immediate Re-Sync...");
      await _updateHeartbeat(deviceId);
      await _checkPendingCommands(deviceId);
      await _syncNotifications(deviceId);
      await _syncWebHistory(deviceId);
    } else {
      print("❌ DEVICE WENT OFFLINE");
    }
  });

  double shakeThreshold = 12.0;
  DateTime? lastShakeTime;
  accelerometerSubscription?.cancel();
  accelerometerSubscription = accelerometerEventStream().listen((event) {
    double x = event.x, y = event.y, z = event.z;
    double acceleration = (x * x + y * y + z * z) / (9.8 * 9.8);
    if (acceleration > shakeThreshold) {
      final now = DateTime.now();
      if (lastShakeTime == null ||
          now.difference(lastShakeTime!).inSeconds > 3) {
        lastShakeTime = now;
        performSosAction();
      }
    }
  }, onError: (e) => print('*** ACCELEROMETER ERROR: $e ***'));

  await firestoreSubscription?.cancel();
  firestoreSubscription = docRef.snapshots().listen((snapshot) async {
    if (!snapshot.exists) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('childDeviceUID');
      service.invoke('stopSelf');
      return;
    }

    final data = snapshot.data()!;
    _processFirestoreCommands(deviceId, data, docRef);
  }, onError: (e) => print("Firestore Listener Error: $e"));

  await blockedAppsSubscription?.cancel();
  blockedAppsSubscription = docRef
      .collection('blocked_apps')
      .doc('list')
      .snapshots()
      .listen((snapshot) async {
        final data = snapshot.data();
        List<String> blockedPackages = List<String>.from(
          data?['blocked_packages'] ?? [],
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('native_blocked_apps', blockedPackages.join(','));
        print('--- Updated blocked apps ---');
      });

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (isFindingDevice) return;
    await _updateHeartbeat(deviceId);
  });

  Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (isFindingDevice) return;
    await _updateVolumes(deviceId);
  });

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    await _syncNotifications(deviceId);
    await _syncWebHistory(deviceId);
  });

  Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (await Permission.locationAlways.isGranted) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await docRef.update({
          'currentLocation': GeoPoint(pos.latitude, pos.longitude),
          'locationLastUpdated': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  });

  Timer.periodic(const Duration(minutes: 5), (timer) async {
    if (await Permission.locationAlways.isGranted) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await docRef.collection('location_history').add({
          'location': GeoPoint(pos.latitude, pos.longitude),
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  });
}

Future<void> _pushVolumeAndRingerStatus(String deviceId) async {
  try {
    final ringerStatus = await SoundMode.ringerModeStatus;

    final double volRing =
        await FlutterVolumeController.getVolume(stream: AudioStream.ring) ??
        0.0;
    final double volAlarm =
        await FlutterVolumeController.getVolume(stream: AudioStream.alarm) ??
        0.0;
    final double volMusic =
        await FlutterVolumeController.getVolume(stream: AudioStream.music) ??
        0.0;

    await FirebaseFirestore.instance
        .collection('child_devices')
        .doc(deviceId)
        .update({
          'ringerMode': ringerStatus.name,
          'vol_ring': volRing,
          'vol_alarm': volAlarm,
          'vol_music': volMusic,
        });
  } catch (e) {
    print("Error syncing volume/ringer: $e");
  }
}

Future<void> _updateVolumes(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  final Map<String, dynamic> stats = {
    'lastUpdated': FieldValue.serverTimestamp(),
  };

  if (stats.isNotEmpty) {
    await docRef.update(stats).catchError((e) {});
  }

  await _pushVolumeAndRingerStatus(deviceId);
}

Future<void> _updateHeartbeat(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  final Map<String, dynamic> stats = {
    'lastUpdated': FieldValue.serverTimestamp(),
  };

  try {
    stats['batteryLevel'] = await Battery().batteryLevel;
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      stats['internetStatus'] = 'WiFi';
      try {
        stats['wifiSsid'] = (await NetworkInfo().getWifiName())?.replaceAll(
          '"',
          '',
        );
      } catch (_) {}
    } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
      stats['internetStatus'] = 'Mobile';
    } else {
      stats['internetStatus'] = 'Offline';
    }
  } catch (_) {}

  if (stats.isNotEmpty) {
    await docRef.update(stats).catchError((e) {});
  }

  await _pushVolumeAndRingerStatus(deviceId);
}

Future<void> _processFirestoreCommands(
  String deviceId,
  Map<String, dynamic> data,
  DocumentReference docRef,
) async {
  if (data.containsKey('requestLock') && data['requestLock'] == true) {
    print("🔒 LOCK REQUEST RECEIVED");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('native_trigger_lock', true);
    await docRef.update({'requestLock': false});
  }

  if (data.containsKey('requestAppUsage') && data['requestAppUsage'] == true) {
    Future.wait([
      fetchAndUploadTodayAppUsage(deviceId),
      fetchAndUploadAppUsageForDuration(
        deviceId,
        const Duration(hours: 24),
        'last_24h_stats',
      ),
      fetchAndUploadAppUsageForDuration(
        deviceId,
        const Duration(days: 30),
        'last_30d_stats',
      ),
    ]).then((_) => docRef.update({'requestAppUsage': false}));
  }

  if (data.containsKey('requestScreenTimeReport') &&
      data['requestScreenTimeReport'] == true) {
    _fetchAndUploadDailyReports(
      deviceId,
    ).then((_) => docRef.update({'requestScreenTimeReport': false}));
  }

  if (data.containsKey('requestForceRing') &&
      data['requestForceRing'] == true) {
    try {
      await SoundMode.setSoundMode(RingerModeStatus.normal);
      await _pushVolumeAndRingerStatus(deviceId);
    } catch (_) {}
    await docRef.update({'requestForceRing': false});
  }

  if (data.containsKey('requestFindDevice') &&
      data['requestFindDevice'] == true) {
    await _performFindDevice(docRef, deviceId);
    await docRef.update({'requestFindDevice': false});
  }

  bool volumeChanged = false;

  if (data.containsKey('setRingerMode')) {
    await _setRingerMode(docRef, data['setRingerMode']);
    volumeChanged = true;
  }

  if (data.containsKey('setRingVolume')) {
    final vol = (data['setRingVolume'] as num).toDouble();
    await _setVolume(AudioStream.ring, vol);
    await _setVolume(AudioStream.notification, vol);
    await docRef.update({'setRingVolume': FieldValue.delete()});
    volumeChanged = true;
  }

  if (data.containsKey('setAlarmVolume')) {
    final vol = (data['setAlarmVolume'] as num).toDouble();
    await _setVolume(AudioStream.alarm, vol);
    await docRef.update({'setAlarmVolume': FieldValue.delete()});
    volumeChanged = true;
  }

  if (data.containsKey('setMusicVolume')) {
    final vol = (data['setMusicVolume'] as num).toDouble();
    await _setVolume(AudioStream.music, vol);
    await docRef.update({'setMusicVolume': FieldValue.delete()});
    volumeChanged = true;
  }

  if (volumeChanged) {
    Future.delayed(const Duration(milliseconds: 100), () {
      _pushVolumeAndRingerStatus(deviceId);
    });
  }

  if (data.containsKey('requestCallLog') && data['requestCallLog'] == true) {
    await fetchAndUploadCallLog(deviceId);
    await docRef.update({'requestCallLog': false});
  }
  if (data.containsKey('requestSmsLog') && data['requestSmsLog'] == true) {
    await fetchAndUploadSmsLog(deviceId);
    await docRef.update({'requestSmsLog': false});
  }
  if (data.containsKey('requestContacts') && data['requestContacts'] == true) {
    await fetchAndUploadContacts(deviceId);
    await docRef.update({'requestContacts': false});
  }
  if (data.containsKey('requestInstalledApps') &&
      data['requestInstalledApps'] == true) {
    await fetchAndUploadInstalledApps(deviceId);
    await docRef.update({'requestInstalledApps': false});
  }
}

Future<void> _checkPendingCommands(String deviceId) async {
  print("🔄 RE-SYNC: Checking for commands sent while offline...");
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);

  try {
    DocumentSnapshot doc = await docRef.get(
      const GetOptions(source: Source.server),
    );

    if (doc.exists && doc.data() != null) {
      await _processFirestoreCommands(
        deviceId,
        doc.data() as Map<String, dynamic>,
        docRef,
      );
    }
  } catch (e) {
    print("Error checking pending commands: $e");
  }
}

Future<void> _syncWebHistory(String deviceId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final webString = prefs.getString('native_web_buffer');

  if (webString != null && webString.isNotEmpty && webString != "[]") {
    try {
      final List<dynamic> jsonList = jsonDecode(webString);
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance
          .collection('child_devices')
          .doc(deviceId)
          .collection('web_history');

      for (var item in jsonList) {
        Map<String, dynamic> data;
        if (item is String) {
          data = jsonDecode(item);
        } else {
          data = item as Map<String, dynamic>;
        }
        int ts = data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
        data['timestamp'] = Timestamp.fromMillisecondsSinceEpoch(ts);

        String uniqueId = "${ts}_${data['url'].hashCode}";
        batch.set(collection.doc(uniqueId), data);
      }
      await batch.commit();
      print("WEB SYNC: Uploaded ${jsonList.length} URLs.");
      await prefs.setString('native_web_buffer', "[]");
    } catch (e) {
      print("WEB SYNC ERROR: $e");
    }
  }
}

Future<void> _syncNotifications(String deviceId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final notifString = prefs.getString('native_notification_buffer');

  if (notifString != null && notifString.isNotEmpty && notifString != "[]") {
    try {
      final List<dynamic> jsonList = jsonDecode(notifString);
      final batch = FirebaseFirestore.instance.batch();
      final notifCollection = FirebaseFirestore.instance
          .collection('child_devices')
          .doc(deviceId)
          .collection('notification_history');

      for (var item in jsonList) {
        Map<String, dynamic> notifData;
        if (item is String) {
          notifData = jsonDecode(item);
        } else {
          notifData = item as Map<String, dynamic>;
        }
        int ts =
            notifData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
        notifData['timestamp'] = Timestamp.fromMillisecondsSinceEpoch(ts);

        String uniqueId =
            "${ts}_${notifData['packageName']}_${notifData['title'].hashCode}";
        batch.set(notifCollection.doc(uniqueId), notifData);
      }
      await batch.commit();
      print("NOTIF SYNC: Uploaded ${jsonList.length} notifications.");
      await prefs.setString('native_notification_buffer', "[]");
    } catch (e) {
      print("NOTIF SYNC ERROR: $e");
    }
  }
}

Future<void> fetchAndUploadInstalledApps(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  try {
    List<AppInfo> installedApps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    );
    List<Map<String, dynamic>> appsData = [];
    for (var app in installedApps) {
      appsData.add({
        'appName': app.name,
        'packageName': app.packageName,
        'versionName': app.versionName,
        'versionCode': app.versionCode,
      });
    }
    await docRef.collection('installed_apps').doc('list').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'apps': appsData,
    });
    await docRef.update({'requestInstalledApps': false});
  } catch (e) {
    print('INSTALLED APPS ERROR: $e');
    await docRef.update({'requestInstalledApps': false});
  }
}

Future<void> fetchAndUploadContacts(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  try {
    if (await Permission.contacts.isGranted) {
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withAccounts: true,
      );
      List<Map<String, dynamic>> contactsData = [];
      for (var contact in contacts) {
        if (contact.phones.isNotEmpty) {
          contactsData.add({
            'displayName': contact.displayName,
            'phoneNumber': contact.phones.first.number,
          });
        }
      }
      await docRef.collection('contacts').doc('list').set({
        'updatedAt': FieldValue.serverTimestamp(),
        'entries': contactsData,
      });
    }
    await docRef.update({'requestContacts': false});
  } catch (e) {
    print('CONTACTS ERROR: $e');
    await docRef.update({'requestContacts': false});
  }
}

Future<void> _performFindDevice(
  DocumentReference docRef,
  String? deviceId,
) async {
  if (isFindingDevice) return;
  isFindingDevice = true;
  try {
    await SoundMode.setSoundMode(RingerModeStatus.normal);
    await FlutterVolumeController.setVolume(1.0, stream: AudioStream.alarm);
    await FlutterVolumeController.setVolume(1.0, stream: AudioStream.ring);

    if (deviceId != null) {
      await _pushVolumeAndRingerStatus(deviceId);
    }

    FlutterRingtonePlayer().playAlarm(looping: true);
    await Future.delayed(const Duration(seconds: 15));
    await FlutterRingtonePlayer().stop();
  } catch (e) {
    print("Find Device Error: $e");
  }
  isFindingDevice = false;
}

Future<void> _setRingerMode(DocumentReference docRef, String mode) async {
  RingerModeStatus status = RingerModeStatus.normal;
  if (mode == "vibrate")
    status = RingerModeStatus.vibrate;
  else if (mode == "silent")
    status = RingerModeStatus.silent;

  try {
    await SoundMode.setSoundMode(status);
  } catch (e) {
    print("Ringer Mode Error: $e");
  }
  await docRef.update({'setRingerMode': FieldValue.delete()});
}

Future<void> _setVolume(AudioStream stream, double volume) async {
  try {
    await FlutterVolumeController.setVolume(
      volume.clamp(0.0, 1.0),
      stream: stream,
    );
  } catch (_) {}
}

Future<void> fetchAndUploadTodayAppUsage(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  try {
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, now.day);
    List<AppUsageInfo> usageList = await AppUsage().getAppUsage(startDate, now);
    await _processAndUploadUsage(
      docRef,
      'today_stats',
      usageList,
      startDate,
      now,
    );
  } catch (e) {
    print('APP USAGE TODAY ERROR: $e');
  }
}

Future<void> fetchAndUploadAppUsageForDuration(
  String deviceId,
  Duration duration,
  String docName,
) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  try {
    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.subtract(duration);
    List<AppUsageInfo> usageList = await AppUsage().getAppUsage(
      startDate,
      endDate,
    );
    await _processAndUploadUsage(
      docRef,
      docName,
      usageList,
      startDate,
      endDate,
    );
  } catch (e) {
    print('APP USAGE $docName ERROR: $e');
  }
}

Future<void> _processAndUploadUsage(
  DocumentReference docRef,
  String docId,
  List<AppUsageInfo> usageList,
  DateTime start,
  DateTime end,
) async {
  Map<String, Duration> aggregatedUsage = {};
  Map<String, DateTime> lastForegroundMap = {};

  for (var info in usageList) {
    if (info.usage.inMinutes > 0) {
      aggregatedUsage.update(
        info.packageName,
        (v) => v + info.usage,
        ifAbsent: () => info.usage,
      );
      lastForegroundMap.update(
        info.packageName,
        (v) => info.lastForeground.isAfter(v) ? info.lastForeground : v,
        ifAbsent: () => info.lastForeground,
      );
    }
  }

  List<AppInfo> installedApps = await InstalledApps.getInstalledApps();
  Map<String, String> appNames = {
    for (var app in installedApps) app.packageName: app.name,
  };

  List<Map<String, dynamic>> appData = [];
  aggregatedUsage.forEach((pkg, dur) {
    appData.add({
      'appName': appNames[pkg] ?? pkg,
      'packageName': pkg,
      'totalUsageMinutes': dur.inMinutes,
      'lastForeground': lastForegroundMap[pkg]?.toIso8601String(),
    });
  });

  await docRef.collection('app_usage').doc(docId).set({
    'updatedAt': FieldValue.serverTimestamp(),
    'startDate': start.toIso8601String(),
    'endDate': end.toIso8601String(),
    'apps': appData,
  });
}

Future<void> _fetchAndUploadDailyReports(String deviceId) async {
  final DateTime now = DateTime.now();
  List<Map<String, dynamic>> dailyReports = [];
  try {
    for (int i = 0; i < 30; i++) {
      final DateTime dayToQuery = now.subtract(Duration(days: i));
      final DateTime startTime = DateTime(
        dayToQuery.year,
        dayToQuery.month,
        dayToQuery.day,
      );
      final DateTime endTime = DateTime(
        dayToQuery.year,
        dayToQuery.month,
        dayToQuery.day,
        23,
        59,
        59,
      );

      final List<AppUsageInfo> usageList = await AppUsage().getAppUsage(
        startTime,
        endTime,
      );
      int totalMinutes = usageList.fold(
        0,
        (sum, item) => sum + item.usage.inMinutes,
      );

      dailyReports.add({
        'date': DateFormat('yyyy-MM-dd').format(startTime),
        'totalUsageMinutes': totalMinutes,
      });
    }
    await FirebaseFirestore.instance
        .collection('child_devices')
        .doc(deviceId)
        .collection('app_usage')
        .doc('daily_30d_report')
        .set({
          'reports': dailyReports,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  } catch (e) {
    print('DAILY REPORT ERROR: $e');
  }
}

Future<void> fetchAndUploadSmsLog(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  try {
    if (await Permission.sms.isGranted) {
      final SmsQuery query = SmsQuery();
      List<SmsMessage> messages = await query.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
      );
      List<Map<String, dynamic>> smsLogData = [];
      final limitedMessages = messages.take(50);
      for (var message in limitedMessages) {
        smsLogData.add({
          'address': message.address,
          'body': message.body,
          'date': message.date,
          'kind': message.kind?.name,
        });
      }
      await docRef.collection('sms_log').doc('history').set({
        'updatedAt': FieldValue.serverTimestamp(),
        'entries': smsLogData,
      });
    }
    await docRef.update({'requestSmsLog': false});
  } catch (e) {
    print('SMS LOG ERROR: $e');
    await docRef.update({'requestSmsLog': false});
  }
}

Future<void> fetchAndUploadCallLog(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  try {
    Iterable<CallLogEntry> entries = await CallLog.get();
    List<Map<String, dynamic>> callLogData = [];
    final limitedEntries = entries.take(50);
    for (var entry in limitedEntries) {
      callLogData.add({
        'name': entry.name,
        'number': entry.number,
        'callType': entry.callType?.name,
        'duration': entry.duration,
        'timestamp': entry.timestamp != null
            ? Timestamp.fromMillisecondsSinceEpoch(entry.timestamp!)
            : null,
      });
    }
    await docRef.collection('call_log').doc('history').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'entries': callLogData,
    });
    await docRef.update({'requestCallLog': false});
  } catch (e) {
    print('CALL LOG ERROR: $e');
    await docRef.update({'requestCallLog': false});
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}
