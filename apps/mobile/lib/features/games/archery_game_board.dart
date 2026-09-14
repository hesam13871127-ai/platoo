import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

const _archeryOrange = Color(0xFFE76F51);

class ArcheryGameBoard extends StatefulWidget {
  const ArcheryGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<ArcheryGameBoard> createState() => _ArcheryGameBoardState();
}

class _ArcheryGameBoardState extends State<ArcheryGameBoard> {
  Offset? aimTap;
  double targetRadius = 130;

  @override
  void didUpdateWidget(covariant ArcheryGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) aimTap = null;
  }

  @override
  Widget build(BuildContext context) {
    final scores = _ints(widget.state['scores']);
    final shots = _ints(widget.state['shots']);
    final rounds = (widget.state['rounds'] as num?)?.toInt() ?? 5;
    final wind = (widget.state['wind'] as num?)?.toInt() ?? 0;
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final viewer = _viewer();
    final isTurn = !finished && widget.match.status == 'active' && viewer != null && widget.state['turnPlayerId'] == viewer['id'];
    final myShots = widget.match.viewerSeat < shots.length ? shots[widget.match.viewerSeat] : 0;
    final accuracy = _aimAccuracy();
    final lastShot = widget.state['lastShot'] is Map ? Map<String, dynamic>.from(widget.state['lastShot'] as Map) : null;
    final history = (widget.state['history'] as List? ?? const []).reversed.take(5).toList();
    final leader = _leader(scores);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _archeryOrange.withOpacity(.17), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.gps_fixed_rounded, color: _archeryOrange)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Archery', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _ArcheryBadge(label: finished ? 'Final' : 'Arrow ${myShots + 1} / $rounds'),
          ]),
          const SizedBox(height: 10),
          _WindBar(wind: wind, finished: finished),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTapDown: isTurn ? (details) => setState(() => aimTap = details.localPosition) : null,
              child: CustomPaint(size: const Size(260, 260), painter: _TargetPainter(aim: aimTap, markers: _myMarkers(), accent: _archeryOrange)),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(isTurn ? (aimTap == null ? 'Tap the target to aim, then loose.' : 'Aiming at $accuracy — wind ${wind == 0 ? 'is calm' : 'pushes ${wind > 0 ? 'right' : 'left'} by ${wind.abs()}'}') : finished ? 'All arrows spent.' : 'Waiting for ${_turnName()} to shoot…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: isTurn && aimTap != null ? () => widget.onAction({'type': 'shoot', 'accuracy': accuracy}) : null, icon: const Icon(Icons.my_location_rounded), label: Text(isTurn ? 'Loose arrow' : finished ? 'Match complete' : 'Waiting for turn'))),
          if (lastShot != null) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: _archeryOrange.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: Text('${_name(lastShot['playerId']?.toString())}: ${lastShot['label'] ?? ''} · ${lastShot['points'] ?? 0} pts${(lastShot['wind'] as num?)?.toInt() != 0 ? ' (wind ${lastShot['wind']})' : ''}', style: const TextStyle(color: _archeryOrange, fontWeight: FontWeight.w800, fontSize: 12))),
          ],
          const SizedBox(height: 14),
          ..._scoreRows(scores, shots, rounds, leader, finished),
          if (history.length > 1) ...[
            const SizedBox(height: 10),
            for (final entry in history.skip(1))
              if (entry is Map)
                Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('${_name(entry['playerId']?.toString())} scored ${entry['points'] ?? 0} pts', style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 11))),
          ],
        ]),
      ),
    );
  }

  int _aimAccuracy() {
    if (aimTap == null) return 50;
    const center = Offset(130, 130);
    final tap = aimTap!;
    final distance = ((tap - center).distance / targetRadius).clamp(0.0, 1.0);
    final side = tap.dx >= center.dx ? 1 : -1;
    return (50 + side * (distance * 50)).round().clamp(0, 100);
  }

  List<_ShotMarker> _myMarkers() {
    final viewer = _viewer();
    if (viewer == null) return const [];
    final markers = <_ShotMarker>[];
    var index = 0;
    for (final entry in (widget.state['history'] as List? ?? const [])) {
      if (entry is Map && entry['playerId'] == viewer['id']) {
        final effective = (entry['effective'] as num?)?.toInt() ?? 50;
        markers.add(_ShotMarker(distance: ((effective - 50).abs() / 50).clamp(0.0, 1.0), angle: index * 2.39996));
        index += 1;
      }
    }
    return markers;
  }

  List<Widget> _scoreRows(List<int> scores, List<int> shots, int rounds, int leader, bool finished) => [
        for (var index = 0; index < widget.match.players.length; index += 1)
          Builder(builder: (context) {
            final score = scores.length > index ? scores[index] : 0;
            final used = shots.length > index ? shots[index] : 0;
            final won = finished && widget.match.winnerIds.contains(_playerId(index));
            final highlight = won || (!finished && index == leader);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), decoration: BoxDecoration(color: highlight ? _archeryOrange.withOpacity(.13) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: highlight ? _archeryOrange.withOpacity(.5) : Theme.of(context).dividerColor)), child: Row(children: [
                Expanded(child: Text(_playerName(index), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                Text('$used/$rounds 🏹', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                if (won) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.emoji_events_rounded, size: 16, color: _archeryOrange)),
                Text('$score', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ])),
            );
          }),
      ];

  Map<String, dynamic>? _viewer() {
    final viewers = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    return viewers.isEmpty ? null : viewers.first;
  }

  String _playerName(int seat) => seat < widget.match.players.length ? widget.match.players[seat]['displayName']?.toString() ?? 'Player' : 'Player';
  String _playerId(int seat) => seat < widget.match.players.length ? widget.match.players[seat]['id']?.toString() ?? '' : '';

  String _name(String? id) {
    if (id == null) return 'Someone';
    final found = widget.match.players.where((player) => player['id'] == id).toList();
    return found.isEmpty ? 'Someone' : found.first['displayName']?.toString() ?? 'Someone';
  }

  String _turnName() {
    final found = widget.match.players.where((player) => player['id'] == widget.state['turnPlayerId']).toList();
    return found.isEmpty ? 'the other player' : found.first['displayName']?.toString() ?? 'the other player';
  }

  int _leader(List<int> scores) {
    var best = 0;
    for (var index = 1; index < widget.match.players.length; index += 1) {
      if ((scores.length > index ? scores[index] : 0) > (scores.length > best ? scores[best] : 0)) best = index;
    }
    return best;
  }

  List<int> _ints(dynamic value) => (value as List? ?? const []).map((item) => (item as num?)?.toInt() ?? 0).toList();
}

