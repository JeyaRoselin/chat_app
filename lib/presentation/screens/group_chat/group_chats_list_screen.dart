import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/group_chat/group_chat_bloc.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

class GroupChatsListScreen extends StatefulWidget {
  final UserEntity currentUser;
  const GroupChatsListScreen({super.key, required this.currentUser});

  @override
  State<GroupChatsListScreen> createState() => _GroupChatsListScreenState();
}

class _GroupChatsListScreenState extends State<GroupChatsListScreen> {
  @override
  void initState() {
    super.initState();
    // This bloc instance is owned by HomeScreen — only streams the list
    context
        .read<GroupChatBloc>()
        .add(LoadGroupChatsEvent(widget.currentUser.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: BlocConsumer<GroupChatBloc, GroupChatState>(
        // Only listen to states relevant to the LIST
        listenWhen: (_, state) =>
            state is GroupCreated || state is GroupChatError,
        listener: (context, state) {
          if (state is GroupCreated) {
            _openGroupChat(state.group);
          }
          if (state is GroupChatError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        // Only rebuild for list states — ignore GroupMessagesLoaded etc.
        buildWhen: (_, state) =>
            state is GroupChatsLoaded ||
            state is GroupChatLoading ||
            state is GroupChatInitial,
        builder: (context, state) {
          final groups = state is GroupChatsLoaded
              ? state.groups
              : <GroupChatEntity>[];
          final isLoading = state is GroupChatLoading;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _buildBanner(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'YOUR GROUPS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              if (isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
                  ),
                )
              else if (groups.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildTile(groups[i], i),
                    childCount: groups.length,
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGroup,
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.group_add_rounded, color: Colors.white),
      ),
    );
  }

  // Navigate to GroupChatScreen which has its OWN bloc
  void _openGroupChat(GroupChatEntity group) {
    final repo = context.read<GroupChatRepository>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(
          currentUser: widget.currentUser,
          group: group,
          repo: repo,
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return GestureDetector(
      onTap: _navigateToCreateGroup,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.15),
              AppColors.accent.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.group_add_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create a Group',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  SizedBox(height: 2),
                  Text('Chat with 2 or more people at once',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildTile(GroupChatEntity group, int index) {
    return GestureDetector(
      onTap: () => _openGroupChat(group),
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
            _groupAvatar(group.name, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(group.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (group.lastMessageTime != null)
                        Text(
                          timeago.format(group.lastMessageTime!,
                              allowFromNow: true),
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.lastMessage != null && group.lastMessage!.isNotEmpty
                        ? '${group.lastSenderName}: ${group.lastMessage}'
                        : '${group.members.length} members',
                    style: TextStyle(
                      color: group.lastMessage != null &&
                              group.lastMessage!.isNotEmpty
                          ? AppColors.textSecondary
                          : AppColors.textHint,
                      fontSize: 13,
                      fontStyle: group.lastMessage == null ||
                              group.lastMessage!.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
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
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child:
                const Icon(Icons.group_outlined, color: AppColors.accent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('No group chats yet',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Create a group and start chatting\nwith multiple people',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  void _navigateToCreateGroup() {
    final authState = context.read<AuthBloc>().state;
    final users =
        authState is UsersLoaded ? authState.users : <UserEntity>[];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(
          currentUser: widget.currentUser,
          availableUsers: users,
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
}
