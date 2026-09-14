import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';

enum GameSocketStatus { connecting, connected, reconnecting, disconnected }

class GameSocket {
  GameSocket(this.store);
  final TokenStore store;

  io.Socket? _socket;
  Timer? _retryTimer;
  String? _matchId;
  void Function(Map<String, dynamic>)? _onUpdate;
  void Function(String)? _onError;
  void Function(GameSocketStatus)? _onStatus;
  void Function(int attempt, Duration nextDelay)? _onRetryAttempt;
  bool _disposed = false;
  bool _connecting = false;
  int _retryAttempt = 0;
  int _connectionGeneration = 0;

  static const int _slowModeAfterAttempts = 8;
  static const Duration _slowModeDelay = Duration(seconds: 30);

  int get retryAttempt => _retryAttempt;
  bool get slowMode => _retryAttempt > _slowModeAfterAttempts;

  Future<void> connect({
    required String matchId,
    required void Function(Map<String, dynamic>) onUpdate,
    required void Function(String) onError,
    required void Function(GameSocketStatus) onStatus,
    void Function(int attempt, Duration nextDelay)? onRetryAttempt,
  }) async {
    _disposed = false;
    final generation = ++_connectionGeneration;
    _retryTimer?.cancel();
    _retryTimer = null;
    final previous = _socket;
    _socket = null;
    previous?.dispose();
    _matchId = matchId;
    _onUpdate = onUpdate;
    _onError = onError;
    _onStatus = onStatus;
    _onRetryAttempt = onRetryAttempt;
    _retryAttempt = 0;
    _setStatus(GameSocketStatus.connecting);

    final token = await store.accessToken();
    if (_disposed || generation != _connectionGeneration) return;
    if (token == null || token.isEmpty) {
      _setStatus(GameSocketStatus.disconnected);
      _onError?.call('Your session has expired. Please sign in again.');
      return;
    }

    final base = apiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    final socket = io.io(
      '$base/games',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .disableReconnection()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      if (!_isCurrent(socket)) return;
      _connecting = false;
      _retryAttempt = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      _setStatus(GameSocketStatus.connected);
      _joinMatch(socket);
    });
    socket.on('connect_error', (data) {
      if (!_isCurrent(socket)) return;
      _connecting = false;
      _onError?.call(_socketMessage(data, fallback: 'Live updates could not connect.'));
      _markDisconnected(schedule: true);
    });
    socket.on('connect_timeout', (_) {
      if (!_isCurrent(socket)) return;
      _connecting = false;
      _markDisconnected(schedule: true);
    });
    socket.on('error', (data) {
      if (_isCurrent(socket)) _onError?.call(_socketMessage(data, fallback: 'The live connection returned an error.'));
    });
    socket.on('disconnect', (reason) {
      if (!_isCurrent(socket)) return;
      _connecting = false;
      if (reason?.toString() == 'io client disconnect') {
        _setStatus(GameSocketStatus.disconnected);
      } else {
        _markDisconnected(schedule: true);
      }
    });
    socket.on('match:update', (data) {
      if (_isCurrent(socket) && data is Map) _onUpdate?.call(Map<String, dynamic>.from(data));
    });
    socket.on('match:error', (data) {
      if (_isCurrent(socket)) _onError?.call(data is Map ? data['message']?.toString() ?? 'The match connection returned an error.' : 'The match connection returned an error.');
    });
    _connecting = true;
    socket.connect();
  }

  void retry() {
    if (_disposed || _connecting) return;
    final socket = _socket;
    if (socket?.connected == true) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _reconnectWithLatestToken();
  }

  void _reconnectWithLatestToken() {
    final matchId = _matchId;
    final onUpdate = _onUpdate;
    final onError = _onError;
    final onStatus = _onStatus;
    if (matchId == null || onUpdate == null || onError == null || onStatus == null) return;
    unawaited(connect(matchId: matchId, onUpdate: onUpdate, onError: onError, onStatus: onStatus, onRetryAttempt: _onRetryAttempt));
  }

  void _joinMatch(io.Socket socket) {
    final matchId = _matchId;
    if (!_isCurrent(socket) || matchId == null || !socket.connected) return;
    socket.emitWithAckAsync('match:join', {'matchId': matchId}).then((data) {
      if (!_isCurrent(socket)) return;
      if (data is Map && data['id'] != null) {
        _onUpdate?.call(Map<String, dynamic>.from(data));
      } else {
        _onError?.call('Could not join the live match room.');
      }
    }).catchError((_) {
      if (_isCurrent(socket)) _onError?.call('Could not join the live match room.');
    });
  }

  void _markDisconnected({required bool schedule}) {
    _setStatus(!schedule || slowMode ? GameSocketStatus.disconnected : GameSocketStatus.reconnecting);
    if (schedule) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _retryTimer != null || _socket?.connected == true) return;
    _retryAttempt += 1;
    final slow = slowMode;
    final delay = slow ? _slowModeDelay : Duration(seconds: _retryAttempt == 1 ? 1 : _retryAttempt == 2 ? 2 : _retryAttempt <= 5 ? 5 : 12);
    if (slow && _retryAttempt == _slowModeAfterAttempts + 1) {
      _setStatus(GameSocketStatus.disconnected);
      _onError?.call('Live updates are offline. Your moves still sync — tap Retry to reconnect now.');
    }
    _onRetryAttempt?.call(_retryAttempt, delay);
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!_disposed && _socket?.connected != true) _reconnectWithLatestToken();
    });
  }

  String _socketMessage(dynamic data, {required String fallback}) {
    if (data is Map && data['message'] != null) return data['message'].toString();
    final value = data?.toString() ?? '';
    return value.isEmpty || value == 'null' ? fallback : value;
  }

  bool _isCurrent(io.Socket socket) => !_disposed && identical(_socket, socket);

  void _setStatus(GameSocketStatus status) {
    if (!_disposed) _onStatus?.call(status);
  }

  void dispose() {
    _disposed = true;
    _connectionGeneration += 1;
    _retryTimer?.cancel();
    _retryTimer = null;
    _connecting = false;
    final socket = _socket;
    _socket = null;
    socket?.dispose();
  }
}
