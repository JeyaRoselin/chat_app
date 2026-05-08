import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';

// ─────────────────────────── EVENTS ───────────────────────────

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class RegisterUserEvent extends AuthEvent {
  final String name;
  final String phoneNumber;
  RegisterUserEvent({required this.name, required this.phoneNumber});
  @override
  List<Object?> get props => [name, phoneNumber];
}

class CheckAuthStatusEvent extends AuthEvent {}

class LogoutEvent extends AuthEvent {}

class LoadUsersEvent extends AuthEvent {
  final String currentUserId;
  LoadUsersEvent(this.currentUserId);
  @override
  List<Object?> get props => [currentUserId];
}

// ─────────────────────────── STATES ───────────────────────────

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

class UsersLoaded extends AuthState {
  final UserEntity currentUser;
  final List<UserEntity> users;
  UsersLoaded({required this.currentUser, required this.users});
  @override
  List<Object?> get props => [currentUser, users.length];
}

// ─────────────────────────── BLOC ───────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  static const _kUserId = 'user_id';
  static const _kUserName = 'user_name';
  static const _kUserPhone = 'user_phone';

  UserEntity? _currentUser;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<RegisterUserEvent>(_onRegister);
    on<CheckAuthStatusEvent>(_onCheckAuth);
    on<LogoutEvent>(_onLogout);
    on<LoadUsersEvent>(_onLoadUsers);
  }

  Future<void> _onRegister(RegisterUserEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _authRepository.registerUser(
      name: event.name,
      phoneNumber: event.phoneNumber,
    );
    await result.fold(
      (failure) async => emit(AuthError(failure.message)),
      (user) async {
        await _saveSession(user);
        await _authRepository.updateUserOnlineStatus(user.id, true);
        _currentUser = user;
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onCheckAuth(CheckAuthStatusEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kUserId);
    final userName = prefs.getString(_kUserName);
    final userPhone = prefs.getString(_kUserPhone);

    if (userId != null && userName != null && userPhone != null) {
      final user = UserEntity(
        id: userId,
        name: userName,
        phoneNumber: userPhone,
        isOnline: true,
        createdAt: DateTime.now(),
      );
      await _authRepository.updateUserOnlineStatus(userId, true);
      _currentUser = user;
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kUserId);
    if (userId != null) {
      await _authRepository.updateUserOnlineStatus(userId, false);
    }
    await prefs.clear();
    _currentUser = null;
    emit(AuthUnauthenticated());
  }

  void _onLoadUsers(LoadUsersEvent event, Emitter<AuthState> emit) {
    final user = _currentUser;
    if (user == null) return;
    emit.forEach<List<UserEntity>>(
      _authRepository.getAllUsers(event.currentUserId),
      onData: (users) => UsersLoaded(currentUser: user, users: users),
      onError: (_, __) => AuthError('Failed to load contacts'),
    );
  }

  Future<void> _saveSession(UserEntity user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, user.id);
    await prefs.setString(_kUserName, user.name);
    await prefs.setString(_kUserPhone, user.phoneNumber);
  }
}
