import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/custom_text_field.dart';
import '../history/history_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TransactionService _txService = TransactionService();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  int _todaySales = 0;
  int _todayExpense = 0;
  int _todayNet = 0;
  List<Map<String, dynamic>> _weeklyData = [];
  String _selectedType = 'sale';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final today = DateHelper.getTodayIsoPrefix();
    final summary = await _txService.getDailySummary(today);
    final weekly = await _txService.getWeeklySalesData();

    setState(() {
      _todaySales = summary['sales'] ?? 0;
      _todayExpense = summary['expense'] ?? 0;
      _todayNet = summary['net'] ?? 0;
      _weeklyData = weekly;
    });
  }

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    int amount = int.tryParse(amountText) ?? 0;

    if (amount <= 0) return;

    await _txService.insertTransaction(TransactionModel(
      type: _selectedType,
      amount: amount,
      description: _descController.text.isEmpty ? '-' : _descController.text,
      createdAt: DateTime.now().toIso8601String(),
    ));

    _amountController.clear();
    _descController.clear();
    if (mounted) Navigator.pop(context);
    _refreshData();
  }

  void _showInputSheet() {
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
              const Text('Tambah Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Pemasukan')),
                      selected: _selectedType == 'sale',
                      selectedColor: Colors.green[100],
                      onSelected: (val) => setSheetState(() => _selectedType = 'sale'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Pengeluaran')),
                      selected: _selectedType == 'expense',
                      selectedColor: Colors.red[100],
                      onSelected: (val) => setSheetState(() => _selectedType = 'expense'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(controller: _amountController, label: 'Jumlah (Rp)', icon: Icons.money, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              CustomTextField(controller: _descController, label: 'Deskripsi / Catatan', icon: Icons.notes, keyboardType: TextInputType.text),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedType == 'sale' ? Colors.green : Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Simpan Transaksi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('C-Kas Warung Bu Ai', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())).then((_) => _refreshData()),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ringkasan Hari Ini', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 10),
              SummaryCard(sales: _todaySales, expense: _todayExpense, net: _todayNet),
              const SizedBox(height: 30),
              const Text('Tren Penjualan Mingguan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildChartCard(),
              const SizedBox(height: 30),
              _buildInsightCard(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInputSheet,
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Catat Transaksi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      height: 300, // Ukuran grafik ditingkatkan
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
      ),
      child: _weeklyData.length < 2 
        ? const Center(child: Text('Butuh minimal 2 hari data untuk melihat tren.'))
        : LineChart(_chartData()),
    );
  }

  LineChartData _chartData() {
    return LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) {
          if (val.toInt() < _weeklyData.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(_weeklyData[val.toInt()]['date'].toString().substring(8), style: const TextStyle(fontSize: 10)),
            );
          }
          return const Text('');
        })),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: _weeklyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['total'] as int).toDouble())).toList(),
          isCurved: true,
          color: AppTheme.primaryBlue,
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: AppTheme.primaryBlue.withOpacity(0.2)),
        ),
      ],
    );
  }

  Widget _buildInsightCard() {
    int prediksi = (_todaySales * 0.10).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primaryBlue, Colors.blueAccent]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tips C-Kas', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('Estimasi Modal Besok:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(CurrencyFormatter.formatRupiah(prediksi), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
              ],
            ),
          )
        ],
      ),
    );
  }
}