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

  Future<List<Map<String, dynamic>>> getWeeklySalesData() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT substr(created_at, 1, 10) as date, SUM(amount) as total
      FROM transactions
      WHERE type = 'sale'
      GROUP BY date
      ORDER BY date DESC
      LIMIT 7
    ''');
    return maps.reversed.toList();
  }

  Future<void> replaceDailyTransactions(String datePrefix, int newSale, int newExpense) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'created_at LIKE ?', whereArgs: ['$datePrefix%']);
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
    await db.delete('transactions', where: 'created_at LIKE ?', whereArgs: ['$datePrefix%']);
  }
}