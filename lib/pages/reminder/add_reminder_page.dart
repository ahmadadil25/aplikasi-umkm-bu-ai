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
  final now = DateTime.now();
  
  // 1. Pilih Tanggal
  final DateTime? date = await showDatePicker(
    context: context,
    initialDate: now, // Default ke hari ini
    firstDate: now,   // Tidak bisa pilih hari sebelum hari ini
    lastDate: now.add(const Duration(days: 365)),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryBlue),
        ),
        child: child!,
      );
    },
  );

  if (!mounted) return; 

  if (date != null) {
    // 2. Pilih Waktu
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(), // Perbaikan: Default ke jam aktual
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primaryBlue),
          ),
          child: child!,
        );
      },
    );

    if (!mounted) return;

    if (time != null) {
      // Gabungkan tanggal dan waktu
      final selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      // 3. Validasi: Jika memilih hari ini, jam tidak boleh sebelum jam sekarang
      if (selected.isBefore(now)) {
        _showSnackBar(
          'Waktu sudah terlewat. Mohon pilih waktu mendatang.', 
          isError: true
        );
        return; // Batalkan pemilihan jika waktu tidak valid
      }

      setState(() {
        _selectedDateTime = selected;
      });
    }
  }
}

  Future<void> _saveReminder() async {
    if (_textController.text.trim().isEmpty) {
      _showSnackBar('Mohon isi catatan pengingat terlebih dahulu.', isError: true);
      return;
    }
    if (_selectedDateTime == null) {
      _showSnackBar('Mohon pilih tanggal dan waktu pengingat.', isError: true);
      return;
    }

    if (_selectedDateTime == null || _selectedDateTime!.isBefore(DateTime.now())) {
    _showSnackBar('Pilih waktu yang akan datang.', isError: true);
    return;
    }

    final reminder = ReminderModel(
      text: _textController.text.trim(),
      reminderDate: _selectedDateTime!.toIso8601String(),
      createdAt: DateTime.now().toIso8601String(),
    );

    int insertedId = await _reminderService.insertReminder(reminder);
    
    await NotificationService.scheduleNotification(
      id: insertedId, 
      title: 'Pengingat C-Kas', 
      body: reminder.text,
      scheduledTime: _selectedDateTime!,
    );

    if (!mounted) return; 

    _textController.clear();
    setState(() {
      _selectedDateTime = null;
    });
    
    FocusScope.of(context).unfocus();
    _loadReminders();
    
    _showSnackBar('Pengingat berhasil dijadwalkan!', isError: false);
  }

  Future<void> _confirmDelete(ReminderModel reminder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pengingat?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus pengingat "${reminder.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _reminderService.deleteReminder(reminder.id!);
      _loadReminders();
      _showSnackBar('Pengingat berhasil dihapus', isError: false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Kelola Reminder', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputCard(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                'Daftar Reminder Anda',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
              ),
            ),
            Expanded(
              child: _reminders.isEmpty ? _buildEmptyState() : _buildReminderList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tambah Pengingat Baru',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Contoh: Bayar supplier beras...',
              prefixIcon: const Icon(Icons.edit_note, color: AppTheme.primaryBlue),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDateTime == null 
                            ? 'Pilih Tanggal & Waktu' 
                            : '${DateHelper.formatToId(_selectedDateTime!.toIso8601String())} - ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: _selectedDateTime == null ? Colors.grey.shade600 : Colors.black87,
                          fontWeight: _selectedDateTime == null ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_selectedDateTime != null)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveReminder,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Simpan Pengingat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final r = _reminders[index];
        final rDate = DateTime.parse(r.reminderDate);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryBlue),
            ),
            title: Text(
              r.text, 
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Padding(
              // PERBAIKAN UTAMA: Typo "EdgeInsets.top: 6.0)" diperbaiki menjadi "EdgeInsets.only(top: 6.0)"
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    DateHelper.formatToId(r.reminderDate),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${rDate.hour.toString().padLeft(2, '0')}:${rDate.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
              onPressed: () => _confirmDelete(r),
              tooltip: 'Hapus Pengingat',
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      // Tambahkan SingleChildScrollView di sini
      child: SingleChildScrollView( 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // Tambahkan ini agar tinggi Column hanya menyesuaikan isinya
          mainAxisSize: MainAxisSize.min, 
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_busy_rounded, size: 64, color: AppTheme.primaryBlue.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum ada pengingat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tambahkan jadwal kegiatan penting\nagar tidak ada yang terlewat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}