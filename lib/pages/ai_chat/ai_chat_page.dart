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
  final List<_ChatMessage> _messages = [];

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('Mode Offline'),
          ],
        ),
        content: const Text(
          'Koneksi internet tidak terdeteksi. Hubungkan ke internet untuk mendapatkan analisis kas yang lebih detail dan akurat dari AI.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
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
          .map((item) => _ChatMessage.fromJson(Map<String, dynamic>.from(item)))
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Obrolan?'),
        content: const Text(
          'Semua riwayat percakapan dengan AI Kas akan dihapus secara permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Batal', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_chatHistoryKey);
              if (!mounted) return;
              setState(() {
                _messages.clear();
              });
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _ChatHeader(onClearPressed: _messages.isNotEmpty ? _confirmClearHistory : null),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const _WelcomeCard()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isThinking && index == _messages.length) {
                        return const _TypingBubble();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
          ),
          _buildQuickQuestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildQuickQuestions() {
    final colorScheme = Theme.of(context).colorScheme;
    final questions = [
      {'text': 'Rangkum kas hari ini', 'icon': Icons.summarize_rounded},
      {'text': 'Analisis pengeluaran', 'icon': Icons.trending_down_rounded},
      {'text': 'Bandingkan hari ini & kemarin', 'icon': Icons.compare_arrows_rounded},
      {'text': 'Pendapatan 7 hari', 'icon': Icons.date_range_rounded},
      {'text': 'Tren 30 hari', 'icon': Icons.show_chart_rounded},
      {'text': 'Estimasi modal besok', 'icon': Icons.lightbulb_outline_rounded},
      {'text': 'Rekomendasi kas', 'icon': Icons.recommend_rounded},
    ];

    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: questions
              .map(
                (q) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _QuickQuestionChip(
                    label: q['text'] as String,
                    icon: q['icon'] as IconData,
                    onTap: _isThinking ? null : () => _sendMessage(q['text'] as String),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Tanya tentang kas warung...',
                    hintStyle: TextStyle(fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: _isThinking || _messageController.text.isEmpty
                    ? colorScheme.surfaceContainerHighest
                    : AppTheme.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _isThinking || _messageController.text.isEmpty
                      ? colorScheme.onSurfaceVariant
                      : Colors.white,
                  size: 20,
                ),
                onPressed: _isThinking ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= WIDGETS TAMBAHAN =================

class _ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onClearPressed;

  const _ChatHeader({this.onClearPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: true,
      title: Column(
        children: [
          Text(
            'AI Kas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.onSurfaceVariant),
          ),
          Text(
            'Asisten keuangan cerdas warungmu',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        if (onClearPressed != null)
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Hapus Riwayat',
            onPressed: onClearPressed,
            color: colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_rounded, size: 48, color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 24),
              const Text(
                'Halo! Aku AI Kas 👋',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Aku siap membantu menganalisis pemasukan, pengeluaran, membaca tren, hingga memberikan estimasi modal warungmu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_circle, color: Colors.amber.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Text('Coba tanyakan:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _ExampleText('Berapa total pemasukan hari ini?'),
                    const _ExampleText('Apakah ada pengeluaran yang janggal?'),
                    const _ExampleText('Berapa estimasi modal untuk besok?'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExampleText extends StatelessWidget {
  final String text;
  const _ExampleText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) const _AiAvatar(),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primaryBlue : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : colorScheme.onSurface,
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message.formattedTime,
                    style: TextStyle(
                      color: isUser ? Colors.white70 : colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AiAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Menganalisis kas...',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.smart_toy_rounded, size: 18, color: AppTheme.primaryBlue),
    );
  }
}

class _QuickQuestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _QuickQuestionChip({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryBlue),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
              ),
            ],
          ),
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
    return DateFormat('HH:mm', 'id_ID').format(createdAt);
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
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}