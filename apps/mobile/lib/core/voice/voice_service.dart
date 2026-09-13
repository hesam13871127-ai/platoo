import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:livekit_client/livekit_client.dart';
import '../network/api_client.dart';

class VoiceService {
  VoiceService(this.api);
  final ApiClient api;
  Room? _room;

  Future<void> joinMatch(String matchId) async {
    final data = Map<String, dynamic>.from(await api.post('/voice/token', data: {'matchId': matchId}) as Map);
    final room = Room();
    await room.connect(data['url'] as String, data['token'] as String, roomOptions: RoomOptions(adaptiveStream: true, dynacast: true));
    await room.localParticipant?.setMicrophoneEnabled(true);
    _room = room;
  }

  Future<void> leave() async { await _room?.disconnect(); _room = null; }
  bool get connected => _room != null;
}

class VoiceRoomButton extends StatefulWidget {
  const VoiceRoomButton({super.key, required this.api, required this.matchId});
  final ApiClient api;
  final String matchId;
  @override State<VoiceRoomButton> createState() => _VoiceRoomButtonState();
}

class _VoiceRoomButtonState extends State<VoiceRoomButton> {
  late final VoiceService voice = VoiceService(widget.api);
  bool loading = false;
  @override void dispose() { voice.leave(); super.dispose(); }
  @override Widget build(BuildContext context) => IconButton(onPressed: loading ? null : () async { setState(() => loading = true); try { if (voice.connected) { await voice.leave(); } else { await voice.joinMatch(widget.matchId); } if (mounted) setState(() {}); } on DioException catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Voice chat is unavailable.'))); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); } finally { if (mounted) setState(() => loading = false); } }, icon: Icon(voice.connected ? Icons.mic_rounded : Icons.mic_none_rounded));
}
