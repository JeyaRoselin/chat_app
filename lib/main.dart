import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'core/theme/app_theme.dart';
import 'data/datasources/remote/firebase_remote_datasource.dart';
import 'data/repositories/repositories_impl.dart';
import 'domain/entities/entities.dart';
import 'domain/repositories/repositories.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/chat/chat_bloc.dart';
import 'presentation/blocs/group_chat/group_chat_bloc.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final remoteDataSource = FirebaseRemoteDataSourceImpl(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    );

    final authRepo = AuthRepositoryImpl(remoteDataSource);
    final chatRepo = ChatRepositoryImpl(remoteDataSource);
    final groupChatRepo = GroupChatRepositoryImpl(remoteDataSource);

    return MultiRepositoryProvider(
      // RepositoryProvider makes repos available via context.read<T>()
      // GroupChatsListScreen reads GroupChatRepository to pass into
      // GroupChatScreen so it can create its own fresh BlocProvider
      providers: [
        RepositoryProvider<GroupChatRepository>.value(value: groupChatRepo),
        RepositoryProvider<ChatRepository>.value(value: chatRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(authRepository: authRepo)
              ..add(CheckAuthStatusEvent()),
          ),
          BlocProvider(
            create: (_) => ChatBloc(chatRepository: chatRepo),
          ),
          BlocProvider(
            create: (_) => GroupChatBloc(groupChatRepository: groupChatRepo),
          ),
        ],
        child: MaterialApp(
          title: 'ChatFlow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const AppNavigator(),
        ),
      ),
    );
  }
}

class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial || state is AuthLoading) {
          return const _SplashScreen();
        }
        if (state is AuthAuthenticated) {
          return HomeScreen(currentUser: state.user);
        }
        if (state is UsersLoaded) {
          return HomeScreen(currentUser: state.currentUser);
        }
        // AuthUnauthenticated or AuthError → Register
        return const RegisterScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.chat_bubble_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            const Text('ChatFlow',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}
