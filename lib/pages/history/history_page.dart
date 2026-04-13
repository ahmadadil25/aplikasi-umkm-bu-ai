import 'package:flutter/material.dart';
import '../../core/utils/date_helper.dart';
import '../../services/transaction_service.dart';
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
    
    // Controller untuk edit
    final editSalesCtrl = TextEditingController(text: summary['sales'].toString());
    final editExpenseCtrl = TextEditingController(text: summary['expense'].toString());

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detail ${DateHelper.formatToId(datePrefix)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SummaryCard(
                  sales: summary['sales'] ?? 0,
                  expense: summary['expense'] ?? 0,
                  net: summary['net'] ?? 0,
                ),
                const Divider(),
                const Text('Edit Total Hari Ini:'),
                TextField(
                  controller: editSalesCtrl,
                  decoration: const InputDecoration(labelText: 'Total Penjualan Baru'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: editExpenseCtrl,
                  decoration: const InputDecoration(labelText: 'Total Pengeluaran Baru'),
                  keyboardType: TextInputType.number,
                ),
              ],
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
            ElevatedButton(
              onPressed: () async {
                int newS = int.tryParse(editSalesCtrl.text) ?? 0;
                int newE = int.tryParse(editExpenseCtrl.text) ?? 0;
                await _txService.replaceDailyTransactions(datePrefix, newS, newE);
                if (mounted) {
                  Navigator.pop(context);
                  _loadDates();
                }
              },
              child: const Text('Simpan Perubahan'),
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
                    subtitle: const Text('Ketuk untuk melihat detail atau mengedit'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showDetailDialog(date),
                  ),
                );
              },
            ),
    );
  }
}