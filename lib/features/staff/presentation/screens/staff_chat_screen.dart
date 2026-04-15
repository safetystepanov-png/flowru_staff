import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';

class StaffChatScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffChatScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<StaffChatScreen> createState() => _StaffChatScreenState();
}

class _StaffChatScreenState extends State<StaffChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _sending = false;
  String? _error;

  List<_ChatMessage> _messages = [];
  String? _currentUserId;

  Uint8List? _pendingImageBytes;
  String? _pendingImageName;

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String get _seenKey => 'staff_chat_seen_${widget.establishmentId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<void> _markSeen() async {
    final prefs = await _sharedPrefs;
    await prefs.setInt(_seenKey, _messages.length);
  }

  Future<void> _loadCurrentUser() async {
    try {
      final token = await _token();

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/v1/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _currentUserId =
            data['id']?.toString() ?? data['user_id']?.toString() ?? '';
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadCurrentUser();
      final token = await _token();

      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/chat/messages?establishment_id=${widget.establishmentId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'chat load failed: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> raw;
      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        raw = decoded['items'] as List<dynamic>;
      } else {
        raw = [];
      }

      if (!mounted) return;

      setState(() {
        _messages = raw
            .map((e) => _ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });

      await _markSeen();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить чат';
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 42,
        maxWidth: 1600,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageName = file.name;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось выбрать изображение';
      });
    }
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImageBytes = null;
      _pendingImageName = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if ((text.isEmpty) && _pendingImageBytes == null) return;
    if (_sending) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final token = await _token();

      final effectiveText = _pendingImageBytes != null
          ? (text.isEmpty ? '📷 Изображение' : '$text\n📷 Изображение')
          : text;

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/chat/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
          'message_text': effectiveText,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'chat send failed: ${response.statusCode} ${response.body}',
        );
      }

      final localMessage = _ChatMessage(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        senderUserId: _currentUserId ?? '',
        senderName: 'Вы',
        messageText: text,
        createdAt: DateTime.now().toIso8601String(),
        localImageBytes: _pendingImageBytes,
        reactions: const [],
      );

      if (!mounted) return;

      setState(() {
        _messages = [..._messages, localMessage];
        _messageController.clear();
        _pendingImageBytes = null;
        _pendingImageName = null;
        _sending = false;
      });

      await _markSeen();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      Future.delayed(const Duration(milliseconds: 400), _load);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Не удалось отправить сообщение';
      });
    }
  }

  bool _isMine(_ChatMessage message) {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    return message.senderUserId == _currentUserId;
  }

  String _formatDate(String value) {
    if (value.isEmpty) return '';
    try {
      final dt = DateTime.parse(value).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mi';
    } catch (_) {
      return value;
    }
  }

  Future<void> _showReactionPicker(_ChatMessage message) async {
    final emojis = ['👍', '🔥', '❤️', '👏', '😂', '😮', '✅', '🎉'];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.90),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.94)),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: emojis
                      .map(
                        (emoji) => InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.of(context).pop();
                            _addLocalReaction(message.id, emoji);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: kStaffBlue.withOpacity(0.08),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _addLocalReaction(String messageId, String emoji) {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    final updated = [..._messages];
    final old = updated[idx];

    final reactions = [...old.reactions];
    final existing = reactions.indexWhere((r) => r.emoji == emoji);

    if (existing >= 0) {
      reactions[existing] = reactions[existing].copyWith(
        count: reactions[existing].count + 1,
      );
    } else {
      reactions.add(_ReactionItem(emoji: emoji, count: 1));
    }

    updated[idx] = old.copyWith(reactions: reactions);

    setState(() {
      _messages = updated;
    });
  }

  Widget _topCard() {
    return StaffGlassPanel(
      radius: 28,
      glowColor: kStaffBlue.withOpacity(0.10),
      child: Row(
        children: [
          const StaffGradientIcon(
            icon: CupertinoIcons.bubble_left_bubble_right_fill,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.establishmentName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kStaffInkPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Чат команды заведения',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kStaffInkSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(
              CupertinoIcons.refresh,
              color: kStaffInkPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    if (_error == null) return const SizedBox.shrink();

    return StaffGlassPanel(
      radius: 22,
      glowColor: Colors.redAccent.withOpacity(0.10),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: Colors.redAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB84C4C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return StaffGlassPanel(
      radius: 24,
      child: Column(
        children: [
          const StaffGradientIcon(
            icon: CupertinoIcons.chat_bubble_2_fill,
            size: 26,
          ),
          const SizedBox(height: 12),
          const Text(
            'Чат пока пустой',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Напиши первое сообщение для команды',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kStaffInkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reactionRow(_ChatMessage message, bool mine) {
    if (message.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        left: mine ? 40 : 0,
        right: mine ? 0 : 40,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: message.reactions
            .map(
              (r) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withOpacity(0.82),
                  border: Border.all(color: kStaffBorder),
                ),
                child: Text(
                  '${r.emoji} ${r.count}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kStaffInkPrimary,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _messageBubble(_ChatMessage message) {
    final mine = _isMine(message);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: MouseRegion(
          child: Row(
            mainAxisAlignment:
                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  child: _reactionFab(message),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.68,
                ),
                child: Column(
                  crossAxisAlignment:
                      mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(22),
                          topRight: const Radius.circular(22),
                          bottomLeft: Radius.circular(mine ? 22 : 8),
                          bottomRight: Radius.circular(mine ? 8 : 22),
                        ),
                        gradient: mine
                            ? const LinearGradient(
                                colors: [kStaffBlue, kStaffViolet],
                              )
                            : null,
                        color: mine ? null : Colors.white.withOpacity(0.84),
                        border: mine
                            ? null
                            : Border.all(color: Colors.white.withOpacity(0.94)),
                        boxShadow: [
                          BoxShadow(
                            color: (mine ? kStaffBlue : Colors.black)
                                .withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!mine)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                message.senderName.isEmpty
                                    ? 'Сотрудник'
                                    : message.senderName,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: kStaffInkSecondary,
                                ),
                              ),
                            ),
                          if (message.localImageBytes != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                message.localImageBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (message.messageText.trim().isNotEmpty)
                              const SizedBox(height: 10),
                          ],
                          if (message.messageText.trim().isNotEmpty)
                            Text(
                              message.messageText,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.42,
                                fontWeight: FontWeight.w700,
                                color: mine ? Colors.white : kStaffInkPrimary,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              _formatDate(message.createdAt),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: mine
                                    ? Colors.white.withOpacity(0.86)
                                    : kStaffInkSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _reactionRow(message, mine),
                  ],
                ),
              ),
              if (mine)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: _reactionFab(message),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reactionFab(_ChatMessage message) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showReactionPicker(message),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.86),
          border: Border.all(color: kStaffBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.smiley,
          size: 18,
          color: kStaffInkPrimary,
        ),
      ),
    );
  }

  Widget _pendingImagePreview() {
    if (_pendingImageBytes == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: StaffGlassPanel(
        radius: 22,
        glowColor: kStaffPink.withOpacity(0.10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                _pendingImageBytes!,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _pendingImageName ?? 'Изображение',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kStaffInkPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: _clearPendingImage,
              icon: const Icon(CupertinoIcons.xmark_circle_fill),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pendingImagePreview(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: Colors.white.withOpacity(0.88),
                  border: Border.all(color: Colors.white.withOpacity(0.94)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _pickImage,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: kStaffPink.withOpacity(0.10),
                        ),
                        child: const Icon(
                          CupertinoIcons.photo,
                          color: kStaffInkPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Сообщение',
                          hintStyle: TextStyle(
                            color: kStaffInkSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [kStaffBlue, kStaffViolet],
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _sending ? null : _sendMessage,
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: Center(
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    CupertinoIcons.arrow_up,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _messagesList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(kStaffViolet),
        ),
      );
    }

    if (_messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _topCard(),
          const SizedBox(height: 14),
          _errorCard(),
          const SizedBox(height: 14),
          _emptyState(),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _topCard(),
        const SizedBox(height: 14),
        _errorCard(),
        if (_error != null) const SizedBox(height: 14),
        ..._messages.map(_messageBubble),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStaffBgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Чат заведения',
          style: TextStyle(
            color: kStaffInkPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: kStaffInkPrimary),
      ),
      body: StaffScreenBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _messagesList()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _composer(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String id;
  final String senderUserId;
  final String senderName;
  final String messageText;
  final String createdAt;
  final Uint8List? localImageBytes;
  final List<_ReactionItem> reactions;

  _ChatMessage({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.messageText,
    required this.createdAt,
    required this.localImageBytes,
    required this.reactions,
  });

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    List<_ReactionItem> parseReactions(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((e) => _ReactionItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }

    return _ChatMessage(
      id: json['message_id']?.toString() ?? json['id']?.toString() ?? '',
      senderUserId: json['sender_user_id']?.toString() ??
          json['user_id']?.toString() ??
          '',
      senderName: json['sender_name']?.toString() ??
          json['full_name']?.toString() ??
          json['username']?.toString() ??
          '',
      messageText: json['message_text']?.toString() ??
          json['text']?.toString() ??
          '',
      createdAt: json['created_at']?.toString() ?? '',
      localImageBytes: null,
      reactions: parseReactions(json['reactions']),
    );
  }

  _ChatMessage copyWith({
    List<_ReactionItem>? reactions,
  }) {
    return _ChatMessage(
      id: id,
      senderUserId: senderUserId,
      senderName: senderName,
      messageText: messageText,
      createdAt: createdAt,
      localImageBytes: localImageBytes,
      reactions: reactions ?? this.reactions,
    );
  }
}

class _ReactionItem {
  final String emoji;
  final int count;

  const _ReactionItem({
    required this.emoji,
    required this.count,
  });

  factory _ReactionItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 1;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 1;
    }

    return _ReactionItem(
      emoji: json['emoji']?.toString() ?? '👍',
      count: parseInt(json['count']),
    );
  }

  _ReactionItem copyWith({
    String? emoji,
    int? count,
  }) {
    return _ReactionItem(
      emoji: emoji ?? this.emoji,
      count: count ?? this.count,
    );
  }
}