import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/chat_repository.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository repository;
  final int establishmentId;
  String? currentUserId;

  ChatCubit({required this.repository, required this.establishmentId})
      : super(ChatState.initial());

  // Загрузка первой страницы сообщений (или обновление)
  Future<void> loadMessages({bool silent = false, String? userId}) async {
    if (userId != null) currentUserId = userId;
    if (!silent) emit(state.copyWith(status: ChatStatus.loading));
    try {
      // Загружаем первую страницу, limit = 30
      final msgs = await repository.getMessages(establishmentId, page: 1, limit: 30);
      emit(state.copyWith(
        status: ChatStatus.success,
        messages: msgs,
        error: null,
        currentPage: 1,
        hasMore: msgs.length >= 30, // если пришло 30 сообщений, возможно есть ещё
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(state.copyWith(status: ChatStatus.failure, error: e.toString()));
    }
  }

  // Загрузка следующих страниц (пагинация)
  Future<void> loadMoreMessages() async {
    // Если уже грузится или больше нет сообщений – выходим
    if (state.isLoadingMore || !state.hasMore) return;

    final nextPage = state.currentPage + 1;
    // Включаем флаг загрузки
    emit(state.copyWith(isLoadingMore: true));

    try {
      final newMessages = await repository.getMessages(
        establishmentId,
        page: nextPage,
        limit: 30,
      );

      final allMessages = [...state.messages, ...newMessages];

      emit(state.copyWith(
        messages: allMessages,
        currentPage: nextPage,
        hasMore: newMessages.length >= 30,
        isLoadingMore: false,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      ));
    }
  }

  // Отправка текстового сообщения (с оптимистичным обновлением)
  Future<void> sendTextMessage(String text, {String? replyToId}) async {
    final optimisticId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: optimisticId,
      senderUserId: currentUserId ?? '',
      senderName: 'Вы',
      messageText: text,
      createdAt: DateTime.now().toIso8601String(),
      localImageBytes: null,
      attachmentUrl: null,
      fileName: null,
      reactions: [],
      isDeleted: false,
      isEdited: false,
      replyToMessageId: replyToId,
      replySenderName: state.replyingToMessageId != null ? 'Сотрудник' : null,
      replyText: null,
      isPinned: false,
      type: AttachmentType.text,
      voiceDurationSeconds: null,
      isLocalOnly: true,
      status: MessageStatus.sending,
      isRead: false,
    );

    final newMessages = [...state.messages, optimistic];
    emit(state.copyWith(messages: newMessages, replyingToMessageId: null));

    try {
      await repository.sendTextMessage(establishmentId, text, replyToId: replyToId);
      // После успешной отправки перезагружаем чат, чтобы получить реальное сообщение с сервера
      await loadMessages(silent: true);
    } catch (e) {
      final withoutOptimistic = state.messages.where((m) => m.id != optimisticId).toList();
      emit(state.copyWith(messages: withoutOptimistic, error: e.toString()));
    }
  }

  // Установка сообщения, на которое отвечаем
  void setReplyingTo(String? messageId) {
    emit(state.copyWith(replyingToMessageId: messageId));
  }

  // Вспомогательный метод (если нужен)
  void emitState(ChatState newState) {
    emit(newState);
  }
}