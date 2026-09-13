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
  bool _disposed = false;
  int _retryAttempt = 0;
  int _connectionGeneration = 0;

  Future<void> connect({
    required String matchId,
    required void Function(Map<String, dynamic>) onUpdate,
    required void Function(String) onError,
    required void Function(GameSocketStatus) onStatus,
  }) async {
    _disposed = false;
    final generation = ++_connectionGeneration;
    _retryTimer?.cancel();
    final previous = _socket;
    _socket = null;
    previous?.dispose();
    _matchId = matchId;
    _onUpdate = onUpdate;
    _onError = onError;
    _onStatus = onStatus;
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
      _retryAttempt = 0;
      _retryTimer?.cancel();
      _setStatus(GameSocketStatus.connected);
      _joinMatch(socket);
    });
    socket.on('connect_error', (_) {
      if (!_isCurrent(socket)) return;
      _setStatus(GameSocketStatus.reconnecting);
      _scheduleReconnect();
    });
    socket.on('reconnect_attempt', (_) {
      if (_isCurrent(socket)) _setStatus(GameSocketStatus.reconnecting);
    });
    socket.on('disconnect', (_) {
      if (!_isCurrent(socket)) return;
      _setStatus(GameSocketStatus.reconnecting);
      _scheduleReconnect();
    });
    socket.on('match:update', (data) {
      if (_isCurrent(socket) && data is Map) _onUpdate?.call(Map<String, dynamic>.from(data));
    });
    socket.on('match:error', (data) {
      if (_isCurrent(socket)) _onError?.call(data is Map ? data['message']?.toString() ?? 'The match connection returned an error.' : 'The match connection returned an error.');
    });
    socket.connect();
  }

  void retry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_disposed || _socket == null || _socket!.connected) return;
    _retryAttempt = 0;
    _reconnectWithLatestToken();
  }

  void _reconnectWithLatestToken() {
    final matchId = _matchId;
    final onUpdate = _onUpdate;
    final onError = _onError;
    final onStatus = _onStatus;
    if (matchId == null || onUpdate == null || onError == null || onStatus == null) return;
    unawaited(connect(matchId: matchId, onUpdate: onUpdate, onError: onError, onStatus: onStatus));
  }

  void _joinMatch(io.Socket socket) {
    final matchId = _matchId;
    if (!_isCurrent(socket) || matchId == null || !socket.connected) return;
    socket.emit('match:join', {'matchId': matchId}, (data) {
      if (!_isCurrent(socket)) return;
      if (data is Map && data['id'] != null) {
        _onUpdate?.call(Map<String, dynamic>.from(data));
      } else {
        _onError?.call('Could not join the live match room.');
      }
    });
  }

  bool _isCurrent(io.Socket socket) => !_disposed && identical(_socket, socket);

  void _scheduleReconnect() {
    if (_disposed || _retryTimer != null || _socket == null) return;
    final seconds = _retryAttempt < 1 ? 1 : _retryAttempt < 4 ? 3 : 8;
    _retryAttempt += 1;
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _retryTimer = null;
      if (!_disposed && _socket != null && !_socket!.connected) {
        _reconnectWithLatestToken();
      }
    });
  }

  void _setStatus(GameSocketStatus status) {
    if (!_disposed) _onStatus?.call(status);
  }

  void dispose() {
    _disposed = true;
    _connectionGeneration += 1;
    _retryTimer?.cancel();
    _retryTimer = null;
    final socket = _socket;
    _socket = null;
    socket?.dispose();
  }
}
