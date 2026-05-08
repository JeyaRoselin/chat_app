import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_chat_app/data/datasources/remote/firebase_remote_datasource.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';


class AuthRepositoryImpl implements AuthRepository {
  final FirebaseRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, UserEntity>> registerUser({
    required String name,
    required String phoneNumber,
  }) async {
    try {
      final user = await _remoteDataSource.registerUser(
        name: name,
        phoneNumber: phoneNumber,
      );
      return Right(user);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      // In this app, we rely on SharedPreferences for session
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      await _remoteDataSource.updateUserOnlineStatus(userId, isOnline);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<List<UserEntity>> getAllUsers(String currentUserId) {
    return _remoteDataSource.getAllUsers(currentUserId);
  }
}

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseRemoteDataSource _remoteDataSource;

  ChatRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, ChatEntity>> createOrGetChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final chat = await _remoteDataSource.createOrGetChat(
        user1Id: currentUserId,
        user2Id: otherUserId,
      );
      return Right(chat);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<List<ChatEntity>> getUserChats(String userId) {
    return _remoteDataSource.getUserChats(userId);
  }

  @override
  Stream<List<MessageEntity>> getChatMessages(String chatId) {
    return _remoteDataSource.getChatMessages(chatId);
  }

  @override
  Future<Either<Failure, void>> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String content,
    required String type,
    String? imageUrl,
  }) async {
    try {
      await _remoteDataSource.sendMessage(
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        content: content,
        type: type,
        imageUrl: imageUrl,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadChatImage({
    required File image,
    required String chatId,
  }) async {
    try {
      final url = await _remoteDataSource.uploadChatImage(
        image: image,
        chatId: chatId,
      );
      return Right(url);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markMessagesAsRead({
    required String chatId,
    required String userId,
  }) async {
    try {
      await _remoteDataSource.markMessagesAsRead(chatId: chatId, userId: userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

class GroupChatRepositoryImpl implements GroupChatRepository {
  final FirebaseRemoteDataSource _remoteDataSource;

  GroupChatRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, GroupChatEntity>> createGroupChat({
    required String name,
    required String createdBy,
    required List<String> members,
    File? groupImage,
  }) async {
    try {
      final group = await _remoteDataSource.createGroupChat(
        name: name,
        createdBy: createdBy,
        members: members,
        groupImage: groupImage,
      );
      return Right(group);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<List<GroupChatEntity>> getUserGroupChats(String userId) {
    return _remoteDataSource.getUserGroupChats(userId);
  }

  @override
  Stream<List<MessageEntity>> getGroupMessages(String groupId) {
    return _remoteDataSource.getGroupMessages(groupId);
  }

  @override
  Future<Either<Failure, void>> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
    required String type,
    String? imageUrl,
  }) async {
    try {
      await _remoteDataSource.sendGroupMessage(
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        content: content,
        type: type,
        imageUrl: imageUrl,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadGroupImage({
    required File image,
    required String groupId,
  }) async {
    try {
      final url = await _remoteDataSource.uploadGroupImage(
        image: image,
        groupId: groupId,
      );
      return Right(url);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addMembersToGroup({
    required String groupId,
    required List<String> newMembers,
  }) async {
    try {
      await _remoteDataSource.addMembersToGroup(
        groupId: groupId,
        newMembers: newMembers,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
