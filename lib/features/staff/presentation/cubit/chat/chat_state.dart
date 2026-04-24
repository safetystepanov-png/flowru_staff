import '../../../data/models/chat_message.dart';
import 'package:equatable/equatable.dart';

part of 'chat_cubit.dart';

enum ChatStatus { initial, loading, success, failure }

class ChatState extends Equatable {
  final ChatStatus status;
  final List<ChatMessage> messages;
  final String? error;
  final String? replyingToMessageId;
  final String? editingMessageId;
  final Set<String> selectedMessageIds;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;

  const ChatState({
    required this.status,
    required this.messages,
    this.error,
    this.replyingToMessageId,
    this.editingMessageId,
    this.selectedMessageIds = const {},
    this.currentPage = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  factory ChatState.initial() => ChatState(
    status: ChatStatus.initial,
    messages: [],
    selectedMessageIds: {},
    currentPage: 1,
    hasMore: true,
    isLoadingMore: false,
  );

  ChatState copyWith({
    ChatStatus? status,
    List<ChatMessage>? messages,
    String? error,
    String? replyingToMessageId,
    String? editingMessageId,
    Set<String>? selectedMessageIds,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      error: error ?? this.error,
      replyingToMessageId: replyingToMessageId ?? this.replyingToMessageId,
      editingMessageId: editingMessageId ?? this.editingMessageId,
      selectedMessageIds: selectedMessageIds ?? this.selectedMessageIds,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    error,
    replyingToMessageId,
    editingMessageId,
    selectedMessageIds,
    currentPage,
    hasMore,
    isLoadingMore,
  ];
}