import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';
import '../cubit/chat/chat_cubit.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  String? _currentUserId;

  Uint8List? _pendingImageBytes;
  String? _pendingImageName;

  String? _editingMessageId;
  String _searchQuery = '';
  String? _replyingToMessageId;
  String? _replyingToSenderName;
  String? _replyingToText;

  String? _highlightedMessageId;
  String? _pinnedMessageId;
  String _draftText = '';
  String? _firstUnreadMessageId;
  String? _expandedVoiceMessageId;
  int _voiceViewSeed = 0;
  final Map<String, dynamic> _voiceAudioElements = <String, dynamic>{};
  final Map<String, double> _voiceCurrentSeconds = <String, double>{};
  final Map<String, double> _voiceTotalSeconds = <String, double>{};
  final Map<String, AudioPlayer> _nativeVoicePlayers = <String, AudioPlayer>{};
  final Map<String, bool> _voiceDownloading = <String, bool>{};
  final Map<String, double> _voiceSpeeds = <String, double>{};
  final Map<String, String> _nativeVoiceLocalPaths = <String, String>{};
  final Map<String, bool> _voiceLoading = <String, bool>{};          // загрузка аудио
  final Map<String, double> _voicePlaybackRates = <String, double>{}; // скорость
  Timer? _voiceProgressTimer;
  String? _playingVoiceMessageId;

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

  // BLoC
  late ChatCubit _chatCubit;

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
    _scrollController.addListener(_onScrollPagination);
    _chatCubit = ChatCubit(
      repository: ChatRepository(),
      establishmentId: widget.establishmentId,
    );
    _init();
  }

  Future<void> _init() async {
    await _loadCurrentUser();
    await _chatCubit.loadMessages(userId: _currentUserId);
    _introController.forward(from: 0);
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
    _voiceProgressTimer?.cancel();
    for (final audio in _voiceAudioElements.values) {
      try {
        audio.pause();
      } catch (_) {}
    }
    _voiceAudioElements.clear();

    for (final player in _nativeVoicePlayers.values) {
      try {
        player.dispose();
      } catch (_) {}
    }
    _nativeVoicePlayers.clear();
    _nativeVoiceLocalPaths.clear();

    _audioRecorder.dispose();
    _chatCubit.close();
    _scrollController.removeListener(_onScrollPagination);
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

  Future<void> _refreshMessagesSilently({bool keepScrollOffset = true}) async {
    await _chatCubit.loadMessages(silent: true, userId: _currentUserId);
    if (keepScrollOffset && _scrollController.hasClients) {
      // сохраняем позицию, но т.к. данные могли измениться, просто оставляем
      // без прыжка вниз
    } else {
      _scrollToBottom(jump: true);
    }
  }

  void _safeUpdateLocalFields(ChatState state) {
    // Вычисляем новые значения
    String? newPinnedId;
    String? newUnreadId;
    for (final m in state.messages.reversed) {
      if (m.isPinned) {
        newPinnedId = m.id;
        break;
      }
    }
    for (final m in state.messages) {
      if (!_isMine(m) && !m.isRead) {
        newUnreadId = m.id;
        break;
      }
    }

    // Обновляем через setState, если что-то изменилось
    if (_pinnedMessageId != newPinnedId ||
        _firstUnreadMessageId != newUnreadId ||
        _loading != (state.status == ChatStatus.loading) ||
        _error != state.error) {
      setState(() {
        _pinnedMessageId = newPinnedId;
        _firstUnreadMessageId = newUnreadId;
        _loading = (state.status == ChatStatus.loading);
        _error = state.error;
      });
    }
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

  void _onScrollPagination() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _chatCubit.loadMoreMessages();
    }
  }

  int get _unreadCount {
    final messages = _chatCubit.state.messages;
    int count = 0;
    for (final m in messages) {
      if (!_isMine(m) && !m.isRead && !m.isDeleted) {
        count++;
      }
    }
    return count;
  }

  void _markVisibleMessagesAsRead() {
    final messages = _chatCubit.state.messages;
    final unreadIds = messages
        .where((m) => !_isMine(m) && !m.isRead && !m.isDeleted)
        .map((m) => m.id)
        .toList();

    if (unreadIds.isEmpty) return;
    _sendReadToBackend(unreadIds);
  }

  void _markOneMessageAsRead(String messageId) {
    // Можно не реализовывать мгновенно, при следующей загрузке обновится
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
    });
  }

  void _startReply(ChatMessage message) {
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

  String _messagePreview(ChatMessage message) {
    if (message.isDeleted) return 'Сообщение';
    if (message.type == AttachmentType.file) {
      return '📎 ${message.fileName ?? 'Файл'}';
    }
    if (message.type == AttachmentType.voice) {
      return '🎤 Голосовое сообщение';
    }
    if (message.type == AttachmentType.image) {
      return message.messageText.trim().isNotEmpty
          ? message.messageText.trim()
          : '📷 Фото';
    }
    if (message.messageText.trim().isNotEmpty) {
      return message.messageText.trim();
    }
    return 'Сообщение';
  }

  bool _isMine(ChatMessage message) {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    return message.senderUserId == _currentUserId;
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    final Uint8List? pendingImageBytes = _pendingImageBytes;
    final String? pendingImageName = _pendingImageName;
    final String? replyingToMessageId = _replyingToMessageId;
    final String? replyingToSenderName = _replyingToSenderName;
    final String? replyingToText = _replyingToText;

    if (text.isEmpty && pendingImageBytes == null) return;
    if (_sending) return;

    if (_editingMessageId != null) {
      await _saveEditedMessage();
      return;
    }

    // Если есть изображение – отправляем через старый метод (пока)
    if (pendingImageBytes != null) {
      await _sendImageMessage(pendingImageBytes, pendingImageName, text, replyingToMessageId);
      return;
    }

    // Текстовое сообщение – через кубит
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
    });

    try {
      HapticFeedback.lightImpact();
      await _chatCubit.sendTextMessage(text, replyToId: replyingToMessageId);
      setState(() {
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _sending = false;
        _error = e.toString();
        _messageController.text = text;
        _replyingToMessageId = replyingToMessageId;
        _replyingToSenderName = replyingToSenderName;
        _replyingToText = replyingToText;
      });
    }
  }

  Future<void> _sendImageMessage(Uint8List bytes, String? filename, String? caption, String? replyToId) async {
    final localId = 'local_img_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: localId,
      senderUserId: _currentUserId ?? '',
      senderName: 'Вы',
      messageText: caption ?? '',
      createdAt: DateTime.now().toIso8601String(),
      localImageBytes: bytes,
      attachmentUrl: null,
      fileName: filename,
      reactions: [],
      isDeleted: false,
      isEdited: false,
      replyToMessageId: replyToId,
      replySenderName: _replyingToSenderName,
      replyText: _replyingToText,
      isPinned: false,
      type: AttachmentType.image,
      voiceDurationSeconds: null,
      isLocalOnly: true,
      status: MessageStatus.sending,
      isRead: false,
    );
    final currentState = _chatCubit.state;
    final newMessages = [...currentState.messages, optimistic];
    _chatCubit.emit(currentState.copyWith(messages: newMessages));
    setState(() {
      _sending = true;
      _pendingImageBytes = null;
      _pendingImageName = null;
      _replyingToMessageId = null;
      _replyingToSenderName = null;
      _replyingToText = null;
    });
    try {
      final repository = ChatRepository();
      await repository.sendImageMessage(
        widget.establishmentId,
        bytes,
        filename ?? 'image.jpg',
        text: caption,
        replyToId: replyToId,
      );
      await _chatCubit.loadMessages(silent: true, userId: _currentUserId);
    } catch (e) {
      final updated = _chatCubit.state.messages.where((m) => m.id != localId).toList();
      _chatCubit.emit(_chatCubit.state.copyWith(messages: updated, error: e.toString()));
    } finally {
      setState(() => _sending = false);
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

    final optimisticMessage = ChatMessage(
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
      type: AttachmentType.voice,
      voiceDurationSeconds: seconds,
      isLocalOnly: true,
      status: MessageStatus.sending,
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
    });

    // Добавляем оптимистично через кубит
    final currentState = _chatCubit.state;
    final newMessages = [...currentState.messages, optimisticMessage];
    _chatCubit.emit(currentState.copyWith(messages: newMessages));

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
            contentType: MediaType('audio', 'mp4'),
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
        // удалим оптимистичное сообщение
        final updated = _chatCubit.state.messages.where((m) => m.id != localMessageId).toList();
        _chatCubit.emit(_chatCubit.state.copyWith(messages: updated));
      });

      await _refreshMessagesSilently(keepScrollOffset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сообщение удалено'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final updated = _chatCubit.state.messages.where((m) => m.id != localMessageId).toList();
      _chatCubit.emit(_chatCubit.state.copyWith(messages: updated));
      setState(() {
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

  Future<void> _startEditMessage(ChatMessage message) async {
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

      await _refreshMessagesSilently(keepScrollOffset: true);

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

  Future<void> _deleteForMe(ChatMessage message) async {
    FocusScope.of(context).unfocus();
    _messageFocusNode.unfocus();
    if (message.isLocalOnly) {
      final updated = _chatCubit.state.messages.where((m) => m.id != message.id).toList();
      _chatCubit.emit(_chatCubit.state.copyWith(messages: updated));
      return;
    }

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

      if (!mounted) return;
      await _refreshMessagesSilently(keepScrollOffset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _deleteForAll(ChatMessage message) async {
    FocusScope.of(context).unfocus();
    _messageFocusNode.unfocus();
    if (message.isLocalOnly) {
      final updated = _chatCubit.state.messages.where((m) => m.id != message.id).toList();
      _chatCubit.emit(_chatCubit.state.copyWith(messages: updated));
      return;
    }

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

      if (!mounted) return;
      await _refreshMessagesSilently(keepScrollOffset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showDeleteSheet(ChatMessage message) async {
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

  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
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

  Future<void> _openEmojiPanel(ChatMessage message) async {
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

  ChatMessage? _getPinnedMessage() {
    final messages = _chatCubit.state.messages;
    if (_pinnedMessageId != null) {
      for (final m in messages) {
        if (m.id == _pinnedMessageId) return m;
      }
    }
    for (final m in messages.reversed) {
      if (m.isPinned) return m;
    }
    return null;
  }

  List<ChatMessage> _filteredMessages() {
    final messages = _chatCubit.state.messages;
    return messages.where(_matchesSearch).toList();
  }

  bool _matchesSearch(ChatMessage message) {
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

  void _enterSelectionMode(ChatMessage message) {
    setState(() {
      _selectionMode = true;
      _selectedMessageIds.add(message.id);
    });
  }

  void _toggleSelection(ChatMessage message) {
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

  List<ChatMessage> _selectedMessages() {
    final messages = _chatCubit.state.messages;
    return messages
        .where((m) => _selectedMessageIds.contains(m.id))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _copyMessageText(ChatMessage message) async {
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

  Future<void> _togglePinnedMessageLocal(ChatMessage message) async {
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

      await _refreshMessagesSilently(keepScrollOffset: true);
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

      final optimistic = ChatMessage(
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
        type: AttachmentType.file,
        voiceDurationSeconds: null,
        isLocalOnly: true,
        status: MessageStatus.sending,
        isRead: false,
      );

      final replyToMessageId = _replyingToMessageId;
      final replySenderName = _replyingToSenderName;
      final replyText = _replyingToText;

      setState(() {
        _replyingToMessageId = null;
        _replyingToSenderName = null;
        _replyingToText = null;
      });
      final currentState = _chatCubit.state;
      final newMessages = [...currentState.messages, optimistic];
      _chatCubit.emit(currentState.copyWith(messages: newMessages));

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

      final updated = _chatCubit.state.messages.where((m) => m.id != localMessageId).toList();
      _chatCubit.emit(_chatCubit.state.copyWith(messages: updated));

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

  Widget _reactionRow(ChatMessage message, bool mine) {
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

  Widget _messageImage(ChatMessage message) {
    if (message.localImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: () => _openBytesPreview(message.localImageBytes!),
          child: Image.memory(message.localImageBytes!, fit: BoxFit.cover),
        ),
      );
    }

    final fullUrl = _fullUrl(message.attachmentUrl);
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

  Widget _fileBubble(bool mine, ChatMessage message) {
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


  Widget _voiceBubble(bool mine, ChatMessage message) {
    final isPlaying = _playingVoiceMessageId == message.id;
    final isLoading = _voiceLoading[message.id] == true;
    final totalSeconds = _voiceEffectiveDuration(message).round();
    final playedSeconds = (_voiceCurrentSeconds[message.id] ?? 0)
        .clamp(0, totalSeconds.toDouble())
        .round();
    final progress = totalSeconds > 0 ? playedSeconds / totalSeconds : 0.0;
    final speed = _voicePlaybackRates[message.id] ?? 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: mine
            ? LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.95),
                  const Color(0xFF8B5CF6).withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.98),
                  const Color(0xFFF0F4F8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: mine
              ? Colors.white.withOpacity(0.3)
              : const Color(0xFFE7EEF0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (mine ? const Color(0xFF6366F1) : Colors.black)
                .withOpacity(mine ? 0.25 : 0.08),
            blurRadius: mine ? 20 : 12,
            offset: Offset(0, mine ? 8 : 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ----- КНОПКА PLAY / PAUSE с жёлтым индикатором загрузки -----
              GestureDetector(
                onTap: isLoading ? null : () => _toggleInlineVoicePlayback(message),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: mine
                        ? const LinearGradient(
                            colors: [Colors.white, Color(0xFFF8F9FF)],
                          )
                        : const LinearGradient(
                            colors: [kChatBlue, Color(0xFF6366F1)],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: (mine ? Colors.white : kChatBlue).withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(kChatAccent), // ЖЁЛТЫЙ
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            key: ValueKey(isPlaying ? 'pause' : 'play'),
                            color: mine ? kChatBlue : Colors.white,
                            size: 22,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // ----- ВОЛНА + ПЕРЕМОТКА (тап и перетаскивание) -----
              Expanded(
                child: Column(
                  children: [
                    GestureDetector(
                      onTapDown: (details) => _seekVoiceMessageFromTap(message, details),
                      onHorizontalDragUpdate: (details) {
                        final box = context.findRenderObject();
                        if (box is RenderBox) {
                          final localPos = box.globalToLocal(details.globalPosition);
                          final dragDetails = TapDownDetails(localPosition: localPos);
                          _seekVoiceMessageFromTap(message, dragDetails);
                        }
                      },
                      child: Container(
                        height: 44,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final barCount = 40;
                            final barWidth = (constraints.maxWidth / barCount) - 1.5;
                            final waveHeights = _voiceWaveHeights(message, count: barCount);
                            return Row(
                              children: List.generate(barCount, (i) {
                                final t = i / (barCount - 1);
                                final isActive = t <= progress;
                                double baseHeight = waveHeights[i];
                                if (isPlaying) {
                                  final pulse = 0.8 + 0.4 * math.sin(
                                    DateTime.now().millisecondsSinceEpoch / 150 + i * 0.5,
                                  );
                                  baseHeight = baseHeight * pulse;
                                }
                                final height = baseHeight.clamp(6.0, 32.0);
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  width: barWidth,
                                  height: height,
                                  margin: const EdgeInsets.only(right: 1.5),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? (mine ? Colors.white : kChatBlue)
                                        : (mine
                                            ? Colors.white.withOpacity(0.45)
                                            : kChatBlue.withOpacity(0.35)),
                                    borderRadius: BorderRadius.circular(barWidth / 2),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ----- НИЖНЯЯ ПАНЕЛЬ: время, скорость, статус прочитано -----
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: mine
                                    ? Colors.white.withOpacity(0.9)
                                    : kChatInkSoft,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                              child: Text(
                                isPlaying
                                    ? _formatSeconds(playedSeconds)
                                    : _formatSeconds(totalSeconds),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Кнопка ускорения (1x / 1.5x / 2x)
                            GestureDetector(
                              onTap: () {
                                double newSpeed;
                                if (speed == 1.0) newSpeed = 1.5;
                                else if (speed == 1.5) newSpeed = 2.0;
                                else newSpeed = 1.0;
                                _setVoiceSpeed(message, newSpeed);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: mine
                                      ? Colors.white.withOpacity(0.2)
                                      : kChatBlue.withOpacity(0.1),
                                ),
                                child: Text(
                                  '${speed.toStringAsFixed(1)}x',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: mine ? Colors.white : kChatBlue,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _formatMessageTime(message.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: mine
                                    ? Colors.white.withOpacity(0.7)
                                    : kChatInkSoft,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _statusIcon(message, mine),   // ← галочки "прочитано"
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleInlineVoicePlayback(ChatMessage message) async {
    final fullUrl = _cacheSafeAttachmentUrl(message) ?? _fullUrl(message.attachmentUrl);
    if (fullUrl == null || fullUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ссылка на голосовое не найдена'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_voiceLoading[message.id] == true) return;
    setState(() {
      _voiceLoading[message.id] = true;
    });

    void resetLoading() {
      if (mounted) {
        setState(() {
          _voiceLoading[message.id] = false;
        });
      }
    }

    if (kIsWeb) {
      final audio = _voiceAudioElements[message.id];
      if (audio == null) {
        resetLoading();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Голосовое ещё загружается, попробуйте ещё раз'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (_playingVoiceMessageId != null && _playingVoiceMessageId != message.id) {
        final previousWeb = _voiceAudioElements[_playingVoiceMessageId!];
        try {
          previousWeb?.pause();
        } catch (_) {}

        final previousNative = _nativeVoicePlayers[_playingVoiceMessageId!];
        if (previousNative != null) {
          try {
            await previousNative.pause();
          } catch (_) {}
        }
      }

      final alreadyPlaying =
          _playingVoiceMessageId == message.id && !(audio.paused == true);

      if (alreadyPlaying) {
        try {
          audio.pause();
        } catch (_) {}
        _voiceProgressTimer?.cancel();
        if (mounted) {
          setState(() {
            _playingVoiceMessageId = null;
          });
        }
        resetLoading();
        return;
      }

      try {
        final maybeFuture = audio.play();
        if (maybeFuture != null) {
          await maybeFuture;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _playingVoiceMessageId = message.id;
        final initialDuration = _safeAudioNumber(audio.duration);
        if (initialDuration > 0) {
          _voiceTotalSeconds[message.id] = initialDuration;
        }
        _voiceCurrentSeconds[message.id] = _safeAudioNumber(audio.currentTime);
      });
      _startVoiceProgressTicker(message.id);
      resetLoading();
      return;
    }

    final player = await _ensureNativeVoicePlayer(message);
    debugPrint('VOICE TAP -> messageId=${message.id}');
    debugPrint('VOICE TAP -> attachmentUrl=${message.attachmentUrl}');
    debugPrint('VOICE TAP -> preparedLocalPath=${_nativeVoiceLocalPaths[message.id]}');
    debugPrint('VOICE TAP -> currentSeconds=${_voiceCurrentSeconds[message.id]}');
    if (player == null) {
      resetLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось подготовить голосовое'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_playingVoiceMessageId != null && _playingVoiceMessageId != message.id) {
      final previousNative = _nativeVoicePlayers[_playingVoiceMessageId!];
      if (previousNative != null) {
        try {
          await previousNative.pause();
        } catch (_) {}
      }

      final previousWeb = _voiceAudioElements[_playingVoiceMessageId!];
      if (previousWeb != null) {
        try {
          previousWeb.pause();
        } catch (_) {}
      }
    }

    final alreadyPlaying = _playingVoiceMessageId == message.id;

    if (alreadyPlaying) {
      try {
        await player.pause();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _playingVoiceMessageId = null;
        });
      }
      resetLoading();
      return;
    }

    final current = _voiceCurrentSeconds[message.id] ?? 0;

    if (current <= 0.05) {
      try {
        await player.stop();
      } catch (_) {}

      final preparedPlayer = await _ensureNativeVoicePlayer(message);
      if (preparedPlayer == null) {
        resetLoading();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось подготовить голосовое'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await preparedPlayer.resume();
    } else {
      await player.resume();
    }

    if (!mounted) return;
    setState(() {
      _playingVoiceMessageId = message.id;
    });
    resetLoading();
  }

  // Новый метод для перемотки через слайдер
  void _seekVoiceMessageFromSeconds(ChatMessage message, double seconds) {
    if (kIsWeb) {
      final audio = _voiceAudioElements[message.id];
      if (audio != null) audio.currentTime = seconds;
    } else {
      _nativeVoicePlayers[message.id]?.seek(Duration(milliseconds: (seconds * 1000).round()));
    }
    if (mounted) {
      setState(() => _voiceCurrentSeconds[message.id] = seconds);
    }
  }

  // Циклическая смена скорости
  void _cycleVoiceSpeed(ChatMessage message) {
    final speeds = [1.0, 1.5, 2.0];
    final current = _voiceSpeeds[message.id] ?? 1.0;
    final nextIndex = (speeds.indexOf(current) + 1) % speeds.length;
    _voiceSpeeds[message.id] = speeds[nextIndex];
    
    final player = _nativeVoicePlayers[message.id];
    player?.setPlaybackRate(speeds[nextIndex]);
    
    if (mounted) setState(() {}); // обновляем кнопку
  }

  Widget _inlineVoicePlayer(bool mine, ChatMessage message) {
    return const SizedBox.shrink();
  }

  Widget _hiddenVoiceAudioHost(ChatMessage message) {
    final fullUrl = _cacheSafeAttachmentUrl(message) ?? _fullUrl(message.attachmentUrl);
    if (!kIsWeb || fullUrl == null || fullUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      ignoring: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: HtmlElementView.fromTagName(
          key: ValueKey('voice_html_audio_${message.id}'),
          tagName: 'div',
          onElementCreated: (Object element) {
            final dynamic host = element;
            host.style.width = '1px';
            host.style.height = '1px';
            host.style.opacity = '0';
            host.style.overflow = 'hidden';
            host.style.pointerEvents = 'none';
            host.innerHtml = '<audio preload="metadata" style="display:none"></audio>';
            final dynamic audio = host.querySelector('audio');
            if (audio == null) return;
            audio.src = fullUrl;
            audio.controls = false;
            audio.preload = 'metadata';
            _voiceAudioElements[message.id] = audio;
            try {
              audio.load();
            } catch (_) {}
            Future<void>.delayed(const Duration(milliseconds: 250), () {
              if (!mounted) return;
              final duration = _safeAudioNumber(audio.duration);
              if (duration > 0) {
                setState(() {
                  _voiceTotalSeconds[message.id] = duration;
                });
              }
            });
          },
        ),
      ),
    );
  }

  void _startVoiceProgressTicker(String messageId) {
    _voiceProgressTimer?.cancel();
    _voiceProgressTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      final audio = _voiceAudioElements[messageId];
      if (audio == null || !mounted) {
        _voiceProgressTimer?.cancel();
        return;
      }

      final current = _safeAudioNumber(audio.currentTime);
      final duration = _safeAudioNumber(audio.duration);
      final paused = audio.paused == true;

      if (mounted) {
        setState(() {
          if (duration > 0) {
            _voiceTotalSeconds[messageId] = duration;
          }
          _voiceCurrentSeconds[messageId] = current;
          if (paused && _playingVoiceMessageId == messageId) {
            _playingVoiceMessageId = null;
          }
        });
      }

      if (paused) {
        _voiceProgressTimer?.cancel();
      }
    });
  }

  void _seekVoiceMessageFromTap(ChatMessage message, TapDownDetails details) {
    if (kIsWeb) {
      final audio = _voiceAudioElements[message.id];
      if (audio == null) return;

      final box = context.findRenderObject();
      if (box is! RenderBox) return;

      final width = box.size.width;
      if (width <= 0) return;

      final localDx = details.localPosition.dx.clamp(0.0, width);
      final ratio = (localDx / width).clamp(0.0, 1.0);
      final duration = _voiceEffectiveDuration(message);
      if (duration <= 0) return;

      final nextValue = duration * ratio;
      try {
        audio.currentTime = nextValue;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _voiceCurrentSeconds[message.id] = nextValue;
        });
      }
      return;
    }

    final player = _nativeVoicePlayers[message.id];
    if (player == null) return;

    final box = context.findRenderObject();
    if (box is! RenderBox) return;

    final width = box.size.width;
    if (width <= 0) return;

    final localDx = details.localPosition.dx.clamp(0.0, width);
    final ratio = (localDx / width).clamp(0.0, 1.0);
    final duration = _voiceEffectiveDuration(message);
    if (duration <= 0) return;

    final nextValue = duration * ratio;
    try {
      player.seek(Duration(milliseconds: (nextValue * 1000).round()));
    } catch (_) {}

    if (mounted) {
      setState(() {
        _voiceCurrentSeconds[message.id] = nextValue;
      });
    }
  }

  Future<AudioPlayer?> _ensureNativeVoicePlayer(ChatMessage message) async {
    final fullUrl =
        _cacheSafeAttachmentUrl(message) ?? _fullUrl(message.attachmentUrl);
    if (fullUrl == null || fullUrl.isEmpty) return null;

    AudioPlayer? player = _nativeVoicePlayers[message.id];

    if (player == null) {
      player = AudioPlayer();
      _nativeVoicePlayers[message.id] = player;

      player.onDurationChanged.listen((duration) {
        if (!mounted) return;
        setState(() {
          _voiceTotalSeconds[message.id] =
              duration.inMilliseconds <= 0 ? 0 : duration.inMilliseconds / 1000.0;
        });
      });

      player.onPositionChanged.listen((position) {
        if (!mounted) return;
        setState(() {
          _voiceCurrentSeconds[message.id] =
              position.inMilliseconds <= 0 ? 0 : position.inMilliseconds / 1000.0;
        });
      });

      player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _playingVoiceMessageId = null;
          _voiceCurrentSeconds[message.id] = 0;
        });
      });
    }

    if (kIsWeb) {
      await player.setSource(UrlSource(fullUrl));
      return player;
    }

    String? localPath = _nativeVoiceLocalPaths[message.id];

    if (localPath != null) {
      final cachedFile = File(localPath);
      if (!await cachedFile.exists()) {
        localPath = null;
        _nativeVoiceLocalPaths.remove(message.id);
      }
    }

    if (localPath == null) {
      debugPrint('VOICE DOWNLOAD START -> $fullUrl');
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode != 200) {
        debugPrint('VOICE DOWNLOAD STATUS -> ${response.statusCode}');
        debugPrint('VOICE DOWNLOAD ERROR: ${response.statusCode}');
        return null;
      }

      final dir = await getTemporaryDirectory();
      final safeId = message.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filePath = '${dir.path}/voice_$safeId.m4a';
      final file = File(filePath);

      await file.writeAsBytes(response.bodyBytes, flush: true);
      debugPrint('VOICE DOWNLOADED TO -> ${file.path}');
      debugPrint('VOICE DOWNLOADED BYTES -> ${response.bodyBytes.length}');
      localPath = file.path;
      _nativeVoiceLocalPaths[message.id] = localPath;
    }

    await player.setSource(DeviceFileSource(localPath));
    final savedSpeed = _voicePlaybackRates[message.id];
    if (savedSpeed != null && savedSpeed != 1.0) {
      await player.setPlaybackRate(savedSpeed);
    }    
    return player;
  }

  double _safeAudioNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) {
      final parsed = value.toDouble();
      if (parsed.isNaN || parsed.isInfinite || parsed < 0) return 0;
      return parsed;
    }
    final parsed = double.tryParse(value.toString());
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
      return 0;
    }
    return parsed;
  }

  double _voiceEffectiveDuration(ChatMessage message) {
    final metaDuration = (message.voiceDurationSeconds ?? 0).toDouble();
    final loadedDuration = _voiceTotalSeconds[message.id] ?? 0;
    final duration = math.max(metaDuration, loadedDuration);
    return duration > 0 ? duration : 1;
  }

  double _voiceProgress(ChatMessage message) {
    final duration = _voiceEffectiveDuration(message);
    if (duration <= 0) return 0;
    final current = (_voiceCurrentSeconds[message.id] ?? 0).clamp(0.0, duration);
    return (current / duration).clamp(0.0, 1.0);
  }

  List<double> _voiceWaveHeights(ChatMessage message, {int count = 34}) {
    final source = '${message.id}${message.createdAt}${message.senderUserId}';
    if (source.isEmpty) {
      return List<double>.filled(count, 10);
    }

    return List<double>.generate(count, (index) {
      final code = source.codeUnitAt(index % source.length);
      final seed = (code + index * 17) % 100;
      final normalized = (seed / 100);
      return 6 + normalized * 11;
    });
  }

  Future<void> _openAttachment(ChatMessage message) async {
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

  String? _cacheSafeAttachmentUrl(ChatMessage message) {
    final raw = message.attachmentUrl;
    final full = _fullUrl(raw);
    if (full == null || full.isEmpty) return null;

    // Для голосовых: если URL через media-proxy, достаём прямую ссылку.
    String result = full;
    if (message.type == AttachmentType.voice &&
        result.contains('/api/v1/staff/chat/media-proxy?url=')) {
      try {
        final uri = Uri.parse(result);
        final direct = uri.queryParameters['url'];
        if (direct != null && direct.trim().isNotEmpty) {
          result = Uri.decodeComponent(direct);
        }
      } catch (_) {}
    }

    // Для веба добавляем cache-buster, для мобильных – нет
    if (!kIsWeb) return result;

    final seedSource = message.createdAt.trim().isNotEmpty
        ? message.createdAt.trim()
        : message.id;
    final separator = result.contains('?') ? '&' : '?';
    return '${result}${separator}v=${Uri.encodeComponent(seedSource)}';
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

  bool _shouldShowVoiceTranscript(ChatMessage message) {
    if (message.type != AttachmentType.voice) return true;
    final text = message.messageText.trim();
    if (text.isEmpty) return false;
    final normalized = text.toLowerCase();
    return normalized != '🎤 голосовое сообщение' &&
        normalized != 'голосовое сообщение';
  }

  Widget _statusIcon(ChatMessage message, bool mine) {
    if (!mine || message.isDeleted) return const SizedBox.shrink();
    
    Icon icon;
    Color color;
    double size = 13;

    switch (message.status) {
      case MessageStatus.sending:
        icon = const Icon(CupertinoIcons.clock_fill);
        color = Colors.white.withOpacity(0.5);
        break;
      case MessageStatus.sent:
        icon = const Icon(CupertinoIcons.check_mark);
        color = Colors.white.withOpacity(0.7);
        break;
      case MessageStatus.delivered:
        // Двойная галочка через Row из двух иконок
        return Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.check_mark, size: 11, color: Colors.white.withOpacity(0.85)),
              const SizedBox(width: -3), // Наложение для эффекта "двойной"
              Icon(CupertinoIcons.check_mark, size: 11, color: Colors.white.withOpacity(0.85)),
            ],
          ),
        );
      case MessageStatus.read:
        return Animate(
          effects: [ScaleEffect(duration: 300.ms, begin: const Offset(0.6, 0.6), end: Offset.zero, curve: Curves.elasticOut), FadeEffect()],
          child: Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.check_mark, size: 12, color: const Color(0xFF64D2FF)),
                const SizedBox(width: -3),
                Icon(CupertinoIcons.check_mark, size: 12, color: const Color(0xFF64D2FF)),
              ],
            ),
          ),
        );
    }
    return Padding(padding: const EdgeInsets.only(left: 5), child: Icon(icon.icon, color: color, size: size));
  }

  bool _shouldShowUnreadDivider(ChatMessage current, ChatMessage? prev) {
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
      child: Animate(
        effects: [
          FadeEffect(duration: 300.ms),
          SlideEffect(begin: const Offset(0, -30), end: Offset.zero, duration: 400.ms),
        ],
        child: _GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: kChatGreen.withOpacity(0.12),
                ),
                child: const Icon(
                  CupertinoIcons.chat_bubble_text_fill,
                  color: kChatGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Печатают',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kChatInk,
                    fontSize: 14,
                  ),
                ),
              ),
              _AnimatedTypingDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageBodyText(ChatMessage message, bool mine) {
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

  bool _shouldShowAuthor(int index, List<ChatMessage> list) {
    if (index == 0) return true;
    final current = list[index];
    final prev = list[index - 1];
    return current.senderUserId != prev.senderUserId ||
        !_isSameDay(current.createdAt, prev.createdAt);
  }

  bool _shouldShowCompactSpacing(int index, List<ChatMessage> list) {
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
    return GestureDetector(
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
    ChatMessage message, {
    required bool showAuthor,
    required bool compactTopSpacing,
    required int order,
  }) {
    final mine = _isMine(message);
    final isHighlighted = _highlightedMessageId == message.id;
    final isSelected = _selectedMessageIds.contains(message.id);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Animate(
        key: ValueKey(message.id),
        effects: [
          FadeEffect(duration: 200.ms, delay: (order * 30).ms),
          ScaleEffect(
            duration: 250.ms,
            begin: const Offset(0.85, 0.85),
            end: const Offset(1, 1),
            curve: Curves.easeOutBack,
          ),
        ],
        child: Container(
          key: _keyForMessage(message.id),
          padding: EdgeInsets.only(bottom: compactTopSpacing ? 6 : 12),
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!mine)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Builder(
                      builder: (buttonContext) => _bubbleSideButton(
                        icon: _selectionMode
                            ? (isSelected
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.circle)
                            : CupertinoIcons.ellipsis_circle,
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelection(message);
                          } else {
                            _openMessageActions(message, anchorContext: buttonContext);
                          }
                        },
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.74,
                  ),
                  child: Column(
                    crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onLongPress: () {
                          if (_selectionMode) {
                            _toggleSelection(message);
                          } else {
                            _enterSelectionMode(message);
                          }
                        },
                        onSecondaryTap: () => _openMessageActions(message),
                        child: message.type == AttachmentType.voice
                            ? Column(   // для голосовых — без внешней плашки
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Автор (если не моё и showAuthor)
                                  if (!mine && showAuthor)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        message.senderName.isEmpty ? 'Сотрудник' : message.senderName,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          color: kChatInkSoft,
                                        ),
                                      ),
                                    ),
                                  // Reply (если есть)
                                  if ((message.replyText ?? '').trim().isNotEmpty ||
                                      (message.replySenderName ?? '').trim().isNotEmpty)
                                    GestureDetector(
                                      onTap: () => _scrollToMessageById(message.replyToMessageId),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                                              margin: const EdgeInsets.only(top: 1, right: 8),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(99),
                                                color: mine ? Colors.white : kChatBlue,
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    (message.replySenderName ?? 'Сотрудник').trim().isEmpty
                                                        ? 'Сотрудник'
                                                        : message.replySenderName!.trim(),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w900,
                                                      color: mine ? Colors.white : kChatBlue,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    (message.replyText ?? '').trim().isEmpty
                                                        ? 'Сообщение'
                                                        : message.replyText!.trim(),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      height: 1.25,
                                                      fontWeight: FontWeight.w700,
                                                      color: mine
                                                          ? Colors.white.withOpacity(0.86)
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
                                  // Само голосовое сообщение
                                  _voiceBubble(mine, message),
                                  if (message.messageText.trim().isNotEmpty) const SizedBox(height: 8),
                                  if (!message.isDeleted &&
                                      message.messageText.trim().isNotEmpty &&
                                      _shouldShowVoiceTranscript(message))
                                    _messageBodyText(message, mine),
                                  const SizedBox(height: 7),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (message.isPinned) ...[
                                        Icon(CupertinoIcons.pin_fill, size: 12,
                                            color: mine ? Colors.white.withOpacity(0.82) : kChatBlue),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        _formatMessageTime(message.createdAt),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: mine ? Colors.white.withOpacity(0.86) : kChatInkSoft,
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
                                            color: mine ? Colors.white.withOpacity(0.80) : kChatInkSoft,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              )
                            : Container(   // для всех остальных типов (текст, фото, файл) — оставляем старую красивую плашку
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
                                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.95),
                                            Colors.white.withOpacity(0.85),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  border: mine
                                      ? Border.all(
                                          color: isSelected
                                              ? kChatAccentSoft.withOpacity(0.90)
                                              : isHighlighted
                                                  ? Colors.white.withOpacity(0.45)
                                                  : Colors.transparent,
                                          width: isSelected ? 1.6 : (isHighlighted ? 1.2 : 0),
                                        )
                                      : Border.all(
                                          color: isSelected
                                              ? kChatAmber.withOpacity(0.90)
                                              : isHighlighted
                                                  ? kChatBlue.withOpacity(0.55)
                                                  : Colors.white.withOpacity(0.94),
                                          width: isSelected ? 1.6 : (isHighlighted ? 1.4 : 1),
                                        ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (mine ? const Color(0xFF6366F1) : Colors.black).withOpacity(0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: (mine ? Colors.black : Colors.white).withOpacity(0.05),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
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
                                          message.senderName.isEmpty ? 'Сотрудник' : message.senderName,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w900,
                                            color: kChatInkSoft,
                                          ),
                                        ),
                                      ),
                                    if ((message.replyText ?? '').trim().isNotEmpty ||
                                        (message.replySenderName ?? '').trim().isNotEmpty)
                                      GestureDetector(
                                        onTap: () => _scrollToMessageById(message.replyToMessageId),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                                                margin: const EdgeInsets.only(top: 1, right: 8),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(99),
                                                  color: mine ? Colors.white : kChatBlue,
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      (message.replySenderName ?? 'Сотрудник').trim().isEmpty
                                                          ? 'Сотрудник'
                                                          : message.replySenderName!.trim(),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: mine ? Colors.white : kChatBlue,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      (message.replyText ?? '').trim().isEmpty
                                                          ? 'Сообщение'
                                                          : message.replyText!.trim(),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        height: 1.25,
                                                        fontWeight: FontWeight.w700,
                                                        color: mine
                                                            ? Colors.white.withOpacity(0.86)
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
                                    if (message.type == AttachmentType.image) ...[
                                      _messageImage(message),
                                      if (_shouldShowVoiceTranscript(message)) const SizedBox(height: 8),
                                    ],
                                    if (message.type == AttachmentType.file) ...[
                                      _fileBubble(mine, message),
                                      if (message.messageText.trim().isNotEmpty) const SizedBox(height: 8),
                                    ],
                                    if (message.type != AttachmentType.voice &&
                                        message.type != AttachmentType.image &&
                                        message.type != AttachmentType.file &&
                                        !message.isDeleted &&
                                        message.messageText.trim().isNotEmpty)
                                      _messageBodyText(message, mine),
                                    const SizedBox(height: 7),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (message.isPinned) ...[
                                          Icon(CupertinoIcons.pin_fill, size: 12,
                                              color: mine ? Colors.white.withOpacity(0.82) : kChatBlue),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          _formatMessageTime(message.createdAt),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: mine ? Colors.white.withOpacity(0.86) : kChatInkSoft,
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
                                              color: mine ? Colors.white.withOpacity(0.80) : kChatInkSoft,
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
                    child: Builder(
                      builder: (buttonContext) => _bubbleSideButton(
                        icon: _selectionMode
                            ? (isSelected
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.circle)
                            : CupertinoIcons.ellipsis_circle,
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelection(message);
                          } else {
                            _openMessageActions(message, anchorContext: buttonContext);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMessageActions(
    ChatMessage message, {
    BuildContext? anchorContext,
  }) async {
    final RenderBox? renderBox = anchorContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = renderBox?.size ?? Size.zero;

    final mine = _isMine(message);

    final items = [
      PopupMenuItem(
        value: 'select',
        child: Row(children: [Icon(CupertinoIcons.check_mark_circled, color: kChatAmber, size: 20), const SizedBox(width: 12), const Text('Выбрать')]),
      ),
      PopupMenuItem(
        value: 'reply',
        child: Row(children: [Icon(CupertinoIcons.reply, color: kChatBlue, size: 20), const SizedBox(width: 12), const Text('Ответить')]),
      ),
      PopupMenuItem(
        value: 'copy',
        child: Row(children: [Icon(CupertinoIcons.doc_on_doc, color: kChatViolet, size: 20), const SizedBox(width: 12), const Text('Копировать')]),
      ),
      PopupMenuItem(
        value: 'react',
        child: Row(children: [Icon(CupertinoIcons.smiley, color: kChatGreen, size: 20), const SizedBox(width: 12), const Text('Добавить реакцию')]),
      ),
      PopupMenuItem(
        value: 'pin',
        child: Row(children: [Icon(CupertinoIcons.pin, color: kChatAmber, size: 20), const SizedBox(width: 12), Text(message.isPinned ? 'Открепить' : 'Закрепить')]),
      ),
      if (message.type == AttachmentType.file || message.type == AttachmentType.voice)
        PopupMenuItem(
          value: 'open',
          child: Row(children: [Icon(message.type == AttachmentType.voice ? CupertinoIcons.play_circle : CupertinoIcons.paperclip, color: kChatBlue, size: 20), const SizedBox(width: 12), Text(message.type == AttachmentType.voice ? 'Прослушать' : 'Открыть файл')]),
        ),
      if (mine && !message.isDeleted && message.type == AttachmentType.text)
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [Icon(CupertinoIcons.pencil, color: kChatBlue, size: 20), const SizedBox(width: 12), const Text('Редактировать')]),
        ),
      PopupMenuItem(
        value: 'delete',
        child: Row(children: [Icon(CupertinoIcons.delete_solid, color: kChatRed, size: 20), const SizedBox(width: 12), Text(mine ? 'Удалить у всех' : 'Удалить у себя')]),
      ),
    ];

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx + size.width / 2,
        position.dy + size.height,
        position.dx + size.width / 2,
        position.dy + size.height,
      ),
      items: items,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    if (selected == null) return;

    switch (selected) {
      case 'select': _enterSelectionMode(message); break;
      case 'reply': _startReply(message); break;
      case 'copy': await _copyMessageText(message); break;
      case 'react': await _openEmojiPanel(message); break;
      case 'pin': await _togglePinnedMessageLocal(message); break;
      case 'open':
        if (message.type == AttachmentType.voice) await _toggleInlineVoicePlayback(message);
        else await _openAttachment(message);
        break;
      case 'edit': await _startEditMessage(message); break;
      case 'delete':
        if (mine) await _deleteForAll(message);
        else await _deleteForMe(message);
        break;
    }
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

    return Animate(
      effects: [
        FadeEffect(duration: 200.ms),
        SlideEffect(begin: const Offset(0, -20), end: Offset.zero, duration: 300.ms, curve: Curves.easeOutBack),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                borderRadius: BorderRadius.circular(32),
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
                  // Анимированный индикатор записи (круг с микрофоном)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(kChatRed),
                          backgroundColor: Color(0x33FF6A5E),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kChatRed,
                            boxShadow: [
                              BoxShadow(
                                color: kChatRed.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.mic, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Запись голосового сообщения',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
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
                              _formatSeconds(_recordingSeconds),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Кнопка Отмена
                  _buildGlassButton(
                    label: 'Отмена',
                    onTap: _cancelVoiceRecording,
                    textColor: Colors.white70,
                  ),
                  const SizedBox(width: 10),
                  // Кнопка Отправить
                  _buildGlassButton(
                    label: 'Отправить',
                    onTap: _stopAndSendVoiceRecording,
                    textColor: Colors.white,
                    filled: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required VoidCallback onTap,
    required Color textColor,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: filled ? kChatBlue : Colors.white.withOpacity(0.15),
          border: filled ? null : Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
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
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _startVoiceRecording();
                        },
                        child: Animate(
                          effects: [
                            ScaleEffect(
                              duration: 150.ms,
                              begin: Offset(1, 1),
                              end: Offset(1.1, 1.1),
                              curve: Curves.easeInOut,
                            ),
                          ],
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: kChatRed.withOpacity(0.15),
                            ),
                            child: const Icon(CupertinoIcons.mic_fill, color: kChatRed),
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
                        child: GestureDetector(
                          onTap: _sending ? null : () async {
                            HapticFeedback.lightImpact();
                            await _sendMessage();
                          },
                          child: AnimatedScale(
                            scale: 0.95,
                            duration: const Duration(milliseconds: 100),
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
    final state = _chatCubit.state;
    final isLoading = state.status == ChatStatus.loading;
    final filteredMessages = _filteredMessages();
    final hasMessages = state.messages.isNotEmpty;
    final hasFiltered = filteredMessages.isNotEmpty;

    if (isLoading) {
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

    if (!hasMessages) {
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

    if (!hasFiltered) {
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

    final itemCount = filteredMessages.length + 1;
    final showLoader = state.isLoadingMore && state.hasMore;

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == filteredMessages.length) {
              if (showLoader) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(kChatViolet),
                      ),
                    ),
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            }

            final message = filteredMessages[index];
            final prev = index > 0 ? filteredMessages[index - 1] : null;
            final showDayDivider = prev == null || !_isSameDay(prev.createdAt, message.createdAt);
            final showUnreadDivider = _shouldShowUnreadDivider(message, prev);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDayDivider)
                  _stagger(
                    index: index + 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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
                if (showUnreadDivider)
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
                _stagger(
                  index: index + 2,
                  child: _messageBubble(
                    message,
                    showAuthor: _shouldShowAuthor(index, filteredMessages),
                    compactTopSpacing: _shouldShowCompactSpacing(index, filteredMessages),
                    order: index,
                  ),
                ),
              ],
            );
          },
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
                              border: Border.all(color: Colors.white.withOpacity(0.94)),
                            ),
                            child: const Icon(CupertinoIcons.mail_solid, color: kChatAmber),
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
                        child: const Icon(CupertinoIcons.arrow_down, color: kChatInk),
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
    final messages = _chatCubit.state.messages;
    for (final m in messages) {
      final name = m.senderName.trim().isEmpty ? 'Сотрудник' : m.senderName.trim();
      set.add(name);
    }
    return set.toList()..sort();
  }

  Future<void> _openParticipantsSheet() async {
    final names = _participantNames();
    final stats = <String, int>{};
    final messages = _chatCubit.state.messages;
    for (final m in messages) {
      final name = m.senderName.trim().isEmpty ? 'Сотрудник' : m.senderName.trim();
      stats[name] = (stats[name] ?? 0) + 1;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 80, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Участники чата',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: names.length,
                      itemBuilder: (ctx, idx) {
                        final name = names[idx];
                        final count = stats[name] ?? 0;
                        final initials = name.split(' ').map((e) => e[0]).take(2).join().toUpperCase();
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: NetworkImage('https://ui-avatars.com/api/?background=6366F1&color=fff&name=$initials'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text('Сообщений: $count', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  Widget _modernActionTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [kChatBlue, kChatViolet]),
              boxShadow: [
                BoxShadow(color: kChatBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _openAttachmentSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Wrap(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _modernActionTile(
                      icon: Icons.image,
                      label: 'Фото',
                      onTap: () { Navigator.pop(context); _pickImage(); },
                    ),
                    _modernActionTile(
                      icon: Icons.camera_alt,
                      label: 'Камера',
                      onTap: () { Navigator.pop(context); _pickFromCamera(); },
                    ),
                    _modernActionTile(
                      icon: Icons.insert_drive_file,
                      label: 'Файл',
                      onTap: () { Navigator.pop(context); _sendDocument(); },
                    ),
                    _modernActionTile(
                      icon: Icons.mic,
                      label: 'Голос',
                      onTap: () { Navigator.pop(context); _startVoiceRecording(); },
                    ),
                  ],
                ),
              ],
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
      centerTitle: false,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Чат',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.establishmentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ),
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
            onTap: () => _refreshMessagesSilently(keepScrollOffset: true),
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
        onTap: () => FocusScope.of(context).unfocus(),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: BlocListener<ChatCubit, ChatState>(
            bloc: _chatCubit,
            listener: (context, state) {
              _safeUpdateLocalFields(state);
            },
            child: BlocBuilder<ChatCubit, ChatState>(
              bloc: _chatCubit,
              builder: (context, state) {
                return Stack(
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
                              left: 0, right: 0, bottom: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _recordingBanner(), // Теперь внизу
                                  _composer(),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _setVoiceSpeed(ChatMessage message, double speed) async {
    if (mounted) {
      setState(() {
        _voicePlaybackRates[message.id] = speed;
      });
    }
    final player = _nativeVoicePlayers[message.id];
    if (player != null) {
      await player.setPlaybackRate(speed);
    }
    final webAudio = _voiceAudioElements[message.id];
    if (webAudio != null && kIsWeb) {
      try {
        webAudio.playbackRate = speed;
      } catch (_) {}
    }
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

class _AnimatedTypingDots extends StatefulWidget {
    @override
    State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
  }

  class _AnimatedTypingDotsState extends State<_AnimatedTypingDots> with SingleTickerProviderStateMixin {
    late AnimationController _controller;

    @override
    void initState() {
      super.initState();
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat();
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDot(0, t),
              const SizedBox(width: 4),
              _buildDot(1, t),
              const SizedBox(width: 4),
              _buildDot(2, t),
            ],
          );
        },
      );
    }

    Widget _buildDot(int index, double t) {
      final delay = index * 0.2;
      final scale = (t + delay) % 1.0;
      final animatedScale = scale < 0.5 ? scale * 2 : 2 - scale * 2;
      return Transform.scale(
        scale: 0.6 + animatedScale * 0.4,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kChatGreen,
          ),
        ),
      );
    }
  }

class _VoiceProgressWave extends StatefulWidget {
  final double progress;
  final bool isPlaying;
  final Color color;
  final double height;

  const _VoiceProgressWave({
    required this.progress,
    required this.isPlaying,
    required this.color,
    this.height = 28,
  });

  @override
  State<_VoiceProgressWave> createState() => _VoiceProgressWaveState();
}

class _VoiceProgressWaveState extends State<_VoiceProgressWave> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    if (widget.isPlaying) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(_VoiceProgressWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Основной builder для волны
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barCount = 24;
          final barWidth = (constraints.maxWidth / barCount) - 2;
          final step = constraints.maxWidth / barCount;
          final now = DateTime.now().millisecondsSinceEpoch;
          return Row(
            children: List.generate(barCount, (i) {
              final t = i / (barCount - 1);
              final isActive = t <= widget.progress;
              // Высота столбика: базовая + анимация, если играет
              double height;
              if (widget.isPlaying) {
                final int phase = (now ~/ 150 + i) % 360;
                height = 10 + 12 * (0.5 + 0.5 * math.sin(phase * math.pi / 180));
              } else {
                // Неактивная часть или завершённая часть – линейное затухание
                if (isActive) {
                  height = 14 + 8 * (1 - (widget.progress - t).abs()).clamp(0.0, 1.0);
                } else {
                  height = 6;
                }
              }
              height = height.clamp(4.0, widget.height - 4);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: barWidth,
                height: height,
                margin: const EdgeInsets.only(right: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(barWidth / 2),
                  color: isActive ? widget.color : widget.color.withOpacity(0.2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}