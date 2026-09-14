import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

const _dartsBronze = Color(0xFFB7791F);

class DartsGameBoard extends StatefulWidget {
  const DartsGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<DartsGameBoard> createState() => _DartsGameBoardState();
}

class _DartsGameBoardState extends State<DartsGameBoard> {
  int segment = 20;
  int ring = 1;
  int? special;

  @override
  void didUpdateWidget(covariant DartsGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) special = null;
  }

  @override
  Widget build(BuildContext context) {
    final scores = _ints(widget.state['scores']);
    final target = (widget.state['target'] as num?)?.toInt() ?? 301;
    final dartsLeft = (widget.state['dartsLeft'] as num?)?.toInt() ?? 3;
    final visitDarts = _ints(widget.state['visitDarts']);
    final lastVisit = widget.state['lastVisit'] is Map ? Map<String, dynamic>.from(widget.state['lastVisit'] as Map) : null;
    final history = (widget.state['history'] as List? ?? const []).reversed.take(5).toList();
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final viewer = _viewer();
    final isTurn = !finished && widget.match.status == 'active' && viewer != null && widget.state['turnPlayerId'] == viewer['id'];
    final myScore = widget.match.viewerSeat < scores.length ? scores[widget.match.viewerSeat] : target;
    final value = special ?? segment * ring;
    final bust = myScore - value < 0 || myScore - value == 1;
    final leader = _leader(scores, finished);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _dartsBronze.withOpacity(.17), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.adjust_rounded, color: _dartsBronze)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Darts 301', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _DartsBadge(label: finished ? 'Final' : 'Dart ${3 - dartsLeft + 1} of 3'),
          ]),
          const SizedBox(height: 6),
          Text(finished ? 'Checkout complete.' : 'Count down from $target to exactly zero · 3 darts per visit.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ..._scoreRows(scores, leader, finished),
          if (visitDarts.isNotEmpty && !finished) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: _dartsBronze.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: Text('Current visit: ${visitDarts.join(' · ')}  (total ${visitDarts.fold<int>(0, (sum, dart) => sum + dart)})', style: const TextStyle(color: _dartsBronze, fontWeight: FontWeight.w800, fontSize: 12))),
          ],
          if (!finished && myScore <= 60 && myScore >= 1) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: Text('🎯 Checkout: throw $myScore to win!', style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w800, fontSize: 12))),
          ],
          if (isTurn) ...[
            const SizedBox(height: 14),
            const Text('Aim your dart', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 1, label: Text('Single')), ButtonSegment(value: 2, label: Text('Double')), ButtonSegment(value: 3, label: Text('Triple'))],
              selected: {ring},
              onSelectionChanged: (selection) => setState(() {
                ring = selection.first;
                special = null;
              }),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var number = 1; number <= 20; number += 1)
                InkWell(
                  onTap: () => setState(() {
                    segment = number;
                    special = null;
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(width: 40, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: special == null && segment == number ? _dartsBronze : _dartsBronze.withOpacity(.1), borderRadius: BorderRadius.circular(10)), child: Text('$number', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: special == null && segment == number ? Colors.white : _dartsBronze))),
                ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => special = 0), style: OutlinedButton.styleFrom(foregroundColor: special == 0 ? Colors.white : null, backgroundColor: special == 0 ? _dartsBronze : null), child: const Text('Miss'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => setState(() => special = 25), style: OutlinedButton.styleFrom(foregroundColor: special == 25 ? Colors.white : null, backgroundColor: special == 25 ? _dartsBronze : null), child: const Text('Outer 25'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => setState(() => special = 50), style: OutlinedButton.styleFrom(foregroundColor: special == 50 ? Colors.white : null, backgroundColor: special == 50 ? _dartsBronze : null), child: const Text('Bull 50'))),
            ]),
            const SizedBox(height: 10),
            if (bust) ...[
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: AppTheme.coral.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Text('⚠️ $value busts from $myScore — pick a smaller dart.', style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w800, fontSize: 12))),
              const SizedBox(height: 10),
            ],
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: bust ? null : () => widget.onAction({'type': 'throw', 'value': value}), icon: const Icon(Icons.sports_rounded), label: Text('Throw for $value'))),
          ] else if (!finished) ...[
            const SizedBox(height: 12),
            Text('Waiting for ${_turnName()} to throw…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
          if (lastVisit != null && !finished) ...[
            const SizedBox(height: 12),
            Text('Last visit · ${_name(lastVisit['playerId']?.toString())}: ${(lastVisit['darts'] as List? ?? const []).join(', ')} (total ${lastVisit['total'] ?? 0})', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
          if (history.length > 1) ...[
            const SizedBox(height: 4),
            for (final entry in history.skip(1))
              if (entry is Map)
                Padding(padding: const EdgeInsets.only(top: 3), child: Text('${_name(entry['playerId']?.toString())}: ${(entry['darts'] as List? ?? const []).join(', ')}', style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 11))),
          ],
        ]),
      ),
    );
  }

  List<Widget> _scoreRows(List<int> scores, int leader, bool finished) => [
        for (var index = 0; index < widget.match.players.length; index += 1)
          Builder(builder: (context) {
            final score = scores.length > index ? scores[index] : 0;
            final won = finished && widget.match.winnerIds.contains(_playerId(index));
            final highlight = won || (!finished && index == leader);
            final isTurn = !finished && widget.state['turnPlayerId'] == _playerId(index);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), decoration: BoxDecoration(color: highlight ? _dartsBronze.withOpacity(.13) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: highlight ? _dartsBronze.withOpacity(.5) : Theme.of(context).dividerColor)), child: Row(children: [
                if (isTurn) const Padding(padding: EdgeInsets.only(right: 7), child: Icon(Icons.adjust_rounded, size: 15, color: _dartsBronze)),
                Expanded(child: Text(_playerName(index), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                if (won) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.emoji_events_rounded, size: 16, color: _dartsBronze)),
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

  int _leader(List<int> scores, bool finished) {
    var best = 0;
    for (var index = 1; index < widget.match.players.length; index += 1) {
      if ((scores.length > index ? scores[index] : 9999) < (scores.length > best ? scores[best] : 9999)) best = index;
    }
    return finished ? -1 : best;
  }

  List<int> _ints(dynamic value) => (value as List? ?? const []).map((item) => (item as num?)?.toInt() ?? 0).toList();
}

class _DartsBadge extends StatelessWidget {
  const _DartsBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: _dartsBronze.withOpacity(.16), borderRadius: BorderRadius.circular(12)), child: Text(label, style: const TextStyle(color: _dartsBronze, fontWeight: FontWeight.w900, fontSize: 12)));
}
