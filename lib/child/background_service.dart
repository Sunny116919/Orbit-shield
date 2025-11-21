
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
bool isSosTriggered = false;
bool isFindingDevice = false;

const MethodChannel _notificationChannel = MethodChannel('com.orbitshield.app/notifications');

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

// ... [Keep performSosAction as is] ...
Future<void> performSosAction() async {
  if (isSosTriggered) return;
  isSosTriggered = true;
  print('*** SOS TRIGGERED! ***');
  final deviceId = await getDeviceId();
  if (deviceId == null) {
    print('*** SOS FAILED: Device ID null ***');
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
    final docRef = FirebaseFirestore.instance.collection('child_devices').doc(deviceId);
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
    service.on('setAsForeground').listen((event) => service.setAsForegroundService());
    service.on('setAsBackground').listen((event) => service.setAsBackgroundService());
  }

  final deviceId = await getDeviceId();
  if (deviceId == null) {
    service.invoke('stopSelf');
    return;
  }

  // ... [Keep existing listeners for clipboard, url, shake] ...

  service.on('clipboardResult').listen((event) async {
    final clipboardText = event?['text'];
    final docRef = FirebaseFirestore.instance.collection('child_devices').doc(deviceId);
    await docRef.update({
      'clipboardText': clipboardText ?? 'Clipboard is empty.',
      'clipboardLastUpdated': FieldValue.serverTimestamp(),
      'requestClipboard': false,
    });
  });

  service.on('newUrl').listen((event) {
    final url = event?['url'];
    if (url != null) _uploadWebHistory(deviceId, url);
  });

  double shakeThreshold = 12.0;
  DateTime? lastShakeTime;
  accelerometerSubscription?.cancel();
  accelerometerSubscription = accelerometerEventStream().listen((event) {
    double x = event.x, y = event.y, z = event.z;
    double acceleration = (x * x + y * y + z * z) / (9.8 * 9.8);
    if (acceleration > shakeThreshold) {
      final now = DateTime.now();
      if (lastShakeTime == null || now.difference(lastShakeTime!).inSeconds > 3) {
        lastShakeTime = now;
        performSosAction();
      }
    }
  }, onError: (e) => print('*** ACCELEROMETER ERROR: $e ***'));

  await firestoreSubscription?.cancel();
  firestoreSubscription = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId)
      .snapshots()
      .listen((snapshot) async {
    if (!snapshot.exists) {
      // ... [Cleanup logic] ...
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('childDeviceUID');
      await accelerometerSubscription?.cancel();
      await firestoreSubscription?.cancel();
      await blockedAppsSubscription?.cancel();
      service.invoke('stopSelf');
      return;
    }

    final data = snapshot.data()!;
    final docRef = FirebaseFirestore.instance.collection('child_devices').doc(deviceId);

    // --- vvv NEW: Handle Notification History Request vvv ---
    if (data.containsKey('requestNotificationHistory') && data['requestNotificationHistory'] == true) {
      print("--- Request: Notification History ---");
      // 1. Sync whatever is in the buffer
      await _syncNotifications(deviceId);
      // 2. ALWAYS reset the flag, so Parent app stops loading
      await docRef.update({'requestNotificationHistory': false});
      print("--- Notification History sync complete. Flag reset. ---");
    }
    // --- ^^^ END NEW ^^^ ---

    if (data.containsKey('requestClipboard') && data['requestClipboard'] == true) {
      service.invoke('getClipboard');
    }

    // ... [Keep all other request handlers: AppUsage, ScreenTime, ForceRing, etc.] ...
    if (data.containsKey('requestAppUsage') && data['requestAppUsage'] == true) {
       // ... existing app usage logic ...
       Future.wait([
        fetchAndUploadTodayAppUsage(deviceId),
        fetchAndUploadAppUsageForDuration(deviceId, const Duration(hours: 24), 'last_24h_stats'),
        fetchAndUploadAppUsageForDuration(deviceId, const Duration(days: 30), 'last_30d_stats'),
      ]).then((_) async {
        await docRef.update({'requestAppUsage': false});
      });
    }
    
    if (data.containsKey('requestScreenTimeReport') && data['requestScreenTimeReport'] == true) {
        _fetchAndUploadDailyReports(deviceId).then((_) async {
        await docRef.update({'requestScreenTimeReport': false});
      });
    }

    if (data.containsKey('requestForceRing') && data['requestForceRing'] == true) {
       try {
        await SoundMode.setSoundMode(RingerModeStatus.normal);
        await docRef.update({'ringerMode': RingerModeStatus.normal.name});
      } catch (_) {}
      await docRef.update({'requestForceRing': false});
    }

    if (data.containsKey('requestFindDevice') && data['requestFindDevice'] == true) {
       await _performFindDevice(docRef);
       await docRef.update({'requestFindDevice': false});
    }
    
    if (data.containsKey('setRingerMode')) {
        _setRingerMode(docRef, data['setRingerMode']);
    }
    // ... (Keep volume control handlers) ...
    if (data.containsKey('setRingVolume')) {
        final vol = (data['setRingVolume'] as num).toDouble();
        _setVolume(AudioStream.ring, vol);
        _setVolume(AudioStream.notification, vol);
        await docRef.update({'setRingVolume': FieldValue.delete()});
    }
     if (data.containsKey('setAlarmVolume')) {
      final vol = (data['setAlarmVolume'] as num).toDouble();
      _setVolume(AudioStream.alarm, vol);
      await docRef.update({'setAlarmVolume': FieldValue.delete()});
    }
    if (data.containsKey('setMusicVolume')) {
      final vol = (data['setMusicVolume'] as num).toDouble();
      _setVolume(AudioStream.music, vol);
      await docRef.update({'setMusicVolume': FieldValue.delete()});
    }
    if (data.containsKey('setNotificationVolume')) {
      final vol = (data['setNotificationVolume'] as num).toDouble();
      _setVolume(AudioStream.notification, vol);
      await docRef.update({'setNotificationVolume': FieldValue.delete()});
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
    if (data.containsKey('requestInstalledApps') && data['requestInstalledApps'] == true) {
       await fetchAndUploadInstalledApps(deviceId);
       await docRef.update({'requestInstalledApps': false});
    }
  });

  // ... [Keep Blocked Apps Subscription] ...
  await blockedAppsSubscription?.cancel();
  blockedAppsSubscription = FirebaseFirestore.instance
      .collection('child_devices').doc(deviceId)
      .collection('blocked_apps').doc('list')
      .snapshots().listen((snapshot) async {
    final data = snapshot.data();
    List<String> blockedPackages = List<String>.from(data?['blocked_packages'] ?? []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('native_blocked_apps', blockedPackages.join(','));
    print('--- Updated blocked apps ---');
  });

  // ... [Keep 1s and 5s timers] ...
   Timer.periodic(const Duration(seconds: 1), (timer) async {
     if (isFindingDevice) return;
     final currentDeviceId = await getDeviceId();
     if (currentDeviceId == null) { timer.cancel(); return; }
     final docRef = FirebaseFirestore.instance.collection('child_devices').doc(currentDeviceId);
     final Map<String, dynamic> stats = {'lastUpdated': FieldValue.serverTimestamp()};
     try {
       final ringerStatus = await SoundMode.ringerModeStatus;
       stats['ringerMode'] = ringerStatus.name;
       // ... (Keep volume gets) ...
       stats['vol_ring'] = await FlutterVolumeController.getVolume(stream: AudioStream.ring) ?? 0.0;
       stats['vol_alarm'] = await FlutterVolumeController.getVolume(stream: AudioStream.alarm) ?? 0.0;
       stats['vol_music'] = await FlutterVolumeController.getVolume(stream: AudioStream.music) ?? 0.0;
     } catch (_) {}
     if (stats.length > 1) await docRef.update(stats);
   });

   Timer.periodic(const Duration(seconds: 5), (timer) async {
      // ... [Keep battery/network stats logic] ...
      final currentDeviceId = await getDeviceId();
      if (currentDeviceId == null) { timer.cancel(); return; }
      final docRef = FirebaseFirestore.instance.collection('child_devices').doc(currentDeviceId);
      final Map<String, dynamic> stats = {};
      try {
        stats['batteryLevel'] = await Battery().batteryLevel;
        final connectivityResult = await Connectivity().checkConnectivity();
        String internetStatus = 'Offline';
        String? wifiSsid;
        if (connectivityResult.contains(ConnectivityResult.wifi)) {
           internetStatus = 'WiFi';
           try { wifiSsid = (await NetworkInfo().getWifiName())?.replaceAll('"', ''); } catch (_) {}
        } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
           internetStatus = 'Mobile';
        }
        stats['internetStatus'] = internetStatus;
        if (wifiSsid != null) stats['wifiSsid'] = wifiSsid;
      } catch (_) {}
      if (stats.isNotEmpty) await docRef.update(stats);
   });


  // --- vvv UPDATED TIMER: Use the shared sync function vvv ---
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    final currentDeviceId = await getDeviceId();
    if (currentDeviceId != null) {
       await _syncNotifications(currentDeviceId);
    }
  });
  // --- ^^^ END TIMER ^^^ ---

  // ... [Keep Live Location Timers] ...
    Timer.periodic(const Duration(seconds: 5), (timer) async {
        // ... existing live location logic ...
        final currentDeviceId = await getDeviceId();
        if (currentDeviceId == null) { timer.cancel(); return; }
        final docRef = FirebaseFirestore.instance.collection('child_devices').doc(currentDeviceId);
        if (await Permission.locationAlways.isGranted) {
             final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
             await docRef.update({
                 'currentLocation': GeoPoint(pos.latitude, pos.longitude),
                 'locationLastUpdated': FieldValue.serverTimestamp(),
             });
        }
    });

    Timer.periodic(const Duration(minutes: 5), (timer) async {
         // ... existing history logic ...
         final currentDeviceId = await getDeviceId();
         if (currentDeviceId == null) { timer.cancel(); return; }
         final docRef = FirebaseFirestore.instance.collection('child_devices').doc(currentDeviceId);
         if (await Permission.locationAlways.isGranted) {
             final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
             await docRef.collection('location_history').add({
                 'location': GeoPoint(pos.latitude, pos.longitude),
                 'timestamp': FieldValue.serverTimestamp(),
             });
        }
    });
}

