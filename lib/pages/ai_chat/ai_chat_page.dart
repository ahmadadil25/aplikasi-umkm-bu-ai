import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../services/ai_chat_service.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({Key? key}) : super(key: key);

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  static const String _chatHistoryKey = 'ai_chat_history';
  final AiChatService _chatService = AiChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text:
          'Halo, aku asisten kas. Kamu bisa tanya ringkasan, pengeluaran, pemasukan, tren, perbandingan, transaksi terbesar, atau estimasi modal.',
      isUser: false,
      createdAt: DateTime.now(),
    ),
  ];

  bool _isThinking = false;
  bool _hasShownOfflineNotice = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? quickQuestion]) async {
    final text = (quickQuestion ?? _messageController.text).trim();
    if (text.isEmpty || _isThinking) return;

    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        createdAt: DateTime.now(),
      ));
      _isThinking = true;
    });
    _messageController.clear();
    _scrollToBottom();
    await _saveChatHistory();

    final answer = await _chatService.ask(text);

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(
        text: answer,
        isUser: false,
        createdAt: DateTime.now(),
      ));
      _isThinking = false;
    });
    await _saveChatHistory();
    if (_chatService.lastOnlineUnavailable && !_hasShownOfflineNotice) {
      _hasShownOfflineNotice = true;
      _showOfflineNotice();
    }
    _scrollToBottom();
  }

  void _showOfflineNotice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Internet Tidak Tersedia'),
        content: const Text(
          'Internet tidak tersedia. Jika ingin menggunakan fitur AI Chat untuk jawaban yang lebih detail dan tepat, hubungkan perangkat ke internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getString(_chatHistoryKey);
    if (rawHistory == null || rawHistory.isEmpty) return;

    try {
      final decoded = jsonDecode(rawHistory);
      if (decoded is! List) return;

      final history = decoded
          .whereType<Map>()
          .map((item) => _ChatMessage.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();

      if (history.isEmpty || !mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(history);
      });
      _scrollToBottom();
    } catch (_) {
      await prefs.remove(_chatHistoryKey);
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = _messages.length > 80
        ? _messages.sublist(_messages.length - 80)
        : _messages;

    await prefs.setString(
      _chatHistoryKey,
      jsonEncode(history.map((message) => message.toJson()).toList()),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'AI Kas',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Hapus History Chat',
            onPressed: _confirmClearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickQuestions(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isThinking && index == _messages.length) {
                  return const _TypingBubble();
                }
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildQuickQuestions() {
    final questions = [
      'Rangkum kas hari ini',
      'Analisis pengeluaran hari ini',
      'Bandingkan hari ini dan kemarin',
      'Pendapatan 7 hari terakhir',
      'Tren 30 hari terakhir',
      'Estimasi modal besok',
      'Beri rekomendasi kas',
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: questions
              .map(
                (question) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(question),
                    labelStyle: const TextStyle(fontSize: 12),
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.08),
                    side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.1)),
                    onPressed: () => _sendMessage(question),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus History Chat?'),
        content: const Text('Semua percakapan AI Kas yang tersimpan akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_chatHistoryKey);
              if (!mounted) return;
              setState(() {
                _messages
                  ..clear()
                  ..add(_ChatMessage(
                    text:
                        'Halo, aku asisten kas. Kamu bisa tanya ringkasan, pengeluaran, pemasukan, tren, perbandingan, transaksi terbesar, atau estimasi modal.',
                    isUser: false,
                    createdAt: DateTime.now(),
                  ));
              });
              Navigator.pop(context);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Tanya soal kas warung...',
                  filled: true,
                  fillColor: const Color(0xFFF1F4F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                onPressed: _isThinking ? null : () => _sendMessage(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  disabledBackgroundColor: Colors.blueGrey[100],
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isUser ? AppTheme.primaryBlue : Colors.white;
    final textColor = message.isUser ? Colors.white : Colors.black87;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(message.isUser ? 18 : 4),
      bottomRight: Radius.circular(message.isUser ? 4 : 18),
    );

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          '${message.text}\n\n${message.formattedTime}',
          style: TextStyle(color: textColor, fontSize: 14, height: 1.35),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Menganalisis data kas...',
          style: TextStyle(color: Colors.blueGrey, fontSize: 13),
        ),
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.createdAt,
  });

  final String text;
  final bool isUser;
  final DateTime createdAt;

  String get formattedTime {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(createdAt);
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'is_user': isUser,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    return _ChatMessage(
      text: json['text']?.toString() ?? '',
      isUser: json['is_user'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
