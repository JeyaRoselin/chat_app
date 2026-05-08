import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/entities.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> registerUser({
    required String name,
    required String phoneNumber,
  });

  Future<Either<Failure, UserEntity?>> getCurrentUser();

  Future<Either<Failure, void>> updateUserOnlineStatus(String userId, bool isOnline);

  Stream<List<UserEntity>> getAllUsers(String currentUserId);
}

abstract class ChatRepository {
  Future<Either<Failure, ChatEntity>> createOrGetChat({
    required String currentUserId,
    required String otherUserId,
  });

  Stream<List<ChatEntity>> getUserChats(String userId);

  Stream<List<MessageEntity>> getChatMessages(String chatId);

  Future<Either<Failure, void>> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String content,
    required String type,
    String? imageUrl,
  });

  Future<Either<Failure, String>> uploadChatImage({
    required File image,
    required String chatId,
  });

  Future<Either<Failure, void>> markMessagesAsRead({
    required String chatId,
    required String userId,
  });
}

abstract class GroupChatRepository {
  Future<Either<Failure, GroupChatEntity>> createGroupChat({
    required String name,
    required String createdBy,
    required List<String> members,
    File? groupImage,
  });

  Stream<List<GroupChatEntity>> getUserGroupChats(String userId);

  Stream<List<MessageEntity>> getGroupMessages(String groupId);

  Future<Either<Failure, void>> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
    required String type,
    String? imageUrl,
  });

  Future<Either<Failure, String>> uploadGroupImage({
    required File image,
    required String groupId,
  });

  Future<Either<Failure, void>> addMembersToGroup({
    required String groupId,
    required List<String> newMembers,
  });
}