Future<void> _syncNotifications(String deviceId) async {
  final prefs = await SharedPreferences.getInstance();
  
  // 1. FIX: FORCE RELOAD FROM DISK
  // This makes Flutter realize the Native Service has written new data.
  await prefs.reload(); 

  // 2. Read the data (flutter. prefix is handled automatically)
  final notifString = prefs.getString('native_notification_buffer');

  if (notifString != null && notifString.isNotEmpty && notifString != "[]") {
    try {
      print("NOTIF SYNC: Found buffered notifications: $notifString");
      final List<dynamic> jsonList = jsonDecode(notifString);
      
      final batch = FirebaseFirestore.instance.batch();
      final notifCollection = FirebaseFirestore.instance
          .collection('child_devices')
          .doc(deviceId)
          .collection('notification_history');

      for (var item in jsonList) {
         Map<String, dynamic> notifData;
         if(item is String) {
           notifData = jsonDecode(item);
         } else {
           notifData = item as Map<String, dynamic>;
         }
         int ts = notifData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
         notifData['timestamp'] = Timestamp.fromMillisecondsSinceEpoch(ts);
         
         final docRef = notifCollection.doc(); 
         batch.set(docRef, notifData);
      }

      await batch.commit();
      print("NOTIF SYNC: Successfully uploaded ${jsonList.length} notifications.");

      // 3. Clear the buffer
      await prefs.setString('native_notification_buffer', "[]"); 
      // 4. Reload again to ensure cache is in sync with the clear
      await prefs.reload();

    } catch (e) {
      print("NOTIF SYNC ERROR: $e");
    }
  } else {
     print("NOTIF SYNC: Buffer empty or null (After reload).");
  }
}

