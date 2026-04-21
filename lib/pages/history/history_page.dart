import 'package:flutter/material.dart';
import '../../core/utils/date_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../widgets/summary_card.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TransactionService _txService = TransactionService();
  List<String> _dates = [];

  @override
  void initState() {
    super.initState();
    _loadDates();
  }

  Future<void> _loadDates() async {
    final dates = await _txService.getTransactionDates();
    setState(() {
      _dates = dates;
    });
  }

  void _showDetailDialog(String datePrefix) async {
    final summary = await _txService.getDailySummary(datePrefix);
    final transactions = await _txService.getDailyTransactions(datePrefix); // Ambil detail
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detail ${DateHelper.formatToId(datePrefix)}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SummaryCard(
                    sales: summary['sales'] ?? 0,
                    expense: summary['expense'] ?? 0,
                    net: summary['net'] ?? 0,
                  ),
                  const Divider(height: 30, thickness: 1),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Daftar Transaksi:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  // List Transaksi Detail dengan Deskripsi
                  ...transactions.map((tx) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      tx.type == 'sale' ? Icons.arrow_downward : Icons.arrow_upward,
                      color: tx.type == 'sale' ? Colors.green : Colors.red,
                    ),
                    title: Text(tx.description, style: const TextStyle(fontSize: 14)), // Tampilkan Deskripsi
                    subtitle: Text(CurrencyFormatter.formatRupiah(tx.amount)),
                    trailing: Text(
                      tx.type == 'sale' ? '+In' : '-Out',
                      style: TextStyle(color: tx.type == 'sale' ? Colors.green : Colors.red, fontSize: 10),
                    ),
                  )).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _txService.deleteDailyTransactions(datePrefix);
                if (mounted) {
                  Navigator.pop(context);
                  _loadDates();
                }
              },
              child: const Text('Hapus Data Hari Ini', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History Transaksi')),
      body: _dates.isEmpty
          ? const Center(child: Text('Belum ada transaksi.'))
          : ListView.builder(
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final date = _dates[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(DateHelper.formatToId(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Ketuk untuk melihat detail transaksi'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showDetailDialog(date),
                  ),
                );
              },
            ),
    );
  }
}