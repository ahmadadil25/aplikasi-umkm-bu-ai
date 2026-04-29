import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/currency_formatter.dart';
import '../models/transaction_model.dart';
import 'transaction_service.dart';

class AiChatService {
  AiChatService({TransactionService? transactionService})
      : _transactionService = transactionService ?? TransactionService();

  final TransactionService _transactionService;
  static const String _endpointKey = 'ai_chat_endpoint';
  static const String defaultEndpoint =
      'https://sorest-inviolately-luella.ngrok-free.dev/api/ai-chat';
  bool lastOnlineUnavailable = false;

  Future<String> getEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_endpointKey) ?? defaultEndpoint;
  }

  Future<String> getSavedEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_endpointKey) ?? '';
  }

  Future<void> saveEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedEndpoint = endpoint.trim();
    if (trimmedEndpoint.isEmpty || trimmedEndpoint == defaultEndpoint) {
      await prefs.remove(_endpointKey);
      return;
    }

    await prefs.setString(_endpointKey, trimmedEndpoint);
  }

  Future<String> ask(String question) async {
    lastOnlineUnavailable = false;

    if (!_isRelatedQuestion(question)) {
      return _outOfScopeWarning();
    }

    final localAnswer = await _askLocal(question);
    final onlineAnswer = await _askOnline(question, localAnswer);
    return onlineAnswer ?? localAnswer;
  }

  Future<String> _askLocal(String question) async {
    final normalizedQuestion = question.toLowerCase();

    if (_isGreeting(normalizedQuestion)) {
      return 'Halo, aku siap bantu soal C-Kas. Kamu bisa tanya ringkasan kas, pengeluaran, pemasukan, tren penjualan, modal, atau laporan warung.';
    }

    if (_isThanks(normalizedQuestion)) {
      return 'Sama-sama. Kalau butuh analisis kas lagi, tinggal tanya saja.';
    }

    if (_containsAny(normalizedQuestion, [
      'banding',
      'dibanding',
      'kemarin vs hari ini',
      'hari ini vs kemarin',
    ])) {
      return _buildTodayComparisonAnswer();
    }

    final period = _resolvePeriod(normalizedQuestion);
    final transactions = await _transactionService.getTransactionsBetween(
      period.start,
      period.end,
    );

    if (transactions.isEmpty) {
      return 'Belum ada transaksi untuk ${period.label}. Catat pemasukan atau pengeluaran dulu, nanti aku bisa bantu rangkum dan analisis.';
    }

    final summary = _buildSummary(transactions);

    if (_containsAny(normalizedQuestion, ['tren', 'trend', 'perkembangan'])) {
      return _buildTrendAnswer(period.label, summary);
    }

    if (_containsAny(normalizedQuestion, ['rekomendasi', 'tips', 'evaluasi', 'saran'])) {
      return _buildRecommendationAnswer(period.label, summary);
    }

    if (_containsAny(normalizedQuestion, ['pengeluaran', 'keluar', 'biaya'])) {
      return _buildExpenseAnswer(period.label, summary);
    }

    if (_containsAny(normalizedQuestion, ['pendapatan', 'pemasukan', 'penjualan', 'omzet'])) {
      return _buildSalesAnswer(period.label, summary);
    }

    if (_containsAny(normalizedQuestion, ['modal', 'besok', 'saran'])) {
      return _buildCapitalSuggestion(period.label, summary);
    }

    if (_containsAny(normalizedQuestion, ['terbesar', 'paling besar', 'tertinggi'])) {
      return _buildBiggestTransactionAnswer(period.label, summary);
    }

    if (_containsAny(normalizedQuestion, ['untung', 'laba', 'bersih', 'profit'])) {
      return _buildNetAnswer(period.label, summary);
    }

    return _buildGeneralAnswer(period.label, summary);
  }

  Future<String?> _askOnline(String question, String localAnswer) async {
    final endpoint = await getEndpoint();
    if (endpoint.isEmpty) return null;

    try {
      final uri = Uri.parse(endpoint);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final request = await client.postUrl(uri).timeout(
            const Duration(seconds: 8),
          );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(await _buildOnlinePayload(question, localAnswer)));

      final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastOnlineUnavailable = true;
        return null;
      }

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final answer = decoded['answer'] ?? decoded['message'] ?? decoded['text'];
        if (answer is String && answer.trim().isNotEmpty) {
          return answer.trim();
        }
      }

      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
    } catch (_) {
      lastOnlineUnavailable = true;
      return null;
    }

    return null;
  }

  Future<Map<String, dynamic>> _buildOnlinePayload(
    String question,
    String localAnswer,
  ) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final sevenDaysStart = todayStart.subtract(const Duration(days: 6));
    final thirtyDaysStart = todayStart.subtract(const Duration(days: 29));

    final today = await _transactionService.getTransactionsBetween(
      todayStart,
      tomorrowStart,
    );
    final yesterday = await _transactionService.getTransactionsBetween(
      yesterdayStart,
      todayStart,
    );
    final sevenDays = await _transactionService.getTransactionsBetween(
      sevenDaysStart,
      tomorrowStart,
    );
    final thirtyDays = await _transactionService.getTransactionsBetween(
      thirtyDaysStart,
      tomorrowStart,
    );
    final recent = await _transactionService.getRecentTransactions(30);

    return {
      'question': question,
      'local_answer': localAnswer,
      'generated_at': now.toIso8601String(),
      'app_context':
          'C-Kas adalah aplikasi pencatatan pemasukan dan pengeluaran warung.',
      'summaries': {
        'today': _summaryToMap(_buildSummary(today)),
        'yesterday': _summaryToMap(_buildSummary(yesterday)),
        'last_7_days': _summaryToMap(_buildSummary(sevenDays)),
        'last_30_days': _summaryToMap(_buildSummary(thirtyDays)),
      },
      'recent_transactions': recent.map(_transactionToMap).toList(),
      'instruction':
          'Jawab dalam bahasa Indonesia, singkat, praktis, dan fokus pada kondisi kas warung. Jangan mengarang data di luar JSON ini.',
    };
  }

  Map<String, dynamic> _summaryToMap(_CashSummary summary) {
    return {
      'sales': summary.sales,
      'expenses': summary.expenses,
      'net': summary.net,
      'sale_count': summary.saleCount,
      'expense_count': summary.expenseCount,
      'expense_ratio': summary.expenseRatio,
      'active_day_count': summary.activeDayCount,
      'biggest_sale': summary.biggestSale == null
          ? null
          : _transactionToMap(summary.biggestSale!),
      'biggest_expense': summary.biggestExpense == null
          ? null
          : _transactionToMap(summary.biggestExpense!),
    };
  }

  Map<String, dynamic> _transactionToMap(TransactionModel transaction) {
    return {
      'id': transaction.id,
      'type': transaction.type,
      'amount': transaction.amount,
      'description': transaction.description,
      'created_at': transaction.createdAt,
    };
  }

  Future<String> _buildTodayComparisonAnswer() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final today = _buildSummary(
      await _transactionService.getTransactionsBetween(
        todayStart,
        tomorrowStart,
      ),
    );
    final yesterday = _buildSummary(
      await _transactionService.getTransactionsBetween(
        yesterdayStart,
        todayStart,
      ),
    );

    if (today.transactions.isEmpty && yesterday.transactions.isEmpty) {
      return 'Belum ada transaksi hari ini maupun kemarin untuk dibandingkan.';
    }

    final salesDiff = today.sales - yesterday.sales;
    final expenseDiff = today.expenses - yesterday.expenses;
    final netDiff = today.net - yesterday.net;

    return 'Perbandingan hari ini vs kemarin:\n'
        '- Pemasukan: ${CurrencyFormatter.formatRupiah(today.sales)} (${_formatDiff(salesDiff)})\n'
        '- Pengeluaran: ${CurrencyFormatter.formatRupiah(today.expenses)} (${_formatDiff(expenseDiff)})\n'
        '- Bersih: ${CurrencyFormatter.formatRupiah(today.net)} (${_formatDiff(netDiff)})\n\n'
        '${_buildComparisonNote(salesDiff, expenseDiff, netDiff)}';
  }

  _ChatPeriod _resolvePeriod(String question) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_containsAny(question, ['minggu', '7 hari', 'pekan'])) {
      return _ChatPeriod(
        label: '7 hari terakhir',
        start: today.subtract(const Duration(days: 6)),
        end: today.add(const Duration(days: 1)),
      );
    }

    if (_containsAny(question, ['bulan', '30 hari'])) {
      return _ChatPeriod(
        label: '30 hari terakhir',
        start: today.subtract(const Duration(days: 29)),
        end: today.add(const Duration(days: 1)),
      );
    }

    if (_containsAny(question, ['kemarin'])) {
      return _ChatPeriod(
        label: 'kemarin',
        start: today.subtract(const Duration(days: 1)),
        end: today,
      );
    }

    return _ChatPeriod(
      label: 'hari ini',
      start: today,
      end: today.add(const Duration(days: 1)),
    );
  }

  _CashSummary _buildSummary(List<TransactionModel> transactions) {
    int sales = 0;
    int expenses = 0;
    TransactionModel? biggestSale;
    TransactionModel? biggestExpense;

    for (final tx in transactions) {
      if (tx.type == 'sale') {
        sales += tx.amount;
        if (biggestSale == null || tx.amount > biggestSale.amount) {
          biggestSale = tx;
        }
      } else if (tx.type == 'expense') {
        expenses += tx.amount;
        if (biggestExpense == null || tx.amount > biggestExpense.amount) {
          biggestExpense = tx;
        }
      }
    }

    return _CashSummary(
      sales: sales,
      expenses: expenses,
      transactions: transactions,
      biggestSale: biggestSale,
      biggestExpense: biggestExpense,
    );
  }

  String _buildGeneralAnswer(String label, _CashSummary summary) {
    final ratio = summary.sales == 0
        ? 0
        : ((summary.expenses / summary.sales) * 100).round();
    final status = summary.net >= 0
        ? 'Kas masih positif.'
        : 'Kas sedang minus, perlu cek pengeluaran terbesar.';

    return 'Ringkasan $label:\n'
        '- Pemasukan: ${CurrencyFormatter.formatRupiah(summary.sales)}\n'
        '- Pengeluaran: ${CurrencyFormatter.formatRupiah(summary.expenses)}\n'
        '- Bersih: ${CurrencyFormatter.formatRupiah(summary.net)}\n'
        '- Rasio pengeluaran: $ratio% dari pemasukan\n\n'
        '$status';
  }

  String _buildTrendAnswer(String label, _CashSummary summary) {
    final averageSales = summary.activeDayCount == 0
        ? 0
        : (summary.sales / summary.activeDayCount).round();
    final averageExpense = summary.activeDayCount == 0
        ? 0
        : (summary.expenses / summary.activeDayCount).round();
    final ratio = summary.sales == 0
        ? 0
        : ((summary.expenses / summary.sales) * 100).round();

    return 'Tren $label:\n'
        '- Hari aktif transaksi: ${summary.activeDayCount} hari\n'
        '- Rata-rata pemasukan: ${CurrencyFormatter.formatRupiah(averageSales)} per hari aktif\n'
        '- Rata-rata pengeluaran: ${CurrencyFormatter.formatRupiah(averageExpense)} per hari aktif\n'
        '- Rasio pengeluaran: $ratio% dari pemasukan\n\n'
        '${_buildTrendNote(summary)}';
  }

  String _buildExpenseAnswer(String label, _CashSummary summary) {
    final biggest = summary.biggestExpense;
    final detail = biggest == null
        ? 'Belum ada pengeluaran tercatat.'
        : 'Pengeluaran terbesar adalah ${biggest.description} sebesar ${CurrencyFormatter.formatRupiah(biggest.amount)}.';

    return 'Total pengeluaran $label adalah ${CurrencyFormatter.formatRupiah(summary.expenses)} dari ${summary.expenseCount} transaksi. $detail';
  }

  String _buildSalesAnswer(String label, _CashSummary summary) {
    final biggest = summary.biggestSale;
    final detail = biggest == null
        ? 'Belum ada pemasukan tercatat.'
        : 'Pemasukan terbesar adalah ${biggest.description} sebesar ${CurrencyFormatter.formatRupiah(biggest.amount)}.';

    return 'Total pemasukan $label adalah ${CurrencyFormatter.formatRupiah(summary.sales)} dari ${summary.saleCount} transaksi. $detail';
  }

  String _buildNetAnswer(String label, _CashSummary summary) {
    final tone = summary.net >= 0
        ? 'Hasilnya sehat karena pemasukan masih lebih besar dari pengeluaran.'
        : 'Hasilnya minus karena pengeluaran lebih besar dari pemasukan.';

    return 'Kas bersih $label adalah ${CurrencyFormatter.formatRupiah(summary.net)}. $tone';
  }

  String _buildCapitalSuggestion(String label, _CashSummary summary) {
    final suggestedCapital = (summary.sales * 0.10).round();
    final extraNote = summary.expenses > summary.sales
        ? 'Karena pengeluaran lebih besar dari pemasukan, tahan belanja tambahan dulu kecuali barang cepat habis.'
        : 'Angka ini bisa dipakai sebagai patokan ringan, lalu sesuaikan dengan stok yang benar-benar menipis.';

    return 'Estimasi modal besok dari data $label sekitar ${CurrencyFormatter.formatRupiah(suggestedCapital)}. $extraNote';
  }

  String _buildRecommendationAnswer(String label, _CashSummary summary) {
    final notes = <String>[];

    if (summary.sales == 0) {
      notes.add('Pemasukan belum tercatat, jadi utamakan input penjualan dulu agar analisis lebih akurat.');
    } else if (summary.expenseRatio >= 70) {
      notes.add('Pengeluaran sudah tinggi, sekitar ${summary.expenseRatio}% dari pemasukan. Cek belanja yang belum mendesak.');
    } else {
      notes.add('Rasio pengeluaran masih cukup terkendali di ${summary.expenseRatio}% dari pemasukan.');
    }

    if (summary.net < 0) {
      notes.add('Kas bersih minus, jadi sebaiknya tahan modal tambahan kecuali untuk barang yang cepat berputar.');
    } else {
      notes.add('Kas bersih positif ${CurrencyFormatter.formatRupiah(summary.net)}, masih ada ruang untuk modal terukur.');
    }

    if (summary.biggestExpense != null) {
      notes.add('Pantau pengeluaran terbesar: ${summary.biggestExpense!.description} (${CurrencyFormatter.formatRupiah(summary.biggestExpense!.amount)}).');
    }

    return 'Rekomendasi dari data $label:\n${notes.map((note) => '- $note').join('\n')}';
  }

  String _buildBiggestTransactionAnswer(String label, _CashSummary summary) {
    final sale = summary.biggestSale;
    final expense = summary.biggestExpense;

    if (sale == null && expense == null) {
      return 'Belum ada transaksi besar yang bisa dibandingkan untuk $label.';
    }

    final lines = <String>['Transaksi terbesar $label:'];
    if (sale != null) {
      lines.add('- Pemasukan: ${sale.description}, ${CurrencyFormatter.formatRupiah(sale.amount)}');
    }
    if (expense != null) {
      lines.add('- Pengeluaran: ${expense.description}, ${CurrencyFormatter.formatRupiah(expense.amount)}');
    }

    return lines.join('\n');
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  bool _isRelatedQuestion(String question) {
    final normalizedQuestion = question.toLowerCase();
    final relatedKeywords = [
      'halo',
      'hallo',
      'hai',
      'hi',
      'hey',
      'pagi',
      'siang',
      'sore',
      'malam',
      'assalam',
      'terima kasih',
      'makasih',
      'thanks',
      'thank',
      'ok',
      'oke',
      'kas',
      'uang',
      'warung',
      'aplikasi',
      'c-kas',
      'ckas',
      'transaksi',
      'pemasukan',
      'pendapatan',
      'penjualan',
      'omzet',
      'pengeluaran',
      'biaya',
      'modal',
      'laba',
      'untung',
      'profit',
      'bersih',
      'saldo',
      'laporan',
      'riwayat',
      'history',
      'ringkasan',
      'rangkum',
      'analisis',
      'tren',
      'trend',
      'hari ini',
      'kemarin',
      'minggu',
      'bulan',
      'terbesar',
      'tertinggi',
      'rekomendasi',
      'saran',
      'estimasi',
      'stok',
      'belanja',
      'jual',
      'beli',
      'catat',
      'nota',
    ];

    return _containsAny(normalizedQuestion, relatedKeywords);
  }

  bool _isGreeting(String text) {
    final trimmed = text.trim();
    final greetings = [
      'halo',
      'hallo',
      'hai',
      'hi',
      'hey',
      'pagi',
      'selamat pagi',
      'siang',
      'selamat siang',
      'sore',
      'selamat sore',
      'malam',
      'selamat malam',
      'assalamualaikum',
      'assalam',
    ];

    return greetings.any((greeting) => trimmed == greeting);
  }

  bool _isThanks(String text) {
    final trimmed = text.trim();
    final thanks = [
      'terima kasih',
      'makasih',
      'thanks',
      'thank you',
      'ok',
      'oke',
      'sip',
      'mantap',
    ];

    return thanks.any((item) => trimmed == item);
  }

  String _outOfScopeWarning() {
    return 'Maaf, aku hanya bisa membantu topik yang terkait aplikasi C-Kas, seperti transaksi, pemasukan, pengeluaran, kas bersih, tren penjualan, modal, dan laporan warung.';
  }

  String _formatDiff(int value) {
    if (value == 0) return 'tetap';
    final prefix = value > 0 ? 'naik' : 'turun';
    return '$prefix ${CurrencyFormatter.formatRupiah(value.abs())}';
  }

  String _buildComparisonNote(int salesDiff, int expenseDiff, int netDiff) {
    if (netDiff > 0 && expenseDiff <= 0) {
      return 'Bagus, kas bersih membaik dan pengeluaran tidak naik.';
    }
    if (netDiff > 0) {
      return 'Kas bersih membaik, tapi tetap cek pengeluaran karena ada perubahan biaya.';
    }
    if (netDiff < 0 && expenseDiff > 0) {
      return 'Kas bersih turun terutama karena pengeluaran naik.';
    }
    if (salesDiff < 0) {
      return 'Kas bersih turun karena pemasukan lebih rendah dari kemarin.';
    }
    return 'Kondisinya relatif stabil dibanding kemarin.';
  }

  String _buildTrendNote(_CashSummary summary) {
    if (summary.sales == 0) {
      return 'Belum ada pemasukan di periode ini, jadi tren penjualan belum bisa dibaca.';
    }
    if (summary.net < 0) {
      return 'Tren perlu diperhatikan karena total periode ini masih minus.';
    }
    if (summary.expenseRatio >= 70) {
      return 'Penjualan ada, tapi biaya mengambil porsi besar. Coba cek stok dan belanja rutin.';
    }
    return 'Tren masih sehat karena pemasukan lebih besar dari pengeluaran.';
  }
}

class _ChatPeriod {
  const _ChatPeriod({
    required this.label,
    required this.start,
    required this.end,
  });

  final String label;
  final DateTime start;
  final DateTime end;
}

class _CashSummary {
  const _CashSummary({
    required this.sales,
    required this.expenses,
    required this.transactions,
    required this.biggestSale,
    required this.biggestExpense,
  });

  final int sales;
  final int expenses;
  final List<TransactionModel> transactions;
  final TransactionModel? biggestSale;
  final TransactionModel? biggestExpense;

  int get net => sales - expenses;
  int get saleCount => transactions.where((tx) => tx.type == 'sale').length;
  int get expenseCount => transactions.where((tx) => tx.type == 'expense').length;
  int get expenseRatio => sales == 0 ? 0 : ((expenses / sales) * 100).round();

  int get activeDayCount {
    final dates = transactions.map((tx) => tx.createdAt.substring(0, 10)).toSet();
    return dates.length;
  }
}