Future<void> fetchAndUploadInstalledApps(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  print('INSTALLED APPS FETCH: Received request.');
  try {
    List<AppInfo> installedApps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    );

    print('INSTALLED APPS FETCH: Found ${installedApps.length} apps.');
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
    print('INSTALLED APPS FETCH: Upload complete.');
    await docRef.update({'requestInstalledApps': false});
  } catch (e) {
    print('INSTALLED APPS FETCH ERROR: ${e.toString()}');
    await docRef.update({'requestInstalledApps': false});
  }
}


Future<void> fetchAndUploadContacts(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  print('CONTACTS FETCH: Received request.');
  try {
    var contactsPermission = await Permission.contacts.status;
    if (contactsPermission.isGranted) {
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
    } else {
      print('CONTACTS FETCH ERROR: Permission was not granted.');
    }
    await docRef.update({'requestContacts': false});
  } catch (e) {
    print('CONTACTS FETCH ERROR: ${e.toString()}');
    await docRef.update({'requestContacts': false});
  }
}

Future<void> _performFindDevice(DocumentReference docRef) async {
  if (isFindingDevice) return;
  isFindingDevice = true;

  try {
    await SoundMode.setSoundMode(RingerModeStatus.normal);
    await docRef.update({'ringerMode': RingerModeStatus.normal.name});
    print("--- Find My Device: Ringer set to NORMAL ---");

    await FlutterVolumeController.setVolume(1.0, stream: AudioStream.alarm);
    await FlutterVolumeController.setVolume(1.0, stream: AudioStream.ring);
    print("--- Find My Device: Alarm & Ring Volume set to MAX ---");

    FlutterRingtonePlayer().playAlarm(looping: true);
    print("--- Find My Device: PLAYING ALARM ---");

    await Future.delayed(const Duration(seconds: 15));
    await FlutterRingtonePlayer().stop();
    print("--- Find My Device: Alarm stopped ---");
  } on PlatformException catch (e) {
    print("--- ERROR during Find My Device: $e ---");
    print(
      "--- THIS LIKELY FAILED. THE APP NEEDS 'DO NOT DISTURB ACCESS' PERMISSION ON THE CHILD'S PHONE. ---",
    );
  } catch (e) {
    print("--- An unknown error occurred during Find My Device: $e ---");
  }

  isFindingDevice = false;
}

