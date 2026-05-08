import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../../blocs/group_chat/group_chat_bloc.dart';

// ═══════════════════════════════════════════════════════════════
//  WHY WRAP IN BlocProvider?
//
//  Problem:
//  HomeScreen provides ONE GroupChatBloc.
//  GroupChatsListScreen uses it for: LoadGroupChatsEvent  → stream A
//  GroupChatScreen     uses it for: LoadGroupMessagesEvent → stream B
//
//  When GroupChatScreen starts stream B, stream A is CANCELLED.
//  Pop back → list screen's stream is dead → empty list.
//
//  Fix:
//  GroupChatScreen wraps itself in a NEW BlocProvider.create()
//  This gives it a FRESH GroupChatBloc instance just for messages.
//  The HomeScreen's GroupChatBloc (list stream) is completely
//  separate and keeps running untouched.
// ═══════════════════════════════════════════════════════════════

class GroupChatScreen extends StatelessWidget {
  final UserEntity currentUser;
  final GroupChatEntity group;
  final GroupChatRepository repo; // injected so we can create new bloc

  const GroupChatScreen({
    super.key,
    required this.currentUser,
    required this.group,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    // Create a FRESH bloc just for this screen's message stream
    return BlocProvider(
      create: (_) => GroupChatBloc(groupChatRepository: repo)
        ..add(LoadGroupMessagesEvent(
          groupId: group.id,
          currentUserId: currentUser.id,
        )),
      child: _GroupChatBody(currentUser: currentUser, group: group),
    );
  }
}

// ─── Actual screen body (reads from its OWN bloc) ─────────────

class _GroupChatBody extends StatefulWidget {
  final UserEntity currentUser;
  final GroupChatEntity group;

  const _GroupChatBody({
    required this.currentUser,
    required this.group,
  });

  @override
  State<_GroupChatBody> createState() => _GroupChatBodyState();
}

class _GroupChatBodyState extends State<_GroupChatBody> {
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

  void _sendText() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    context.read<GroupChatBloc>().add(SendGroupTextMessageEvent(
      groupId: widget.group.id,
      senderId: widget.currentUser.id,
      senderName: widget.currentUser.name,
      content: text,
    ));
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null && mounted) {
      context.read<GroupChatBloc>().add(SendGroupImageMessageEvent(
        groupId: widget.group.id,
        senderId: widget.currentUser.id,
        senderName: widget.currentUser.name,
        image: File(picked.path),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GroupChatBloc, GroupChatState>(
      listener: (_, state) {
        if (state is GroupMessagesLoaded) _scrollToBottom();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: _buildAppBar(),
        body: BlocBuilder<GroupChatBloc, GroupChatState>(
          builder: (context, state) => Column(
            children: [
              Expanded(child: _buildBody(state)),
              _buildInputBar(state),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bgCard,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary, size: 20),
      ),
      title: GestureDetector(
        onTap: _showGroupInfo,
        child: Row(
          children: [
            _groupAvatar(widget.group.name, size: 36),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.group.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                Text('${widget.group.members.length} members',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
      // actions: [
      //   IconButton(
      //     onPressed: _showGroupInfo,
      //     icon: const Icon(Icons.info_outline_rounded,
      //         color: AppColors.textSecondary),
      //   ),
      //   const SizedBox(width: 4),
      // ],
    );
  }

  Widget _buildBody(GroupChatState state) {
    if (state is GroupChatLoading || state is GroupChatInitial) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    // ── KEY FIX: check GroupMessagesLoaded, NOT GroupChatsLoaded ──
    if (state is GroupMessagesLoaded) {
      if (state.messages.isEmpty) return _emptyState();
      return ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        itemCount: state.messages.length,
        itemBuilder: (_, i) {
          final msg = state.messages[i];
          // isMine uses state.currentUserId — passed from LoadGroupMessagesEvent
          final isMine = msg.senderId == state.currentUserId;
          final showDate = i == 0 ||
              !_sameDay(state.messages[i - 1].timestamp, msg.timestamp);
          final showSenderName =
              i == 0 || state.messages[i - 1].senderId != msg.senderId;

          return Column(
            children: [
              if (showDate) _dateDivider(msg.timestamp),
              _bubble(msg, isMine, showSenderName && !isMine),
            ],
          );
        },
      );
    }

    if (state is GroupChatError) {
      return Center(
          child: Text(state.message,
              style: const TextStyle(color: AppColors.error)));
    }

    return _emptyState();
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.group_outlined,
                  color: AppColors.accent, size: 48),
            ),
            const SizedBox(height: 16),
            Text('${widget.group.name} is ready!',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Send the first message',
                style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      );

  Widget _bubble(MessageEntity msg, bool isMine, bool showSenderName) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: showSenderName ? 8 : 2,
          bottom: 2,
          left: isMine ? 50 : 0,
          right: isMine ? 0 : 50,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showSenderName)
              Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 4),
                child: Text(
                  msg.senderName,
                  style: TextStyle(
                    color: _senderColor(msg.senderName),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: isMine
                    ? AppColors.sentBubble
                    : AppColors.receivedBubble,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            msg.content,
                            style: TextStyle(
                              color: isMine
                                  ? AppColors.sentText
                                  : AppColors.receivedText,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('h:mm a').format(msg.timestamp),
                            style: TextStyle(
                              color: isMine
                                  ? Colors.white.withOpacity(0.6)
                                  : AppColors.textHint,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
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
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipRRect(
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                DateFormat('h:mm a').format(msg.timestamp),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
          ],
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

  Widget _buildInputBar(GroupChatState state) {
    final uploading =
        state is GroupMessagesLoaded && state.isUploadingImage;

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
          GestureDetector(
            onTap: uploading ? null : _pickImage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: uploading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    )
                  : const Icon(Icons.image_rounded,
                      color: AppColors.textSecondary, size: 22),
            ),
          ),
          const SizedBox(width: 10),
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
                  hintText: 'Message...',
                  hintStyle:
                      TextStyle(color: AppColors.textHint, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              key: ValueKey(_showSend),
              onTap: _showSend ? _sendText : null,
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
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _showSend ? Colors.white : AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
              child: Text(_fmtDate(date),
                  style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ),
            const Expanded(child: Divider(color: AppColors.divider)),
          ],
        ),
      );

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  _groupAvatar(widget.group.name, size: 72),
                  const SizedBox(height: 12),
                  Text(widget.group.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 20)),
                  Text('${widget.group.members.length} members',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
            const Divider(color: AppColors.divider),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: widget.group.members.length,
                itemBuilder: (_, i) {
                  final memberId = widget.group.members[i];
                  final isMe = memberId == widget.currentUser.id;
                  final isAdmin = memberId == widget.group.createdBy;
                  return ListTile(
                    leading: _groupAvatar(
                        isMe ? widget.currentUser.name : 'U',
                        size: 40),
                    title: Text(
                      isMe
                          ? '${widget.currentUser.name} (You)'
                          : memberId,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                    trailing: isAdmin
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Admin',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupAvatar(String name, {double size = 44}) {
    const colors = [
      Color(0xFF00D4AA), Color(0xFF6C63FF),
      Color(0xFFFF6B6B), Color(0xFFFFB347), Color(0xFF48CAE4),
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
        child: Text(name[0].toUpperCase(),
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.4)),
      ),
    );
  }

  Color _senderColor(String name) {
    const colors = [
      Color(0xFF00D4AA), Color(0xFFFFB347),
      Color(0xFFFF6B6B), Color(0xFF48CAE4), Color(0xFFE76F51),
    ];
    return colors[name.codeUnits.first % colors.length];
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return 'Today';
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(d);
  }
}
