import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/utils/currency_input_formatter.dart';
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
  List<TransactionModel> _recentTransactions = [];
  int _totalTransactionDays = 0;

  String _selectedType = 'sale';
  bool _isVisible = false;
  bool _isMonthly = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
    // Efek animasi masuk yang halus
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  Future<void> _refreshData() async {
    // Bersihkan data transaksi yang lebih lama dari 3 bulan secara otomatis
    await _txService.deleteOldTransactions();

    final today = DateHelper.getTodayIsoPrefix();
    final summary = await _txService.getDailySummary(today);
    final weekly = await _txService.getWeeklySalesData();
    final monthly = await _txService.getMonthlySalesData();
    final recent = await _txService.getRecentTransactions(3);
    final totalDays = await _txService.getTotalTransactionDays();

    setState(() {
      _todaySales = summary['sales'] ?? 0;
      _todayExpense = summary['expense'] ?? 0;
      _todayNet = summary['net'] ?? 0;
      _weeklyData = weekly;
      _monthlyData = monthly;
      _recentTransactions = recent;
      _totalTransactionDays = totalDays;
    });
  }

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    int amount = int.tryParse(amountText) ?? 0;

    // Validasi sederhana agar pengguna tidak menyimpan data kosong
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Masukkan jumlah nominal yang benar ya, Bu.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    await _txService.insertTransaction(TransactionModel(
      type: _selectedType,
      amount: amount,
      description: _descController.text.isEmpty ? '-' : _descController.text,
      createdAt: DateTime.now().toIso8601String(),
    ));

    _amountController.clear();
    _descController.clear();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _selectedType == 'sale'
              ? 'Pemasukan berhasil dicatat!'
              : 'Pengeluaran berhasil dicatat!',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
    _refreshData();
  }

  // Modifikasi agar bisa menerima tipe default saat dibuka dari tombol Aksi Cepat
  void _showInputSheet({String defaultType = 'sale'}) {
    setState(() {
      _selectedType = defaultType;
    });

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saleSelectedColor =
        isDark ? Colors.green.withValues(alpha: 0.28) : Colors.green[100];
    final expenseSelectedColor =
        isDark ? Colors.red.withValues(alpha: 0.28) : Colors.red[100];
    final chipTextColor = isDark ? colorScheme.onSurface : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 20),
          child: ListView(
            shrinkWrap: true,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                'Catat Buku Kas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Pilihan Pemasukan / Pengeluaran
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
                            color: _selectedType == 'sale'
                                ? Colors.green[800]
                                : chipTextColor,
                          ),
                        ),
                      ),
                      selected: _selectedType == 'sale',
                      selectedColor: saleSelectedColor,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      checkmarkColor: Colors.green[700],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) =>
                          setSheetState(() => _selectedType = 'sale'),
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
                            color: _selectedType == 'expense'
                                ? Colors.red[800]
                                : chipTextColor,
                          ),
                        ),
                      ),
                      selected: _selectedType == 'expense',
                      selectedColor: expenseSelectedColor,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      checkmarkColor: Colors.red[700],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) =>
                          setSheetState(() => _selectedType = 'expense'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CustomTextField(
                controller: _amountController,
                label: 'Jumlah Uang (Rp)',
                icon: Icons.payments_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  CurrencyInputFormatter(),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                  controller: _descController,
                  label: 'Catatan (Cth: Beli Telur)',
                  icon: Icons.edit_note_rounded,
                  keyboardType: TextInputType.text),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedType == 'sale'
                        ? Colors.green
                        : Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  child: Text(
                      _selectedType == 'sale'
                          ? 'Simpan Pemasukan'
                          : 'Simpan Pengeluaran',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
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
      color: colorScheme.onSurface,
      letterSpacing: 0.2,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // Bar atas dibersihkan agar tidak menumpuk di layar HP kecil
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        toolbarHeight: 70,
        centerTitle: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, Bu Ai 👋',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'C-Kas • ${DateHelper.formatToId(DateHelper.getTodayIsoPrefix())}',
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.smart_toy_rounded,
                  color: AppTheme.primaryBlue, size: 24),
              tooltip: 'Asisten AI',
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AiChatPage()));
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: colorScheme.onSurfaceVariant, size: 26),
            tooltip: 'Pengaturan',
            onPressed: _showThemeSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppTheme.primaryBlue,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: _isVisible ? 1.0 : 0.0,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BAGIAN 1: RINGKASAN KAS ---
                  Column(
                    children: [
                      SummaryCard(
                          sales: _todaySales,
                          expense: _todayExpense,
                          net: _todayNet),
                      _buildInsightCard(),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // --- BAGIAN 2: MENU AKSI CEPAT ---
                  Text('Aksi Cepat', style: sectionStyle),
                  const SizedBox(height: 16),
                  _buildQuickActionsRow(),

                  const SizedBox(height: 32),

                  // --- BAGIAN 3: TRANSAKSI TERAKHIR ---
                  Text('Transaksi Terakhir', style: sectionStyle),
                  const SizedBox(height: 12),
                  _buildRecentTransactions(),

                  const SizedBox(height: 32),

                  // --- BAGIAN 4: RASIO KAS ---
                  Text('Rasio Kas Hari Ini', style: sectionStyle),
                  const SizedBox(height: 16),
                  _buildPieChartCard(),
                  const SizedBox(height: 32),

                  // --- BAGIAN 5: GRAFIK TREN ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tren Penjualan', style: sectionStyle),
                      if (_totalTransactionDays >= 7)
                        GestureDetector(
                          onTap: () => setState(() {
                            _isMonthly = !_isMonthly;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _isMonthly ? '30 Hari' : '7 Hari',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.swap_horiz_rounded,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLineChartCard(),

                  const SizedBox(height: 80), // Spacing ekstra untuk scroll
                ],
              ),
            ),
          ),
        ),
      ),
      // FAB dipertahankan sebagai tombol utama yang mencolok
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInputSheet(),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  // WIDGET BARU: Menu Aksi Cepat
  Widget _buildQuickActionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionBtn(
          icon: Icons.add_circle_outline_rounded,
          label: 'Pemasukan',
          color: Colors.green,
          onTap: () => _showInputSheet(defaultType: 'sale'),
        ),
        _buildActionBtn(
          icon: Icons.remove_circle_outline_rounded,
          label: 'Pengeluaran',
          color: Colors.redAccent,
          onTap: () => _showInputSheet(defaultType: 'expense'),
        ),
        _buildActionBtn(
          icon: Icons.history_rounded,
          label: 'Riwayat',
          color: Colors.orange,
          onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HistoryPage()))
              .then((_) => _refreshData()),
        ),
        _buildActionBtn(
          icon: Icons.notifications_active_outlined,
          label: 'Pengingat',
          color: Colors.purple,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddReminderPage())),
        ),
      ],
    );
  }

  Widget _buildActionBtn(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeService.themeMode,
        builder: (context, currentMode, _) {
          return Container(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 6,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text(
                    'Pengaturan Tampilan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildThemeOption(
                    title: 'Sesuai Sistem',
                    subtitle: 'Ikuti pengaturan tema HP',
                    icon: Icons.phone_android_rounded,
                    mode: ThemeMode.system,
                    currentMode: currentMode,
                  ),
                  _buildThemeOption(
                    title: 'Terang',
                    subtitle: 'Tampilan standar',
                    icon: Icons.light_mode_rounded,
                    mode: ThemeMode.light,
                    currentMode: currentMode,
                  ),
                  _buildThemeOption(
                    title: 'Gelap',
                    subtitle: 'Nyaman untuk mata di malam hari',
                    icon: Icons.dark_mode_rounded,
                    mode: ThemeMode.dark,
                    currentMode: currentMode,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
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
    final isSelected = mode == currentMode;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: isSelected
                ? AppTheme.primaryBlue
                : colorScheme.onSurfaceVariant),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? AppTheme.primaryBlue : colorScheme.outline,
      ),
      onTap: () async {
        await ThemeService.setThemeMode(mode);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  Widget _buildRecentTransactions() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_recentTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded,
                  size: 40, color: colorScheme.outline),
              const SizedBox(height: 8),
              Text(
                'Belum ada transaksi',
                style: TextStyle(
                    fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _recentTransactions.map((tx) {
        final isSale = tx.type == 'sale';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: ListTile(
            onTap: () {
              if (tx.createdAt.length >= 10) {
                final datePrefix = tx.createdAt.substring(0, 10);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistoryDetailPage(datePrefix: datePrefix),
                  ),
                ).then((_) => _refreshData());
              }
            },
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: isSale
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSale ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: isSale ? Colors.green[700] : Colors.red[700],
                size: 24,
              ),
            ),
            title: Text(
              tx.description,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colorScheme.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${DateHelper.formatToId(tx.createdAt.substring(0, 10))} • ${tx.createdAt.substring(11, 16)}',
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
            trailing: Text(
              '${isSale ? '+' : '-'}${CurrencyFormatter.formatRupiah(tx.amount)}',
              style: TextStyle(
                  color: isSale ? Colors.green[700] : Colors.red[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieChartCard() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_todaySales == 0 && _todayExpense == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart_outline_rounded,
                  size: 40, color: colorScheme.outline),
              const SizedBox(height: 8),
              Text(
                'Belum ada transaksi hari ini',
                style: TextStyle(
                    fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 35,
                  sections: [
                    if (_todaySales > 0)
                      PieChartSectionData(
                        color: Colors.green[600],
                        value: _todaySales.toDouble(),
                        title:
                            '${((_todaySales / (_todaySales + _todayExpense)) * 100).toStringAsFixed(0)}%',
                        radius: 28,
                        titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    if (_todayExpense > 0)
                      PieChartSectionData(
                        color: Colors.red[500],
                        value: _todayExpense.toDouble(),
                        title:
                            '${((_todayExpense / (_todaySales + _todayExpense)) * 100).toStringAsFixed(0)}%',
                        radius: 28,
                        titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPieLegend('Pemasukan', Colors.green[600]!, _todaySales),
                const SizedBox(height: 16),
                _buildPieLegend('Pengeluaran', Colors.red[500]!, _todayExpense),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.formatRupiah(amount),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildLineChartCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final currentData = _isMonthly ? _monthlyData : _weeklyData;

    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: (_totalTransactionDays < 7 || currentData.isEmpty)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart_rounded,
                      size: 40, color: colorScheme.outline),
                  const SizedBox(height: 8),
                  Text(
                    'Data belum cukup untuk grafik',
                    style: TextStyle(
                        fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : LineChart(_lineChartData(currentData)),
    );
  }

  LineChartData _lineChartData(List<Map<String, dynamic>> data) {
    final colorScheme = Theme.of(context).colorScheme;

    return LineChartData(
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: AppTheme.primaryBlue.withValues(alpha: 0.9),
          tooltipRoundedRadius: 8,
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final index = barSpot.x.toInt();
              return LineTooltipItem(
                '${data[index]['date']}\n',
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 11),
                children: [
                  TextSpan(
                    text: CurrencyFormatter.formatRupiah(barSpot.y.toInt()),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: null,
        getDrawingHorizontalLine: (value) => FlLine(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          strokeWidth: 1,
          dashArray: [5, 5],
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (val, meta) {
              int index = val.toInt();
              if (index >= 0 && index < data.length) {
                if (_isMonthly && index % 5 != 0) return const SizedBox();
                // Ambil tanggal saja (DD dari YYYY-MM-DD)
                String date = data[index]['date'].toString().split('-').last;
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    date,
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: data
              .asMap()
              .entries
              .map((e) => FlSpot(
                  e.key.toDouble(), (e.value['total'] as int).toDouble()))
              .toList(),
          isCurved: true,
          curveSmoothness: 0.3,
          color: AppTheme.primaryBlue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
              radius: 4,
              color: colorScheme.surface,
              strokeWidth: 2.5,
              strokeColor: AppTheme.primaryBlue,
            ),
          ),
          belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: 0.2),
                    AppTheme.primaryBlue.withValues(alpha: 0.0),
                  ])),
        ),
      ],
    );
  }

  Widget _buildInsightCard() {
    // Estimasi disesuaikan jadi 10% dari pemasukan hari ini
    int prediksi = (_todaySales * 0.10).round();

    return Container(
      // Padding atas sedikit dihapus agar menempel menyatu dengan SummaryCard di atasnya jika diinginkan
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24), top: Radius.circular(4)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.lightbulb_outline_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estimasi Modal Besok',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(CurrencyFormatter.formatRupiah(prediksi),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold))
              ],
            ),
          )
        ],
      ),
    );
  }
}
