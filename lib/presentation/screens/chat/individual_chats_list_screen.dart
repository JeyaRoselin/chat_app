import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/chat/chat_bloc.dart';
import 'individual_chat_screen.dart';

class IndividualChatsListScreen extends StatefulWidget {
  final UserEntity currentUser;
  const IndividualChatsListScreen({super.key, required this.currentUser});

  @override
  State<IndividualChatsListScreen> createState() => _IndividualChatsListScreenState();
}

class _IndividualChatsListScreenState extends State<IndividualChatsListScreen> {
  @override
  void initState() {
    super.initState();
 //   context.read<ChatBloc>().add(LoadChatsEvent(widget.currentUser.id));
    context.read<AuthBloc>().add(LoadUsersEvent(widget.currentUser.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, chatState) {
          return BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              final users = authState is UsersLoaded ? authState.users : <UserEntity>[];
              final chats = chatState is ChatsLoaded ? chatState.chats : <ChatEntity>[];

              return CustomScrollView(
                slivers: [
                  // Search bar
                  // SliverToBoxAdapter(
                  //   child: Padding(
                  //     padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  //     child: _buildSearchBar(),
                  //   ),
                  // ),

                  // Contacts strip
                  if (users.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'CONTACTS',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 96,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            return _buildContactChip(users[index], index);
                          },
                        ),
                      ),
                    ),
                  ],

                  // Chats header
                  // SliverToBoxAdapter(
                  //   child: Padding(
                  //     padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  //     child: Text(
                  //       'MESSAGES',
                  //       style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  //         letterSpacing: 1.2,
                  //         color: AppColors.textHint,
                  //         fontWeight: FontWeight.w700,
                  //       ),
                  //     ),
                  //   ),
                  // ),

                  // Chat list
                  if (chatState is ChatLoading)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ),
                    )
                  // else if (chats.isEmpty)
                  //   SliverToBoxAdapter(child: _buildEmptyState())
                  // else
                  //   SliverList(
                  //     delegate: SliverChildBuilderDelegate(
                  //       (context, index) {
                  //         final chat = chats[index];
                  //         final otherUserId = chat.user1Id == widget.currentUser.id
                  //             ? chat.user2Id
                  //             : chat.user1Id;
                  //         final otherUser = users.firstWhere(
                  //           (u) => u.id == otherUserId,
                  //           orElse: () => UserEntity(
                  //             id: otherUserId,
                  //             name: 'Unknown User',
                  //             phoneNumber: '',
                  //             createdAt: DateTime.now(),
                  //           ),
                  //         );
                  //         return _buildChatTile(chat, otherUser, index);
                  //       },
                  //       childCount: chats.length,
                  //     ),
                  //   ),
                ],
              );
            },
          );
        },
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () => _showNewChatDialog(context),
      //   backgroundColor: AppColors.primary,
      //   elevation: 4,
      //   child: const Icon(Icons.chat_rounded, color: Colors.white),
      // ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Row(
        children: [
          SizedBox(width: 14),
          Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
          SizedBox(width: 10),
          Text('Search conversations...', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildContactChip(UserEntity user, int index) {
    return GestureDetector(
      onTap: () => _openChat(user),
      child: Container(
        margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _avatarColor(user.name),
                        _avatarColor(user.name).withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                // if (user.isOnline)
                //   Positioned(
                //     bottom: 0,
                //     right: 0,
                //     child: Container(
                //       width: 14,
                //       height: 14,
                //       decoration: BoxDecoration(
                //         color: AppColors.online,
                //         shape: BoxShape.circle,
                //         border: Border.all(color: AppColors.bgDark, width: 2),
                //       ),
                //     ),
                //   ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              user.name.split(' ')[0],
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: (index * 50).ms, duration: 400.ms)
          .slideX(begin: 0.3, end: 0),
    );
  }

  Widget _buildChatTile(ChatEntity chat, UserEntity otherUser, int index) {
    final isLastMine = chat.lastSenderId == widget.currentUser.id;

    return GestureDetector(
      onTap: () => _navigateToChat(chat, otherUser),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _avatarColor(otherUser.name),
                        _avatarColor(otherUser.name).withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      otherUser.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                if (otherUser.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bgDark, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        otherUser.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (chat.lastMessageTime != null)
                        Text(
                          timeago.format(chat.lastMessageTime!, allowFromNow: true),
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isLastMine)
                        const Icon(Icons.done_all_rounded, color: AppColors.accent, size: 14),
                      if (isLastMine) const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          chat.lastMessage ?? 'Start a conversation',
                          style: TextStyle(
                            color: chat.lastMessage != null
                                ? AppColors.textSecondary
                                : AppColors.textHint,
                            fontSize: 13,
                            fontStyle: chat.lastMessage == null ? FontStyle.italic : FontStyle.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: (index * 60).ms, duration: 400.ms)
          .slideX(begin: 0.1, end: 0),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'No conversations yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start chatting with your contacts\nby tapping the chat button',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _openChat(UserEntity otherUser) {
    context.read<ChatBloc>().add(OpenChatEvent(
      currentUserId: widget.currentUser.id,
      otherUserId: otherUser.id,
    ));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IndividualChatScreen(
          currentUser: widget.currentUser,
          otherUser: otherUser,
        ),
      ),
    );
  }

  void _navigateToChat(ChatEntity chat, UserEntity otherUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IndividualChatScreen(
          currentUser: widget.currentUser,
          otherUser: otherUser,
          existingChatId: chat.id,
        ),
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! UsersLoaded) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'New Message',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: authState.users.length,
                itemBuilder: (_, index) {
                  final user = authState.users[index];
                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_avatarColor(user.name), _avatarColor(user.name).withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          user.name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    title: Text(user.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(user.phoneNumber, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: user.isOnline
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppColors.online, shape: BoxShape.circle),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openChat(user);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00D4AA),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFB347),
      const Color(0xFF48CAE4),
      const Color(0xFFE76F51),
      const Color(0xFF2A9D8F),
      const Color(0xFFE9C46A),
    ];
    final index = name.codeUnits.first % colors.length;
    return colors[index];
  }
}
