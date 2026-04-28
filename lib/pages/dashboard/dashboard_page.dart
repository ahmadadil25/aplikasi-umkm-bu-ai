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
  List<Map<String, dynamic>> _monthlyData = []; // Data untuk grafik bulanan
  
  String _selectedType = 'sale';
  bool _isVisible = false; // Untuk animasi fade-in
  bool _isMonthly = false; // Toggle mode grafik (Mingguan/Bulanan)

  @override
  void initState() {
    super.initState();
    _refreshData();
    // Jalankan animasi setelah frame pertama
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  Future<void> _refreshData() async {
    final today = DateHelper.getTodayIsoPrefix();
    final summary = await _txService.getDailySummary(today);
    final weekly = await _txService.getWeeklySalesData();
    
    // Pastikan Anda sudah menambahkan fungsi getMonthlySalesData di transaction_service.dart
    final monthly = await _txService.getMonthlySalesData(); 

    setState(() {
      _todaySales = summary['sales'] ?? 0;
      _todayExpense = summary['expense'] ?? 0;
      _todayNet = summary['net'] ?? 0;
      _weeklyData = weekly;
      _monthlyData = monthly;
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
      backgroundColor: Colors.transparent, // Biar efek rounded luarnya mulus
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
            left: 20, 
            right: 20, 
            top: 20
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Text('Catat Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Pemasukan', style: TextStyle(fontWeight: FontWeight.bold))),
                      selected: _selectedType == 'sale',
                      selectedColor: Colors.green[100],
                      backgroundColor: Colors.grey[100],
                      onSelected: (val) => setSheetState(() => _selectedType = 'sale'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold))),
                      selected: _selectedType == 'expense',
                      selectedColor: Colors.red[100],
                      backgroundColor: Colors.grey[100],
                      onSelected: (val) => setSheetState(() => _selectedType = 'expense'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CustomTextField(controller: _amountController, label: 'Jumlah (Rp)', icon: Icons.money, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              CustomTextField(controller: _descController, label: 'Deskripsi / Catatan', icon: Icons.notes, keyboardType: TextInputType.text),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedType == 'sale' ? Colors.green : Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                  elevation: 0,
                ),
                child: const Text('Simpan Transaksi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Tema Light
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('C-Kas Warung', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(DateHelper.formatToId(DateHelper.getTodayIsoPrefix()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppTheme.primaryBlue, size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())).then((_) => _refreshData()),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryBlue,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 800),
          opacity: _isVisible ? 1.0 : 0.0,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ringkasan Kas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 12),
                SummaryCard(sales: _todaySales, expense: _todayExpense, net: _todayNet),
                
                const SizedBox(height: 25),

                if (_todaySales > 0 || _todayExpense > 0) ...[
                  const Text('Rasio Kas Hari Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  _buildPieChartCard(),
                  const SizedBox(height: 25),
                ],

                const Text('Tren Penjualan (Ketuk untuk ubah)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 12),
                _buildLineChartCard(),

                const SizedBox(height: 25),
                _buildInsightCard(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInputSheet,
        backgroundColor: AppTheme.primaryBlue,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Transaksi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // =======================================================================
  // WIDGET DIAGRAM PIE
  // =======================================================================
  Widget _buildPieChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 30,
                  sections: [
                    PieChartSectionData(
                      color: Colors.greenAccent[700],
                      value: _todaySales.toDouble(),
                      title: '', 
                      radius: 20,
                    ),
                    PieChartSectionData(
                      color: Colors.redAccent[400],
                      value: _todayExpense.toDouble(),
                      title: '',
                      radius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPieLegend('Pemasukan', Colors.green, _todaySales),
                const SizedBox(height: 10),
                _buildPieLegend('Pengeluaran', Colors.red, _todayExpense),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPieLegend(String title, Color color, int amount) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(CurrencyFormatter.formatRupiah(amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  // =======================================================================
  // WIDGET GRAFIK LINE (INTERAKTIF)
  // =======================================================================
  Widget _buildLineChartCard() {
    final currentData = _isMonthly ? _monthlyData : _weeklyData;
    final label = _isMonthly ? 'Tren 30 Hari Terakhir' : 'Tren 7 Hari Terakhir';

    return GestureDetector(
      onTap: () {
        setState(() {
          _isMonthly = !_isMonthly; // Tukar mode saat diklik
        });
      },
      child: Container(
        height: 260,
        padding: const EdgeInsets.fromLTRB(15, 20, 20, 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                Icon(_isMonthly ? Icons.calendar_view_month : Icons.calendar_view_week, size: 18, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: currentData.length < 2
                  ? const Center(child: Text('Data belum cukup untuk grafik', style: TextStyle(fontSize: 12, color: Colors.grey)))
                  : LineChart(_lineChartData(currentData)),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _lineChartData(List<Map<String, dynamic>> data) {
    return LineChartData(
      // --- MENAMPILKAN DETAIL SAAT TITIK DIKLIK/SENTUH ---
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
         tooltipBgColor: AppTheme.primaryBlue, // Warna background tooltip
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final index = barSpot.x.toInt();
              return LineTooltipItem(
                '${data[index]['date']}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                children: [
                  TextSpan(
                    text: CurrencyFormatter.formatRupiah(barSpot.y.toInt()),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: 11),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: 1, // KUNCI UTAMA: Agar label tidak dobel
            getTitlesWidget: (val, meta) {
              int index = val.toInt();
              if (index >= 0 && index < data.length) {
                // Untuk mode bulanan, tampilkan label setiap 5 hari agar tetap rapi
                if (_isMonthly && index % 5 != 0) return const SizedBox(); 
                
                String date = data[index]['date'].toString().substring(8);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['total'] as int).toDouble())).toList(),
          isCurved: true,
          color: AppTheme.primaryBlue,
          barWidth: 4,
          isStrokeCapRound: true,
          // --- MENAMPILKAN TITIK DI SETIAP KOORDINAT ---
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4,
              color: Colors.white,
              strokeWidth: 2,
              strokeColor: AppTheme.primaryBlue,
            ),
          ),
          belowBarData: BarAreaData(show: true, color: AppTheme.primaryBlue.withOpacity(0.1)),
        ),
      ],
    );
  }

  // =======================================================================
  // WIDGET INSIGHT CARD
  // =======================================================================
  Widget _buildInsightCard() {
    int prediksi = (_todaySales * 0.10).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.primaryBlue, Colors.blue[800]!]),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estimasi Modal Besok', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(CurrencyFormatter.formatRupiah(prediksi), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
              ],
            ),
          )
        ],
      ),
    );
  }
}