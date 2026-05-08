import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';

// ═══════════════════════════════════════════════════════════════
//  EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadChatsEvent extends ChatEvent {
  final String userId;
  LoadChatsEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class OpenChatEvent extends ChatEvent {
  final String currentUserId;
  final String otherUserId;
  OpenChatEvent({required this.currentUserId, required this.otherUserId});
  @override
  List<Object?> get props => [currentUserId, otherUserId];
}

class LoadMessagesEvent extends ChatEvent {
  final String chatId;
  final String currentUserId;
  LoadMessagesEvent({required this.chatId, required this.currentUserId});
  @override
  List<Object?> get props => [chatId, currentUserId];
}

class SendTextMessageEvent extends ChatEvent {
  final String chatId;
  final String senderId;
  final String senderName;
  final String content;
  SendTextMessageEvent({
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.content,
  });
  @override
  List<Object?> get props => [chatId, senderId, content];
}

class SendImageMessageEvent extends ChatEvent {
  final String chatId;
  final String senderId;
  final String senderName;
  final File image;
  SendImageMessageEvent({
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.image,
  });
  @override
  List<Object?> get props => [chatId, senderId];
}

// ═══════════════════════════════════════════════════════════════
//  STATES
// ═══════════════════════════════════════════════════════════════

abstract class ChatState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}
class ChatLoading extends ChatState {}

class ChatsLoaded extends ChatState {
  final List<ChatEntity> chats;
  ChatsLoaded(this.chats);
  @override
  List<Object?> get props => [chats];
}

class ChatOpened extends ChatState {
  final ChatEntity chat;
  ChatOpened(this.chat);
  @override
  List<Object?> get props => [chat];
}

class MessagesLoaded extends ChatState {
  final String chatId;
  final String currentUserId;
  final List<MessageEntity> messages;
  final bool isUploadingImage;

  MessagesLoaded({
    required this.chatId,
    required this.currentUserId,
    required this.messages,
    this.isUploadingImage = false,
  });

  MessagesLoaded copyWith({
    List<MessageEntity>? messages,
    bool? isUploadingImage,
  }) => MessagesLoaded(
    chatId: chatId,
    currentUserId: currentUserId,
    messages: messages ?? this.messages,
    isUploadingImage: isUploadingImage ?? this.isUploadingImage,
  );

  @override
  List<Object?> get props => [chatId, currentUserId, messages, isUploadingImage];
}

class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
//  BLOC
//
//  ROOT CAUSE OF THE ERROR:
//  "An event handler completed but left pending subscriptions behind"
//
//  When you write:
//    void _onLoadChats(event, emit) {
//      emit.forEach(...);   ← NOT awaited → subscription leaks!
//    }
//
//  The handler returns immediately (void) but emit.forEach is
//  still running in background. BLoC detects this and throws.
//
//  FIX: Every handler that uses emit.forEach MUST be:
//    async + await emit.forEach(...)
//
//  ROOT CAUSE OF GROUP LIST DISAPPEARING:
//  There is ONE GroupChatBloc shared between:
//    - GroupListScreen  → LoadGroupChatsEvent  → emit.forEach (stream A)
//    - GroupChatScreen  → LoadGroupMessagesEvent → emit.forEach (stream B)
//
//  When GroupChatScreen dispatches LoadGroupMessagesEvent,
//  the NEW emit.forEach (stream B) CANCELS stream A.
//  When you pop back, stream A is gone → list is empty.
//
//  FIX: Use SEPARATE BLoC instances for list vs chat screen.
//  GroupChatScreen creates its own BlocProvider.
// ═══════════════════════════════════════════════════════════════

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _chatRepository;

  ChatBloc({required ChatRepository chatRepository})
      : _chatRepository = chatRepository,
        super(ChatInitial()) {
    on<LoadChatsEvent>(_onLoadChats);
    on<OpenChatEvent>(_onOpenChat);
    on<LoadMessagesEvent>(_onLoadMessages);
    // concurrent transformer: send runs alongside the active stream
    // so SendText does NOT cancel the LoadMessages stream
    on<SendTextMessageEvent>(_onSendText,
        transformer: (events, mapper) => events.asyncExpand(mapper));
    on<SendImageMessageEvent>(_onSendImage,
        transformer: (events, mapper) => events.asyncExpand(mapper));
  }

  // ── FIX: async + await ──────────────────────────────────────
  Future<void> _onLoadChats(
      LoadChatsEvent event, Emitter<ChatState> emit) async {
    await emit.forEach<List<ChatEntity>>(
      _chatRepository.getUserChats(event.userId),
      onData: ChatsLoaded.new,
      onError: (_, __) => ChatError('Failed to load chats'),
    );
  }

  Future<void> _onOpenChat(
      OpenChatEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final result = await _chatRepository.createOrGetChat(
      currentUserId: event.currentUserId,
      otherUserId: event.otherUserId,
    );
    result.fold(
      (failure) => emit(ChatError(failure.message)),
      (chat) => emit(ChatOpened(chat)),
    );
  }

  // ── FIX: async + await ──────────────────────────────────────
  Future<void> _onLoadMessages(
      LoadMessagesEvent event, Emitter<ChatState> emit) async {
    _chatRepository.markMessagesAsRead(
      chatId: event.chatId,
      userId: event.currentUserId,
    );
    await emit.forEach<List<MessageEntity>>(
      _chatRepository.getChatMessages(event.chatId),
      onData: (messages) => MessagesLoaded(
        chatId: event.chatId,
        currentUserId: event.currentUserId,
        messages: messages,
      ),
      onError: (_, __) => ChatError('Failed to load messages'),
    );
  }

  Future<void> _onSendText(
      SendTextMessageEvent event, Emitter<ChatState> emit) async {
    await _chatRepository.sendMessage(
      chatId: event.chatId,
      senderId: event.senderId,
      senderName: event.senderName,
      content: event.content,
      type: 'text',
    );
  }

  Future<void> _onSendImage(
      SendImageMessageEvent event, Emitter<ChatState> emit) async {
    final current = state;
    if (current is MessagesLoaded) {
      emit(current.copyWith(isUploadingImage: true));
    }
    final uploadResult = await _chatRepository.uploadChatImage(
      image: event.image,
      chatId: event.chatId,
    );
    await uploadResult.fold(
      (failure) async {
        if (current is MessagesLoaded) {
          emit(current.copyWith(isUploadingImage: false));
        }
      },
      (imageUrl) async {
        await _chatRepository.sendMessage(
          chatId: event.chatId,
          senderId: event.senderId,
          senderName: event.senderName,
          content: '📷 Photo',
          type: 'image',
          imageUrl: imageUrl,
        );
        if (current is MessagesLoaded) {
          emit(current.copyWith(isUploadingImage: false));
        }
      },
    );
  }
}
