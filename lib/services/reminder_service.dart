import '../core/db/local_db_service.dart';
import '../models/reminder_model.dart';

class ReminderService {
  final dbService = LocalDbService.instance;

  Future<int> insertReminder(ReminderModel reminder) async {
    final db = await dbService.database;
    return await db.insert('reminders', reminder.toMap());
  }

  Future<List<ReminderModel>> getUpcomingReminders() async {
    final db = await dbService.database;
    final now = DateTime.now().toIso8601String();
    
    // Hanya ambil reminder yang waktunya >= sekarang
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'reminder_date >= ?',
      whereArgs: [now],
      orderBy: 'reminder_date ASC',
    );
    return maps.map((e) => ReminderModel.fromMap(e)).toList();
  }

  Future<List<ReminderModel>> getAllReminders() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      orderBy: 'reminder_date DESC', // Yang terbaru di atas
    );
    return maps.map((e) => ReminderModel.fromMap(e)).toList();
  }

  Future<void> deleteReminder(int id) async {
    final db = await dbService.database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // Fungsi baru untuk Snooze
  Future<void> updateReminderDate(int id, String newDate) async {
    final db = await dbService.database;
    await db.update(
      'reminders', 
      {'reminder_date': newDate}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}