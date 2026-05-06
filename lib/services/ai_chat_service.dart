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

  Future<String> ask(
    String question, {
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    lastOnlineUnavailable = false;

    final effectiveQuestion = _buildEffectiveQuestion(
      question,
      conversationHistory,
    );
    final localAnswer = await _askLocal(
      question,
      effectiveQuestion: effectiveQuestion,
    );
    final onlineAnswer = await _askOnline(
      question,
      localAnswer,
      conversationHistory: conversationHistory,
      effectiveQuestion: effectiveQuestion,
    );
    return onlineAnswer ?? localAnswer;
  }

  String _buildEffectiveQuestion(
    String question,
    List<Map<String, String>> conversationHistory,
  ) {
    final normalizedQuestion = question.toLowerCase().trim();
    if (!_looksLikeFollowUp(normalizedQuestion) || conversationHistory.isEmpty) {
      return question;
    }

    final recentHistory = conversationHistory.length > 6
        ? conversationHistory.sublist(conversationHistory.length - 6)
        : conversationHistory;
    final contextLines = recentHistory
        .map((item) {
          final role = item['role'] == 'assistant' ? 'AI' : 'User';
          final text = item['text']?.trim() ?? '';
          if (text.isEmpty) return '';
          return '$role: $text';
        })
        .where((line) => line.isNotEmpty)
        .join('\n');

    if (contextLines.isEmpty) {
      return question;
    }

    return '$question\n\nKonteks percakapan:\n$contextLines';
  }

  bool _looksLikeFollowUp(String question) {
    final words = question.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    final followUpKeywords = [
      'itu',
      'tadi',
      'yang mana',
      'yang paling',
      'kalau',
      'terus',
      'lalu',
      'detail',
      'lebih rinci',
      'jelasin',
      'kenapa',
      'kok',
      'gimana',
      'bagaimana',
    ];

    return words.length <= 6 || _containsAny(question, followUpKeywords);
  }

  Future<String> _askLocal(
    String question, {
    required String effectiveQuestion,
  }) async {
    final normalizedQuestion = question.toLowerCase();
    final normalizedEffectiveQuestion = effectiveQuestion.toLowerCase();

    if (_isGreeting(normalizedQuestion)) {
      return 'Halo, aku siap bantu soal C-Kas. Kamu bisa tanya dengan bahasa santai juga, misalnya minta ringkasan kas, cek pengeluaran, bandingkan periode, cari transaksi terbesar, atau minta saran modal.';
    }

    if (_isThanks(normalizedQuestion)) {
      return 'Sama-sama. Kalau butuh analisis kas lagi, tinggal tanya saja.';
    }

    if (_isCapabilityQuestion(normalizedEffectiveQuestion)) {
      return _buildCapabilityAnswer();
    }

    if (!_isRelatedQuestion(normalizedEffectiveQuestion)) {
      return _outOfScopeWarning();
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'banding',
      'dibanding',
      'vs',
      'versus',
      'lebih bagus mana',
      'lebih besar mana',
    ])) {
      return _buildComparisonAnswer(normalizedEffectiveQuestion);
    }

    final period = _resolvePeriod(
      normalizedQuestion,
      fallbackQuestion: normalizedEffectiveQuestion,
    );
    final transactions = await _transactionService.getTransactionsBetween(
      period.start,
      period.end,
    );

    if (transactions.isEmpty) {
      return 'Belum ada transaksi untuk ${period.label}. Catat pemasukan atau pengeluaran dulu, nanti aku bisa bantu rangkum dan analisis.';
    }

    final summary = _buildSummary(transactions);

    if (_containsAny(normalizedEffectiveQuestion, [
      'janggal',
      'aneh',
      'boros',
      'membengkak',
      'tidak wajar',
    ])) {
      return _buildAnomalyAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'rata-rata',
      'rerata',
      'average',
      'avg',
    ])) {
      return _buildAverageAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'berapa transaksi',
      'jumlah transaksi',
      'berapa kali',
      'berapa data',
    ])) {
      return _buildTransactionCountAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'transaksi terakhir',
      'aktivitas terakhir',
      'yang terakhir',
      'terbaru',
      'recent',
      'baru saja',
    ])) {
      return _buildLatestActivityAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'sehat',
      'aman',
      'bagus gak',
      'bagaimana kondisi',
      'kondisi kas',
    ])) {
      return _buildHealthAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'tren',
      'trend',
      'perkembangan',
    ])) {
      return _buildTrendAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'rekomendasi',
      'tips',
      'evaluasi',
      'saran',
      'apa yang harus',
      'langkah',
    ])) {
      return _buildRecommendationAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'pengeluaran',
      'keluar',
      'biaya',
      'belanja',
    ])) {
      return _buildExpenseAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'pendapatan',
      'pemasukan',
      'penjualan',
      'omzet',
    ])) {
      return _buildSalesAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, ['modal', 'besok'])) {
      return _buildCapitalSuggestion(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'terbesar',
      'paling besar',
      'tertinggi',
    ])) {
      return _buildBiggestTransactionAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, [
      'untung',
      'laba',
      'bersih',
      'profit',
    ])) {
      return _buildNetAnswer(period.label, summary);
    }

    if (_containsAny(normalizedEffectiveQuestion, ['kenapa', 'kok'])) {
      return _buildWhyAnswer(period.label, summary);
    }

    return _buildGeneralAnswer(period.label, summary);
  }

  Future<String?> _askOnline(
    String question,
    String localAnswer, {
    required List<Map<String, String>> conversationHistory,
    required String effectiveQuestion,
  }) async {
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
      request.write(
        jsonEncode(
          await _buildOnlinePayload(
            question,
            localAnswer,
            conversationHistory: conversationHistory,
            effectiveQuestion: effectiveQuestion,
          ),
        ),
      );

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
    {
    required List<Map<String, String>> conversationHistory,
    required String effectiveQuestion,
    }
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
      'effective_question': effectiveQuestion,
      'local_answer': localAnswer,
      'generated_at': now.toIso8601String(),
      'app_context':
          'C-Kas adalah aplikasi pencatatan pemasukan dan pengeluaran warung.',
      'conversation_history': _trimConversationHistory(conversationHistory),
      'summaries': {
        'today': _summaryToMap(_buildSummary(today)),
        'yesterday': _summaryToMap(_buildSummary(yesterday)),
        'last_7_days': _summaryToMap(_buildSummary(sevenDays)),
        'last_30_days': _summaryToMap(_buildSummary(thirtyDays)),
      },
      'recent_transactions': recent.map(_transactionToMap).toList(),
      'instruction':
          'Jawab dalam bahasa Indonesia yang natural, fleksibel, dan praktis. Gunakan conversation_history untuk memahami pertanyaan lanjutan yang singkat. Fokus pada kondisi kas warung dan penggunaan aplikasi C-Kas. Jangan mengarang data di luar JSON ini. Jika data kurang, katakan jujur lalu beri langkah atau saran berikutnya.',
    };
  }

  List<Map<String, String>> _trimConversationHistory(
    List<Map<String, String>> conversationHistory,
  ) {
    final trimmed = conversationHistory.length > 12
        ? conversationHistory.sublist(conversationHistory.length - 12)
        : conversationHistory;

    return trimmed
        .map(
          (item) => {
            'role': item['role'] ?? 'user',
            'text': item['text']?.trim() ?? '',
          },
        )
        .where((item) => item['text']!.isNotEmpty)
        .toList();
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

  Future<String> _buildComparisonAnswer(String question) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    if (_containsAny(question, ['minggu lalu', 'pekan lalu', '7 hari sebelumnya'])) {
      return _buildPeriodComparisonAnswer(
        currentLabel: '7 hari terakhir',
        currentStart: todayStart.subtract(const Duration(days: 6)),
        currentEnd: todayStart.add(const Duration(days: 1)),
        previousLabel: '7 hari sebelumnya',
        previousStart: todayStart.subtract(const Duration(days: 13)),
        previousEnd: todayStart.subtract(const Duration(days: 6)),
      );
    }

    if (_containsAny(question, ['bulan lalu', '30 hari sebelumnya'])) {
      return _buildPeriodComparisonAnswer(
        currentLabel: '30 hari terakhir',
        currentStart: todayStart.subtract(const Duration(days: 29)),
        currentEnd: todayStart.add(const Duration(days: 1)),
        previousLabel: '30 hari sebelumnya',
        previousStart: todayStart.subtract(const Duration(days: 59)),
        previousEnd: todayStart.subtract(const Duration(days: 29)),
      );
    }

    return _buildTodayComparisonAnswer();
  }

  Future<String> _buildTodayComparisonAnswer() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    return _buildPeriodComparisonAnswer(
      currentLabel: 'hari ini',
      currentStart: todayStart,
      currentEnd: tomorrowStart,
      previousLabel: 'kemarin',
      previousStart: yesterdayStart,
      previousEnd: todayStart,
    );
  }

  Future<String> _buildPeriodComparisonAnswer({
    required String currentLabel,
    required DateTime currentStart,
    required DateTime currentEnd,
    required String previousLabel,
    required DateTime previousStart,
    required DateTime previousEnd,
  }) async {
    final today = _buildSummary(
      await _transactionService.getTransactionsBetween(
        currentStart,
        currentEnd,
      ),
    );
    final yesterday = _buildSummary(
      await _transactionService.getTransactionsBetween(
        previousStart,
        previousEnd,
      ),
    );

    if (today.transactions.isEmpty && yesterday.transactions.isEmpty) {
      return 'Belum ada transaksi pada periode $currentLabel maupun $previousLabel untuk dibandingkan.';
    }

    final salesDiff = today.sales - yesterday.sales;
    final expenseDiff = today.expenses - yesterday.expenses;
    final netDiff = today.net - yesterday.net;

    return 'Perbandingan $currentLabel vs $previousLabel:\n'
        '- Pemasukan: ${CurrencyFormatter.formatRupiah(today.sales)} (${_formatDiff(salesDiff)})\n'
        '- Pengeluaran: ${CurrencyFormatter.formatRupiah(today.expenses)} (${_formatDiff(expenseDiff)})\n'
        '- Bersih: ${CurrencyFormatter.formatRupiah(today.net)} (${_formatDiff(netDiff)})\n\n'
        '${_buildComparisonNote(salesDiff, expenseDiff, netDiff)}';
  }

  _ChatPeriod _resolvePeriod(
    String question, {
    String? fallbackQuestion,
  }) {
    return _extractPeriod(question) ??
        _extractPeriod(fallbackQuestion ?? '') ??
        _defaultPeriod();
  }

  _ChatPeriod? _extractPeriod(String question) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedQuestion = question.toLowerCase();
    final dayMatch = RegExp(r'(\d+)\s*hari').firstMatch(normalizedQuestion);

    if (_containsAny(normalizedQuestion, ['semua', 'seluruh', 'overall'])) {
      return _ChatPeriod(
        label: 'semua data',
        start: DateTime(2000),
        end: today.add(const Duration(days: 1)),
      );
    }

    if (dayMatch != null) {
      final days = int.tryParse(dayMatch.group(1) ?? '');
      if (days != null && days > 0) {
        return _ChatPeriod(
          label: '$days hari terakhir',
          start: today.subtract(Duration(days: days - 1)),
          end: today.add(const Duration(days: 1)),
        );
      }
    }

    if (_containsAny(normalizedQuestion, ['minggu lalu', 'pekan lalu'])) {
      return _ChatPeriod(
        label: '7 hari sebelumnya',
        start: today.subtract(const Duration(days: 13)),
        end: today.subtract(const Duration(days: 6)),
      );
    }

    if (_containsAny(normalizedQuestion, ['bulan lalu'])) {
      return _ChatPeriod(
        label: '30 hari sebelumnya',
        start: today.subtract(const Duration(days: 59)),
        end: today.subtract(const Duration(days: 29)),
      );
    }

    if (_containsAny(normalizedQuestion, ['minggu ini', 'minggu', '7 hari', 'pekan'])) {
      return _ChatPeriod(
        label: '7 hari terakhir',
        start: today.subtract(const Duration(days: 6)),
        end: today.add(const Duration(days: 1)),
      );
    }

    if (_containsAny(normalizedQuestion, ['bulan ini', 'bulan', '30 hari'])) {
      return _ChatPeriod(
        label: '30 hari terakhir',
        start: today.subtract(const Duration(days: 29)),
        end: today.add(const Duration(days: 1)),
      );
    }

    if (_containsAny(normalizedQuestion, ['kemarin'])) {
      return _ChatPeriod(
        label: 'kemarin',
        start: today.subtract(const Duration(days: 1)),
        end: today,
      );
    }

    if (_containsAny(normalizedQuestion, ['hari ini', 'sekarang', 'today'])) {
      return _defaultPeriod();
    }

    return null;
  }

  _ChatPeriod _defaultPeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
        '- Jumlah transaksi: ${summary.transactions.length}\n'
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

    return 'Total pengeluaran $label adalah ${CurrencyFormatter.formatRupiah(summary.expenses)} dari ${summary.expenseCount} transaksi. Rata-rata pengeluaran per transaksi sekitar ${CurrencyFormatter.formatRupiah(summary.averageExpensePerTransaction)}. $detail';
  }

  String _buildSalesAnswer(String label, _CashSummary summary) {
    final biggest = summary.biggestSale;
    final detail = biggest == null
        ? 'Belum ada pemasukan tercatat.'
        : 'Pemasukan terbesar adalah ${biggest.description} sebesar ${CurrencyFormatter.formatRupiah(biggest.amount)}.';

    return 'Total pemasukan $label adalah ${CurrencyFormatter.formatRupiah(summary.sales)} dari ${summary.saleCount} transaksi. Rata-rata pemasukan per transaksi sekitar ${CurrencyFormatter.formatRupiah(summary.averageSalePerTransaction)}. $detail';
  }

  String _buildNetAnswer(String label, _CashSummary summary) {
    final tone = summary.net >= 0
        ? 'Hasilnya sehat karena pemasukan masih lebih besar dari pengeluaran.'
        : 'Hasilnya minus karena pengeluaran lebih besar dari pemasukan.';

    return 'Kas bersih $label adalah ${CurrencyFormatter.formatRupiah(summary.net)}. $tone';
  }

  String _buildCapitalSuggestion(String label, _CashSummary summary) {
    final baselineCapital =
        ((summary.averageSalesPerActiveDay * 0.35) + (summary.expenses * 0.20))
            .round();
    final suggestedCapital = baselineCapital <= 0
        ? (summary.sales * 0.10).round()
        : baselineCapital;
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

  String _buildAnomalyAnswer(String label, _CashSummary summary) {
    if (summary.expenseCount == 0) {
      return 'Belum ada pengeluaran di $label, jadi belum terlihat pola pengeluaran yang janggal.';
    }

    final biggestExpense = summary.biggestExpense;
    final biggestShare = biggestExpense == null || summary.expenses == 0
        ? 0
        : ((biggestExpense.amount / summary.expenses) * 100).round();

    final notes = <String>[
      'Total pengeluaran $label mencapai ${CurrencyFormatter.formatRupiah(summary.expenses)}.',
    ];

    if (biggestExpense != null) {
      notes.add(
        'Pengeluaran terbesar ada di ${biggestExpense.description} sebesar ${CurrencyFormatter.formatRupiah(biggestExpense.amount)} atau sekitar $biggestShare% dari total pengeluaran.',
      );
    }

    if (summary.expenseRatio >= 70) {
      notes.add('Rasio pengeluaran terhadap pemasukan sudah tinggi di ${summary.expenseRatio}%, jadi ada tanda biaya mulai membengkak.');
    } else if (biggestShare >= 45) {
      notes.add('Biaya cukup terkonsentrasi di satu transaksi, jadi item ini paling layak dicek dulu.');
    } else {
      notes.add('Belum terlihat lonjakan ekstrem, tapi tetap pantau transaksi terbesar dan belanja yang berulang.');
    }

    return notes.join(' ');
  }

  String _buildAverageAnswer(String label, _CashSummary summary) {
    return 'Rata-rata $label:\n'
        '- Pemasukan per transaksi: ${CurrencyFormatter.formatRupiah(summary.averageSalePerTransaction)}\n'
        '- Pengeluaran per transaksi: ${CurrencyFormatter.formatRupiah(summary.averageExpensePerTransaction)}\n'
        '- Pemasukan per hari aktif: ${CurrencyFormatter.formatRupiah(summary.averageSalesPerActiveDay)}\n'
        '- Pengeluaran per hari aktif: ${CurrencyFormatter.formatRupiah(summary.averageExpensesPerActiveDay)}';
  }

  String _buildTransactionCountAnswer(String label, _CashSummary summary) {
    return 'Jumlah transaksi $label ada ${summary.transactions.length} transaksi, terdiri dari ${summary.saleCount} pemasukan dan ${summary.expenseCount} pengeluaran.';
  }

  String _buildLatestActivityAnswer(String label, _CashSummary summary) {
    final latest = summary.latestTransaction;
    if (latest == null) {
      return 'Belum ada aktivitas transaksi untuk $label.';
    }

    final typeLabel = latest.type == 'sale' ? 'pemasukan' : 'pengeluaran';
    final description = latest.description.isEmpty
        ? 'Tanpa keterangan'
        : latest.description;

    return 'Aktivitas terakhir di $label adalah $typeLabel sebesar ${CurrencyFormatter.formatRupiah(latest.amount)} untuk "$description".';
  }

  String _buildHealthAnswer(String label, _CashSummary summary) {
    final notes = <String>[];

    if (summary.net >= 0) {
      notes.add('Kas $label masih sehat karena bersihnya positif di ${CurrencyFormatter.formatRupiah(summary.net)}.');
    } else {
      notes.add('Kas $label belum sehat karena bersihnya minus ${CurrencyFormatter.formatRupiah(summary.net.abs())}.');
    }

    if (summary.expenseRatio >= 70) {
      notes.add('Pengeluaran sudah memakan ${summary.expenseRatio}% dari pemasukan, jadi ruang aman kas mulai tipis.');
    } else {
      notes.add('Rasio pengeluaran masih di ${summary.expenseRatio}%, jadi masih cukup terkendali.');
    }

    return notes.join(' ');
  }

  String _buildWhyAnswer(String label, _CashSummary summary) {
    if (summary.transactions.isEmpty) {
      return 'Aku belum bisa jelaskan penyebabnya karena belum ada transaksi di $label.';
    }

    if (summary.net < 0 && summary.biggestExpense != null) {
      return 'Kondisi $label cenderung tertekan karena pengeluaran lebih besar dari pemasukan. Faktor yang paling terasa datang dari ${summary.biggestExpense!.description} sebesar ${CurrencyFormatter.formatRupiah(summary.biggestExpense!.amount)}.';
    }

    if (summary.expenseRatio >= 70) {
      return 'Penyebab utamanya kemungkinan rasio pengeluaran yang sudah tinggi, yaitu ${summary.expenseRatio}% dari pemasukan, jadi margin kas jadi sempit.';
    }

    return 'Sejauh ini kondisi $label masih cukup stabil karena pemasukan masih lebih besar dari pengeluaran.';
  }

  bool _isCapabilityQuestion(String text) {
    return _containsAny(text, [
      'bisa bantu apa',
      'bisa apa',
      'fitur apa',
      'kamu bisa apa',
      'apa saja yang bisa',
      'tolong apa',
      'siapa kamu',
    ]);
  }

  String _buildCapabilityAnswer() {
    return 'Aku bisa bantu baca data kas di C-Kas dengan gaya tanya yang santai juga. Contohnya: ringkas hari ini, cek pengeluaran paling besar, bandingkan dengan kemarin, lihat tren 7 atau 30 hari, cari transaksi janggal, hitung rata-rata, sampai kasih saran modal atau langkah yang perlu diprioritaskan.';
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
      'fitur',
      'bantu',
      'siapa kamu',
      'janggal',
      'aneh',
      'boros',
      'rata-rata',
      'rerata',
      'average',
      'aman',
      'sehat',
      'detail',
      'terakhir',
      'terbaru',
      'bandingkan',
      'vs',
      'versus',
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
    return 'Aku paling membantu untuk hal yang terkait C-Kas dan kondisi kas warung, seperti transaksi, pemasukan, pengeluaran, tren, perbandingan periode, modal, dan laporan. Kalau mau, coba tanya seperti "pengeluaran 7 hari terakhir", "apa yang paling boros minggu ini?", atau "bandingkan hari ini dengan kemarin".';
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
  TransactionModel? get latestTransaction =>
      transactions.isEmpty ? null : transactions.first;
  int get averageSalePerTransaction =>
      saleCount == 0 ? 0 : (sales / saleCount).round();
  int get averageExpensePerTransaction =>
      expenseCount == 0 ? 0 : (expenses / expenseCount).round();
  int get averageSalesPerActiveDay =>
      activeDayCount == 0 ? 0 : (sales / activeDayCount).round();
  int get averageExpensesPerActiveDay =>
      activeDayCount == 0 ? 0 : (expenses / activeDayCount).round();

  int get activeDayCount {
    final dates = transactions.map((tx) => tx.createdAt.substring(0, 10)).toSet();
    return dates.length;
  }
}
