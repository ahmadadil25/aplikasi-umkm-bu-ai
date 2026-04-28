import '../core/db/local_db_service.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final dbService = LocalDbService.instance;

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await dbService.database;
    return await db.insert('transactions', transaction.toMap());
  }

  // Ambil semua transaksi di hari tertentu (untuk detail di History)
  Future<List<TransactionModel>> getDailyTransactions(String datePrefix) async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'created_at LIKE ?',
      whereArgs: ['$datePrefix%'],
      orderBy: 'created_at DESC',
    );
    return maps.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<Map<String, int>> getDailySummary(String datePrefix) async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'created_at LIKE ?',
      whereArgs: ['$datePrefix%'],
    );

    int totalSales = 0;
    int totalExpense = 0;

    for (var map in maps) {
      if (map['type'] == 'sale') {
        totalSales += map['amount'] as int;
      } else if (map['type'] == 'expense') {
        totalExpense += map['amount'] as int;
      }
    }

    return {
      'sales': totalSales,
      'expense': totalExpense,
      'net': totalSales - totalExpense,
    };
  }

  Future<List<String>> getTransactionDates() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT substr(created_at, 1, 10) as date 
      FROM transactions 
      ORDER BY date DESC
    ''');
    return maps.map((e) => e['date'] as String).toList();
  }

  Future<void> replaceDailyTransactions(
      String datePrefix, int newSale, int newExpense) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      await txn.delete('transactions',
          where: 'created_at LIKE ?', whereArgs: ['$datePrefix%']);
      if (newSale > 0) {
        await txn.insert('transactions', {
          'type': 'sale',
          'amount': newSale,
          'description': 'Update harian',
          'created_at': '${datePrefix}T12:00:00'
        });
      }
      if (newExpense > 0) {
        await txn.insert('transactions', {
          'type': 'expense',
          'amount': newExpense,
          'description': 'Update harian',
          'created_at': '${datePrefix}T12:00:00'
        });
      }
    });
  }

  Future<void> deleteDailyTransactions(String datePrefix) async {
    final db = await dbService.database;
    await db.delete('transactions',
        where: 'created_at LIKE ?', whereArgs: ['$datePrefix%']);
  }

  // Tambahkan di dalam class TransactionService Anda
  Future<int> updateTransaction(int id, TransactionModel updatedTx) async {
    final db = await LocalDbService.instance.database;
    return await db.update(
      'transactions',
      {
        'type': updatedTx.type,
        'amount': updatedTx.amount,
        'description': updatedTx.description,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// Tambahkan di dalam class TransactionService
  // Fungsi untuk 7 Hari Terakhir
  Future<List<Map<String, dynamic>>> getWeeklySalesData() async {
    final db = await LocalDbService.instance.database;
    
    // Hitung tanggal batas (7 hari yang lalu dari hari ini)
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

    // Ambil data yang tanggalnya lebih dari/sama dengan 7 hari yang lalu
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT SUBSTR(created_at, 1, 10) as date, SUM(amount) as total
      FROM transactions
      WHERE type = 'sale' AND created_at >= ?
      GROUP BY date
      ORDER BY date ASC
    ''', [sevenDaysAgo]);
    
    return result;
  }

  // Fungsi untuk 30 Hari Terakhir (Bulanan)
  Future<List<Map<String, dynamic>>> getMonthlySalesData() async {
    final db = await LocalDbService.instance.database;
    
    // Hitung tanggal batas (30 hari yang lalu)
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT SUBSTR(created_at, 1, 10) as date, SUM(amount) as total
      FROM transactions
      WHERE type = 'sale' AND created_at >= ?
      GROUP BY date
      ORDER BY date ASC
    ''', [thirtyDaysAgo]);
    
    return result;
  }

  // Tambahkan di dalam class TransactionService
Future<List<TransactionModel>> getRecentTransactions(int limit) async {
  final db = await LocalDbService.instance.database;
  final List<Map<String, dynamic>> maps = await db.query(
    'transactions',
    orderBy: 'created_at DESC',
    limit: limit,
  );
  
  return List.generate(maps.length, (i) {
    return TransactionModel(
      id: maps[i]['id'],
      type: maps[i]['type'],
      amount: maps[i]['amount'],
      description: maps[i]['description'],
      createdAt: maps[i]['created_at'],
    );
  });
}
}
