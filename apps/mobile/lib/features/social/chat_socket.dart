import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';

enum ChatSocketStatus { connecting, connected, reconnecting, disconnected }

class ChatSocket {
  ChatSocket(this.store);
  final TokenStore store;
  io.Socket? _socket;
  Timer? _retryTimer;
  String? _conversationId;
  void Function(Map<String, dynamic>)? _onMessage;
  void Function(ChatSocketStatus)? _onStatus;
  bool _disposed = false;
  bool _connecting = false;
  int _attempt = 0;
  int _generation = 0;

  static const int _slowModeAfterAttempts = 8;
  static const Duration _slowModeDelay = Duration(seconds: 30);

  int get retryAttempt => _attempt;
  bool get slowMode => _attempt > _slowModeAfterAttempts;

  Future<void> connect({required String conversationId, required void Function(Map<String, dynamic>) onMessage, void Function(ChatSocketStatus)? onStatus}) async {
    _disposed = false;
    final generation = ++_generation;
    _retryTimer?.cancel();
    _retryTimer = null;
    _socket?.dispose();
    _socket = null;
    _conversationId = conversationId;
    _onMessage = onMessage;
    _onStatus = onStatus;
    _attempt = 0;
    _setStatus(ChatSocketStatus.connecting);
    final token = await store.accessToken();
    if (_disposed || generation != _generation) return;
    if (token == null || token.isEmpty) { _setStatus(ChatSocketStatus.disconnected); return; }
    final base = apiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    final socket = io.io('$base/chat', io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).disableAutoConnect().disableReconnection().build());
    _socket = socket;
    socket.onConnect((_) { if (!_current(socket)) return; _connecting = false; _attempt = 0; _retryTimer?.cancel(); _retryTimer = null; _setStatus(ChatSocketStatus.connected); socket.emit('conversation:join', {'conversationId': conversationId}); });
    socket.on('connect_error', (_) { if (!_current(socket)) return; _connecting = false; _markReconnecting(); });
    socket.on('disconnect', (reason) { if (!_current(socket)) return; _connecting = false; if (reason?.toString() == 'io client disconnect') _setStatus(ChatSocketStatus.disconnected); else _markReconnecting(); });
    socket.on('message:new', (data) { if (_current(socket) && data is Map && data['conversationId'] == conversationId) onMessage(Map<String, dynamic>.from(data)); });
    _connecting = true;
    socket.connect();
  }

  void retry() {
    if (_disposed || _connecting || _socket?.connected == true) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _attempt = 0;
    _connectAgain();
  }

  void _connectAgain() {
    final id = _conversationId;
    final message = _onMessage;
    if (id == null || message == null) return;
    unawaited(connect(conversationId: id, onMessage: message, onStatus: _onStatus));
  }

  void _markReconnecting() {
    _setStatus(slowMode ? ChatSocketStatus.disconnected : ChatSocketStatus.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _retryTimer != null || _socket?.connected == true) return;
    _attempt += 1;
    final delay = slowMode ? _slowModeDelay : Duration(seconds: _attempt == 1 ? 1 : _attempt < 5 ? 4 : 10);
    _retryTimer = Timer(delay, () { _retryTimer = null; if (!_disposed && _socket?.connected != true) _connectAgain(); });
  }

  bool _current(io.Socket socket) => !_disposed && identical(_socket, socket);
  void _setStatus(ChatSocketStatus status) { if (!_disposed) _onStatus?.call(status); }

  void dispose() {
    _disposed = true;
    _generation += 1;
    _retryTimer?.cancel();
    _retryTimer = null;
    _connecting = false;
    _socket?.dispose();
    _socket = null;
  }
}
