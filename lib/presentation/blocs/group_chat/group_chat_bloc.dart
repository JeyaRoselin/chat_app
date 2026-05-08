import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';

// ═══════════════════════════════════════════════════════════════
//  EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class GroupChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadGroupChatsEvent extends GroupChatEvent {
  final String userId;
  LoadGroupChatsEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class CreateGroupChatEvent extends GroupChatEvent {
  final String name;
  final String createdBy;
  final List<String> members;
  final File? groupImage;
  CreateGroupChatEvent({
    required this.name,
    required this.createdBy,
    required this.members,
    this.groupImage,
  });
  @override
  List<Object?> get props => [name, createdBy, members];
}

class LoadGroupMessagesEvent extends GroupChatEvent {
  final String groupId;
  final String currentUserId;
  LoadGroupMessagesEvent({required this.groupId, required this.currentUserId});
  @override
  List<Object?> get props => [groupId, currentUserId];
}

class SendGroupTextMessageEvent extends GroupChatEvent {
  final String groupId;
  final String senderId;
  final String senderName;
  final String content;
  SendGroupTextMessageEvent({
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.content,
  });
  @override
  List<Object?> get props => [groupId, senderId, content];
}

class SendGroupImageMessageEvent extends GroupChatEvent {
  final String groupId;
  final String senderId;
  final String senderName;
  final File image;
  SendGroupImageMessageEvent({
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.image,
  });
}

class AddMembersToGroupEvent extends GroupChatEvent {
  final String groupId;
  final List<String> newMembers;
  AddMembersToGroupEvent({required this.groupId, required this.newMembers});
}

// ═══════════════════════════════════════════════════════════════
//  STATES
// ═══════════════════════════════════════════════════════════════

abstract class GroupChatState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GroupChatInitial extends GroupChatState {}
class GroupChatLoading extends GroupChatState {}

class GroupChatsLoaded extends GroupChatState {
  final List<GroupChatEntity> groups;
  GroupChatsLoaded(this.groups);
  @override
  List<Object?> get props => [groups];
}

class GroupCreated extends GroupChatState {
  final GroupChatEntity group;
  GroupCreated(this.group);
  @override
  List<Object?> get props => [group];
}

class GroupMessagesLoaded extends GroupChatState {
  final String groupId;
  final String currentUserId;
  final List<MessageEntity> messages;
  final bool isUploadingImage;

  GroupMessagesLoaded({
    required this.groupId,
    required this.currentUserId,
    required this.messages,
    this.isUploadingImage = false,
  });

  GroupMessagesLoaded copyWith({
    List<MessageEntity>? messages,
    bool? isUploadingImage,
  }) => GroupMessagesLoaded(
    groupId: groupId,
    currentUserId: currentUserId,
    messages: messages ?? this.messages,
    isUploadingImage: isUploadingImage ?? this.isUploadingImage,
  );

  @override
  List<Object?> get props =>
      [groupId, currentUserId, messages, isUploadingImage];
}

class GroupChatError extends GroupChatState {
  final String message;
  GroupChatError(this.message);
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════
//  BLOC
//
//  TWO SEPARATE BLOC PURPOSES:
//  ┌────────────────────────────────────────────────────────┐
//  │ GroupChatBloc (LIST)   → used in GroupChatsListScreen  │
//  │   handles: LoadGroupChatsEvent, CreateGroupChatEvent   │
//  │   stream: groups list                                  │
//  ├────────────────────────────────────────────────────────┤
//  │ GroupChatBloc (MESSAGES) → created INSIDE GroupChatScreen│
//  │   handles: LoadGroupMessagesEvent, SendGroupTextMessageEvent│
//  │   stream: messages list                                │
//  └────────────────────────────────────────────────────────┘
//
//  GroupChatScreen creates its OWN BlocProvider so it gets a
//  FRESH bloc instance. When user pops back, the screen's bloc
//  is disposed — the LIST bloc in HomeScreen is untouched.
// ═══════════════════════════════════════════════════════════════

class GroupChatBloc extends Bloc<GroupChatEvent, GroupChatState> {
  final GroupChatRepository _repo;

