class AppConstants {
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String groupChatsCollection = 'group_chats';
  static const String groupMessagesCollection = 'group_messages';

  // Storage Paths
  static const String profileImagesPath = 'profile_images';
  static const String chatImagesPath = 'chat_images';
  static const String groupImagesPath = 'group_images';

  // Chat Types
  static const String individualChat = 'individual';
  static const String groupChat = 'group';

  // Message Types
  static const String textMessage = 'text';
  static const String imageMessage = 'image';

  // App Info
  static const String appName = 'ChatFlow';
  static const int maxGroupMembers = 50;
  static const int messagePageSize = 30;
}
