import 'dart:typed_data';
import 'reaction_item.dart';

enum MessageStatus { sending, sent, delivered, read }
enum AttachmentType { text, image, file, voice }

class ChatMessage {
  final String id;
  final String senderUserId;
  final String senderName;
  final String messageText;
  final String createdAt;
  final Uint8List? localImageBytes;
  final String? attachmentUrl;
  final String? fileName;
  final List<ReactionItem> reactions;
  final bool isDeleted;
  final bool isEdited;
  final String? replyToMessageId;
  final String? replySenderName;
  final String? replyText;
  final bool isPinned;
  final AttachmentType type;
  final int? voiceDurationSeconds;
  final bool isLocalOnly;
  final MessageStatus status;
  final bool isRead;

  ChatMessage({
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

  bool isMine(String currentUserId) => senderUserId == currentUserId;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<ReactionItem> parseReactions(dynamic value) {
      if (value is! List) return [];
      return value.map((e) => ReactionItem.fromJson(e as Map<String, dynamic>)).toList();
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

    MessageStatus parseStatus(dynamic value, bool isRead) {
      final s = value?.toString().toLowerCase() ?? '';
      if (isRead) return MessageStatus.read;
      if (s == 'read') return MessageStatus.read;
      if (s == 'delivered') return MessageStatus.delivered;
      if (s == 'sending') return MessageStatus.sending;
      return MessageStatus.sent;
    }

    final typeRaw = (json['message_type']?.toString().toLowerCase() ??
            json['type']?.toString().toLowerCase() ??
            '')
        .trim();

    final fileUrl = json['file_url']?.toString() ?? json['attachment_url']?.toString();
    final imageUrl = json['image_url']?.toString() ?? json['media_url']?.toString();
    final audioUrl = json['audio_url']?.toString() ?? json['voice_url']?.toString();
    final attachmentTypeRaw = (json['attachment_type']?.toString().toLowerCase() ?? '').trim();
    final attachmentUrl = imageUrl?.trim().isNotEmpty == true
        ? imageUrl
        : fileUrl?.trim().isNotEmpty == true
            ? fileUrl
            : audioUrl;

    final fileName = json['file_name']?.toString() ??
        json['original_file_name']?.toString() ??
        json['attachment_name']?.toString() ??
        json['document_name']?.toString();

    AttachmentType attachmentType;
    if (typeRaw == 'voice' ||
        typeRaw == 'audio' ||
        audioUrl?.isNotEmpty == true ||
        attachmentTypeRaw.startsWith('audio/')) {
      attachmentType = AttachmentType.voice;
    } else if (typeRaw == 'file' || typeRaw == 'document') {
      attachmentType = AttachmentType.file;
    } else if (typeRaw == 'image' || typeRaw == 'photo') {
      attachmentType = AttachmentType.image;
    } else if ((imageUrl ?? '').isNotEmpty) {
      attachmentType = AttachmentType.image;
    } else if ((fileUrl ?? '').isNotEmpty) {
      attachmentType = AttachmentType.file;
    } else {
      attachmentType = AttachmentType.text;
    }

    final isRead = parseBool(json['is_read'] ?? json['read']);

    return ChatMessage(
      id: json['message_id']?.toString() ?? json['id']?.toString() ?? '',
      senderUserId: json['sender_user_id']?.toString() ?? json['user_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ??
          json['full_name']?.toString() ??
          json['username']?.toString() ??
          '',
      messageText: json['message_text']?.toString() ?? json['text']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      localImageBytes: null,
      attachmentUrl: attachmentUrl,
      fileName: fileName,
      reactions: parseReactions(json['reactions']),
      isDeleted: parseBool(json['is_deleted'] ?? json['deleted']),
      isEdited: parseBool(json['is_edited'] ?? json['edited']),
      replyToMessageId: json['reply_to_message_id']?.toString(),
      replySenderName: json['reply_sender_name']?.toString() ?? json['reply_to_sender_name']?.toString(),
      replyText: json['reply_text']?.toString() ?? json['reply_to_message_text']?.toString(),
      isPinned: parseBool(json['is_pinned']),
      type: attachmentType,
      voiceDurationSeconds: parseInt(json['voice_duration_seconds'] ?? json['duration_seconds']),
      isLocalOnly: false,
      status: parseStatus(json['status'], isRead),
      isRead: isRead,
    );
  }

  ChatMessage copyWith({
    String? messageText,
    Uint8List? localImageBytes,
    String? attachmentUrl,
    String? fileName,
    List<ReactionItem>? reactions,
    bool? isDeleted,
    bool? isEdited,
    String? replyToMessageId,
    String? replySenderName,
    String? replyText,
    bool? isPinned,
    AttachmentType? type,
    int? voiceDurationSeconds,
    bool? isLocalOnly,
    MessageStatus? status,
    bool? isRead,
  }) {
    return ChatMessage(
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