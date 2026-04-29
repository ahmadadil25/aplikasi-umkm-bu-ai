import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/custom_text_field.dart';

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
      ),
      body: _dates.isEmpty
          ? const Center(child: Text('Belum ada transaksi.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final date = _dates[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_month, color: AppTheme.primaryBlue), // Ikon Tanggal Ditambahkan
                    ),
                    title: Text(DateHelper.formatToId(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Lihat detail & grafik grafik', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () {
                      // Pindah ke halaman detail, dan refresh saat kembali agar sinkron
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => HistoryDetailPage(datePrefix: date)),
                      ).then((_) => _loadDates());
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// HALAMAN DETAIL BARU (DENGAN GRAFIK & FITUR EDIT)
// ============================================================================

class HistoryDetailPage extends StatefulWidget {
  final String datePrefix;
  const HistoryDetailPage({Key? key, required this.datePrefix}) : super(key: key);

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  final TransactionService _txService = TransactionService();
  Map<String, int> _summary = {'sales': 0, 'expense': 0, 'net': 0};
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetailData();
  }

  Future<void> _loadDetailData() async {
    final summary = await _txService.getDailySummary(widget.datePrefix);
    final transactions = await _txService.getDailyTransactions(widget.datePrefix);
    setState(() {
      _summary = summary;
      _transactions = transactions;
      _isLoading = false;
    });
  }

  void _showEditSheet(TransactionModel tx) {
    final amountController = TextEditingController(text: tx.amount.toString());
    final descController = TextEditingController(text: tx.description);
    String selectedType = tx.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('Edit Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Pemasukan')),
                      selected: selectedType == 'sale',
                      selectedColor: Colors.green[100],
                      onSelected: (val) => setSheetState(() => selectedType = 'sale'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Pengeluaran')),
                      selected: selectedType == 'expense',
                      selectedColor: Colors.red[100],
                      onSelected: (val) => setSheetState(() => selectedType = 'expense'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(controller: amountController, label: 'Jumlah (Rp)', icon: Icons.money, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              CustomTextField(controller: descController, label: 'Deskripsi / Catatan', icon: Icons.notes, keyboardType: TextInputType.text),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final amountText = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                  int amount = int.tryParse(amountText) ?? 0;
                  if (amount <= 0 || tx.id == null) return;

                  // Memanggil fungsi update (pastikan fungsi ini ada di service Anda)
                  await _txService.updateTransaction(
                    tx.id!,
                    TransactionModel(
                      id: tx.id,
                      type: selectedType,
                      amount: amount,
                      description: descController.text.isEmpty ? '-' : descController.text,
                      createdAt: tx.createdAt,
                    ),
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    _loadDetailData(); // Refresh data setelah edit agar sinkron
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedType == 'sale' ? Colors.green : Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data Hari Ini?'),
        content: const Text('Semua transaksi pada hari ini akan dihapus secara permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await _txService.deleteDailyTransactions(widget.datePrefix);
              if (mounted) {
                Navigator.pop(context); // Tutup dialog
                Navigator.pop(context); // Kembali ke halaman utama history
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    int sales = _summary['sales'] ?? 0;
    int expense = _summary['expense'] ?? 0;
    bool hasDataForChart = sales > 0 || expense > 0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(DateHelper.formatToId(widget.datePrefix), style: const TextStyle(fontSize: 18)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            tooltip: 'Hapus Hari Ini',
            onPressed: _confirmDeleteAll,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SummaryCard(sales: sales, expense: expense, net: _summary['net'] ?? 0),
                const SizedBox(height: 30),
                
                // --- GRAFIK PIE CHART ---
                if (hasDataForChart) ...[
                  const Text('Rasio Kas Hari Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          if (sales > 0)
                            PieChartSectionData(
                              color: Colors.green,
                              value: sales.toDouble(),
                              title: 'Masuk\n${((sales / (sales + expense)) * 100).toStringAsFixed(1)}%',
                              radius: 50,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          if (expense > 0)
                            PieChartSectionData(
                              color: Colors.red,
                              value: expense.toDouble(),
                              title: 'Keluar\n${((expense / (sales + expense)) * 100).toStringAsFixed(1)}%',
                              radius: 50,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                const Text('Detail Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                // --- LIST TRANSAKSI DENGAN FITUR EDIT ---
                ..._transactions.map((tx) => Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tx.type == 'sale' ? Colors.green[100] : Colors.red[100],
                      child: Icon(
                        tx.type == 'sale' ? Icons.arrow_downward : Icons.arrow_upward,
                        color: tx.type == 'sale' ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      CurrencyFormatter.formatRupiah(tx.amount),
                      style: TextStyle(color: tx.type == 'sale' ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: () => _showEditSheet(tx), // Panggil sheet edit
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
    );
  }
}
