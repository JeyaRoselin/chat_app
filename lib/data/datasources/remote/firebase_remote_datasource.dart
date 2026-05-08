import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../../core/constants/app_constants.dart';

abstract class FirebaseRemoteDataSource {
  Future<UserModel> registerUser({required String name, required String phoneNumber});
  Future<UserModel?> getUserById(String userId);
  Future<void> updateUserOnlineStatus(String userId, bool isOnline);
  Stream<List<UserModel>> getAllUsers(String currentUserId);

  Future<ChatModel> createOrGetChat({required String user1Id, required String user2Id});
  Stream<List<ChatModel>> getUserChats(String userId);
  Stream<List<MessageModel>> getChatMessages(String chatId);
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String content,
    required String type,
    String? imageUrl,
  });
  Future<String> uploadChatImage({required File image, required String chatId});
  Future<void> markMessagesAsRead({required String chatId, required String userId});

  Future<GroupChatModel> createGroupChat({
    required String name,
    required String createdBy,
    required List<String> members,
    File? groupImage,
  });
  Stream<List<GroupChatModel>> getUserGroupChats(String userId);
  Stream<List<MessageModel>> getGroupMessages(String groupId);
  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
    required String type,
    String? imageUrl,
  });
  Future<String> uploadGroupImage({required File image, required String groupId});
  Future<void> addMembersToGroup({required String groupId, required List<String> newMembers});
}

class FirebaseRemoteDataSourceImpl implements FirebaseRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final Uuid _uuid;

  FirebaseRemoteDataSourceImpl({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _firestore = firestore,
        _storage = storage,
        _uuid = const Uuid();

  // ======================== AUTH ========================

  @override
  Future<UserModel> registerUser({required String name, required String phoneNumber}) async {
    // Check if user with this phone number already exists
    final query = await _firestore
        .collection(AppConstants.usersCollection)
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return UserModel.fromFirestore(query.docs.first);
    }

    final userId = _uuid.v4();
    final user = UserModel(
      id: userId,
      name: name,
      phoneNumber: phoneNumber,
      isOnline: true,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .set(user.toFirestore());

    return user;
  }

  @override
  Future<UserModel?> getUserById(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  @override
  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({
      'isOnline': isOnline,
      'lastSeen': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Stream<List<UserModel>> getAllUsers(String currentUserId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => doc.id != currentUserId)
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  // ======================== INDIVIDUAL CHAT ========================

  @override
  Future<ChatModel> createOrGetChat({
    required String user1Id,
    required String user2Id,
  }) async {
    // Generate consistent chat ID
    final ids = [user1Id, user2Id]..sort();
    final chatId = '${ids[0]}_${ids[1]}';

    final doc = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .get();

    if (doc.exists) {
      return ChatModel.fromFirestore(doc);
    }

    final chat = ChatModel(
      id: chatId,
      user1Id: user1Id,
      user2Id: user2Id,
    );

    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .set(chat.toFirestore());

    return chat;
  }

  @override
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .where(Filter.or(
          Filter('user1Id', isEqualTo: userId),
          Filter('user2Id', isEqualTo: userId),
        ))
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatModel.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String content,
    required String type,
    String? imageUrl,
  }) async {
    final messageId = _uuid.v4();
    final message = MessageModel(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: type,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
    );

    final batch = _firestore.batch();

    // Add message
    batch.set(
      _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId),
      message.toFirestore(),
    );

    // Update chat last message
    batch.update(
      _firestore.collection(AppConstants.chatsCollection).doc(chatId),
      {
        'lastMessage': type == 'image' ? '📷 Photo' : content,
        'lastMessageType': type,
        'lastMessageTime': Timestamp.fromDate(DateTime.now()),
        'lastSenderId': senderId,
      },
    );

    await batch.commit();
  }

  @override
  Future<String> uploadChatImage({required File image, required String chatId}) async {
    final fileName = '${_uuid.v4()}.jpg';
    final ref = _storage.ref().child('${AppConstants.chatImagesPath}/$chatId/$fileName');
    final uploadTask = await ref.putFile(image);
    return await uploadTask.ref.getDownloadURL();
  }

  @override
  Future<void> markMessagesAsRead({required String chatId, required String userId}) async {
    final messages = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ======================== GROUP CHAT ========================

  @override
  Future<GroupChatModel> createGroupChat({
    required String name,
    required String createdBy,
    required List<String> members,
    File? groupImage,
  }) async {
    final groupId = _uuid.v4();
    String? imageUrl;

    if (groupImage != null) {
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref().child('${AppConstants.groupImagesPath}/$groupId/$fileName');
      final uploadTask = await ref.putFile(groupImage);
      imageUrl = await uploadTask.ref.getDownloadURL();
    }

    final allMembers = [...members];
    if (!allMembers.contains(createdBy)) {
      allMembers.add(createdBy);
    }

    final group = GroupChatModel(
      id: groupId,
      name: name,
      groupImage: imageUrl,
      createdBy: createdBy,
      members: allMembers,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.groupChatsCollection)
        .doc(groupId)
        .set(group.toFirestore());

    return group;
  }

  @override
  Stream<List<GroupChatModel>> getUserGroupChats(String userId) {
    return _firestore
        .collection(AppConstants.groupChatsCollection)
        .where('members', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => GroupChatModel.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<MessageModel>> getGroupMessages(String groupId) {
    return _firestore
        .collection(AppConstants.groupChatsCollection)
        .doc(groupId)
        .collection(AppConstants.groupMessagesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
    required String type,
    String? imageUrl,
  }) async {
    final messageId = _uuid.v4();
    final message = MessageModel(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: type,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
    );

    final batch = _firestore.batch();

    batch.set(
      _firestore
          .collection(AppConstants.groupChatsCollection)
          .doc(groupId)
          .collection(AppConstants.groupMessagesCollection)
          .doc(messageId),
      message.toFirestore(),
    );

    batch.update(
      _firestore.collection(AppConstants.groupChatsCollection).doc(groupId),
      {
        'lastMessage': type == 'image' ? '📷 Photo' : content,
        'lastMessageType': type,
        'lastMessageTime': Timestamp.fromDate(DateTime.now()),
        'lastSenderId': senderId,
        'lastSenderName': senderName,
      },
    );

    await batch.commit();
  }

  @override
  Future<String> uploadGroupImage({required File image, required String groupId}) async {
    final fileName = '${_uuid.v4()}.jpg';
    final ref = _storage.ref().child('${AppConstants.groupImagesPath}/$groupId/$fileName');
    final uploadTask = await ref.putFile(image);
    return await uploadTask.ref.getDownloadURL();
  }

  @override
  Future<void> addMembersToGroup({
    required String groupId,
    required List<String> newMembers,
  }) async {
    await _firestore
        .collection(AppConstants.groupChatsCollection)
        .doc(groupId)
        .update({
      'members': FieldValue.arrayUnion(newMembers),
    });
  }
}
