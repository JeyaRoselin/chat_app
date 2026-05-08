import 'package:flutter_chat_app/domain/entities/entities.dart';

abstract class HasMessages {
  List<MessageEntity> get messages;
  String get currentUserId;
}