import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
const Color kChatGreen = Color(0xFF1FCB7B);
const Color kChatRed = Color(0xFFFF6A5E);
const Color kChatAmber = Color(0xFFFFA11D);

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
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  String? _recordingFilePath;
  bool _loading = true;
  bool _sending = false;
  bool _showScrollToBottom = false;
  bool _isRecordingVoice = false;
  bool _selectionMode = false;
  bool _showTypingMock = false;
  String? _error;

  List<_ChatMessage> _messages = [];
  String? _currentUserId;

  Uint8List? _pendingImageBytes;
  String? _pendingImageName;
  String? _pendingImagePath;

  String? _editingMessageId;
  String _searchQuery = '';
  String? _replyingToMessageId;
  String? _replyingToSenderName;
  String? _replyingToText;

  String? _highlightedMessageId;
  String? _pinnedMessageId;
  String _draftText = '';
  String? _firstUnreadMessageId;

  final Set<String> _selectedMessageIds = <String>{};
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};

  Timer? _recordingTimer;
  Timer? _highlightTimer;
  Timer? _typingTimer;
  int _recordingSeconds = 0;

  late final AnimationController _bgController;
  late final AnimationController _introController;

  static const List<String> _emojiPalette = <String>[
    '👍', '❤️', '🔥', '👏', '😂', '😍', '😮', '😎', '🙏', '✅',
    '🎉', '💯', '👀', '🤝', '👌', '😢', '😡', '🤔', '🙌', '💥',
    '🥳', '😴', '👎', '💔', '😅', '😬', '🤩', '😐', '🤯', '💪',
    '🫶', '🫡',
  ];

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

    _scrollController.addListener(_onScrollChanged);
    _messageController.addListener(_onComposerChanged);
    _init();
  }

  Future<void> _init() async {
    await _refreshMessagesSilently(keepScrollOffset: true);
  }

  void _onComposerChanged() {
    if (_editingMessageId == null) {
      _draftText = _messageController.text;
    }

    final shouldShowTyping = _messageController.text.trim().isNotEmpty &&
        !_sending &&
        !_isRecordingVoice;

    if (shouldShowTyping != _showTypingMock && mounted) {
      setState(() {
        _showTypingMock = shouldShowTyping;
      });
    }

    _typingTimer?.cancel();
    if (shouldShowTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (_messageController.text.trim().isEmpty) {
          setState(() {
            _showTypingMock = false;
          });
        }
      });
    }

    if (mounted) setState(() {});
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;

    final distance =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    final shouldShow = distance > 280;

    if (shouldShow != _showScrollToBottom && mounted) {
      setState(() {
        _showScrollToBottom = shouldShow;
      });
    }

    if (distance < 80) {
      _markVisibleMessagesAsRead();
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _highlightTimer?.cancel();
    _typingTimer?.cancel();
    _messageController.removeListener(_onComposerChanged);
    _messageController.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _bgController.dispose();
    _introController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  String _extractErrorText(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error;
        }
      }
    } catch (_) {}
    return 'Ошибка ${response.statusCode}';
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

  Future<void> _load({
    bool silent = false,
    bool keepScrollOffset = false,
    bool jumpToBottomAfter = true,
  }) async {
    final double? previousOffset =
        keepScrollOffset && _scrollController.hasClients
            ? _scrollController.offset
            : null;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      _error = null;
    }

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
        throw Exception(_extractErrorText(response));
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

      final serverMessages = raw
          .map((e) => _ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();

      final localPending = _messages
          .where((m) => m.isLocalOnly && m.status == _MessageStatus.sending)
          .toList();

      String? pinnedId;
      String? unreadId;
      for (final m in serverMessages.reversed) {
        if (m.isPinned) {
          pinnedId = m.id;
          break;
        }
      }
      for (final m in serverMessages) {
        if (!m.isMineLocal(_currentUserId) && !m.isRead) {
          unreadId = m.id;
          break;
        }
      }
      pinnedId ??= _pinnedMessageId;

      setState(() {
        _messages = [...serverMessages, ...localPending];
        _pinnedMessageId = pinnedId;
        _firstUnreadMessageId = unreadId;
        _loading = false;
      });

      if (!silent) {
        if (!silent) {
        _introController.forward(from: 0);
      }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        if (keepScrollOffset && previousOffset != null && _scrollController.hasClients) {
          final max = _scrollController.position.maxScrollExtent;
          final target = previousOffset.clamp(0.0, max);
          _scrollController.jumpTo(target);
        } else if (jumpToBottomAfter) {
          _scrollToBottom(jump: true);
        }

        await _markDeliveredToBackend();
        _markVisibleMessagesAsRead();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _introController.forward(from: 0);
    }
  }

  Future<void> _refreshMessagesSilently({bool keepScrollOffset = true}) async {
    await _load(
      silent: true,
      keepScrollOffset: keepScrollOffset,
      jumpToBottomAfter: !keepScrollOffset,
    );
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent + 180;
    if (jump) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  int get _unreadCount {
    int count = 0;
    for (final m in _messages) {
      if (!_isMine(m) && !m.isRead && !m.isDeleted) {
        count++;
      }
    }
    return count;
  }

  void _markVisibleMessagesAsRead() {
    if (!mounted) return;

    final unreadIds = _messages
        .where((m) => !_isMine(m) && !m.isRead && !m.isDeleted)
        .map((m) => m.id)
        .toList();

    if (unreadIds.isEmpty) return;

    final updated = <_ChatMessage>[];
    for (final m in _messages) {
      if (!_isMine(m) && !m.isRead && !m.isDeleted) {
        updated.add(m.copyWith(isRead: true, status: _MessageStatus.read));
      } else {
        updated.add(m);
      }
    }

    setState(() {
      _messages = updated;
      _firstUnreadMessageId = null;
    });

    _sendReadToBackend(unreadIds);
  }

  void _markOneMessageAsRead(String messageId) {
    if (!mounted) return;

    bool changed = false;
    final updated = <_ChatMessage>[];

    for (final m in _messages) {
      if (m.id == messageId && !_isMine(m) && !m.isRead) {
        updated.add(m.copyWith(isRead: true, status: _MessageStatus.read));
        changed = true;
      } else {
        updated.add(m);
      }
    }

    if (!changed) return;

    String? firstUnread;
    for (final m in updated) {
      if (!_isMine(m) && !m.isRead && !m.isDeleted) {
        firstUnread = m.id;
        break;
      }
    }

    setState(() {
      _messages = updated;
      _firstUnreadMessageId = firstUnread;
    });
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 74,
        maxWidth: 1800,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageName = file.name;
        _pendingImagePath = file.path;
      });
      _messageFocusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось выбрать изображение';
      });
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 76,
        maxWidth: 1800,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageName = file.name.isEmpty ? 'camera_image.jpg' : file.name;
        _pendingImagePath = file.path;
      });
      _messageFocusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось открыть камеру';
      });
    }
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImageBytes = null;
      _pendingImageName = null;
      _pendingImagePath = null;
      _pendingImagePath = null;
    });
  }

  void _startReply(_ChatMessage message) {
    final previewText = _messagePreview(message);

    setState(() {
      _replyingToMessageId = message.id;
      _replyingToSenderName = message.senderName.trim().isEmpty
          ? 'Сотрудник'
          : message.senderName.trim();
      _replyingToText = previewText;
    });
    _messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessageId = null;
      _replyingToSenderName = null;
      _replyingToText = null;
    });
  }

  String _messagePreview(_ChatMessage message) {
    if (message.isDeleted) return 'Сообщение';
    if (message.type == _AttachmentType.file) {
      return '📎 ${message.fileName ?? 'Файл'}';
    }
    if (message.type == _AttachmentType.voice) {
      return '🎤 Голосовое сообщение';
    }
    if (message.type == _AttachmentType.image) {
      return message.messageText.trim().isNotEmpty
          ? message.messageText.trim()
          : '📷 Фото';
    }
    if (message.messageText.trim().isNotEmpty) {
      return message.messageText.trim();
    }
    return 'Сообщение';
  }

  bool _isMine(_ChatMessage message) {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    return message.senderUserId == _currentUserId;
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    final Uint8List? pendingImageBytes = _pendingImageBytes;
    final String? pendingImageName = _pendingImageName;
    final String? pendingImagePath = _pendingImagePath;
    final String? replyingToMessageId = _replyingToMessageId;
    final String? replyingToSenderName = _replyingToSenderName;
    final String? replyingToText = _replyingToText;

    if (text.isEmpty && pendingImageBytes == null) return;
    if (_sending) return;

    if (_editingMessageId != null) {
      await _saveEditedMessage();
      return;
    }

    final String localMessageId =
        'local_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(99999)}';

    final _ChatMessage optimisticMessage = _ChatMessage(
      id: localMessageId,
      senderUserId: _currentUserId ?? 'me',
      senderName: 'Вы',
      messageText: text,
      createdAt: DateTime.now().toIso8601String(),
      localImageBytes: pendingImageBytes,
      attachmentUrl: null,
      fileName: pendingImageBytes != null ? (pendingImageName ?? 'image.jpg') : null,
      reactions: const [],
      isDeleted: false,
      isEdited: false,
      replyToMessageId: replyingToMessageId,
      replySenderName: replyingToSenderName,
      replyText: replyingToText,
      isPinned: false,
      type: pendingImageBytes != null ? _AttachmentType.image : _AttachmentType.text,
      voiceDurationSeconds: null,
      isLocalOnly: true,
      status: _MessageStatus.sending,
      isRead: false,
    );

    setState(() {
      _sending = true;
      _error = null;
      _showTypingMock = false;
      _draftText = '';
      _messageController.clear();
      _pendingImageBytes = null;
      _pendingImageName = null;
      _replyingToMessageId = null;
      _replyingToSenderName = null;
      _replyingToText = null;
      _messages = [..._messages, optimisticMessage];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      final token = await _token();

      if (pendingImageBytes != null) {
        final uri = Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/chat/messages/upload-image',
        );

        final request = http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'application/json'
          ..fields['establishment_id'] = widget.establishmentId.toString()
          ;

        if (pendingImagePath != null && pendingImagePath.trim().isNotEmpty) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              pendingImagePath,
              filename: pendingImageName ?? _fileNameFromPath(pendingImagePath),
              contentType: _mediaTypeForPath(
                pendingImagePath,
                fallbackType: 'image',
                fallbackSubtype: 'jpeg',
              ),
            ),
          );
        } else {
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              pendingImageBytes,
              filename: pendingImageName ?? 'chat_image.jpg',
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }

        if (text.isNotEmpty) {
          request.fields['message_text'] = text;
        }
        if (replyingToMessageId != null) {
          request.fields['reply_to_message_id'] = replyingToMessageId;
        }

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception(_extractErrorText(response));
        }
      } else {
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/v1/staff/chat/messages'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'establishment_id': widget.establishmentId,
            'message_text': text,
            if (replyingToMessageId != null)
              'reply_to_message_id': replyingToMessageId,
          }),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception(_extractErrorText(response));
        }
      }

      if (!mounted) return;

      setState(() {
        _messages = _messages.where((m) => m.id != localMessageId).toList();
        _sending = false;
      });

      await _load(silent: true, keepScrollOffset: false, jumpToBottomAfter: true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages = _messages.where((m) => m.id != localMessageId).toList();
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _messageController.text = text;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
        _pendingImageBytes = pendingImageBytes;
        _pendingImageName = pendingImageName;
        _pendingImagePath = pendingImagePath;
        _replyingToMessageId = replyingToMessageId;
        _replyingToSenderName = replyingToSenderName;
        _replyingToText = replyingToText;
        if (_messageController.text.trim().isNotEmpty) {
          _draftText = _messageController.text;
        }
      });

      _messageFocusNode.requestFocus();
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecordingVoice) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        setState(() {
          _error = 'Нет доступа к микрофону';
        });
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecordingVoice = true;
        _recordingSeconds = 0;
        _error = null;
        _showTypingMock = false;
        _recordingFilePath = filePath;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _recordingSeconds += 1;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось начать запись: ${e.toString()}';
        _isRecordingVoice = false;
        _recordingSeconds = 0;
        _recordingFilePath = null;
      });
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();

    try {
      if (await _audioRecorder.isRecording()) {
        final path = await _audioRecorder.stop();
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
      _recordingFilePath = null;
    });
  }

  Future<void> _stopAndSendVoiceRecording() async {
    _recordingTimer?.cancel();
    final int seconds = _recordingSeconds <= 0 ? 1 : _recordingSeconds;

    String? recordedPath;

    try {
      recordedPath = await _audioRecorder.stop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = false;
        _recordingSeconds = 0;
        _recordingFilePath = null;
        _error = 'Не удалось завершить запись: ${e.toString()}';
      });
      return;
    }

    recordedPath ??= _recordingFilePath;

    if (recordedPath == null || recordedPath.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = false;
        _recordingSeconds = 0;
        _recordingFilePath = null;
        _error = 'Файл голосового сообщения не найден';
      });
      return;
    }

    final file = File(recordedPath);
    if (!await file.exists()) {
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = false;
        _recordingSeconds = 0;
        _recordingFilePath = null;
        _error = 'Записанный файл не найден';
      });
      return;
    }

    if (!mounted) return;

    final String localMessageId =
        'local_voice_${DateTime.now().microsecondsSinceEpoch}';

    final optimisticMessage = _ChatMessage(
      id: localMessageId,
      senderUserId: _currentUserId ?? 'me',
      senderName: 'Вы',
      messageText: '',
      createdAt: DateTime.now().toIso8601String(),
      localImageBytes: null,
      attachmentUrl: null,
      fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      reactions: const [],
      isDeleted: false,
      isEdited: false,
      replyToMessageId: _replyingToMessageId,
      replySenderName: _replyingToSenderName,
      replyText: _replyingToText,
      isPinned: false,
      type: _AttachmentType.voice,
      voiceDurationSeconds: seconds,
      isLocalOnly: true,
      status: _MessageStatus.sending,
      isRead: false,
    );

    final replyToMessageId = _replyingToMessageId;
    final replySenderName = _replyingToSenderName;
    final replyText = _replyingToText;

    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
      _recordingFilePath = null;
      _replyingToMessageId = null;
      _replyingToSenderName = null;
      _replyingToText = null;
      _error = null;
      _messages = [..._messages, optimisticMessage];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      final token = await _token();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/chat/messages/audio'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/json'
        ..fields['establishment_id'] = widget.establishmentId.toString()
        ..fields['message_text'] = ''
        ..files.add(
          await http.MultipartFile.fromPath(
            'audio',
            recordedPath,
            filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
            contentType: _mediaTypeForPath(
              recordedPath,
              fallbackType: 'audio',
              fallbackSubtype: 'mp4',
            ),
          ),
        );

      if (replyToMessageId != null) {
        request.fields['reply_to_message_id'] = replyToMessageId;
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_extractErrorText(response));
      }

      if (!mounted) return;

      setState(() {
        _messages = _messages.where((m) => m.id != localMessageId).toList();
      });

      await _refreshMessagesSilently(keepScrollOffset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => m.id != localMessageId).toList();
        _replyingToMessageId = replyToMessageId;
        _replyingToSenderName = replySenderName;
        _replyingToText = replyText;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> _startEditMessage(_ChatMessage message) async {
    setState(() {
      _editingMessageId = message.id;
      _messageController.text = message.messageText;
      _replyingToMessageId = null;
      _replyingToSenderName = null;
      _replyingToText = null;
      _showTypingMock = false;
    });
    _messageFocusNode.requestFocus();
    await Future.delayed(const Duration(milliseconds: 120));
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _error = null;
      _messageController.text = _draftText;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });
    _messageFocusNode.requestFocus();
  }

  Future<void> _saveEditedMessage() async {
    final messageId = _editingMessageId;
    final text = _messageController.text.trim();
    if (messageId == null || text.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final token = await _token();
      final response = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/chat/messages/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
          'message_text': text,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(_extractErrorText(response));
      }

      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        final updated = [..._messages];
        updated[index] = updated[index].copyWith(
          messageText: text,
          isEdited: true,
        );
        _messages = updated;
      }

      if (!mounted) return;
      setState(() {
        _editingMessageId = null;
        _messageController.clear();
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _deleteForMe(_ChatMessage message) async {
    final previousMessages = List<_ChatMessage>.from(_messages);

    if (message.isLocalOnly) {
      setState(() {
        _messages = _messages.where((m) => m.id != message.id).toList();
      });
      return;
    }

    setState(() {
      _messages = _messages.where((m) => m.id != message.id).toList();
    });

    try {
      final token = await _token();
      final response = await http.delete(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/chat/messages/${message.id}?for_all=false&establishment_id=${widget.establishmentId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(_extractErrorText(response));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = previousMessages;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _deleteForAll(_ChatMessage message) async {
    final previousMessages = List<_ChatMessage>.from(_messages);

    if (message.isLocalOnly) {
      setState(() {
        _messages = _messages.where((m) => m.id != message.id).toList();
      });
      return;
    }

    setState(() {
      _messages = _messages.where((m) => m.id != message.id).toList();
    });

    try {
      final token = await _token();
      final response = await http.delete(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/chat/messages/${message.id}?for_all=true&establishment_id=${widget.establishmentId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(_extractErrorText(response));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = previousMessages;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showDeleteSheet(_ChatMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.96)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Удалить сообщение',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: kChatInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_isMine(message) && !message.isLocalOnly)
                      _sheetAction(
                        icon: CupertinoIcons.eye_slash,
                        color: kChatBlue,
                        title: 'Удалить у себя',
                        onTap: () {
                          Navigator.of(context).pop();
                          _deleteForMe(message);
                        },
                      ),
                    if (_isMine(message) || message.isLocalOnly) ...[
                      if (!_isMine(message) && !message.isLocalOnly)
                        const SizedBox(height: 8),
                      _sheetAction(
                        icon: CupertinoIcons.delete_solid,
                        color: kChatRed,
                        title: 'Удалить у всех',
                        onTap: () {
                          Navigator.of(context).pop();
                          _deleteForAll(message);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleReaction(_ChatMessage message, String emoji) async {
    if (message.isLocalOnly) return;

    try {
      final token = await _token();
      final response = await http.post(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/chat/messages/${message.id}/react',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
          'emoji': emoji,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(_extractErrorText(response));
      }
      await _refreshMessagesSilently(keepScrollOffset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openEmojiPanel(_ChatMessage message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.18),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _emojiPalette.map((emoji) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        Navigator.of(dialogContext).pop();
                        await _toggleReaction(message, emoji);
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: kChatBlue.withOpacity(0.06),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 21),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _flashMessageHighlight(String messageId) {
    _highlightTimer?.cancel();
    setState(() {
      _highlightedMessageId = messageId;
    });
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _highlightedMessageId = null;
      });
    });
  }

  Future<void> _scrollToMessageById(String? messageId) async {
    if (messageId == null || messageId.trim().isEmpty) return;
    await Future.delayed(const Duration(milliseconds: 60));
    final key = _messageKeys[messageId];
    final contextToScroll = key?.currentContext;
    if (contextToScroll != null) {
      await Scrollable.ensureVisible(
        contextToScroll,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
      _markOneMessageAsRead(messageId);
      _flashMessageHighlight(messageId);
    }
  }

  Future<void> _jumpToFirstUnread() async {
    await _scrollToMessageById(_firstUnreadMessageId);
  }

  _ChatMessage? _getPinnedMessage() {
    if (_pinnedMessageId != null) {
      for (final m in _messages) {
        if (m.id == _pinnedMessageId) return m;
      }
    }
    for (final m in _messages.reversed) {
      if (m.isPinned) return m;
    }
    return null;
  }

  List<_ChatMessage> _filteredMessages() {
    return _messages.where(_matchesSearch).toList();
  }

  bool _matchesSearch(_ChatMessage message) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return message.messageText.toLowerCase().contains(q) ||
        message.senderName.toLowerCase().contains(q) ||
        (message.replyText?.toLowerCase().contains(q) ?? false) ||
        (message.replySenderName?.toLowerCase().contains(q) ?? false) ||
        (message.fileName?.toLowerCase().contains(q) ?? false);
  }

  void _jumpToSearchResult() {
    final filtered = _filteredMessages();
    if (filtered.isEmpty) return;
    _scrollToMessageById(filtered.last.id);
  }

  void _enterSelectionMode(_ChatMessage message) {
    setState(() {
      _selectionMode = true;
      _selectedMessageIds.add(message.id);
    });
  }

  void _toggleSelection(_ChatMessage message) {
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
      if (_selectedMessageIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _clearSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  List<_ChatMessage> _selectedMessages() {
    return _messages
        .where((m) => _selectedMessageIds.contains(m.id))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _copyMessageText(_ChatMessage message) async {
    final String text = _messagePreview(message).trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Текст сообщения скопирован'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _togglePinnedMessageLocal(_ChatMessage message) async {
    final bool shouldPin = !(message.isPinned || _pinnedMessageId == message.id);

    try {
      final token = await _token();

      final response = await http.post(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/chat/messages/${message.id}/pin',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
          'is_pinned': shouldPin,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_extractErrorText(response));
      }

      if (!mounted) return;

      setState(() {
        final updated = [..._messages];

        for (int i = 0; i < updated.length; i++) {
          if (updated[i].isPinned) {
            updated[i] = updated[i].copyWith(isPinned: false);
          }
        }

        final index = updated.indexWhere((m) => m.id == message.id);
        if (index >= 0) {
          updated[index] = updated[index].copyWith(isPinned: shouldPin);
        }

        _messages = updated;
        _pinnedMessageId = shouldPin ? message.id : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _deleteSelectedMessages() async {
    final selected = _selectedMessages();
    if (selected.isEmpty) return;

    for (final message in selected) {
      if (message.isLocalOnly || _isMine(message)) {
        await _deleteForAll(message);
      } else {
        await _deleteForMe(message);
      }
    }

    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _sendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final path = picked.path;
      if (path == null || path.isEmpty) {
        setState(() {
          _error = 'Не удалось получить путь к файлу';
        });
        return;
      }

      final localMessageId =
          'local_file_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(99999)}';

      final optimistic = _ChatMessage(
        id: localMessageId,
        senderUserId: _currentUserId ?? 'me',
        senderName: 'Вы',
        messageText: '',
        createdAt: DateTime.now().toIso8601String(),
        localImageBytes: null,
        attachmentUrl: null,
        fileName: picked.name,
        reactions: const [],
        isDeleted: false,
        isEdited: false,
        replyToMessageId: _replyingToMessageId,
        replySenderName: _replyingToSenderName,
        replyText: _replyingToText,
        isPinned: false,
        type: _AttachmentType.file,
        voiceDurationSeconds: null,
        isLocalOnly: true,
        status: _MessageStatus.sending,
        isRead: false,
      );

      final replyToMessageId = _replyingToMessageId;
      final replySenderName = _replyingToSenderName;
      final replyText = _replyingToText;

      setState(() {
        _replyingToMessageId = null;
        _replyingToSenderName = null;
        _replyingToText = null;
        _messages = [..._messages, optimistic];
      });

      final token = await _token();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/chat/messages/file'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/json'
        ..fields['establishment_id'] = widget.establishmentId.toString()
        ..fields['message_text'] = ''
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            path,
            filename: picked.name,
          ),
        );

      if (replyToMessageId != null) {
        request.fields['reply_to_message_id'] = replyToMessageId;
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_extractErrorText(response));
      }

      setState(() {
        _messages = _messages.where((m) => m.id != localMessageId).toList();
      });

      await _refreshMessagesSilently(keepScrollOffset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatMessageTime(String raw) {
    if (raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      return raw;
    }
  }

  String _formatSeconds(int seconds) {
    final mm = (seconds ~/ 60).toString();
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _formatDayLabel(String raw) {
    if (raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(target).inDays;

      if (diff == 0) return 'Сегодня';
      if (diff == 1) return 'Вчера';

      const months = <String>[
        'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
      ];

      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return raw;
    }
  }

  bool _isSameDay(String a, String b) {
    try {
      final da = DateTime.parse(a).toLocal();
      final db = DateTime.parse(b).toLocal();
      return da.year == db.year && da.month == db.month && da.day == db.day;
    } catch (_) {
      return false;
    }
  }

  GlobalKey _keyForMessage(String id) {
    return _messageKeys.putIfAbsent(id, () => GlobalKey());
  }

  Future<void> _sendReadToBackend(List<String> messageIds) async {
    if (messageIds.isEmpty) return;

    try {
      final token = await _token();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/chat/mark_read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_extractErrorText(response));
      }
    } catch (_) {}
  }

  Future<void> _markDeliveredToBackend() async {
    try {
      final token = await _token();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/chat/delivered'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_extractErrorText(response));
      }
    } catch (_) {}
  }


  String _fileNameFromPath(String path) {
    if (path.trim().isEmpty) return 'file';
    return path.split(Platform.pathSeparator).last;
  }

  MediaType _mediaTypeForPath(
    String? path, {
    required String fallbackType,
    required String fallbackSubtype,
  }) {
    final normalized = (path ?? '').toLowerCase();

    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (normalized.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (normalized.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    if (normalized.endsWith('.heic')) {
      return MediaType('image', 'heic');
    }
    if (normalized.endsWith('.m4a')) {
      return MediaType('audio', 'mp4');
    }
    if (normalized.endsWith('.aac')) {
      return MediaType('audio', 'aac');
    }
    if (normalized.endsWith('.mp3')) {
      return MediaType('audio', 'mpeg');
    }
    if (normalized.endsWith('.wav')) {
      return MediaType('audio', 'wav');
    }
    if (normalized.endsWith('.ogg')) {
      return MediaType('audio', 'ogg');
    }

    return MediaType(fallbackType, fallbackSubtype);
  }

  String? _cacheSafeAttachmentUrl(_ChatMessage message) {
    final fullUrl = _fullUrl(message.attachmentUrl);
    if (fullUrl == null || fullUrl.isEmpty) return null;

    final separator = fullUrl.contains('?') ? '&' : '?';
    return '$fullUrl${separator}m=${Uri.encodeComponent(message.id)}_${Uri.encodeComponent(message.createdAt)}';
  }

  bool _showDeletedPlaceholder(_ChatMessage message) {
    return message.isDeleted &&
        message.messageText.trim().isEmpty &&
        message.type == _AttachmentType.text;
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
            'Месседжер пока пустой',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kChatInk,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Начни переписку с командой заведения',
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
    if (message.reactions.isEmpty || message.isDeleted) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        top: 6,
        left: mine ? 28 : 0,
        right: mine ? 0 : 28,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 5,
        children: message.reactions.map((entry) {
          final selected = entry.reactedByMe;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _toggleReaction(message, entry.emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: selected
                    ? kChatGreen.withOpacity(0.16)
                    : Colors.white.withOpacity(0.84),
                border: Border.all(
                  color: selected
                      ? kChatGreen.withOpacity(0.45)
                      : const Color(0xFFE7EEF0),
                ),
              ),
              child: Text(
                '${entry.emoji} ${entry.count}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kChatInk,
                  fontSize: 12.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _messageImage(_ChatMessage message) {
    if (message.localImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: () => _openBytesPreview(message.localImageBytes!),
          child: Image.memory(message.localImageBytes!, fit: BoxFit.cover),
        ),
      );
    }

    final fullUrl = _cacheSafeAttachmentUrl(message);
    if (fullUrl != null && fullUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: () => _openUrlPreview(fullUrl),
          child: Image.network(
            fullUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withOpacity(0.06),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.photo,
                color: kChatInkSoft,
                size: 30,
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _fileBubble(bool mine, _ChatMessage message) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openAttachment(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: mine
              ? Colors.white.withOpacity(0.14)
              : const Color(0xFFF3F7FA),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: mine
                    ? Colors.white.withOpacity(0.18)
                    : kChatAmber.withOpacity(0.12),
              ),
              child: Icon(
                CupertinoIcons.doc_fill,
                size: 20,
                color: mine ? Colors.white : kChatAmber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName?.trim().isNotEmpty == true
                        ? message.fileName!
                        : 'Файл',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: mine ? Colors.white : kChatInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Нажмите, чтобы открыть',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: mine
                          ? Colors.white.withOpacity(0.84)
                          : kChatInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.paperclip,
              size: 16,
              color: mine ? Colors.white : kChatInkSoft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceBubble(bool mine, int durationSeconds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: mine
            ? Colors.white.withOpacity(0.14)
            : const Color(0xFFF3F7FA),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mine
                  ? Colors.white.withOpacity(0.18)
                  : kChatBlue.withOpacity(0.10),
            ),
            child: Icon(
              CupertinoIcons.play_fill,
              size: 18,
              color: mine ? Colors.white : kChatBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List<Widget>.generate(
                16,
                (i) => Container(
                  width: 4,
                  height: (8 + (i % 4) * 6).toDouble(),
                  decoration: BoxDecoration(
                    color: mine
                        ? Colors.white.withOpacity(0.75)
                        : kChatBlue.withOpacity(0.68),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatSeconds(durationSeconds),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: mine ? Colors.white : kChatInk,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(_ChatMessage message) async {
    final fullUrl = _fullUrl(message.attachmentUrl);
    if (fullUrl == null || fullUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ссылка на файл не найдена'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final opened = await launchUrlString(fullUrl, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      await Clipboard.setData(ClipboardData(text: fullUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть файл. Ссылка скопирована'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? _fullUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${AppConfig.baseUrl}${url.startsWith('/') ? '' : '/'}$url';
  }

  void _openBytesPreview(Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImagePreviewScreen.memory(bytes: bytes),
      ),
    );
  }

  void _openUrlPreview(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImagePreviewScreen.network(url: url),
      ),
    );
  }

  Widget _statusIcon(_ChatMessage message, bool mine) {
    if (!mine || message.isDeleted) return const SizedBox.shrink();

    IconData icon;
    Color color;

    switch (message.status) {
      case _MessageStatus.sending:
        icon = CupertinoIcons.clock;
        color = Colors.white.withOpacity(0.78);
        break;
      case _MessageStatus.sent:
        icon = CupertinoIcons.check_mark;
        color = Colors.white.withOpacity(0.82);
        break;
      case _MessageStatus.delivered:
        icon = CupertinoIcons.check_mark;
        color = Colors.white.withOpacity(0.86);
        break;
      case _MessageStatus.read:
        icon = CupertinoIcons.check_mark_circled_solid;
        color = Colors.white;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Icon(icon, size: 12, color: color),
    );
  }

  bool _shouldShowUnreadDivider(_ChatMessage current, _ChatMessage? prev) {
    if (_firstUnreadMessageId == null) return false;
    return current.id == _firstUnreadMessageId &&
        (prev == null || prev.id != _firstUnreadMessageId);
  }

  Widget _selectionTopBar() {
    if (!_selectionMode) return const SizedBox.shrink();

    return Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _clearSelectionMode,
            icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
          ),
          Expanded(
            child: Text(
              'Выбрано: ${_selectedMessageIds.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          IconButton(
            onPressed: _selectedMessageIds.isEmpty ? null : () async {
              final text = _selectedMessages()
                  .map((m) => _messagePreview(m))
                  .join('\n\n');
              await Clipboard.setData(ClipboardData(text: text));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Сообщения скопированы'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              _clearSelectionMode();
            },
            icon: Icon(
              CupertinoIcons.doc_on_doc,
              color: _selectedMessageIds.isEmpty
                  ? Colors.white.withOpacity(0.35)
                  : Colors.white,
            ),
          ),
          IconButton(
            onPressed: _selectedMessageIds.isEmpty ? null : _deleteSelectedMessages,
            icon: Icon(
              CupertinoIcons.delete,
              color: _selectedMessageIds.isEmpty
                  ? Colors.white.withOpacity(0.35)
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingBar() {
    if (!_showTypingMock || _selectionMode || _isRecordingVoice) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _GlassCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: kChatGreen.withOpacity(0.12),
              ),
              child: const Icon(
                CupertinoIcons.chat_bubble_text_fill,
                color: kChatGreen,
                size: 15,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Печатают…',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kChatInk,
                  fontSize: 13,
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Row(
                  children: List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: Duration(milliseconds: 220 + index * 120),
                      margin: EdgeInsets.only(right: index == 2 ? 0 : 4),
                      width: 6,
                      height: 6 + (index == 1 ? value * 2 : value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kChatGreen.withOpacity(0.55 + value * 0.25),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBodyText(_ChatMessage message, bool mine) {
    final baseStyle = TextStyle(
      fontSize: 15,
      height: 1.42,
      fontWeight: FontWeight.w700,
      color: mine ? Colors.white : kChatInk,
    );

    final mentionStyle = baseStyle.copyWith(
      color: mine ? Colors.white : kChatBlue,
      fontWeight: FontWeight.w900,
    );

    final hashtagStyle = baseStyle.copyWith(
      color: mine ? Colors.white : kChatViolet,
      fontWeight: FontWeight.w900,
    );

    final highlightStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w900,
      backgroundColor: mine
          ? Colors.white.withOpacity(0.22)
          : kChatAccentSoft.withOpacity(0.45),
    );

    return RichText(
      text: TextSpan(
        children: _buildHighlightedPieces(
          text: message.messageText,
          baseStyle: baseStyle,
          mentionStyle: mentionStyle,
          hashtagStyle: hashtagStyle,
          highlightStyle: highlightStyle,
        ),
      ),
      softWrap: true,
      overflow: TextOverflow.visible,
    );
  }

  bool _shouldShowAuthor(int index, List<_ChatMessage> list) {
    if (index == 0) return true;
    final current = list[index];
    final prev = list[index - 1];
    return current.senderUserId != prev.senderUserId ||
        !_isSameDay(current.createdAt, prev.createdAt);
  }

  bool _shouldShowCompactSpacing(int index, List<_ChatMessage> list) {
    if (index == 0) return false;
    final current = list[index];
    final prev = list[index - 1];
    return current.senderUserId == prev.senderUserId &&
        _isSameDay(current.createdAt, prev.createdAt);
  }

  Widget _bubbleSideButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.90),
          border: Border.all(color: const Color(0xFFE7EEF0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 15.5, color: kChatInk),
      ),
    );
  }

  Widget _messageBubble(
    _ChatMessage message, {
    required bool showAuthor,
    required bool compactTopSpacing,
  }) {
    final mine = _isMine(message);
    final isHighlighted = _highlightedMessageId == message.id;
    final isSelected = _selectedMessageIds.contains(message.id);

    return Container(
      key: _keyForMessage(message.id),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: compactTopSpacing ? 6 : 12),
          child: Row(
            mainAxisAlignment:
                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!mine && showAuthor)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _bubbleSideButton(
                    icon: _selectionMode
                        ? (isSelected
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle)
                        : CupertinoIcons.smiley,
                    onTap: () {
                      if (_selectionMode) {
                        _toggleSelection(message);
                      } else {
                        _openEmojiPanel(message);
                      }
                    },
                  ),
                )
              else if (!mine)
                const SizedBox(width: 36),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.74,
                ),
                child: Column(
                  crossAxisAlignment:
                      mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_selectionMode) {
                          _toggleSelection(message);
                        }
                      },
                      onLongPress: () {
                        if (_selectionMode) {
                          _toggleSelection(message);
                        } else {
                          _openMessageActions(message);
                        }
                      },
                      onSecondaryTap: () => _openMessageActions(message),
                      onHorizontalDragEnd: (details) {
                        if (_selectionMode) return;
                        final velocity = details.primaryVelocity ?? 0;
                        if (!mine && velocity > 180) {
                          _startReply(message);
                        } else if (mine && velocity < -180) {
                          _startReply(message);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(showAuthor ? 24 : 18),
                            topRight: Radius.circular(showAuthor ? 24 : 18),
                            bottomLeft: Radius.circular(mine ? 24 : 8),
                            bottomRight: Radius.circular(mine ? 8 : 24),
                          ),
                          gradient: mine
                              ? const LinearGradient(
                                  colors: [kChatBlue, kChatViolet],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xF4FFFFFF),
                                    Color(0xEAFFFFFF),
                                  ],
                                ),
                          border: mine
                              ? Border.all(
                                  color: isSelected
                                      ? kChatAccentSoft.withOpacity(0.90)
                                      : isHighlighted
                                          ? Colors.white.withOpacity(0.45)
                                          : Colors.transparent,
                                  width: isSelected
                                      ? 1.6
                                      : isHighlighted
                                          ? 1.2
                                          : 0,
                                )
                              : Border.all(
                                  color: isSelected
                                      ? kChatAmber.withOpacity(0.90)
                                      : isHighlighted
                                          ? kChatBlue.withOpacity(0.55)
                                          : Colors.white.withOpacity(0.94),
                                  width: isSelected
                                      ? 1.6
                                      : isHighlighted
                                          ? 1.4
                                          : 1,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: (mine ? kChatBlue : Colors.black)
                                  .withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                            ),
                            if (isHighlighted)
                              BoxShadow(
                                color: kChatBlue.withOpacity(0.14),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            if (isSelected)
                              BoxShadow(
                                color: kChatAmber.withOpacity(0.14),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!mine && showAuthor)
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
                            if (_showDeletedPlaceholder(message))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  'Сообщение удалено',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.35,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    color: mine
                                        ? Colors.white.withOpacity(0.88)
                                        : kChatInkSoft,
                                  ),
                                ),
                              ),
                            if ((message.replyText ?? '').trim().isNotEmpty ||
                                (message.replySenderName ?? '').trim().isNotEmpty)
                              GestureDetector(
                                onTap: () =>
                                    _scrollToMessageById(message.replyToMessageId),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: mine
                                        ? Colors.white.withOpacity(0.16)
                                        : kChatBlue.withOpacity(0.08),
                                    border: Border.all(
                                      color: mine
                                          ? Colors.white.withOpacity(0.18)
                                          : kChatBlue.withOpacity(0.14),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 30,
                                        margin: const EdgeInsets.only(
                                          top: 1,
                                          right: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          color:
                                              mine ? Colors.white : kChatBlue,
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (message.replySenderName ??
                                                          'Сотрудник')
                                                      .trim()
                                                      .isEmpty
                                                  ? 'Сотрудник'
                                                  : message.replySenderName!
                                                      .trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w900,
                                                color: mine
                                                    ? Colors.white
                                                    : kChatBlue,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              (message.replyText ?? '')
                                                      .trim()
                                                      .isEmpty
                                                  ? 'Сообщение'
                                                  : message.replyText!.trim(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                height: 1.25,
                                                fontWeight: FontWeight.w700,
                                                color: mine
                                                    ? Colors.white
                                                        .withOpacity(0.86)
                                                    : kChatInkSoft,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (message.type == _AttachmentType.image) ...[
                              _messageImage(message),
                              if (message.messageText.trim().isNotEmpty)
                                const SizedBox(height: 8),
                            ],
                            if (message.type == _AttachmentType.voice) ...[
                              _voiceBubble(
                                mine,
                                message.voiceDurationSeconds ?? 1,
                              ),
                              if (message.messageText.trim().isNotEmpty)
                                const SizedBox(height: 8),
                            ],
                            if (message.type == _AttachmentType.file) ...[
                              _fileBubble(mine, message),
                              if (message.messageText.trim().isNotEmpty)
                                const SizedBox(height: 8),
                            ],
                            if (!message.isDeleted &&
                                message.messageText.trim().isNotEmpty)
                              _messageBodyText(message, mine),
                            const SizedBox(height: 7),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.isPinned) ...[
                                  Icon(
                                    CupertinoIcons.pin_fill,
                                    size: 12,
                                    color: mine
                                        ? Colors.white.withOpacity(0.82)
                                        : kChatBlue,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  _formatMessageTime(message.createdAt),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: mine
                                        ? Colors.white.withOpacity(0.86)
                                        : kChatInkSoft,
                                  ),
                                ),
                                _statusIcon(message, mine),
                                if (message.isEdited && !message.isDeleted) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'изменено',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: mine
                                          ? Colors.white.withOpacity(0.80)
                                          : kChatInkSoft,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    _reactionRow(message, mine),
                  ],
                ),
              ),
              if (mine)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _bubbleSideButton(
                    icon: _selectionMode
                        ? (isSelected
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle)
                        : CupertinoIcons.ellipsis,
                    onTap: () {
                      if (_selectionMode) {
                        _toggleSelection(message);
                      } else {
                        _openMessageActions(message);
                      }
                    },
                  ),
                )
              else if (mine)
                const SizedBox(width: 36),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMessageActions(_ChatMessage message) async {
    final mine = _isMine(message);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.98)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8E2E6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: mine
                                ? kChatBlue.withOpacity(0.10)
                                : kChatGreen.withOpacity(0.10),
                          ),
                          child: Icon(
                            mine ? CupertinoIcons.ellipsis : CupertinoIcons.chat_bubble_2_fill,
                            color: mine ? kChatBlue : kChatGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mine ? 'Действия с вашим сообщением' : 'Действия с сообщением',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: kChatInk,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _messagePreview(message),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: kChatInkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _sheetAction(
                      icon: CupertinoIcons.check_mark_circled,
                      color: kChatAmber,
                      title: 'Выбрать',
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _enterSelectionMode(message);
                      },
                    ),
                    const SizedBox(height: 8),
                    _sheetAction(
                      icon: CupertinoIcons.reply,
                      color: kChatBlue,
                      title: 'Ответить',
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _startReply(message);
                      },
                    ),
                    const SizedBox(height: 8),
                    _sheetAction(
                      icon: CupertinoIcons.doc_on_doc,
                      color: kChatViolet,
                      title: 'Копировать',
                      onTap: () async {
                        Navigator.of(dialogContext).pop();
                        await _copyMessageText(message);
                      },
                    ),
                    const SizedBox(height: 8),
                    _sheetAction(
                      icon: CupertinoIcons.smiley,
                      color: kChatGreen,
                      title: 'Добавить реакцию',
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _openEmojiPanel(message);
                      },
                    ),
                    const SizedBox(height: 8),
                    _sheetAction(
                      icon: CupertinoIcons.pin,
                      color: kChatAmber,
                      title: message.isPinned || _pinnedMessageId == message.id
                          ? 'Убрать из закрепа'
                          : 'Закрепить',
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _togglePinnedMessageLocal(message);
                      },
                    ),
                    if (message.type == _AttachmentType.file) ...[
                      const SizedBox(height: 8),
                      _sheetAction(
                        icon: CupertinoIcons.paperclip,
                        color: kChatBlue,
                        title: 'Открыть файл',
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          _openAttachment(message);
                        },
                      ),
                    ],
                    if (mine && !message.isDeleted && message.type == _AttachmentType.text) ...[
                      const SizedBox(height: 8),
                      _sheetAction(
                        icon: CupertinoIcons.pencil,
                        color: kChatBlue,
                        title: 'Редактировать',
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          _startEditMessage(message);
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    _sheetAction(
                      icon: CupertinoIcons.delete_solid,
                      color: kChatRed,
                      title: mine ? 'Удалить у всех' : 'Удалить у себя',
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        if (mine || message.isLocalOnly) {
                          _deleteForAll(message);
                        } else {
                          _deleteForMe(message);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pendingImagePreview() {
    if (_pendingImageBytes == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _GlassCard(
        radius: 22,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                  color: kChatInk,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
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

  Widget _pinnedBanner() {
    final pinned = _getPinnedMessage();
    if (pinned == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () => _scrollToMessageById(pinned.id),
        child: _GlassCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: kChatAmber.withOpacity(0.12),
                ),
                child: const Icon(
                  CupertinoIcons.pin_fill,
                  color: kChatAmber,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Закреплённое сообщение',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: kChatInk,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _messagePreview(pinned),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kChatInkSoft,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _togglePinnedMessageLocal(pinned),
                icon: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: kChatRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBanner() {
    if (_searchQuery.trim().isEmpty) return const SizedBox.shrink();
    final count = _filteredMessages().length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _GlassCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: kChatViolet.withOpacity(0.10),
              ),
              child: const Icon(
                CupertinoIcons.search,
                color: kChatViolet,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Найдено: $count',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: kChatInk,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _searchQuery,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kChatInkSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _jumpToSearchResult,
              icon: const Icon(
                CupertinoIcons.arrow_down_circle_fill,
                color: kChatBlue,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                });
              },
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

  Widget _replyBanner() {
    if (_replyingToMessageId == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _GlassCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: kChatBlue.withOpacity(0.10),
              ),
              child: const Icon(
                CupertinoIcons.reply,
                color: kChatBlue,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _replyingToSenderName ?? 'Сотрудник',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: kChatInk,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _replyingToText ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kChatInkSoft,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _cancelReply,
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

  Widget _editBanner() {
    if (_editingMessageId == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _GlassCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: kChatAmber.withOpacity(0.12),
              ),
              child: const Icon(
                CupertinoIcons.pencil,
                color: kChatAmber,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Режим редактирования сообщения',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: kChatInk,
                  fontSize: 13.5,
                ),
              ),
            ),
            TextButton(
              onPressed: _cancelEdit,
              child: const Text(
                'Отмена',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kChatInkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordingBanner() {
    if (!_isRecordingVoice) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _GlassCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kChatRed.withOpacity(0.12),
              ),
              child: const Icon(
                CupertinoIcons.mic_fill,
                color: kChatRed,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: kChatRed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Идёт запись • ${_formatSeconds(_recordingSeconds)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: kChatInk,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _cancelVoiceRecording,
              child: const Text('Отмена'),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: _stopAndSendVoiceRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: kChatBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('Отправить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _draftBanner() {
    if (_selectionMode ||
        _editingMessageId != null ||
        _draftText.trim().isEmpty ||
        _messageController.text.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _GlassCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: kChatPink.withOpacity(0.10),
              ),
              child: const Icon(
                CupertinoIcons.doc_text,
                color: kChatPink,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Черновик',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: kChatInk,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _draftText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kChatInkSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _messageController.text = _draftText;
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _messageController.text.length),
                  );
                });
                _messageFocusNode.requestFocus();
              },
              child: const Text('Открыть'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unreadJumpBanner() {
    if (_firstUnreadMessageId == null || _selectionMode) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _GlassCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: kChatAmber.withOpacity(0.14),
              ),
              child: const Icon(
                CupertinoIcons.envelope_badge,
                color: kChatAmber,
                size: 15,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Есть непрочитанные сообщения',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kChatInk,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: _jumpToFirstUnread,
              child: const Text('Открыть'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topChatBanners() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pinnedBanner(),
        _typingBar(),
        _unreadJumpBanner(),
        _searchBanner(),
        _replyBanner(),
        _editBanner(),
        _recordingBanner(),
        _draftBanner(),
      ],
    );
  }

  Widget _composer() {
    final showSendButton = _messageController.text.trim().isNotEmpty ||
        _pendingImageBytes != null ||
        _editingMessageId != null;

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
                padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _openAttachmentSheet,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: kChatPink.withOpacity(0.10),
                        ),
                        child: const Icon(
                          CupertinoIcons.add,
                          color: kChatInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        minLines: 1,
                        maxLines: 7,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: _editingMessageId != null
                              ? 'Изменить сообщение'
                              : _replyingToMessageId != null
                                  ? 'Напиши ответ...'
                                  : 'Написать сообщение',
                          hintStyle: const TextStyle(
                            color: kChatInkSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!showSendButton)
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _startVoiceRecording,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: kChatRed.withOpacity(0.10),
                          ),
                          child: const Icon(
                            CupertinoIcons.mic_fill,
                            color: kChatRed,
                          ),
                        ),
                      )
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            colors: _editingMessageId != null
                                ? const [kChatAmber, kChatAccentSoft]
                                : const [kChatBlue, kChatViolet],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_editingMessageId != null
                                      ? kChatAmber
                                      : kChatBlue)
                                  .withOpacity(0.22),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _sending ? null : _sendMessage,
                          child: SizedBox(
                            width: 44,
                            height: 44,
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
                                  : Icon(
                                      _editingMessageId != null
                                          ? CupertinoIcons.check_mark
                                          : CupertinoIcons.arrow_up,
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
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
        children: const [
          Center(
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

    final filteredMessages = _filteredMessages();

    if (_messages.isEmpty) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
        children: [
          _stagger(index: 0, child: _errorCard()),
          if (_error != null) const SizedBox(height: 14),
          _stagger(index: 1, child: _emptyState()),
        ],
      );
    }

    if (filteredMessages.isEmpty) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
        children: [
          _stagger(index: 0, child: _errorCard()),
          if (_error != null) const SizedBox(height: 14),
          _stagger(index: 1, child: _searchEmptyState()),
        ],
      );
    }

    final children = <Widget>[
      _stagger(index: 0, child: _errorCard()),
      if (_error != null) const SizedBox(height: 14),
    ];

    for (int i = 0; i < filteredMessages.length; i++) {
      final message = filteredMessages[i];
      final prev = i > 0 ? filteredMessages[i - 1] : null;
      final showDayDivider =
          prev == null || !_isSameDay(prev.createdAt, message.createdAt);

      if (showDayDivider) {
        children.add(
          _stagger(
            index: i + 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withOpacity(0.20),
                    border: Border.all(color: Colors.white.withOpacity(0.24)),
                  ),
                  child: Text(
                    _formatDayLabel(message.createdAt),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (_shouldShowUnreadDivider(message, prev)) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: kChatAmber.withOpacity(0.18),
                  border: Border.all(color: Colors.white.withOpacity(0.24)),
                ),
                child: const Text(
                  'Непрочитанные сообщения',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      children.add(
        _stagger(
          index: i + 2,
          child: _messageBubble(
            message,
            showAuthor: _shouldShowAuthor(i, filteredMessages),
            compactTopSpacing: _shouldShowCompactSpacing(i, filteredMessages),
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
          children: children,
        ),
        if (_showScrollToBottom)
          Positioned(
            right: 18,
            bottom: 132,
            child: Column(
              children: [
                if (_firstUnreadMessageId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Pressable(
                      onTap: _jumpToFirstUnread,
                      borderRadius: 18,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.90),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.94),
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.mail_solid,
                              color: kChatAmber,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                _Pressable(
                  onTap: () => _scrollToBottom(),
                  borderRadius: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.90),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.94)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_down,
                          color: kChatInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _searchEmptyState() {
    return _GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  kChatViolet.withOpacity(0.16),
                  kChatBlue.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              CupertinoIcons.search,
              color: kChatInkSoft,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Ничего не найдено',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kChatInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'По запросу “$_searchQuery” нет совпадений',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kChatInkSoft,
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
            },
            child: const Text('Сбросить поиск'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSearchSheet() async {
    final controller = TextEditingController(text: _searchQuery);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.96)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Поиск по сообщениям',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: kChatInk,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Введите текст',
                        filled: true,
                        fillColor: const Color(0xFFF5F8F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(''),
                            child: const Text('Сбросить'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(controller.text.trim()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kChatBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text('Найти'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _searchQuery = result;
      });
    }
  }

  List<String> _participantNames() {
    final set = <String>{};
    for (final m in _messages) {
      final name = m.senderName.trim().isEmpty ? 'Сотрудник' : m.senderName.trim();
      set.add(name);
    }
    return set.toList()..sort();
  }

  Future<void> _openParticipantsSheet() async {
    final names = _participantNames();
    final stats = <String, int>{};
    for (final m in _messages) {
      final name = m.senderName.trim().isEmpty ? 'Сотрудник' : m.senderName.trim();
      stats[name] = (stats[name] ?? 0) + 1;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.98)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8E2E6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: kChatBlue.withOpacity(0.10),
                          ),
                          child: const Icon(
                            CupertinoIcons.person_2_fill,
                            color: kChatBlue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Участники чата',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: kChatInk,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Всего: ${names.length} • Сообщений: ${_messages.where((m) => !m.isDeleted).length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kChatInkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (names.isEmpty)
                      const Text(
                        'Список пока пуст',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kChatInkSoft,
                        ),
                      )
                    else
                      ...names.map(
                        (name) {
                          final count = stats[name] ?? 0;
                          final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
                          final initials = parts.isEmpty
                              ? 'С'
                              : parts.take(2).map((e) => e.substring(0, 1).toUpperCase()).join();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: const Color(0xFFF7FAFC),
                              border: Border.all(color: const Color(0xFFE8EEF2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [kChatBlue.withOpacity(0.85), kChatViolet.withOpacity(0.85)],
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: kChatInk,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Сообщений в чате: $count',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: kChatInkSoft,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_selectionMode) {
      return AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        toolbarHeight: kToolbarHeight,
        titleSpacing: 0,
        title: _selectionTopBar(),
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Месседжер',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            widget.establishmentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _topIconButton(
            icon: CupertinoIcons.person_2_fill,
            onTap: _openParticipantsSheet,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _topIconButton(
                icon: CupertinoIcons.search,
                onTap: _openSearchSheet,
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kChatRed,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _topIconButton(
            icon: CupertinoIcons.refresh,
            onTap: _load,
          ),
        ),
      ],
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.09),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: kChatInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _buildHighlightedPieces({
    required String text,
    required TextStyle baseStyle,
    required TextStyle mentionStyle,
    required TextStyle hashtagStyle,
    required TextStyle highlightStyle,
  }) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(@[\w._]+|#[\w_]+)');
    int cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        final plain = text.substring(cursor, match.start);
        spans.addAll(
          _highlightPlainText(
            text: plain,
            baseStyle: baseStyle,
            highlightStyle: highlightStyle,
          ),
        );
      }

      final token = match.group(0) ?? '';
      final tokenStyle = token.startsWith('@') ? mentionStyle : hashtagStyle;

      spans.addAll(
        _highlightPlainText(
          text: token,
          baseStyle: tokenStyle,
          highlightStyle: highlightStyle.merge(tokenStyle),
        ),
      );

      cursor = match.end;
    }

    if (cursor < text.length) {
      final tail = text.substring(cursor);
      spans.addAll(
        _highlightPlainText(
          text: tail,
          baseStyle: baseStyle,
          highlightStyle: highlightStyle,
        ),
      );
    }

    return spans;
  }

  List<InlineSpan> _highlightPlainText({
    required String text,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
  }) {
    final String q = _searchQuery.trim();
    if (q.isEmpty || text.isEmpty) {
      return <InlineSpan>[TextSpan(text: text, style: baseStyle)];
    }

    final List<InlineSpan> spans = <InlineSpan>[];
    final String sourceLower = text.toLowerCase();
    final String queryLower = q.toLowerCase();
    int start = 0;

    while (true) {
      final int index = sourceLower.indexOf(queryLower, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }

      final int end = index + q.length;

      spans.add(
        TextSpan(
          text: text.substring(index, end),
          style: highlightStyle,
        ),
      );

      start = end;
    }

    return spans;
  }

  Widget _attachmentTile({
    required IconData icon,
    required List<Color> colors,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.94),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: colors),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                color: kChatInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                color: kChatInkSoft,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachmentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withOpacity(0.98)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Быстрые действия',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              color: kChatInk,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: kChatInkSoft,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.25,
                      children: [
                        _attachmentTile(
                          icon: CupertinoIcons.doc_fill,
                          colors: const [kChatAmber, kChatAccentSoft],
                          title: 'Файл',
                          subtitle: 'Любой документ',
                          onTap: () {
                            Navigator.of(context).pop();
                            _sendDocument();
                          },
                        ),
                        _attachmentTile(
                          icon: CupertinoIcons.camera_fill,
                          colors: const [kChatBlue, kChatViolet],
                          title: 'Камера',
                          subtitle: 'Снимок',
                          onTap: () {
                            Navigator.of(context).pop();
                            _pickFromCamera();
                          },
                        ),
                        _attachmentTile(
                          icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                          colors: const [kChatPink, kChatRed],
                          title: 'Галерея',
                          subtitle: 'Одно фото',
                          onTap: () {
                            Navigator.of(context).pop();
                            _pickImage();
                          },
                        ),
                        _attachmentTile(
                          icon: CupertinoIcons.mic_fill,
                          colors: const [kChatRed, kChatPink],
                          title: 'Голос',
                          subtitle: 'Сообщение',
                          onTap: () {
                            Navigator.of(context).pop();
                            _startVoiceRecording();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stagger({
    required int index,
    required Widget child,
  }) {
    final double start = (index * 0.08).clamp(0.0, 0.82).toDouble();
    final double end = (start + 0.24).clamp(0.0, 1.0).toDouble();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kChatMintTop,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Stack(
            children: [
              _background(),
              SafeArea(
                top: false,
                child: Stack(
                  children: [
                    Positioned.fill(child: _messagesList()),
                    if (!_selectionMode)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: _topChatBanners(),
                      ),
                    if (!_selectionMode)
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
            gradient: const LinearGradient(
              colors: [kChatCardStrong, kChatCard],
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

class _ImagePreviewScreen extends StatelessWidget {
  final Uint8List? bytes;
  final String? url;

  const _ImagePreviewScreen.memory({
    required Uint8List this.bytes,
    super.key,
  }) : url = null;

  const _ImagePreviewScreen.network({
    required String this.url,
    super.key,
  }) : bytes = null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: bytes != null ? Image.memory(bytes!) : Image.network(url!),
        ),
      ),
    );
  }
}

enum _MessageStatus { sending, sent, delivered, read }
enum _AttachmentType { text, image, file, voice }

class _ChatMessage {
  final String id;
  final String senderUserId;
  final String senderName;
  final String messageText;
  final String createdAt;
  final Uint8List? localImageBytes;
  final String? attachmentUrl;
  final String? fileName;
  final List<_ReactionItem> reactions;
  final bool isDeleted;
  final bool isEdited;
  final String? replyToMessageId;
  final String? replySenderName;
  final String? replyText;
  final bool isPinned;
  final _AttachmentType type;
  final int? voiceDurationSeconds;
  final bool isLocalOnly;
  final _MessageStatus status;
  final bool isRead;

  _ChatMessage({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.messageText,
    required this.createdAt,
    required this.localImageBytes,
    required this.attachmentUrl,
    required this.fileName,
    required this.reactions,
    required this.isDeleted,
    required this.isEdited,
    required this.replyToMessageId,
    required this.replySenderName,
    required this.replyText,
    required this.isPinned,
    required this.type,
    required this.voiceDurationSeconds,
    required this.isLocalOnly,
    required this.status,
    required this.isRead,
  });

  bool isMineLocal(String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) return false;
    return senderUserId == currentUserId;
  }

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    List<_ReactionItem> parseReactions(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((e) => _ReactionItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final s = value?.toString().toLowerCase() ?? '';
      return s == 'true' || s == '1' || s == 'yes';
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    _MessageStatus parseStatus(dynamic value, bool isRead) {
      final s = value?.toString().toLowerCase() ?? '';
      if (isRead) return _MessageStatus.read;
      if (s == 'read') return _MessageStatus.read;
      if (s == 'delivered') return _MessageStatus.delivered;
      if (s == 'sending') return _MessageStatus.sending;
      return _MessageStatus.sent;
    }

    final typeRaw = (json['message_type']?.toString().toLowerCase() ??
            json['type']?.toString().toLowerCase() ??
            '')
        .trim();

    final fileUrl = json['file_url']?.toString() ?? json['attachment_url']?.toString();
    final imageUrl = json['image_url']?.toString() ?? json['media_url']?.toString();
    final audioUrl = json['audio_url']?.toString() ?? json['voice_url']?.toString();
    final attachmentUrl = imageUrl?.trim().isNotEmpty == true
        ? imageUrl
        : fileUrl?.trim().isNotEmpty == true
            ? fileUrl
            : audioUrl;

    final fileName = json['file_name']?.toString() ??
        json['original_file_name']?.toString() ??
        json['attachment_name']?.toString() ??
        json['document_name']?.toString();

    _AttachmentType attachmentType;
    if (typeRaw == 'voice' || typeRaw == 'audio' || audioUrl?.isNotEmpty == true) {
      attachmentType = _AttachmentType.voice;
    } else if (typeRaw == 'file' || typeRaw == 'document') {
      attachmentType = _AttachmentType.file;
    } else if (typeRaw == 'image' || typeRaw == 'photo') {
      attachmentType = _AttachmentType.image;
    } else if ((imageUrl ?? '').isNotEmpty) {
      attachmentType = _AttachmentType.image;
    } else if ((fileUrl ?? '').isNotEmpty) {
      attachmentType = _AttachmentType.file;
    } else {
      attachmentType = _AttachmentType.text;
    }

    final isRead = parseBool(json['is_read'] ?? json['read']);

    return _ChatMessage(
      id: json['message_id']?.toString() ?? json['id']?.toString() ?? '',
      senderUserId:
          json['sender_user_id']?.toString() ?? json['user_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ??
          json['full_name']?.toString() ??
          json['username']?.toString() ??
          '',
      messageText:
          json['message_text']?.toString() ?? json['text']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      localImageBytes: null,
      attachmentUrl: attachmentUrl,
      fileName: fileName,
      reactions: parseReactions(json['reactions']),
      isDeleted: parseBool(json['is_deleted'] ?? json['deleted']),
      isEdited: parseBool(json['is_edited'] ?? json['edited']),
      replyToMessageId: json['reply_to_message_id']?.toString(),
      replySenderName: json['reply_sender_name']?.toString() ??
          json['reply_to_sender_name']?.toString(),
      replyText: json['reply_text']?.toString() ??
          json['reply_to_message_text']?.toString(),
      isPinned: parseBool(json['is_pinned']),
      type: attachmentType,
      voiceDurationSeconds:
          parseInt(json['voice_duration_seconds'] ?? json['duration_seconds']),
      isLocalOnly: false,
      status: parseStatus(json['status'], isRead),
      isRead: isRead,
    );
  }

  _ChatMessage copyWith({
    String? messageText,
    Uint8List? localImageBytes,
    String? attachmentUrl,
    String? fileName,
    List<_ReactionItem>? reactions,
    bool? isDeleted,
    bool? isEdited,
    String? replyToMessageId,
    String? replySenderName,
    String? replyText,
    bool? isPinned,
    _AttachmentType? type,
    int? voiceDurationSeconds,
    bool? isLocalOnly,
    _MessageStatus? status,
    bool? isRead,
  }) {
    return _ChatMessage(
      id: id,
      senderUserId: senderUserId,
      senderName: senderName,
      messageText: messageText ?? this.messageText,
      createdAt: createdAt,
      localImageBytes: localImageBytes ?? this.localImageBytes,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      fileName: fileName ?? this.fileName,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
      isEdited: isEdited ?? this.isEdited,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replySenderName: replySenderName ?? this.replySenderName,
      replyText: replyText ?? this.replyText,
      isPinned: isPinned ?? this.isPinned,
      type: type ?? this.type,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
    );
  }
}

class _ReactionItem {
  final String emoji;
  final int count;
  final bool reactedByMe;

  const _ReactionItem({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });

  factory _ReactionItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 1;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 1;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final s = value?.toString().toLowerCase() ?? '';
      return s == 'true' || s == '1' || s == 'yes';
    }

    return _ReactionItem(
      emoji: json['emoji']?.toString() ?? '👍',
      count: parseInt(json['count']),
      reactedByMe: parseBool(
        json['reacted_by_me'] ?? json['is_mine'] ?? json['selected'],
      ),
    );
  }
}
