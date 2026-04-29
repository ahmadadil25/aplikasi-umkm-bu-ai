import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_input_formatter.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDates();
  }

  Future<void> _loadDates() async {
    setState(() => _isLoading = true);
    final dates = await _txService.getTransactionDates();
    setState(() {
      _dates = dates;
      _isLoading = false;
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
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dates.isEmpty
              ? _buildEmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        'Tercatat ${_dates.length} hari transaksi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _dates.length,
                        itemBuilder: (context, index) {
                          final date = _dates[index];
                          return _buildHistoryCard(context, date, colorScheme);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada transaksi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Transaksi yang Anda catat\nakan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, String date, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      color: colorScheme.surfaceContainerLowest,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HistoryDetailPage(datePrefix: date)),
          ).then((_) => _loadDates());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateHelper.formatToId(date),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Klik untuk lihat detail & grafik',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HALAMAN DETAIL
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
    final amountController = TextEditingController(
      text: NumberFormat.decimalPattern('id').format(tx.amount),
    );
    final descController = TextEditingController(text: tx.description);
    String selectedType = tx.type;

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saleSelectedColor = isDark ? Colors.green.withValues(alpha: 0.28) : Colors.green[100];
    final expenseSelectedColor = isDark ? Colors.red.withValues(alpha: 0.28) : Colors.red[100];
    final chipTextColor = isDark ? colorScheme.onSurface : Colors.grey[700];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (innerContext, setSheetState) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(innerContext).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Text(
                  'Edit Transaksi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),

                // Choice Chips
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        label: Center(
                          child: Text(
                            'Pemasukan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selectedType == 'sale' ? Colors.green[800] : chipTextColor,
                            ),
                          ),
                        ),
                        selected: selectedType == 'sale',
                        selectedColor: saleSelectedColor,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        checkmarkColor: Colors.green[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) => setSheetState(() => selectedType = 'sale'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        label: Center(
                          child: Text(
                            'Pengeluaran',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selectedType == 'expense' ? Colors.red[800] : chipTextColor,
                            ),
                          ),
                        ),
                        selected: selectedType == 'expense',
                        selectedColor: expenseSelectedColor,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        checkmarkColor: Colors.red[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) => setSheetState(() => selectedType = 'expense'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  controller: amountController,
                  label: 'Jumlah Uang (Rp)',
                  icon: Icons.payments_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: descController,
                  label: 'Catatan (Cth: Beli Telur)',
                  icon: Icons.edit_note_rounded,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amountText = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                      int amount = int.tryParse(amountText) ?? 0;
                      if (amount <= 0 || tx.id == null) return;

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

                      if (!innerContext.mounted) return;
                      Navigator.pop(innerContext);

                      if (!mounted) return;
                      _loadDetailData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedType == 'sale' ? Colors.green : Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Hapus Data?'),
          ],
        ),
        content: const Text(
          'Semua transaksi pada hari ini akan dihapus secara permanen dan tidak dapat dikembalikan.',
          style: TextStyle(fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Batal', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              await _txService.deleteDailyTransactions(widget.datePrefix);

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Ya, Hapus'),
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
        title: Text(DateHelper.formatToId(widget.datePrefix), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
            tooltip: 'Hapus Hari Ini',
            onPressed: _confirmDeleteAll,
          ),
          const SizedBox(width: 8),
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
                  const SizedBox(height: 32),

                  // --- GRAFIK PIE CHART ---
                  if (hasDataForChart) ...[
                    const Text('Rasio Keuangan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 4,
                                centerSpaceRadius: 45,
                                sections: [
                                  if (sales > 0)
                                    PieChartSectionData(
                                      color: Colors.green,
                                      value: sales.toDouble(),
                                      title: '${((sales / (sales + expense)) * 100).toStringAsFixed(0)}%',
                                      radius: 40,
                                      titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  if (expense > 0)
                                    PieChartSectionData(
                                      color: Colors.red,
                                      value: expense.toDouble(),
                                      title: '${((expense / (sales + expense)) * 100).toStringAsFixed(0)}%',
                                      radius: 40,
                                      titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Legend untuk mempermudah baca grafik
                          Wrap(
                            spacing: 24,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildLegendItem(Colors.green, 'Pemasukan'),
                              _buildLegendItem(Colors.red, 'Pengeluaran'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  const Text('Daftar Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // --- LIST TRANSAKSI DENGAN FITUR EDIT ---
                  if (_transactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          'Tidak ada detail transaksi.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    )
                  else
                    ..._transactions.map((tx) {
                      final isSale = tx.type == 'sale';
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        color: colorScheme.surfaceContainerLowest,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: isSale ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isSale ? Icons.south_west_rounded : Icons.north_east_rounded,
                              color: isSale ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            tx.description,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              CurrencyFormatter.formatRupiah(tx.amount),
                              style: TextStyle(
                                color: isSale ? Colors.green[700] : Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          trailing: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                            ),
                            tooltip: 'Edit Transaksi',
                            onPressed: () => _showEditSheet(tx),
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}