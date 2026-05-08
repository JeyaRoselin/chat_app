import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String phoneNumber;
  final String? profileImage;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.profileImage,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, phoneNumber, profileImage, isOnline, lastSeen, createdAt];
}

class MessageEntity extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final String type; // 'text' or 'image'
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;

  const MessageEntity({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [id, senderId, content, type, timestamp, isRead];
}

class ChatEntity extends Equatable {
  final String id;
  final String user1Id;
  final String user2Id;
  final String? lastMessage;
  final String? lastMessageType;
  final DateTime? lastMessageTime;
  final String? lastSenderId;
  final int unreadCount;

  const ChatEntity({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageTime,
    this.lastSenderId,
    this.unreadCount = 0,
  });

  @override
  List<Object?> get props => [id, user1Id, user2Id, lastMessage, lastMessageTime];
}

class GroupChatEntity extends Equatable {
  final String id;
  final String name;
  final String? groupImage;
  final String createdBy;
  final List<String> members;
  final String? lastMessage;
  final String? lastMessageType;
  final String? lastSenderId;
  final String? lastSenderName;
  final DateTime? lastMessageTime;
  final DateTime createdAt;

  const GroupChatEntity({
    required this.id,
    required this.name,
    this.groupImage,
    required this.createdBy,
    required this.members,
    this.lastMessage,
    this.lastMessageType,
    this.lastSenderId,
    this.lastSenderName,
    this.lastMessageTime,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, members, lastMessage, lastMessageTime];
}
