import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/summary_card.dart';
import '../history/history_page.dart';
import '../reminder/add_reminder_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _salesController = TextEditingController();
  final _expenseController = TextEditingController();
  final TransactionService _txService = TransactionService();

  int _todaySales = 0;
  int _todayExpense = 0;
  int _todayNet = 0;

  @override
  void initState() {
    super.initState();
    _loadTodaySummary();
  }

  Future<void> _loadTodaySummary() async {
    final today = DateHelper.getTodayIsoPrefix();
    final summary = await _txService.getDailySummary(today);
    setState(() {
      _todaySales = summary['sales'] ?? 0;
      _todayExpense = summary['expense'] ?? 0;
      _todayNet = summary['net'] ?? 0;
    });
  }

  Future<void> _saveTransaction() async {
    final salesText = _salesController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final expenseText = _expenseController.text.replaceAll(RegExp(r'[^0-9]'), '');

    int salesAmount = int.tryParse(salesText) ?? 0;
    int expenseAmount = int.tryParse(expenseText) ?? 0;

    if (salesAmount == 0 && expenseAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi minimal satu transaksi (Penjualan/Pengeluaran)')),
      );
      return;
    }

    final nowStr = DateTime.now().toIso8601String();

    if (salesAmount > 0) {
      await _txService.insertTransaction(TransactionModel(
        type: 'sale',
        amount: salesAmount,
        createdAt: nowStr,
      ));
    }

    if (expenseAmount > 0) {
      await _txService.insertTransaction(TransactionModel(
        type: 'expense',
        amount: expenseAmount,
        createdAt: nowStr,
      ));
    }

    _salesController.clear();
    _expenseController.clear();
    FocusScope.of(context).unfocus();
    _loadTodaySummary();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaksi berhasil disimpan!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    int prediksiBahanBaku = (_todaySales * 0.10).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('C-Kas Warung Bu Ai', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              ).then((_) => _loadTodaySummary());
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Input Transaksi Hari Ini',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _salesController,
              label: 'Penjualan Hari Ini (Rp)',
              icon: Icons.point_of_sale,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _expenseController,
              label: 'Pengeluaran Hari Ini (Rp)',
              icon: Icons.money_off,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Simpan Transaksi', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Ringkasan Hari Ini',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SummaryCard(sales: _todaySales, expense: _todayExpense, net: _todayNet),
            const SizedBox(height: 16),

            // Fitur Prediksi Sederhana
            Card(
              color: Colors.yellow.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Prediksi Modal Bahan Baku Besok (10%):', style: TextStyle(fontSize: 12)),
                          Text(
                            CurrencyFormatter.formatRupiah(prediksiBahanBaku),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddReminderPage()),
                );
              },
              icon: const Icon(Icons.alarm_add),
              label: const Text('Kelola Pengingat / Reminder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}