Future<void> _setRingerMode(DocumentReference docRef, String mode) async {
  RingerModeStatus status;

  if (mode == "VIBRATE") {
    status = RingerModeStatus.vibrate;
  } else if (mode == "SILENT") {
    status = RingerModeStatus.silent;
  } else {
    status = RingerModeStatus.normal;
  }

  try {
    await SoundMode.setSoundMode(status);
    print("--- Ringer mode successfully set to $mode ---");
    await docRef.update({'ringerMode': status.name});
  } on PlatformException catch (e) {
    print("--- ERROR SETTING RINGER MODE: $e ---");
    print(
      "--- THIS LIKELY FAILED. THE APP NEEDS 'DO NOT DISTURB ACCESS' PERMISSION ON THE CHILD'S PHONE. ---",
    );
  } catch (e) {
    print("--- An unknown error occurred: $e ---");
  }

  await docRef.update({'setRingerMode': FieldValue.delete()});
}

Future<void> _setVolume(AudioStream stream, double volume) async {
  try {
    final safeVolume = volume.clamp(0.0, 1.0);
    await FlutterVolumeController.setVolume(safeVolume, stream: stream);
  } catch (e) {
    print("--- Error setting volume for $stream: $e ---");
  }
}

Future<void> fetchAndUploadTodayAppUsage(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  print('APP USAGE FETCH (Today)');
  try {
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, now.day);
    List<AppUsageInfo> usageList = await AppUsage().getAppUsage(startDate, now);
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

    List<AppInfo> installedApps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      withIcon: false,
    );

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
    await docRef.collection('app_usage').doc('today_stats').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'startDate': startDate.toIso8601String(),
      'endDate': now.toIso8601String(),
      'apps': appData,
    });
    print('APP USAGE FETCH (Today): Upload complete.');
  } catch (e) {
    print('APP USAGE FETCH (Today) ERROR: $e');
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
  print('APP USAGE FETCH ($docName): Duration $duration');
  try {
    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.subtract(duration);
    List<AppUsageInfo> usageList = await AppUsage().getAppUsage(
      startDate,
      endDate,
    );
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

    List<AppInfo> installedApps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      withIcon: false,
    );

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
    await docRef.collection('app_usage').doc(docName).set({
      'updatedAt': FieldValue.serverTimestamp(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'apps': appData,
    });
    print('APP USAGE FETCH ($docName): Upload complete.');
  } catch (e) {
    print('APP USAGE FETCH ($docName) ERROR: $e');
  }
}

