import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

const _bowlingBlue = Color(0xFF4F7CAC);

class BowlingGameBoard extends StatefulWidget {
  const BowlingGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<BowlingGameBoard> createState() => _BowlingGameBoardState();
}

class _BowlingGameBoardState extends State<BowlingGameBoard> {
  int pins = 7;

  @override
  void didUpdateWidget(covariant BowlingGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) pins = 7;
  }

  @override
  Widget build(BuildContext context) {
    final frame = (widget.state['frame'] as num?)?.toInt() ?? 1;
    final ball = (widget.state['ball'] as num?)?.toInt() ?? 1;
    final totals = _ints(widget.state['totals']);
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final viewer = _viewer();
    final isTurn = !finished && widget.match.status == 'active' && viewer != null && widget.state['turnPlayerId'] == viewer['id'];
    final myRolls = _myCurrentRolls(frame);
    final maxPins = _maxPins(myRolls, frame - 1);
    final clamped = pins.clamp(0, maxPins);
    final lastRoll = widget.state['lastRoll'] is Map ? Map<String, dynamic>.from(widget.state['lastRoll'] as Map) : null;
    final leader = _leader(totals);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _bowlingBlue.withOpacity(.17), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.sports_rounded, color: _bowlingBlue)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Bowling', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _BowlingBadge(label: finished ? 'Final' : 'Frame $frame · Ball $ball'),
          ]),
          const SizedBox(height: 6),
          Text(finished ? 'All ten frames are complete.' : 'Strikes and spares earn bonus pins — highest total wins.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          if (lastRoll != null && !finished) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: _bowlingBlue.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: Text('${_name(lastRoll['playerId']?.toString())} knocked ${lastRoll['pins'] ?? 0} pins (frame ${lastRoll['frame'] ?? '–'})', style: const TextStyle(color: _bowlingBlue, fontWeight: FontWeight.w800, fontSize: 12))),
          ],
          const SizedBox(height: 12),
          for (var index = 0; index < widget.match.players.length; index += 1) ...[
            _PlayerScorecard(name: _playerName(index), total: totals.length > index ? totals[index] : 0, frames: _playerFrames(index), scorecard: _playerScorecard(index), isViewer: index == widget.match.viewerSeat, isTurn: !finished && widget.state['turnPlayerId'] == _playerId(index), won: finished && widget.match.winnerIds.contains(_playerId(index)), isLeader: !finished && index == leader),
            if (index < widget.match.players.length - 1) const SizedBox(height: 10),
          ],
          if (isTurn) ...[
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _bowlingBlue.withOpacity(.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: _bowlingBlue.withOpacity(.3))), child: Column(children: [
              Text('Your roll — up to $maxPins pins standing', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton.filledTonal(onPressed: clamped > 0 ? () => setState(() => pins = clamped - 1) : null, icon: const Icon(Icons.remove_rounded)),
                Container(width: 64, alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor)), child: Text('$clamped', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22))),
                IconButton.filledTonal(onPressed: clamped < maxPins ? () => setState(() => pins = clamped + 1) : null, icon: const Icon(Icons.add_rounded)),
              ]),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => widget.onAction({'type': 'roll', 'pins': clamped}), icon: const Icon(Icons.sports_rounded), label: const Text('Roll'))),
            ])),
          ] else if (!finished) ...[
            const SizedBox(height: 12),
            Text('Waiting for ${_turnName()} to roll…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }

  List<List<int>> _playerFrames(int seat) {
    final frames = widget.state['frames'] as List? ?? const [];
    if (seat >= frames.length || frames[seat] is! List) return List.generate(10, (_) => <int>[]);
    final mine = frames[seat] as List;
    return List.generate(10, (frame) => frame < mine.length && mine[frame] is List ? (mine[frame] as List).map((pins) => (pins as num?)?.toInt() ?? 0).toList() : <int>[]);
  }

  List<int?> _playerScorecard(int seat) {
    final card = widget.state['scorecard'] as List? ?? const [];
    if (seat >= card.length || card[seat] is! List) return List.filled(10, null);
    final mine = card[seat] as List;
    return List.generate(10, (frame) => frame < mine.length ? (mine[frame] as num?)?.toInt() : null);
  }

  List<int> _myCurrentRolls(int frame) {
    final frames = _playerFrames(widget.match.viewerSeat);
    if (frame < 1 || frame > 10) return const [];
    return frames[frame - 1];
  }

  int _maxPins(List<int> rolls, int frameIndex) {
    if (frameIndex < 9) {
      if (rolls.isEmpty) return 10;
      return rolls[0] == 10 ? 0 : 10 - rolls[0];
    }
    if (rolls.isEmpty) return 10;
    if (rolls.length == 1) return rolls[0] == 10 ? 10 : 10 - rolls[0];
    final first = rolls[0];
    final second = rolls[1];
    if (first == 10 && second == 10) return 10;
    if (first == 10) return 10 - second;
    return 10;
  }

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

  int _leader(List<int> totals) {
    var best = 0;
    for (var index = 1; index < widget.match.players.length; index += 1) {
      if ((totals.length > index ? totals[index] : 0) > (totals.length > best ? totals[best] : 0)) best = index;
    }
    return best;
  }

  List<int> _ints(dynamic value) => (value as List? ?? const []).map((item) => (item as num?)?.toInt() ?? 0).toList();
}

class _PlayerScorecard extends StatelessWidget {
  const _PlayerScorecard({required this.name, required this.total, required this.frames, required this.scorecard, required this.isViewer, required this.isTurn, required this.won, required this.isLeader});
  final String name;
  final int total;
  final List<List<int>> frames;
  final List<int?> scorecard;
  final bool isViewer;
  final bool isTurn;
  final bool won;
  final bool isLeader;

  @override
  Widget build(BuildContext context) {
    final highlight = won || isLeader;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: isViewer ? _bowlingBlue.withOpacity(.08) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: highlight ? _bowlingBlue.withOpacity(.55) : Theme.of(context).dividerColor, width: highlight ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (isTurn) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.sports_rounded, size: 15, color: _bowlingBlue)),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
          if (won) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.emoji_events_rounded, size: 16, color: _bowlingBlue)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: _bowlingBlue.withOpacity(.14), borderRadius: BorderRadius.circular(9)), child: Text('$total', style: const TextStyle(color: _bowlingBlue, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var frame = 0; frame < 10; frame += 1) ...[
              _FrameCell(marks: _marks(frames[frame], frame), cumulative: frame < scorecard.length ? scorecard[frame] : null),
              if (frame < 9) const SizedBox(width: 4),
            ],
          ]),
        ),
      ]),
    );
  }

  String _marks(List<int> rolls, int frameIndex) {
    String mark(int value) => value == 0 ? '–' : '$value';
    if (rolls.isEmpty) return '';
    if (frameIndex < 9) {
      if (rolls[0] == 10) return 'X';
      if (rolls.length == 1) return mark(rolls[0]);
      return rolls[0] + rolls[1] == 10 ? '${mark(rolls[0])} /' : '${mark(rolls[0])} ${mark(rolls[1])}';
    }
    final marks = <String>[];
    for (var index = 0; index < rolls.length; index += 1) {
      if (index == 0) {
        marks.add(rolls[0] == 10 ? 'X' : mark(rolls[0]));
      } else if (index == 1) {
        if (rolls[0] == 10) {
          marks.add(rolls[1] == 10 ? 'X' : mark(rolls[1]));
        } else {
          marks.add(rolls[0] + rolls[1] == 10 ? '/' : mark(rolls[1]));
        }
      } else {
        if (rolls[0] == 10 && rolls[1] == 10) {
          marks.add(rolls[2] == 10 ? 'X' : mark(rolls[2]));
        } else if (rolls[0] == 10) {
          marks.add(rolls[1] + rolls[2] == 10 ? '/' : mark(rolls[2]));
        } else {
          marks.add(rolls[2] == 10 ? 'X' : mark(rolls[2]));
        }
      }
    }
    return marks.join(' ');
  }
}

class _FrameCell extends StatelessWidget {
  const _FrameCell({required this.marks, required this.cumulative});
  final String marks;
  final int? cumulative;
  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: Theme.of(context).dividerColor)),
        child: Column(children: [
          SizedBox(height: 15, child: Text(marks, maxLines: 1, overflow: TextOverflow.visible, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: _bowlingBlue))),
          const SizedBox(height: 2),
          Text(cumulative == null ? '·' : '$cumulative', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: cumulative == null ? Theme.of(context).disabledColor : Theme.of(context).colorScheme.onSurface)),
        ]),
      );
}

class _BowlingBadge extends StatelessWidget {
  const _BowlingBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: _bowlingBlue.withOpacity(.16), borderRadius: BorderRadius.circular(12)), child: Text(label, style: const TextStyle(color: _bowlingBlue, fontWeight: FontWeight.w900, fontSize: 12)));
}
