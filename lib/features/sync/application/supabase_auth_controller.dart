import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:evoly/features/sync/application/sync_initial_snapshot_queue.dart';
import 'package:evoly/features/sync/data/sqlite_sync_state_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SupabaseAuthStatus {
  unavailable,
  signedOut,
  signing,
  signedIn,
}

enum SupabaseAuthOperation {
  signIn,
  signUp,
  signOut,
}

class SupabaseAuthController extends ChangeNotifier {
  SupabaseAuthController(
    this._client,
    this._syncStateRepository, {
    required String authCallbackUrl,
    SyncInitialSnapshotQueue? initialSnapshotQueue,
  })  : _authCallbackUrl = authCallbackUrl,
        _initialSnapshotQueue = initialSnapshotQueue;

  final SupabaseClient? _client;
  final SqliteSyncStateRepository _syncStateRepository;
  final String _authCallbackUrl;
  final SyncInitialSnapshotQueue? _initialSnapshotQueue;
  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;
  var _busy = false;
  SupabaseAuthOperation? _operation;
  String? _errorMessage;
  String? _noticeMessage;

  bool get isConfigured => _client != null;
  bool get isBusy => _busy;
  SupabaseAuthOperation? get operation => _operation;
  bool get isSignedIn => _session != null;
  bool get isSyncEnabled => isSignedIn;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  String? get email => _session?.user.email;
  String? get userId => _session?.user.id;

  SupabaseAuthStatus get status {
    if (!isConfigured) {
      return SupabaseAuthStatus.unavailable;
    }
    if (_busy) {
      return SupabaseAuthStatus.signing;
    }
    return isSignedIn
        ? SupabaseAuthStatus.signedIn
        : SupabaseAuthStatus.signedOut;
  }

  Future<void> load() async {
    final client = _client;
    if (client == null) {
      await _persistSessionState(null);
      return;
    }

    _session = client.auth.currentSession;
    await _persistSessionState(_session);
    _authSubscription ??= client.auth.onAuthStateChange.listen((authState) {
      _session = authState.session;
      _errorMessage = null;
      unawaited(_persistSessionState(_session));
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (!_validateCredentials(email, password)) {
      return;
    }

    await _runAuthAction(SupabaseAuthOperation.signIn, (client) async {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _session = response.session ?? client.auth.currentSession;
      await _persistSessionState(_session);
      _noticeMessage = '已登录，同步已开启';
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    if (!_validateCredentials(email, password)) {
      return;
    }

    await _runAuthAction(SupabaseAuthOperation.signUp, (client) async {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: _authCallbackUrl,
      );
      _session = response.session ?? client.auth.currentSession;
      await _persistSessionState(_session);
      _noticeMessage = _session == null ? '账号已创建，请完成邮箱确认后再登录' : '账号已创建并登录';
    });
  }

  Future<void> signOut() async {
    await _runAuthAction(SupabaseAuthOperation.signOut, (client) async {
      await client.auth.signOut();
      _session = null;
      await _persistSessionState(null);
      _noticeMessage = '已退出登录，同步已关闭';
    });
  }

  bool _validateCredentials(String email, String password) {
    if (email.trim().isEmpty || password.isEmpty) {
      _errorMessage = '请输入邮箱和密码';
      _noticeMessage = null;
      notifyListeners();
      return false;
    }

    if (password.length < 6) {
      _errorMessage = '密码至少需要 6 位';
      _noticeMessage = null;
      notifyListeners();
      return false;
    }

    return true;
  }

  Future<void> _persistSessionState(Session? session) async {
    if (session == null) {
      await _syncStateRepository.setSyncEnabled(false);
      await _syncStateRepository.write(SyncStateKey.accountId, '');
      await _syncStateRepository.write(SyncStateKey.lastPulledRevision, '0');
      await _syncStateRepository.write(SyncStateKey.lastSuccessAt, '');
      await _syncStateRepository.write(SyncStateKey.lastError, '');
      return;
    }

    final previousAccountId = await _syncStateRepository.read(
      SyncStateKey.accountId,
    );
    if (previousAccountId != null &&
        previousAccountId.isNotEmpty &&
        previousAccountId != session.user.id) {
      await _syncStateRepository.write(SyncStateKey.lastPulledRevision, '0');
      await _syncStateRepository.write(SyncStateKey.lastSuccessAt, '');
      await _syncStateRepository.write(SyncStateKey.lastError, '');
    }

    await _syncStateRepository.write(SyncStateKey.accountId, session.user.id);
    await _syncStateRepository.setSyncEnabled(true);
    await _initialSnapshotQueue?.queueForAccount(session.user.id);
  }

  Future<void> _runAuthAction(
    SupabaseAuthOperation operation,
    Future<void> Function(SupabaseClient client) action,
  ) async {
    final client = _client;
    if (client == null) {
      _errorMessage = 'Supabase 未配置';
      notifyListeners();
      return;
    }

    _busy = true;
    _operation = operation;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      await action(client).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      _errorMessage = '连接 Supabase 超时，请检查网络或项目配置';
    } on AuthException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = '认证失败：$error';
    } finally {
      _busy = false;
      _operation = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
