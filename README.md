# 📱 Flutter Chat App (Individual + Group Chat)

A real-time chat application built with **Flutter**, using **Bloc architecture** and **Firebase Firestore** as the backend.

---

## 🚀 Features

### 🔐 Authentication
- User registration using mobile number
- First screen is Register screen

---

### 💬 Chat Options

After successful registration, user will see two options:

#### 👤 Individual Chat
- One-to-one messaging
- Real-time chat using Firestore
- Messages stored per conversation
- Instant updates using streams

#### 👥 Group Chat
- Create new group
- Add members to group
- Send messages to group members
- Real-time updates for all users


---

## 🏗️ Architecture

This project follows **Clean Architecture + Bloc Pattern**

lib/

├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── errors/
│   │   └── failures.dart
│   └── theme/
│       └── app_theme.dart
│
├── data/
│   ├── datasources/
│   │   └── firebase_remote_datasource.dart
│   ├── models/
│   │   └── models.dart
│   └── repositories/
│       └── repositories_impl.dart
│
├── domain/
│   ├── entities/
│   │   └── entities.dart
│   └── repositories/
│       └── repositories.dart
│
├── presentation/
│   ├── blocs/
│   │   ├── auth/
│   │   │   └── auth_bloc.dart
│   │   ├── chat/
│   │   │   └── chat_bloc.dart
│   │   └── group_chat/
│   │       ├── group_chat_bloc.dart
│   │       └── has_messages.dart
│   │
│   ├── screens/
│   │   ├── auth/
│   │   ├── chat/
│   │   │   ├── individual_chat_screen.dart
│   │   │   ├── individual_chats_list_screen.dart
│   │   ├── group_chat/
│   │   │   ├── create_group_screen.dart
│   │   │   ├── group_chat_screen.dart
│   │   │   ├── group_chats_list_screen.dart
│   │   └── home/
│   │       └── home_screen.dart
│
├── firebase_options.dart
└── main.dart

---

## ⚙️ Tech Stack

- Flutter
- flutter_bloc (Bloc)

- Cloud Firestore
- Firebase Storage

---

## 🔄 Data Flow

UI → Bloc → Repository → Firebase → Stream → Bloc → UI

- Bloc manages business logic
- Repository handles data operations
- Firestore provides real-time updates
- emit.forEach is used for streaming messages

---

## 📂 Firestore Structure

### Users
users/
  userId/
    name
    phone

### Individual Chats
chats/
  chatId/
    messages/
      messageId/
        senderId
        content
        timestamp

### Group Chats
groups/
  groupId/
    name
    members[]
    createdBy
    messages/
      messageId/
        senderId
        content
        type (text/image)
        imageUrl
        timestamp

---

## 🖼️ Features Included

- Real-time messaging
- Individual chat
- Group chat
- Group creation
- Add members
- Image messaging
- Bloc state management
- Clean architecture structure

---


## ⚠️ Important Notes

- Uses emit.forEach for real-time Firestore updates
- Uses concurrent event transformer for sending messages
- Each chat screen should ideally have separate Bloc
- Avoid multiple stream subscriptions in same Bloc

---


