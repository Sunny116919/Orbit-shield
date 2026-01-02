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

  double _ringVolume = 0.0;
  double _alarmVolume = 0.0;
  double _musicVolume = 0.0;

  double? _serverRingVol;
  double? _serverAlarmVol;
  double? _serverMusicVol;

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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Select Ringer Mode',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildModeOption(
                  ctx,
                  'Normal',
                  Icons.volume_up_rounded,
                  'normal',
                  Colors.blue,
                ),
                _buildModeOption(
                  ctx,
                  'Vibrate',
                  Icons.vibration_rounded,
                  'vibrate',
                  Colors.orange,
                ),
                _buildModeOption(
                  ctx,
                  'Silent',
                  Icons.volume_off_rounded,
                  'silent',
                  Colors.red,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeOption(
    BuildContext ctx,
    String label,
    IconData icon,
    String value,
    Color color,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.grey,
      ),
      onTap: () {
        _docRef.update({'setRingerMode': value});
        Navigator.pop(ctx);
      },
    );
  }

  void _setVolume(String fieldName, double value) {
    _docRef.update({fieldName: value});
  }

  Widget _buildRingerModeCard(String? ringerMode) {
    IconData icon;
    String text;
    Color color;
    String description;

    switch (ringerMode) {
      case "normal":
        icon = Icons.volume_up_rounded;
        text = "Normal Mode";
        description = "Sound and vibration enabled";
        color = Colors.blue;
        break;
      case "vibrate":
        icon = Icons.vibration_rounded;
        text = "Vibrate Mode";
        description = "Device will vibrate for calls";
        color = Colors.orange;
        break;
      case "silent":
        icon = Icons.volume_off_rounded;
        text = "Silent Mode";
        description = "Sound and vibration disabled";
        color = Colors.red;
        break;
      default:
        icon = Icons.sync_problem_rounded;
        text = "Loading...";
        description = "Fetching status";
        color = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: ringerMode == null ? null : _showRingerModePicker,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    required Color activeColor,
  }) {
    final int percentage = ((currentVolume ?? 0.0) * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? activeColor.withOpacity(0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? activeColor : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isEnabled ? '$percentage%' : 'Off',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isEnabled ? activeColor : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: isEnabled ? activeColor : Colors.grey[300],
              inactiveTrackColor: isEnabled
                  ? activeColor.withOpacity(0.1)
                  : Colors.grey[200],
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
                elevation: 4,
              ),
              overlayColor: activeColor.withOpacity(0.1),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              disabledThumbColor: Colors.grey[400],
            ),
            child: Slider(
              value: currentVolume ?? 0.0,
              min: 0.0,
              max: 1.0,
              divisions: 100,
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Text(
              'Sound Control',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.deviceName,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _docRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final ringerMode = data['ringerMode'] as String?;

          final double newVolRing =
              (data['vol_ring'] as num?)?.toDouble() ?? 0.0;
          final double newVolAlarm =
              (data['vol_alarm'] as num?)?.toDouble() ?? 0.0;
          final double newVolMusic =
              (data['vol_music'] as num?)?.toDouble() ?? 0.0;

          if (newVolRing != _serverRingVol) {
            _serverRingVol = newVolRing;
            if (!_isDraggingRing) _ringVolume = newVolRing;
          }

          if (newVolAlarm != _serverAlarmVol) {
            _serverAlarmVol = newVolAlarm;
            if (!_isDraggingAlarm) _alarmVolume = newVolAlarm;
          }

          if (newVolMusic != _serverMusicVol) {
            _serverMusicVol = newVolMusic;
            if (!_isDraggingMusic) _musicVolume = newVolMusic;
          }

          final bool isRingEnabled = ringerMode == "normal";

          return ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              _buildRingerModeCard(ringerMode),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  'VOLUME LEVELS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _buildVolumeSlider(
                title: 'Ring & Alerts',
                icon: Icons.notifications_active_rounded,
                currentVolume: _ringVolume,
                firestoreField: 'setRingVolume',
                isEnabled: isRingEnabled,
                activeColor: const Color(0xFF6366F1),
                onDragStatusChanged: (isDragging) =>
                    setState(() => _isDraggingRing = isDragging),
                onValueChanged: (value) => setState(() => _ringVolume = value),
                onChangeEnd: (value) => _setVolume(
                  'setRingVolume',
                  value,
                ), 
              ),
              const SizedBox(height: 16),
              _buildVolumeSlider(
                title: 'Alarms',
                icon: Icons.alarm_rounded,
                currentVolume: _alarmVolume,
                firestoreField: 'setAlarmVolume',
                isEnabled: true,
                activeColor: const Color(0xFFEC4899),
                onDragStatusChanged: (isDragging) =>
                    setState(() => _isDraggingAlarm = isDragging),
                onValueChanged: (value) => setState(() => _alarmVolume = value),
                onChangeEnd: (value) => _setVolume('setAlarmVolume', value),
              ),
              const SizedBox(height: 16),
              _buildVolumeSlider(
                title: 'Media & Music',
                icon: Icons.music_note_rounded,
                currentVolume: _musicVolume,
                firestoreField: 'setMusicVolume',
                isEnabled: true,
                activeColor: const Color(0xFF10B981),
                onDragStatusChanged: (isDragging) =>
                    setState(() => _isDraggingMusic = isDragging),
                onValueChanged: (value) => setState(() => _musicVolume = value),
                onChangeEnd: (value) => _setVolume('setMusicVolume', value),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