class _ShotMarker {
  const _ShotMarker({required this.distance, required this.angle});
  final double distance;
  final double angle;
}

class _TargetPainter extends CustomPainter {
  const _TargetPainter({required this.aim, required this.markers, required this.accent});
  final Offset? aim;
  final List<_ShotMarker> markers;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const bands = [Color(0xFFF8FAFC), Color(0xFF1F2937), Color(0xFF38BDF8), Color(0xFFEF4444), Color(0xFFFBBF24)];
    for (var index = 0; index < bands.length; index += 1) {
      canvas.drawCircle(center, radius * (1 - index * 0.2), Paint()..color = bands[index]);
    }
    for (var ring = 1; ring <= 10; ring += 1) {
      canvas.drawCircle(center, radius * ring / 10, Paint()..color = Colors.black.withOpacity(.14)..style = PaintingStyle.stroke..strokeWidth = 1);
    }
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFFB45309));
    for (final marker in markers) {
      final point = center + Offset(math.cos(marker.angle), math.sin(marker.angle)) * (marker.distance * radius);
      canvas.drawCircle(point, 5, Paint()..color = accent);
      canvas.drawCircle(point, 5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    if (aim != null) {
      canvas.drawCircle(aim!, 9, Paint()..color = accent.withOpacity(.25));
      canvas.drawCircle(aim!, 9, Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawLine(aim! + const Offset(-13, 0), aim! + const Offset(13, 0), Paint()..color = accent..strokeWidth = 2);
      canvas.drawLine(aim! + const Offset(0, -13), aim! + const Offset(0, 13), Paint()..color = accent..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _TargetPainter oldDelegate) => oldDelegate.aim != aim || oldDelegate.markers.length != markers.length;
}

class _WindBar extends StatelessWidget {
  const _WindBar({required this.wind, required this.finished});
  final int wind;
  final bool finished;
  @override
  Widget build(BuildContext context) {
    final calm = wind == 0 || finished;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.1), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Transform.flip(flipX: !calm && wind < 0, child: Icon(calm ? Icons.air_rounded : Icons.arrow_right_alt_rounded, color: AppTheme.mint, size: 18)),
        const SizedBox(width: 8),
        Expanded(child: Text(calm ? (finished ? 'The range is quiet.' : 'No wind — aim dead center.') : 'Wind ${wind.abs()} pushing ${wind > 0 ? 'right → aim left' : 'left → aim right'}', style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w800, fontSize: 12))),
      ]),
    );
  }
}

class _ArcheryBadge extends StatelessWidget {
  const _ArcheryBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: _archeryOrange.withOpacity(.16), borderRadius: BorderRadius.circular(12)), child: Text(label, style: const TextStyle(color: _archeryOrange, fontWeight: FontWeight.w900, fontSize: 12)));
}
