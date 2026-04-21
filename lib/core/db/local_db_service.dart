import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._init();
  static Database? _database;

  LocalDbService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ckas.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // KUNCI UTAMA: Ubah version menjadi 2 agar SQLite tahu ada pembaruan
    return await openDatabase(
      path,
      version: 2, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Fungsi ini berjalan JIKA database belum pernah dibuat sama sekali (Install Baru)
  Future _createDB(Database db, int version) async {
    // 1. Buat tabel transactions (Sudah termasuk kolom description)
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Buat tabel reminders
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        reminder_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // Fungsi ini berjalan JIKA database versi lama sudah ada, dan kita naikkan version-nya
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Jika user pindah dari versi 1 ke versi 2, tambahkan kolom description ke tabel lama
      await db.execute(
        "ALTER TABLE transactions ADD COLUMN description TEXT DEFAULT '-';"
      );
    }
  }
}