import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VolumeControlScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const VolumeControlScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<VolumeControlScreen> createState() => _VolumeControlScreenState();
}

class _VolumeControlScreenState extends State<VolumeControlScreen> {
  late DocumentReference _docRef;

  double? _ringVolume;
  double? _alarmVolume;
  double? _musicVolume;

  bool _isDraggingRing = false;
  bool _isDraggingAlarm = false;
  bool _isDraggingMusic = false;

  @override
  void initState() {
    super.initState();
    _docRef = FirebaseFirestore.instance
        .collection('child_devices')
        .doc(widget.deviceId);
  }

  void _showRingerModePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.volume_up_rounded,
                    color: Theme.of(context).colorScheme.primary),
                title:
                    Text('normal', style: Theme.of(context).textTheme.titleLarge),
                onTap: () {
                  _docRef.update({'setRingerMode': 'normal'});
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.vibration_rounded,
                    color: Theme.of(context).colorScheme.primary),
                title: Text('vibrate',
                    style: Theme.of(context).textTheme.titleLarge),
                onTap: () {
                  _docRef.update({'setRingerMode': 'vibrate'});
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.volume_off_rounded,
                    color: Theme.of(context).colorScheme.primary),
                title:
                    Text('silent', style: Theme.of(context).textTheme.titleLarge),
                onTap: () {
                  _docRef.update({'setRingerMode': 'silent'});
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _setVolume(String fieldName, double value) {
    _docRef.update({fieldName: value});
  }

  Widget _buildRingerModeCard(String? ringerMode) {
    IconData icon;
    String text;

    switch (ringerMode) {
      case "normal":
        icon = Icons.volume_up_rounded;
        text = "Mode: Normal";
        break;
      case "vibrate":
        icon = Icons.vibration_rounded;
        text = "Mode: Vibrate";
        break;
      case "silent":
        icon = Icons.volume_off_rounded;
        text = "Mode: Silent";
        break;
      default:
        icon = Icons.sync_problem_rounded;
        text = "Loading...";
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Text(
                  text,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            ElevatedButton(
              onPressed: ringerMode == null ? null : _showRingerModePicker,
              child: const Text('Change Mode'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeSlider({
    required String title,
    required IconData icon,
    required double? currentVolume,
    required String firestoreField,
    required bool isEnabled,
    required ValueChanged<bool> onDragStatusChanged,
    required ValueChanged<double> onValueChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isEnabled ? Colors.black87 : Colors.grey),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isEnabled ? Colors.black87 : Colors.grey,
                      ),
                ),
                const Spacer(),
                Text(
                  isEnabled
                      ? '${((currentVolume ?? 0.0) * 100).toInt()}%'
                      : 'Disabled',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isEnabled
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            Slider(
              value: currentVolume ?? 0.0,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: '${((currentVolume ?? 0.0) * 100).toInt()}%',
              activeColor:
                  isEnabled ? Theme.of(context).colorScheme.primary : Colors.grey,
              inactiveColor: isEnabled
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              onChanged: isEnabled
                  ? (value) {
                      onDragStatusChanged(true);
                      onValueChanged(value);
                    }
                  : null,
              onChangeEnd: isEnabled
                  ? (value) {
                      onDragStatusChanged(false);
                      onChangeEnd(value);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.deviceName} - Volume')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _docRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final ringerMode = data['ringerMode'] as String?;
          final volRing = (data['vol_ring'] as num?)?.toDouble();
          final volAlarm = (data['vol_alarm'] as num?)?.toDouble();
          final volMusic = (data['vol_music'] as num?)?.toDouble();

          if (!_isDraggingRing) _ringVolume = volRing;
          if (!_isDraggingAlarm) _alarmVolume = volAlarm;
          if (!_isDraggingMusic) _musicVolume = volMusic;

          final bool isRingEnabled = ringerMode == "normal";

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildRingerModeCard(ringerMode),
              const SizedBox(height: 20),
              _buildVolumeSlider(
                title: 'Ring & Notification Volume',
                icon: Icons.ring_volume_rounded,
                currentVolume: _ringVolume,
                firestoreField: 'setRingVolume',
                isEnabled: isRingEnabled,
                onDragStatusChanged: (isDragging) =>
                    setState(() => _isDraggingRing = isDragging),
                onValueChanged: (value) =>
                    setState(() => _ringVolume = value),
                onChangeEnd: (value) {
                  _docRef.update({
                    'setRingVolume': value,
                    'setNotificationVolume': value,
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildVolumeSlider(
                title: 'Alarm Volume',
                icon: Icons.alarm_rounded,
                currentVolume: _alarmVolume,
                firestoreField: 'setAlarmVolume',
                isEnabled: true,
                onDragStatusChanged: (isDragging) =>
                    setState(() => _isDraggingAlarm = isDragging),
                onValueChanged: (value) =>
                    setState(() => _alarmVolume = value),
                onChangeEnd: (value) => _setVolume('setAlarmVolume', value),
              ),
              const SizedBox(height: 12),
              _buildVolumeSlider(
                title: 'Media Volume (Audio/Video)',
                icon: Icons.music_note_rounded,
                currentVolume: _musicVolume,
                firestoreField: 'setMusicVolume',
                isEnabled: true,
                onDragStatusChanged: (isDragging) =>
                    setState(() => _isDraggingMusic = isDragging),
                onValueChanged: (value) =>
                    setState(() => _musicVolume = value),
                onChangeEnd: (value) => _setVolume('setMusicVolume', value),
              ),
            ],
          );
        },
      ),
    );
  }
}