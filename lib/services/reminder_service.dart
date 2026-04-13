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
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      orderBy: 'reminder_date ASC',
    );
    return maps.map((e) => ReminderModel.fromMap(e)).toList();
  }

  Future<void> deleteReminder(int id) async {
    final db = await dbService.database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }
}