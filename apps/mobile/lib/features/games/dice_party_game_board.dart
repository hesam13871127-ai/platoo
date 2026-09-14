import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class DicePartyGameBoard extends StatelessWidget {
  const DicePartyGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  static const _pips = <int, List<int>>{
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final scores = _ints(state['scores']);
    final rolls = state['rolls'] as List? ?? const [];
    final round = (state['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (state['maxRounds'] as num?)?.toInt() ?? 5;
    final finished = match.status == 'finished' || state['finished'] == true;
    final viewer = _viewer();
    final isTurn = !finished && match.status == 'active' && viewer != null && state['turnPlayerId'] == viewer['id'];
    final lastRoll = state['lastRoll'] is Map ? Map<String, dynamic>.from(state['lastRoll'] as Map) : null;
    final history = (state['history'] as List? ?? const []).reversed.take(8).toList();
    final leader = _leader(scores);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.17), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.casino_rounded, color: AppTheme.gold)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Dice Party', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _DiceBadge(label: finished ? 'Final' : 'Round $round / $maxRounds'),
          ]),
          const SizedBox(height: 6),
          Text(finished ? 'The dice have settled.' : 'Highest total after $maxRounds rounds wins.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          if (lastRoll != null && !finished) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: Text('${_name(lastRoll['playerId']?.toString())} rolled a ${lastRoll['value'] ?? '–'}', style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w800, fontSize: 12))),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var index = 0; index < match.players.length; index += 1)
              _PlayerDie(name: _playerName(index), value: index < rolls.length ? (rolls[index] as num?)?.toInt() : null, isLeader: !finished && index == leader && scores.isNotEmpty, isViewer: index == match.viewerSeat),
          ]),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: isTurn ? () => onAction({'type': 'roll'}) : null, icon: const Icon(Icons.casino_rounded), label: Text(isTurn ? 'Roll the dice' : finished ? 'Match complete' : 'Waiting for turn'))),
          const SizedBox(height: 14),
          const Text('Standings', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 8),
          ..._standings(scores, leader, finished),
          if (history.isNotEmpty && !finished) ...[
            const SizedBox(height: 12),
            const Text('Recent rolls', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 6),
            for (final entry in history)
              if (entry is Map)
                Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('Round ${entry['round'] ?? '–'} · ${_name(entry['playerId']?.toString())} rolled ${entry['value'] ?? '–'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700))),
          ],
        ]),
      ),
    );
  }

  List<Widget> _standings(List<int> scores, int leader, bool finished) {
    final order = List<int>.generate(match.players.length, (index) => index)..sort((a, b) => (scores.length > b ? scores[b] : 0).compareTo(scores.length > a ? scores[a] : 0));
    return [
      for (var rank = 0; rank < order.length; rank += 1)
        Builder(builder: (context) {
          final index = order[rank];
          final name = _playerName(index);
          final score = scores.length > index ? scores[index] : 0;
          final won = finished && match.winnerIds.contains(_playerId(index));
          final highlight = won || (!finished && index == leader);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), decoration: BoxDecoration(color: highlight ? AppTheme.gold.withOpacity(.13) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: highlight ? AppTheme.gold.withOpacity(.5) : Theme.of(context).dividerColor)), child: Row(children: [
              Text('${rank + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: highlight ? AppTheme.gold : Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(width: 10),
              Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
              if (won) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.emoji_events_rounded, size: 16, color: AppTheme.gold)),
              Text('$score', style: const TextStyle(fontWeight: FontWeight.w900)),
            ])),
          );
        }),
    ];
  }

  Map<String, dynamic>? _viewer() {
    final viewers = match.players.where((player) => player['seat'] == match.viewerSeat).toList();
    return viewers.isEmpty ? null : viewers.first;
  }

  String _playerName(int seat) => seat < match.players.length ? match.players[seat]['displayName']?.toString() ?? 'Player' : 'Player';
  String _playerId(int seat) => seat < match.players.length ? match.players[seat]['id']?.toString() ?? '' : '';

  String _name(String? id) {
    if (id == null) return 'Someone';
    final found = match.players.where((player) => player['id'] == id).toList();
    return found.isEmpty ? 'Someone' : found.first['displayName']?.toString() ?? 'Someone';
  }

  int _leader(List<int> scores) {
    var best = 0;
    for (var index = 1; index < match.players.length; index += 1) {
      if ((scores.length > index ? scores[index] : 0) > (scores.length > best ? scores[best] : 0)) best = index;
    }
    return best;
  }

  List<int> _ints(dynamic value) => (value as List? ?? const []).map((item) => (item as num?)?.toInt() ?? 0).toList();
}

class _PlayerDie extends StatelessWidget {
  const _PlayerDie({required this.name, required this.value, required this.isLeader, required this.isViewer});
  final String name;
  final int? value;
  final bool isLeader;
  final bool isViewer;

  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(color: isViewer ? AppTheme.gold.withOpacity(.12) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: isLeader ? AppTheme.gold : Theme.of(context).dividerColor, width: isLeader ? 2 : 1)),
        child: Column(children: [
          _DieFace(value: value),
          const SizedBox(height: 7),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
        ]),
      );
}

class _DieFace extends StatelessWidget {
  const _DieFace({required this.value});
  final int? value;

  @override
  Widget build(BuildContext context) {
    final active = value == null ? const <int>[] : DicePartyGameBoard._pips[value] ?? const <int>[];
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: value == null ? Theme.of(context).disabledColor.withOpacity(.12) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor), boxShadow: value == null ? null : [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 6, offset: const Offset(0, 2))]),
      child: value == null
          ? Center(child: Text('?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Theme.of(context).disabledColor)))
          : GridView.builder(physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3), itemCount: 9, itemBuilder: (_, index) => Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: active.contains(index) ? const Color(0xFF1F2937) : Colors.transparent)))),
    );
  }
}

class _DiceBadge extends StatelessWidget {
  const _DiceBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.16), borderRadius: BorderRadius.circular(12)), child: Text(label, style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w900, fontSize: 12)));
}
