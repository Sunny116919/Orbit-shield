import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_usage/app_usage.dart';
import 'package:geolocator/geolocator.dart';
import 'qr_scanner_screen.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:sound_mode/permission_handler.dart' as DndPermission;
import 'dart:io' show Platform;

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _isCameraGranted = false;
  bool _isCallLogGranted = false;
  bool _isSmsGranted = false;
  bool _isContactsGranted = false;
  bool _isLocationGranted = false;
  bool _isBackgroundLocationGranted = false;
  bool _isGpsEnabled = false;
  bool _isBatteryOptimizationDisabled = false;
  bool _isDndAccessGranted = false;
  bool _isNotificationListenerGranted = false;
  bool _isAccessibilityGranted = false;

  // 1. NEW: Variable for System Alert Window
  bool _isOverlayGranted = false;

  static const MethodChannel _nativeChannel = MethodChannel(
    'com.orbitshield.app/native',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final callLogStatus = await Permission.phone.status;
    final smsStatus = await Permission.sms.status;
    final contactsStatus = await Permission.contacts.status;
    final locationStatus = await Permission.location.status;
    final backgroundLocationStatus = await Permission.locationAlways.status;
    final isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    final isBatteryOptDisabled =
        await DisableBatteryOptimization.isBatteryOptimizationDisabled;
    final isDndGranted =
        await DndPermission.PermissionHandler.permissionsGranted;

    // 2. NEW: Check Overlay Status
    final overlayStatus = await Permission.systemAlertWindow.status;

    bool isNotifListenerGranted = false;
    bool isAccessServiceGranted = false;

    if (Platform.isAndroid) {
      try {
        isNotifListenerGranted = await _nativeChannel.invokeMethod(
          'checkNotificationPermission',
        );
        isAccessServiceGranted = await _nativeChannel.invokeMethod(
          'checkAccessibilityPermission',
        );
      } catch (e) {
        print("Native Bridge Error: $e");
      }
    }

    if (mounted) {
      setState(() {
        _isCameraGranted = cameraStatus.isGranted;
        _isCallLogGranted = callLogStatus.isGranted;
        _isSmsGranted = smsStatus.isGranted;
        _isContactsGranted = contactsStatus.isGranted;
        _isLocationGranted = locationStatus.isGranted;
        _isBackgroundLocationGranted = backgroundLocationStatus.isGranted;
        _isGpsEnabled = isGpsEnabled;
        _isBatteryOptimizationDisabled = isBatteryOptDisabled ?? false;
        _isDndAccessGranted = isDndGranted ?? false;
        _isNotificationListenerGranted = isNotifListenerGranted;
        _isAccessibilityGranted = isAccessServiceGranted;
        
        // 3. NEW: Update Overlay State
        _isOverlayGranted = overlayStatus.isGranted;
      });
    }
  }

  // ... Existing request methods ...
  Future<void> _requestCameraPermission() async {
    await Permission.camera.request();
    _checkAllPermissions();
  }

  Future<void> _requestCallLogPermission() async {
    await Permission.phone.request();
    _checkAllPermissions();
  }

  Future<void> _requestSmsPermission() async {
    await Permission.sms.request();
    _checkAllPermissions();
  }

  Future<void> _requestContactsPermission() async {
    await Permission.contacts.request();
    _checkAllPermissions();
  }

  Future<void> _requestLocationPermission() async {
    await Permission.location.request();
    _checkAllPermissions();
  }

  Future<void> _requestBackgroundLocationPermission() async {
    await Permission.locationAlways.request();
    _checkAllPermissions();
  }

  Future<void> _openBackgroundSettings() async {
    await openAppSettings();
  }

  Future<void> _openUsageSettings() async {
    AppUsage().getAppUsage(
      DateTime.now().subtract(const Duration(hours: 1)),
      DateTime.now(),
    );
  }

  Future<void> _openGpsSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _requestBatteryOptimization() async {
    await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
  }

  Future<void> _requestDndAccess() async {
    await DndPermission.PermissionHandler.openDoNotDisturbSetting();
  }

  Future<void> _requestNotificationListenerPermission() async {
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('requestNotificationPermission');
      } catch (e) {
        print("Error opening settings: $e");
      }
    }
  }

  Future<void> _openAccessibilitySettings() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Important for Android 13+"),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "If 'Orbit Shield' is GRAYED OUT and you cannot click it:\n",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text("1. Go to your phone Settings > Apps > Orbit Shield."),
              Text("2. Tap the 3 dots (top right corner)."),
              Text("3. Select 'Allow Restricted Settings'."),
              SizedBox(height: 10),
              Text("Then come back here and click Enable again."),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchAccessibility();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _launchAccessibility() async {
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('requestAccessibilityPermission');
      } catch (e) {
        const AndroidIntent intent = AndroidIntent(
          action: 'android.settings.ACCESSIBILITY_SETTINGS',
        );
        await intent.launch();
      }
    }
  }

  // 4. NEW: Request Overlay Permission
  Future<void> _requestOverlayPermission() async {
    if (await Permission.systemAlertWindow.isDenied) {
      await Permission.systemAlertWindow.request();
    }
    // Check immediately after returning
    _checkAllPermissions(); 
  }

  @override
  Widget build(BuildContext context) {
    // 5. NEW: Add _isOverlayGranted to validation
    final bool canContinue =
        _isCameraGranted &&
        _isCallLogGranted &&
        _isSmsGranted &&
        _isContactsGranted &&
        _isLocationGranted &&
        _isGpsEnabled &&
        _isBackgroundLocationGranted &&
        _isBatteryOptimizationDisabled &&
        _isDndAccessGranted &&
        _isOverlayGranted; // Added here

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              // ... Same Header Code ...
              child: const Column(
                children: [
                  Icon(
                    Icons.shield_rounded,
                    size: 60,
                    color: Color(0xFF4A90E2),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Setup Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'To protect this device, please grant the following permissions',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionLabel("Basic Permissions"),
                  // ... Camera, Call, SMS, Contacts ...
                  _buildPermissionCard(
                    title: 'Camera',
                    subtitle: 'Needed to scan the QR code',
                    icon: Icons.camera_alt,
                    isGranted: _isCameraGranted,
                    onTap: _requestCameraPermission,
                  ),
                  _buildPermissionCard(
                    title: 'Call Logs',
                    subtitle: 'Monitor call history',
                    icon: Icons.phone_in_talk,
                    isGranted: _isCallLogGranted,
                    onTap: _requestCallLogPermission,
                  ),
                  _buildPermissionCard(
                    title: 'SMS Messages',
                    subtitle: 'Read text messages',
                    icon: Icons.sms,
                    isGranted: _isSmsGranted,
                    onTap: _requestSmsPermission,
                  ),
                  _buildPermissionCard(
                    title: 'Contacts',
                    subtitle: 'Show contact names',
                    icon: Icons.contacts,
                    isGranted: _isContactsGranted,
                    onTap: _requestContactsPermission,
                  ),

                  const SizedBox(height: 16),
                  _buildSectionLabel("Location & Tracking"),
                  _buildPermissionCard(
                    title: 'Location',
                    subtitle: 'Required for tracking',
                    icon: Icons.location_on,
                    isGranted: _isLocationGranted,
                    onTap: _requestLocationPermission,
                  ),
                  _buildPermissionCard(
                    title: 'GPS Service',
                    subtitle: 'Must be enabled',
                    icon: Icons.gps_fixed,
                    isGranted: _isGpsEnabled,
                    onTap: _openGpsSettings,
                  ),
                  _buildPermissionCard(
                    title: 'Background Location',
                    subtitle: 'Select "Allow all the time"',
                    icon: Icons.timelapse,
                    isGranted: _isBackgroundLocationGranted,
                    onTap: !_isLocationGranted
                        ? null
                        : _requestBackgroundLocationPermission,
                    isLocked: !_isLocationGranted,
                  ),

                  const SizedBox(height: 16),
                  _buildSectionLabel("Advanced Monitoring"),
                  
                  // 6. NEW: Display Over Other Apps Card
                  _buildPermissionCard(
                    title: 'Lock Screen Overlay',
                    subtitle: 'Required to Lock Device',
                    icon: Icons.layers,
                    isGranted: _isOverlayGranted,
                    onTap: _requestOverlayPermission,
                  ),

                  _buildPermissionCard(
                    title: 'Accessibility',
                    subtitle: _isAccessibilityGranted
                        ? "Active"
                        : 'Tap to Enable (Fix Gray Button)',
                    icon: Icons.accessibility_new,
                    isGranted: _isAccessibilityGranted,
                    isActionAlwaysVisible: true,
                    onTap: _openAccessibilitySettings,
                    customButtonLabel: "Enable",
                  ),

                  _buildPermissionCard(
                    title: 'Notification Access',
                    subtitle: 'Select "Orbit Shield" > Enable',
                    icon: Icons.notifications_active,
                    isGranted: _isNotificationListenerGranted,
                    isActionAlwaysVisible: true,
                    onTap: _requestNotificationListenerPermission,
                    customButtonLabel: "Settings",
                  ),

                  _buildPermissionCard(
                    title: 'Background Activity',
                    subtitle: 'Allow Background Activity',
                    icon: Icons.battery_alert,
                    isGranted: false,
                    isActionAlwaysVisible: true,
                    onTap: _openBackgroundSettings,
                    customButtonLabel: "Settings",
                  ),
                  
                  // ... Usage, DND, Battery Opt ...
                  _buildPermissionCard(
                    title: 'App Usage',
                    subtitle: 'Enable "Permit usage access"',
                    icon: Icons.data_usage,
                    isGranted: false,
                    isActionAlwaysVisible: true,
                    onTap: _openUsageSettings,
                    customButtonLabel: "Settings",
                  ),
                  _buildPermissionCard(
                    title: 'Do Not Disturb',
                    subtitle: 'Allow Do Not Disturb',
                    icon: Icons.do_not_disturb_on,
                    isGranted: _isDndAccessGranted,
                    onTap: _requestDndAccess,
                    customButtonLabel: "Settings",
                  ),
                  _buildPermissionCard(
                    title: 'Battery Optimization',
                    subtitle: 'Select "Allow"',
                    icon: Icons.battery_std,
                    isGranted: _isBatteryOptimizationDisabled,
                    onTap: _requestBatteryOptimization,
                    customButtonLabel: "Disable",
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomSheet: Container(
        color: const Color(0xFFF5F7FA),
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canContinue
                  ? const Color(0xFF4A90E2)
                  : Colors.grey[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: canContinue ? 4 : 0,
            ),
            onPressed: !canContinue
                ? null
                : () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const QrScannerScreen(),
                      ),
                    );
                  },
            child: const Text(
              'Continue Setup',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required VoidCallback? onTap,
    bool isLocked = false,
    bool isActionAlwaysVisible = false,
    String customButtonLabel = "Allow",
  }) {
    final bool showCheck = isGranted && !isActionAlwaysVisible;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: showCheck
                ? Colors.green.withOpacity(0.1)
                : const Color(0xFF4A90E2).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: showCheck ? Colors.green : const Color(0xFF4A90E2),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: showCheck
            ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
            : SizedBox(
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLocked
                        ? Colors.grey[300]
                        : const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: onTap,
                  child: Text(
                    isLocked ? "Locked" : customButtonLabel,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
      ),
    );
  }
}