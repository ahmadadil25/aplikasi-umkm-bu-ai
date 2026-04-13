import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helper.dart';
import '../../models/reminder_model.dart';
import '../../services/reminder_service.dart';
import '../../services/notification_service.dart';

class AddReminderPage extends StatefulWidget {
  const AddReminderPage({Key? key}) : super(key: key);

  @override
  State<AddReminderPage> createState() => _AddReminderPageState();
}

class _AddReminderPageState extends State<AddReminderPage> {
  final _textController = TextEditingController();
  final ReminderService _reminderService = ReminderService();
  List<ReminderModel> _reminders = [];
  
  DateTime? _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final reminders = await _reminderService.getUpcomingReminders();
    setState(() {
      _reminders = reminders;
    });
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 8, minute: 0),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveReminder() async {
    if (_textController.text.isEmpty || _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi catatan dan pilih waktu pengingat!')),
      );
      return;
    }

    final reminder = ReminderModel(
      text: _textController.text,
      reminderDate: _selectedDateTime!.toIso8601String(),
      createdAt: DateTime.now().toIso8601String(),
    );

    int insertedId = await _reminderService.insertReminder(reminder);
    
    // Jadwalkan Notifikasi Sesuai Waktu yang Dipilih!
    await NotificationService.scheduleNotification(
      id: insertedId, 
      title: 'Pengingat C-Kas', 
      body: _textController.text,
      scheduledTime: _selectedDateTime!,
    );

    _textController.clear();
    setState(() {
      _selectedDateTime = null;
    });
    FocusScope.of(context).unfocus();
    _loadReminders();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder dan Notifikasi berhasil dijadwalkan!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Reminder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Catatan Pengingat Baru',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateTime,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDateTime == null 
                        ? 'Pilih Waktu Notifikasi' 
                        : 'Waktu: ${DateHelper.formatToId(_selectedDateTime!.toIso8601String())} ${_selectedDateTime!.hour}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveReminder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  child: const Text('Simpan'),
                )
              ],
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Daftar Reminder:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _reminders.length,
                itemBuilder: (context, index) {
                  final r = _reminders[index];
                  final rDate = DateTime.parse(r.reminderDate);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active, color: Colors.orange),
                      title: Text(r.text),
                      subtitle: Text('${DateHelper.formatToId(r.reminderDate)} jam ${rDate.hour}:${rDate.minute.toString().padLeft(2, '0')}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _reminderService.deleteReminder(r.id!);
                          _loadReminders();
                        },
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}