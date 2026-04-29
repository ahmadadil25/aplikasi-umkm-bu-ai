import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/custom_text_field.dart';
import '../ai_chat/ai_chat_page.dart';
import '../history/history_page.dart';
import '../reminder/add_reminder_page.dart';

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
  List<Map<String, dynamic>> _monthlyData = []; 
  List<TransactionModel> _recentTransactions = []; // Data transaksi terbaru
  
  String _selectedType = 'sale';
  bool _isVisible = false; 
  bool _isMonthly = false; 

  @override
  void initState() {
    super.initState();
    _refreshData();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  Future<void> _refreshData() async {
    final today = DateHelper.getTodayIsoPrefix();
    final summary = await _txService.getDailySummary(today);
    final weekly = await _txService.getWeeklySalesData();
    final monthly = await _txService.getMonthlySalesData(); 
    final recent = await _txService.getRecentTransactions(3); // Ambil 3 terbaru

    setState(() {
      _todaySales = summary['sales'] ?? 0;
      _todayExpense = summary['expense'] ?? 0;
      _todayNet = summary['net'] ?? 0;
      _weeklyData = weekly;
      _monthlyData = monthly;
      _recentTransactions = recent;
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saleSelectedColor =
        isDark ? Colors.green.withOpacity(0.28) : Colors.green[100];
    final expenseSelectedColor =
        isDark ? Colors.red.withOpacity(0.28) : Colors.red[100];
    final chipTextColor = isDark ? colorScheme.onSurface : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                'Catat Transaksi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          'Pemasukan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: chipTextColor,
                          ),
                        ),
                      ),
                      selected: _selectedType == 'sale',
                      selectedColor: saleSelectedColor,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      checkmarkColor: isDark ? Colors.greenAccent : Colors.green,
                      onSelected: (val) => setSheetState(() => _selectedType = 'sale'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          'Pengeluaran',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: chipTextColor,
                          ),
                        ),
                      ),
                      selected: _selectedType == 'expense',
                      selectedColor: expenseSelectedColor,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      checkmarkColor: isDark ? Colors.redAccent : Colors.red,
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
    final colorScheme = Theme.of(context).colorScheme;
    final sectionStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'C-Kas Warung',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              DateHelper.formatToId(DateHelper.getTodayIsoPrefix()),
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_rounded, color: AppTheme.primaryBlue, size: 26),
            tooltip: 'AI Kas',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_rounded, color: AppTheme.primaryBlue, size: 28),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddReminderPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppTheme.primaryBlue, size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())).then((_) => _refreshData()),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: AppTheme.primaryBlue, size: 26),
            tooltip: 'Pengaturan Tema',
            onPressed: _showThemeSheet,
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
                Text('Ringkasan Kas', style: sectionStyle),
                const SizedBox(height: 12),
                
                Column(
                  children: [
                    SummaryCard(sales: _todaySales, expense: _todayExpense, net: _todayNet),
                    const SizedBox(height: 8), 
                    _buildInsightCard(),
                  ],
                ),
                
                const SizedBox(height: 25),

                if (_todaySales > 0 || _todayExpense > 0) ...[
                  Text('Rasio Kas Hari Ini', style: sectionStyle),
                  const SizedBox(height: 12),
                  _buildPieChartCard(),
                  const SizedBox(height: 25),
                ],

                // --- BAGIAN TRANSAKSI TERAKHIR DITAMBAHKAN ---
                if (_recentTransactions.isNotEmpty) ...[
                  Text('Transaksi Terakhir', style: sectionStyle),
                  const SizedBox(height: 12),
                  _buildRecentTransactions(),
                  const SizedBox(height: 25),
                ],

                Text('Tren Penjualan (Ketuk untuk ubah)', style: sectionStyle),
                const SizedBox(height: 12),
                _buildLineChartCard(),

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

  void _showThemeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeService.themeMode,
        builder: (context, currentMode, _) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Text(
                  'Tampilan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildThemeOption(
                  title: 'Sesuai Sistem',
                  subtitle: 'Ikuti pengaturan tema perangkat',
                  icon: Icons.phone_android_rounded,
                  mode: ThemeMode.system,
                  currentMode: currentMode,
                ),
                _buildThemeOption(
                  title: 'Light Mode',
                  subtitle: 'Tampilan terang',
                  icon: Icons.light_mode_rounded,
                  mode: ThemeMode.light,
                  currentMode: currentMode,
                ),
                _buildThemeOption(
                  title: 'Dark Mode',
                  subtitle: 'Tampilan gelap',
                  icon: Icons.dark_mode_rounded,
                  mode: ThemeMode.dark,
                  currentMode: currentMode,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode currentMode,
  }) {
    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: currentMode,
      activeColor: AppTheme.primaryBlue,
      secondary: Icon(icon, color: AppTheme.primaryBlue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      onChanged: (value) async {
        if (value == null) return;
        await ThemeService.setThemeMode(value);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  // WIDGET TRANSAKSI TERAKHIR (3 DATA)
  Widget _buildRecentTransactions() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: _recentTransactions.map((tx) => Card(
        elevation: 0.5,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: tx.type == 'sale'
                ? Colors.green.withOpacity(0.14)
                : Colors.red.withOpacity(0.14),
            child: Icon(
              tx.type == 'sale' ? Icons.arrow_downward : Icons.arrow_upward,
              color: tx.type == 'sale' ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          title: Text(
            tx.description,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            CurrencyFormatter.formatRupiah(tx.amount),
            style: TextStyle(
              color: tx.type == 'sale' ? Colors.green[700] : Colors.red[700], 
              fontWeight: FontWeight.bold,
              fontSize: 13
            ),
          ),
          trailing: Text(
            tx.createdAt.substring(11, 16), // Menampilkan jam:menit
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildPieChartCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
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
                    PieChartSectionData(color: Colors.greenAccent[700], value: _todaySales.toDouble(), title: '', radius: 20),
                    PieChartSectionData(color: Colors.redAccent[400], value: _todayExpense.toDouble(), title: '', radius: 20),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            Text(
              CurrencyFormatter.formatRupiah(amount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildLineChartCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final currentData = _isMonthly ? _monthlyData : _weeklyData;
    final label = _isMonthly ? 'Tren 30 Hari Terakhir' : 'Tren 7 Hari Terakhir';

    return GestureDetector(
      onTap: () {
        setState(() { _isMonthly = !_isMonthly; });
      },
      child: Container(
        height: 260,
        padding: const EdgeInsets.fromLTRB(15, 20, 20, 15),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  _isMonthly ? Icons.calendar_view_month : Icons.calendar_view_week,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: currentData.length < 2
                  ? Center(
                      child: Text(
                        'Data belum cukup untuk grafik',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : LineChart(_lineChartData(currentData)),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _lineChartData(List<Map<String, dynamic>> data) {
    final colorScheme = Theme.of(context).colorScheme;

    return LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
         tooltipBgColor: AppTheme.primaryBlue, 
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
            interval: 1, 
            getTitlesWidget: (val, meta) {
              int index = val.toInt();
              if (index >= 0 && index < data.length) {
                if (_isMonthly && index % 5 != 0) return const SizedBox(); 
                String date = data[index]['date'].toString().substring(8);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    date,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
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
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: AppTheme.primaryBlue,
            ),
          ),
          belowBarData: BarAreaData(show: true, color: AppTheme.primaryBlue.withOpacity(0.1)),
        ),
      ],
    );
  }

  Widget _buildInsightCard() {
    int prediksi = (_todaySales * 0.10).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20), top: Radius.circular(8)),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.primaryBlue, Colors.blue[800]!]),
        boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 24),
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
