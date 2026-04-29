import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import '../../services/reminder_service.dart';
import '../../services/notification_service.dart';
import '../../core/theme/app_theme.dart'; // Sesuaikan path

class AlarmRingPage extends StatefulWidget {
  final AlarmSettings alarmSettings;

  const AlarmRingPage({Key? key, required this.alarmSettings}) : super(key: key);

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  final ReminderService _reminderService = ReminderService();

  Future<void> _stopAlarm() async {
    // Matikan alarm
    await Alarm.stop(widget.alarmSettings.id);
    if (!mounted) return;
    Navigator.pop(context); // Tutup halaman
  }

  Future<void> _snoozeAlarm() async {
    // 1. Matikan alarm saat ini
    await Alarm.stop(widget.alarmSettings.id);

    // 2. Hitung waktu snooze (+5 Menit)
    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));

    // 3. Update database
    await _reminderService.updateReminderDate(
      widget.alarmSettings.id, 
      snoozeTime.toIso8601String()
    );

    // 4. Jadwalkan ulang alarm
    await NotificationService.scheduleNotification(
      id: widget.alarmSettings.id,
      title: widget.alarmSettings.notificationSettings.title,
      body: widget.alarmSettings.notificationSettings.body,
      scheduledTime: snoozeTime,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarm ditunda 5 menit')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ikon Lonceng Bergetar/Animasi
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  size: 100,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                widget.alarmSettings.notificationSettings.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                widget.alarmSettings.notificationSettings.body,
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 64),
              
              // Tombol Matikan (Primary Action)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _stopAlarm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'MATIKAN ALARM',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Tombol Snooze (Secondary Action)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: _snoozeAlarm,
                  icon: const Icon(Icons.snooze_rounded),
                  label: const Text(
                    'Tunda 5 Menit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : AppTheme.primaryBlue,
                    side: BorderSide(
                      color: isDark ? Colors.white30 : AppTheme.primaryBlue,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}