Future<void> _fetchAndUploadDailyReports(String deviceId) async {
  print('DAILY REPORT (On-Demand): Starting 30-day loop...');
  final DateTime now = DateTime.now();
  List<Map<String, dynamic>> dailyReports = [];

  try {
    for (int i = 0; i < 30; i++) {
      final DateTime dayToQuery = now.subtract(Duration(days: i));

      final DateTime startTime = DateTime(
        dayToQuery.year,
        dayToQuery.month,
        dayToQuery.day,
        0,
        0,
        0,
      );
      final DateTime endTime = DateTime(
        dayToQuery.year,
        dayToQuery.month,
        dayToQuery.day,
        23,
        59,
        59,
      );
      final String dateString = DateFormat('yyyy-MM-dd').format(startTime);

      final List<AppUsageInfo> usageList = await AppUsage().getAppUsage(
        startTime,
        endTime,
      );

      int totalMinutes = 0;
      for (var info in usageList) {
        totalMinutes += info.usage.inMinutes;
      }

      dailyReports.add({'date': dateString, 'totalUsageMinutes': totalMinutes});
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

    print('DAILY REPORT (On-Demand): Upload complete.');
  } catch (e) {
    print('DAILY REPORT (On-Demand) ERROR: $e');
  }
}

Future<void> fetchAndUploadSmsLog(String deviceId) async {
  final SmsQuery query = SmsQuery();
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  try {
    var smsPermission = await Permission.sms.status;
    var contactsPermission = await Permission.contacts.status;
    Map<String, String> contactsMap = {};
    if (contactsPermission.isGranted) {
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          String normalizedNumber = _normalizePhoneNumber(phone.number);
          if (normalizedNumber.isNotEmpty) {
            contactsMap[normalizedNumber] = contact.displayName;
          }
        }
      }
    }
    if (smsPermission.isGranted) {
      List<SmsMessage> messages = await query.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
      );
      List<Map<String, dynamic>> smsLogData = [];
      for (var message in messages) {
        if (message.address == null) continue;
        String normalizedAddress = _normalizePhoneNumber(message.address!);
        smsLogData.add({
          'name': contactsMap[normalizedAddress],
          'address': message.address,
          'body': message.body,
          'kind': message.kind?.name,
          'date': message.date,
        });
      }
      await docRef.collection('sms_log').doc('history').set({
        'updatedAt': FieldValue.serverTimestamp(),
        'entries': smsLogData,
      });
    }
    await docRef.update({'requestSmsLog': false});
  } catch (e) {
    print('SMS LOG FETCH ERROR: ${e.toString()}');
    await docRef.update({'requestSmsLog': false});
  }
}

Future<void> _uploadWebHistory(String deviceId, String url) async {
  try {
    final docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(deviceId)
        .collection('web_history')
        .doc();

    await docRef.set({'url': url, 'timestamp': FieldValue.serverTimestamp()});
  } catch (e) {
    print("--- Error uploading web history: $e ---");
  }
}

Future<void> fetchAndUploadCallLog(String deviceId) async {
  final docRef = FirebaseFirestore.instance
      .collection('child_devices')
      .doc(deviceId);
  try {
    Iterable<CallLogEntry> entries = await CallLog.get();
    List<Map<String, dynamic>> callLogData = [];
    for (var entry in entries) {
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
    print('CALL LOG FETCH ERROR: ${e.toString()}');
    await docRef.update({'requestCallLog': false});
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}
