class ReminderModel {
  final int? id;
  final String text;
  final String reminderDate;
  final String createdAt;

  ReminderModel({
    this.id,
    required this.text,
    required this.reminderDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'reminder_date': reminderDate,
      'created_at': createdAt,
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      id: map['id'],
      text: map['text'],
      reminderDate: map['reminder_date'],
      createdAt: map['created_at'],
    );
  }
}