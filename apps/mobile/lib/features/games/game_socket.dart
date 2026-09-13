import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';

class GameSocket {
  GameSocket(this.store);
  final TokenStore store;
  io.Socket? _socket;
  void connect({required String matchId, required void Function(Map<String, dynamic>) onUpdate, required void Function(String) onError}) async {
    final token = await store.accessToken(); if (token == null) return;
    final base = apiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    final socket = io.io('$base/games', io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).disableAutoConnect().build());
    _socket = socket;
    socket.onConnect((_) => socket.emit('match:join', {'matchId': matchId}, (data) { if (data is Map) onUpdate(Map<String, dynamic>.from(data)); }));
    socket.on('match:update', (data) { if (data is Map) onUpdate(Map<String, dynamic>.from(data)); });
    socket.on('match:error', (data) => onError(data is Map ? data['message']?.toString() ?? 'Match error' : 'Match error'));
    socket.connect();
  }
  void dispose() { _socket?.dispose(); _socket = null; }
}
