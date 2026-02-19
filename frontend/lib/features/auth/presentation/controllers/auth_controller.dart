import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/session_storage.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/auth_session.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthState {
  const AuthState({
    this.session,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
  });

  final AuthSession? session;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    AuthSession? session,
    bool clearSession = false,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;
  late final SessionStorage _storage;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    _storage = ref.watch(sessionStorageProvider);
    Future<void>.microtask(restoreSession);
    return const AuthState();
  }

  Future<void> restoreSession() async {
    final stored = await _storage.read();
    state = state.copyWith(
      session: stored,
      isInitialized: true,
      clearError: true,
    );
  }

  Future<bool> loginPatient({
    required String phone,
    required String birthdate,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _repository.loginPatient(
        phone: phone,
        birthdate: birthdate,
      );
      await _storage.save(session);
      state = state.copyWith(
        session: session,
        isLoading: false,
        isInitialized: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _repository.resolveErrorMessage(error),
        isInitialized: true,
      );
      return false;
    }
  }

  Future<bool> loginDoctor({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _repository.loginDoctor(
        phone: phone,
        password: password,
      );
      await _storage.save(session);
      state = state.copyWith(
        session: session,
        isLoading: false,
        isInitialized: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _repository.resolveErrorMessage(error),
        isInitialized: true,
      );
      return false;
    }
  }

  Future<bool> registerPatient({
    required String phone,
    required String name,
    required String birthdate,
    String? titularPatientId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.registerPatient(
        phone: phone,
        name: name,
        birthdate: birthdate,
        titularPatientId: titularPatientId,
      );
      state = state.copyWith(
        isLoading: false,
        clearError: true,
        isInitialized: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _repository.resolveErrorMessage(error),
        isInitialized: true,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    state = state.copyWith(
      clearSession: true,
      clearError: true,
      isInitialized: true,
      isLoading: false,
    );
  }
}
