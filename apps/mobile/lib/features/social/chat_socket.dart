import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';

class ChatSocket {
  ChatSocket(this.store);
  final TokenStore store;
  io.Socket? _socket;
  Future<void> connect({required String conversationId, required void Function(Map<String, dynamic>) onMessage}) async {
    final token = await store.accessToken();
    if (token == null) return;
    final base = apiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    final socket = io.io('$base/chat', io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).disableAutoConnect().build());
    _socket = socket;
    socket.onConnect((_) => socket.emit('conversation:join', {'conversationId': conversationId}));
    socket.on('message:new', (data) { if (data is Map && data['conversationId'] == conversationId) onMessage(Map<String, dynamic>.from(data)); });
    socket.connect();
  }
  void dispose() { _socket?.dispose(); _socket = null; }
}
