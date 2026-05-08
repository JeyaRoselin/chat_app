import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/entities.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.phoneNumber,
    super.profileImage,
    super.isOnline,
    super.lastSeen,
    required super.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      profileImage: data['profileImage'],
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'profileImage': profileImage,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      phoneNumber: entity.phoneNumber,
      profileImage: entity.profileImage,
      isOnline: entity.isOnline,
      lastSeen: entity.lastSeen,
      createdAt: entity.createdAt,
    );
  }
}

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.senderId,
    required super.senderName,
    required super.content,
    required super.type,
    required super.timestamp,
    super.isRead,
    super.imageUrl,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      type: data['type'] ?? 'text',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'imageUrl': imageUrl,
    };
  }
}

class ChatModel extends ChatEntity {
  const ChatModel({
    required super.id,
    required super.user1Id,
    required super.user2Id,
    super.lastMessage,
    super.lastMessageType,
    super.lastMessageTime,
    super.lastSenderId,
    super.unreadCount,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      user1Id: data['user1Id'] ?? '',
      user2Id: data['user2Id'] ?? '',
      lastMessage: data['lastMessage'],
      lastMessageType: data['lastMessageType'],
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastSenderId: data['lastSenderId'],
      unreadCount: data['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user1Id': user1Id,
      'user2Id': user2Id,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
    };
  }
}

class GroupChatModel extends GroupChatEntity {
  const GroupChatModel({
    required super.id,
    required super.name,
    super.groupImage,
    required super.createdBy,
    required super.members,
    super.lastMessage,
    super.lastMessageType,
    super.lastSenderId,
    super.lastSenderName,
    super.lastMessageTime,
    required super.createdAt,
  });

  factory GroupChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupChatModel(
      id: doc.id,
      name: data['name'] ?? '',
      groupImage: data['groupImage'],
      createdBy: data['createdBy'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageType: data['lastMessageType'],
      lastSenderId: data['lastSenderId'],
      lastSenderName: data['lastSenderName'],
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'groupImage': groupImage,
      'createdBy': createdBy,
      'members': members,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastSenderId': lastSenderId,
      'lastSenderName': lastSenderName,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