  GroupChatBloc({required GroupChatRepository groupChatRepository})
      : _repo = groupChatRepository,
        super(GroupChatInitial()) {
    // ── List screen events ──────────────────────────────────
    on<LoadGroupChatsEvent>(_onLoadGroups);
    on<CreateGroupChatEvent>(_onCreate);

    // ── Chat screen events (run concurrently with stream) ───
    on<LoadGroupMessagesEvent>(_onLoadMessages);
    on<SendGroupTextMessageEvent>(
      _onSendText,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<SendGroupImageMessageEvent>(
      _onSendImage,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<AddMembersToGroupEvent>(_onAddMembers);
  }

  // ── FIX: async + await emit.forEach ────────────────────────
  Future<void> _onLoadGroups(
      LoadGroupChatsEvent event, Emitter<GroupChatState> emit) async {
    await emit.forEach<List<GroupChatEntity>>(
      _repo.getUserGroupChats(event.userId),
      onData: GroupChatsLoaded.new,
      onError: (_, __) => GroupChatError('Failed to load groups'),
    );
  }

  Future<void> _onCreate(
      CreateGroupChatEvent event, Emitter<GroupChatState> emit) async {
    emit(GroupChatLoading());
    final result = await _repo.createGroupChat(
      name: event.name,
      createdBy: event.createdBy,
      members: event.members,
      groupImage: event.groupImage,
    );
    result.fold(
      (failure) => emit(GroupChatError(failure.message)),
      (group) => emit(GroupCreated(group)),
    );
  }

  // ── FIX: async + await emit.forEach ────────────────────────
  Future<void> _onLoadMessages(
      LoadGroupMessagesEvent event, Emitter<GroupChatState> emit) async {
    await emit.forEach<List<MessageEntity>>(
      _repo.getGroupMessages(event.groupId),
      onData: (messages) => GroupMessagesLoaded(
        groupId: event.groupId,
        currentUserId: event.currentUserId,
        messages: messages,
      ),
      onError: (_, __) => GroupChatError('Failed to load messages'),
    );
  }

  // ── Runs concurrently — does NOT cancel the message stream ─
  Future<void> _onSendText(
      SendGroupTextMessageEvent event, Emitter<GroupChatState> emit) async {
    await _repo.sendGroupMessage(
      groupId: event.groupId,
      senderId: event.senderId,
      senderName: event.senderName,
      content: event.content,
      type: 'text',
    );
    // No emit needed — Firestore stream auto-pushes new message
  }

  Future<void> _onSendImage(
      SendGroupImageMessageEvent event, Emitter<GroupChatState> emit) async {
    final current = state;
    if (current is GroupMessagesLoaded) {
      emit(current.copyWith(isUploadingImage: true));
    }
    final result = await _repo.uploadGroupImage(
      image: event.image,
      groupId: event.groupId,
    );
    await result.fold(
      (failure) async {
        if (current is GroupMessagesLoaded) {
          emit(current.copyWith(isUploadingImage: false));
        }
      },
      (imageUrl) async {
        await _repo.sendGroupMessage(
          groupId: event.groupId,
          senderId: event.senderId,
          senderName: event.senderName,
          content: '📷 Photo',
          type: 'image',
          imageUrl: imageUrl,
        );
        if (current is GroupMessagesLoaded) {
          emit(current.copyWith(isUploadingImage: false));
        }
      },
    );
  }

  Future<void> _onAddMembers(
      AddMembersToGroupEvent event, Emitter<GroupChatState> emit) async {
    final result = await _repo.addMembersToGroup(
      groupId: event.groupId,
      newMembers: event.newMembers,
    );
    result.fold(
      (failure) => emit(GroupChatError(failure.message)),
      (_) {},
    );
  }
}
