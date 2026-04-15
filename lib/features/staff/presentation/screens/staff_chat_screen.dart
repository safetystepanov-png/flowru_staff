import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';

const Color kChatMintTop = Color(0xFF0CB7B3);
const Color kChatMintMid = Color(0xFF08A9AB);
const Color kChatMintBottom = Color(0xFF067D87);
const Color kChatMintDeep = Color(0xFF055E66);

const Color kChatAccent = Color(0xFFFFA11D);
const Color kChatAccentSoft = Color(0xFFFFC45E);

const Color kChatCard = Color(0xCCFFFFFF);
const Color kChatCardStrong = Color(0xE8FFFFFF);
const Color kChatStroke = Color(0xA6FFFFFF);

const Color kChatInk = Color(0xFF103238);
const Color kChatInkSoft = Color(0xFF58767D);
const Color kChatShadow = Color(0x22062E36);

const Color kChatBlue = Color(0xFF4E7CFF);
const Color kChatPink = Color(0xFFFF5F8F);
const Color kChatViolet = Color(0xFF7A63FF);

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

class _StaffChatScreenState extends State<StaffChatScreen>
    with TickerProviderStateMixin {
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

  late final AnimationController _bgController;
  late final AnimationController _introController;

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String get _seenKey => 'staff_chat_seen_${widget.establishmentId}';

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6800),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _bgController.dispose();
    _introController.dispose();
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
      _introController.forward(from: 0);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить чат';
      });
      _introController.forward(from: 0);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 140,
      duration: const Duration(milliseconds: 280),
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

    if (text.isEmpty && _pendingImageBytes == null) return;
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
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(28),
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
                              color: kChatBlue.withOpacity(0.08),
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

  Widget _stagger({
    required int index,
    required Widget child,
  }) {
    final start = (index * 0.08).clamp(0.0, 0.82);
    final end = (start + 0.24).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _softBlob({
    required double width,
    required double height,
    required List<Color> colors,
  }) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _background() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final t = _bgController.value;
        final shiftA = math.sin(t * math.pi * 2) * 18;
        final shiftB = math.cos(t * math.pi * 2) * 12;
        final rotate = math.sin(t * math.pi * 2) * 0.03;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kChatMintTop,
                    kChatMintMid,
                    kChatMintBottom,
                    kChatMintDeep,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.40, 0.78, 1.0],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.07),
                        Colors.transparent,
                        Colors.black.withOpacity(0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -84 + shiftA,
              right: -36,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 280,
                  height: 280,
                  colors: [
                    Colors.white.withOpacity(0.16),
                    kChatAccent.withOpacity(0.12),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -64,
              top: 210 + shiftB,
              child: Transform.rotate(
                angle: -rotate,
                child: _softBlob(
                  width: 220,
                  height: 220,
                  colors: [
                    Colors.white.withOpacity(0.10),
                    kChatBlue.withOpacity(0.07),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 48 - shiftA,
              right: -18,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 210,
                  height: 210,
                  colors: [
                    kChatAccentSoft.withOpacity(0.10),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _topIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 18,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard() {
    return _GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const _FloatingGlyph(
            icon: CupertinoIcons.chat_bubble_2,
            mainColor: kChatBlue,
            secondaryColor: kChatViolet,
            size: 82,
            iconSize: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.establishmentName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kChatInk,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Чат команды заведения',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kChatInkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _InlineIconButton(
            icon: CupertinoIcons.refresh,
            onTap: _load,
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    if (_error == null) return const SizedBox.shrink();

    return _GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: Color(0xFFE85B63),
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
    return const _GlassCard(
      radius: 28,
      padding: EdgeInsets.all(22),
      child: Column(
        children: [
          _EmptyOrb(),
          SizedBox(height: 14),
          Text(
            'Чат пока пустой',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kChatInk,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Напиши первое сообщение для команды',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kChatInkSoft,
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
                  color: Colors.white.withOpacity(0.84),
                  border: Border.all(color: const Color(0xFFE7EEF0)),
                ),
                child: Text(
                  '${r.emoji} ${r.count}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kChatInk,
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
                        topLeft: const Radius.circular(24),
                        topRight: const Radius.circular(24),
                        bottomLeft: Radius.circular(mine ? 24 : 8),
                        bottomRight: Radius.circular(mine ? 8 : 24),
                      ),
                      gradient: mine
                          ? const LinearGradient(
                              colors: [kChatBlue, kChatViolet],
                            )
                          : null,
                      color: mine ? null : Colors.white.withOpacity(0.88),
                      border: mine
                          ? null
                          : Border.all(color: Colors.white.withOpacity(0.94)),
                      boxShadow: [
                        BoxShadow(
                          color: (mine ? kChatBlue : Colors.black)
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
                                color: kChatInkSoft,
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
                              color: mine ? Colors.white : kChatInk,
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
                                  : kChatInkSoft,
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
          border: Border.all(color: const Color(0xFFE7EEF0)),
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
          color: kChatInk,
        ),
      ),
    );
  }

  Widget _pendingImagePreview() {
    if (_pendingImageBytes == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _GlassCard(
        radius: 24,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                _pendingImageBytes!,
                width: 56,
                height: 56,
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
                  color: kChatInk,
                ),
              ),
            ),
            IconButton(
              onPressed: _clearPendingImage,
              icon: const Icon(
                CupertinoIcons.xmark_circle_fill,
                color: kChatInkSoft,
              ),
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
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Colors.white.withOpacity(0.90),
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: kChatPink.withOpacity(0.10),
                        ),
                        child: const Icon(
                          CupertinoIcons.photo,
                          color: kChatInk,
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
                            color: kChatInkSoft,
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
                          colors: [kChatBlue, kChatViolet],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kChatBlue.withOpacity(0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _sending ? null : _sendMessage,
                        child: SizedBox(
                          width: 48,
                          height: 48,
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
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _stagger(index: 0, child: _headerCard()),
          const SizedBox(height: 14),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(kChatViolet),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _stagger(index: 0, child: _headerCard()),
          const SizedBox(height: 14),
          _stagger(index: 1, child: _errorCard()),
          if (_error != null) const SizedBox(height: 14),
          _stagger(index: 2, child: _emptyState()),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _stagger(index: 0, child: _headerCard()),
        const SizedBox(height: 14),
        _stagger(index: 1, child: _errorCard()),
        if (_error != null) const SizedBox(height: 14),
        ..._messages.asMap().entries.map(
          (entry) => _stagger(
            index: entry.key + 2,
            child: _messageBubble(entry.value),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kChatMintTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Чат заведения',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _topIconButton(
              icon: CupertinoIcons.refresh,
              onTap: _load,
            ),
          ),
        ],
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            _background(),
            SafeArea(
              top: false,
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
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const _GlassCard({
    required this.child,
    required this.padding,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: [
                kChatCardStrong,
                kChatCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kChatStroke),
            boxShadow: [
              BoxShadow(
                color: kChatShadow.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InlineIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _InlineIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.72),
          border: Border.all(color: Colors.white.withOpacity(0.72)),
        ),
        child: Icon(
          icon,
          color: kChatInk,
          size: 18,
        ),
      ),
    );
  }
}

class _EmptyOrb extends StatelessWidget {
  const _EmptyOrb();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  kChatBlue.withOpacity(0.18),
                  kChatViolet.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.92),
            ),
            child: const Icon(
              CupertinoIcons.chat_bubble_2,
              color: kChatInkSoft,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingGlyph extends StatelessWidget {
  final IconData icon;
  final Color mainColor;
  final Color secondaryColor;
  final double size;
  final double iconSize;

  const _FloatingGlyph({
    required this.icon,
    required this.mainColor,
    required this.secondaryColor,
    this.size = 76,
    this.iconSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  mainColor.withOpacity(0.22),
                  secondaryColor.withOpacity(0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: size * 0.74,
            height: size * 0.74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.86),
              boxShadow: [
                BoxShadow(
                  color: mainColor.withOpacity(0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.54,
            height: size * 0.54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [mainColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          Positioned(
            top: size * 0.11,
            right: size * 0.14,
            child: Container(
              width: size * 0.14,
              height: size * 0.14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.90),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  const _Pressable({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _tap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _tap,
      child: AnimatedScale(
        scale: _pressed ? 0.982 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
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