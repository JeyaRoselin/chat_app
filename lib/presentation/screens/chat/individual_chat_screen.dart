import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../blocs/chat/chat_bloc.dart';

/// Individual 1-to-1 chat screen.
///
/// Two entry paths:
///  1. From chat list  → [existingChatId] is provided, skip OpenChatEvent.
///  2. From contacts   → [existingChatId] is null, dispatch OpenChatEvent first
///                       to create/fetch the chat doc, then load messages.
class IndividualChatScreen extends StatefulWidget {
  final UserEntity currentUser;
  final UserEntity otherUser;
  final String? existingChatId;

  const IndividualChatScreen({
    super.key,
    required this.currentUser,
    required this.otherUser,
    this.existingChatId,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showSend = false;

  @override
  void initState() {
    super.initState();

    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _showSend) setState(() => _showSend = has);
    });

    if (widget.existingChatId != null) {
      // Already have chatId — jump straight to loading messages
      _loadMessages(widget.existingChatId!);
    } else {
      // Need to create/fetch the chat first; listener handles the rest
      context.read<ChatBloc>().add(OpenChatEvent(
        currentUserId: widget.currentUser.id,
        otherUserId: widget.otherUser.id,
      ));
    }
  }

  void _loadMessages(String chatId) {
    context.read<ChatBloc>().add(LoadMessagesEvent(
      chatId: chatId,
      currentUserId: widget.currentUser.id, // ← userId passed here
    ));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText(String chatId) {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    context.read<ChatBloc>().add(SendTextMessageEvent(
      chatId: chatId,
      senderId: widget.currentUser.id,
      senderName: widget.currentUser.name,
      content: text,
    ));
  }

  Future<void> _pickImage(String chatId) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null && mounted) {
      context.read<ChatBloc>().add(SendImageMessageEvent(
        chatId: chatId,
        senderId: widget.currentUser.id,
        senderName: widget.currentUser.name,
        image: File(picked.path),
      ));
    }
  }

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatOpened) {
          // Chat doc created — now load messages using the returned chatId
          _loadMessages(state.chat.id);
        }
        if (state is MessagesLoaded) {
          _scrollToBottom();
        }
      },
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          // Resolve chatId from state or from prop
          final chatId = state is MessagesLoaded
              ? state.chatId
              : state is ChatOpened
                  ? state.chat.id
                  : widget.existingChatId;

          return Scaffold(
            backgroundColor: AppColors.bgDark,
            appBar: _buildAppBar(),
            body: Column(
              children: [
                Expanded(child: _buildBody(state)),
                if (chatId != null) _buildInputBar(state, chatId),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bgCard,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary, size: 20),
      ),
      title: Row(
        children: [
          _avatarWidget(widget.otherUser.name, size: 36),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherUser.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              // Row(
              //   children: [
              //     Container(
              //       width: 7,
              //       height: 7,
              //       decoration: BoxDecoration(
              //         color: widget.otherUser.isOnline
              //             ? AppColors.online
              //             : AppColors.offline,
              //         shape: BoxShape.circle,
              //       ),
              //     ),
              //     const SizedBox(width: 4),
              //     Text(
              //       widget.otherUser.isOnline
              //           ? 'Online'
              //           : widget.otherUser.lastSeen != null
              //               ? 'Last seen ${timeago.format(widget.otherUser.lastSeen!)}'
              //               : 'Offline',
              //       style: TextStyle(
              //         color: widget.otherUser.isOnline
              //             ? AppColors.online
              //             : AppColors.textHint,
              //         fontSize: 11,
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ],
      ),
      // actions: [
      //   IconButton(
      //     onPressed: () {},
      //     icon: const Icon(Icons.video_call_rounded, color: AppColors.textSecondary),
      //   ),
      //   IconButton(
      //     onPressed: () {},
      //     icon: const Icon(Icons.call_rounded, color: AppColors.textSecondary),
      //   ),
      //   const SizedBox(width: 4),
      // ],
    );
  }

  // ─── Message body ────────────────────────────────────────────

  Widget _buildBody(ChatState state) {
    print("Current State: $state");
      print("STATE: ${state.runtimeType}");
    if (state is ChatLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (state is MessagesLoaded ) {
      if (state.messages.isEmpty) return _emptyState();
      return ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        itemCount: state.messages.length,
        itemBuilder: (_, i) {
          final msg = state.messages[i];
          // ← Use state.currentUserId — not widget.currentUser.id
          //   (they're the same, but this proves the userId flows through state)
          final isMine = msg.senderId == state.currentUserId;
          final showDate = i == 0 ||
              !_sameDay(state.messages[i - 1].timestamp, msg.timestamp);
          final showTime = i == state.messages.length - 1 ||
              msg.senderId != state.messages[i + 1].senderId ||
              !_sameMinute(msg.timestamp, state.messages[i + 1].timestamp);

          return Column(
            children: [
              if (showDate) _dateDivider(msg.timestamp),
              _bubble(msg, isMine, showTime),
            ],
          );
        },
      );
    }
    if (state is ChatError) {
      return Center(
        child: Text(state.message, style: const TextStyle(color: AppColors.error)),
      );
    }
     return Container();
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Say hello to ${widget.otherUser.name.split(' ')[0]}!',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );

  // ─── Bubble ──────────────────────────────────────────────────

  Widget _bubble(MessageEntity msg, bool isMine, bool showTime) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 2,
          bottom: showTime ? 8 : 2,
          left: isMine ? 60 : 0,
          right: isMine ? 0 : 60,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color:
                    isMine ? AppColors.sentBubble : AppColors.receivedBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: msg.type == 'image'
                  ? _imgBubble(msg)
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Text(
                        msg.content,
                        style: TextStyle(
                          color: isMine
                              ? AppColors.sentText
                              : AppColors.receivedText,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
            ),
            if (showTime)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(msg.timestamp),
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 10),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg.isRead
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        color: msg.isRead
                            ? AppColors.accent
                            : AppColors.textHint,
                        size: 14,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 250.ms)
          .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _imgBubble(MessageEntity msg) => GestureDetector(
        onTap: () => _previewImage(msg.imageUrl!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: msg.imageUrl!,
            width: 220,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 220,
              height: 200,
              color: AppColors.bgSurface,
              child: const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 220,
              height: 200,
              color: AppColors.bgSurface,
              child: const Icon(Icons.broken_image_rounded,
                  color: AppColors.textHint),
            ),
          ),
        ),
      );

  void _previewImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoView(
            imageProvider: CachedNetworkImageProvider(url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          ),
        ),
      ),
    );
  }

  // ─── Date divider ─────────────────────────────────────────

  Widget _dateDivider(DateTime date) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            const Expanded(child: Divider(color: AppColors.divider)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                _fmtDate(date),
                style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.divider)),
          ],
        ),
      );

  // ─── Input bar ────────────────────────────────────────────

  Widget _buildInputBar(ChatState state, String chatId) {
    final uploading =
        state is MessagesLoaded && state.isUploadingImage;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          // Image attach
          // GestureDetector(
          //   onTap: uploading ? null : () => _pickImage(chatId),
          //   child: Container(
          //     width: 44,
          //     height: 44,
          //     decoration: BoxDecoration(
          //       color: AppColors.bgInput,
          //       borderRadius: BorderRadius.circular(14),
          //       border: Border.all(color: AppColors.divider),
          //     ),
          //     child: uploading
          //         ? const Padding(
          //             padding: EdgeInsets.all(10),
          //             child: CircularProgressIndicator(
          //                 color: AppColors.primary, strokeWidth: 2),
          //           )
          //         : const Icon(Icons.image_rounded,
          //             color: AppColors.textSecondary, size: 22),
          //   ),
          // ),
          const SizedBox(width: 10),
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                controller: _msgCtrl,
                maxLines: null,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                      color: AppColors.textHint, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendText(chatId),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send / mic button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              key: ValueKey(_showSend),
              onTap: _showSend ? () => _sendText(chatId) : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: _showSend
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _showSend ? null : AppColors.bgInput,
                  borderRadius: BorderRadius.circular(14),
                  border: _showSend
                      ? null
                      : Border.all(color: AppColors.divider),
                  boxShadow: _showSend
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.send_rounded ,
                  color:
                      _showSend ? Colors.white : AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────

  Widget _avatarWidget(String name, {double size = 44}) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00D4AA),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFB347),
      const Color(0xFF48CAE4),
    ];
    final color = colors[name.codeUnits.first % colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _sameMinute(DateTime a, DateTime b) =>
      _sameDay(a, b) && a.hour == b.hour && a.minute == b.minute;

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return 'Today';
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(d);
  }
}
