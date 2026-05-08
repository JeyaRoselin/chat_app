import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../blocs/group_chat/group_chat_bloc.dart';

class CreateGroupScreen extends StatefulWidget {
  final UserEntity currentUser;
  final List<UserEntity> availableUsers;

  const CreateGroupScreen({
    super.key,
    required this.currentUser,
    required this.availableUsers,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  int _step = 0; // 0 = select members, 1 = group name

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createGroup() {
    if (_nameController.text.trim().isEmpty) return;
    if (_selectedUserIds.isEmpty) return;

    context.read<GroupChatBloc>().add(CreateGroupChatEvent(
      name: _nameController.text.trim(),
      createdBy: widget.currentUser.id,
      members: _selectedUserIds.toList(),
    ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        leading: IconButton(
          onPressed: _step == 0 ? () => Navigator.pop(context) : () => setState(() => _step = 0),
          icon: Icon(
            _step == 0 ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Group',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              _step == 0
                  ? '${_selectedUserIds.length} selected'
                  : 'Set group name',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (_step == 0 && _selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Next', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          if (_step == 1)
            TextButton(
              onPressed: _createGroup,
              child: const Text('Create', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _step == 0 ? _buildSelectMembers() : _buildSetGroupName(),
      ),
    );
  }

  Widget _buildSelectMembers() {
    return Column(
      key: const ValueKey(0),
      children: [
        // Selected members chips
        if (_selectedUserIds.isNotEmpty)
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _selectedUserIds.map((id) {
                final user = widget.availableUsers.firstWhere((u) => u.id == id);
                return Padding(
                  padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryLight],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -2,
                            right: -2,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedUserIds.remove(id)),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        // User list
        Expanded(
          child: ListView.builder(
            itemCount: widget.availableUsers.length,
            itemBuilder: (context, index) {
              final user = widget.availableUsers[index];
              final isSelected = _selectedUserIds.contains(user.id);

              return ListTile(
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_avatarColor(user.name), _avatarColor(user.name).withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  user.phoneNumber,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedUserIds.remove(user.id);
                    } else {
                      _selectedUserIds.add(user.id);
                    }
                  });
                },
              )
                  .animate()
                  .fadeIn(delay: (index * 30).ms, duration: 300.ms);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSetGroupName() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Group icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.group_rounded, color: Colors.white, size: 40),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.7, 0.7)),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText: 'Group Name',
              prefixIcon: Icon(Icons.group_rounded, color: AppColors.textHint),
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 16),
          Text(
            '${_selectedUserIds.length} members selected',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _createGroup,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_add_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text('Create Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 400.ms)
              .slideY(begin: 0.3, end: 0),
        ],
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
    ];
    final index = name.codeUnits.first % colors.length;
    return colors[index];
  }
}
