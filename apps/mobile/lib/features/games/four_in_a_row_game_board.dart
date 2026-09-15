import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class FourInARowGameBoard extends StatefulWidget {
  const FourInARowGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<FourInARowGameBoard> createState() => _FourInARowGameBoardState();
}

class _FourInARowGameBoardState extends State<FourInARowGameBoard> {
  _Drop? _drop;
  Timer? _dropTimer;

  @override
  void dispose() {
    _dropTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FourInARowGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) _detectDrop(_boardOf(oldWidget.state), _boardOf(widget.state));
  }

  List<List<int>> _boardOf(Map<String, dynamic> state) => (state['board'] as List? ?? const []).map((row) => (row as List).map((cell) => (cell as num).toInt()).toList()).toList();

  void _detectDrop(List<List<int>> previous, List<List<int>> next) {
    for (var row = 0; row < 6; row += 1) {
      for (var column = 0; column < 7; column += 1) {
        final before = previous.length > row && previous[row].length > column ? previous[row][column] : 0;
        final after = next.length > row && next[row].length > column ? next[row][column] : 0;
        if (before == 0 && after != 0) {
          _dropTimer?.cancel();
          setState(() => _drop = _Drop(row: row, column: column, value: after, landed: false));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              final drop = _drop;
              if (drop != null) _drop = _Drop(row: drop.row, column: drop.column, value: drop.value, landed: true);
            });
          });
          _dropTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _drop = null);
          });
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _boardOf(widget.state);
    final ownPlayers = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    final isTurn = ownPlayers.isNotEmpty && widget.state['turnPlayerId'] == ownPlayers.first['id'] && widget.match.status == 'active';
    final moveCount = (widget.state['moveCount'] as num?)?.toInt() ?? 0;
    final winLine = widget.match.status == 'finished' ? _winningLine(board) : <int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppTheme.oceanGradient, borderRadius: BorderRadius.circular(13), boxShadow: AppTheme.glow(AppTheme.violet, strength: .35)), child: const Icon(Icons.view_week_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          Text('4 in a Row', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppTheme.violet.withOpacity(.3))), child: Text('$moveCount / 42', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        _StatusDot(text: _status(isTurn), active: isTurn, finished: widget.match.status == 'finished'),
        const SizedBox(height: 11),
        Row(children: [
          _SeatChip(name: _playerName(0), color: AppTheme.coral, active: widget.state['turnPlayerId'] == _idFor(0)),
          const SizedBox(width: 8),
          _SeatChip(name: _playerName(1), color: AppTheme.gold, active: widget.state['turnPlayerId'] == _idFor(1)),
        ]),
        const SizedBox(height: 11),
        AspectRatio(
          aspectRatio: 7 / 6.4,
          child: LayoutBuilder(builder: (context, constraints) {
            const pad = 9.0;
            final cellW = (constraints.maxWidth - pad * 2) / 7;
            final cellH = (constraints.maxHeight - pad * 2) / 6;
            final drop = _drop;
            return Container(
              decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3D5AFE), Color(0xFF283593)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(.3), width: 1.5), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6))]),
              child: Stack(children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(pad),
                    child: Column(children: [
                      for (var row = 0; row < 6; row += 1)
                        Expanded(child: Row(children: [
                          for (var column = 0; column < 7; column += 1)
                            Expanded(child: InkWell(
                              onTap: isTurn && board.isNotEmpty && board[0][column] == 0 ? () => widget.onAction({'type': 'drop', 'column': column}) : null,
                              borderRadius: BorderRadius.circular(99),
                              child: Padding(padding: const EdgeInsets.all(3), child: _Slot(value: board.length > row && board[row].length > column ? board[row][column] : 0, hidden: drop != null && drop.row == row && drop.column == column, highlighted: winLine.contains(row * 7 + column))),
                            )),
                        ])),
                    ]),
                  ),
                ),
                if (drop != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeIn,
                    left: pad + drop.column * cellW + 3,
                    top: drop.landed ? pad + drop.row * cellH + 3 : -cellH,
                    width: cellW - 6,
                    height: cellH - 6,
                    child: _Disc(value: drop.value),
                  ),
              ]),
            );
          }),
        ),
      ],
    );
  }

  String _status(bool isTurn) {
    if (widget.match.status == 'finished') {
      if (widget.match.draw) return 'Draw · the grid is full.';
      final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
      final viewerId = viewer.isEmpty ? null : viewer.first['id']?.toString();
      return widget.match.winnerIds.contains(viewerId) ? 'You connected four!' : 'The match is finished.';
    }
    return isTurn ? 'Your turn · tap a column to drop.' : 'Waiting for the other player…';
  }

  String? _idFor(int seat) {
    final player = widget.match.players.where((candidate) => candidate['seat'] == seat).toList();
    return player.isEmpty ? null : player.first['id']?.toString();
  }

  String _playerName(int seat) {
    final player = widget.match.players.where((candidate) => candidate['seat'] == seat).toList();
    return player.isEmpty ? 'Player ${seat + 1}' : player.first['displayName']?.toString() ?? 'Player ${seat + 1}';
  }

  Set<int> _winningLine(List<List<int>> board) {
    for (var row = 0; row < 6; row += 1) {
      for (var column = 0; column < 7; column += 1) {
        final value = board.length > row && board[row].length > column ? board[row][column] : 0;
        if (value == 0) continue;
        for (final direction in const [[0, 1], [1, 0], [1, 1], [1, -1]]) {
          final cells = [row * 7 + column];
          var r = row;
          var c = column;
          for (var step = 0; step < 3; step += 1) {
            r += direction[0];
            c += direction[1];
            if (r < 0 || r >= 6 || c < 0 || c >= 7 || board[r][c] != value) break;
            cells.add(r * 7 + c);
          }
          if (cells.length == 4) return cells.toSet();
        }
      }
    }
    return <int>{};
  }
}

class _Drop {
  const _Drop({required this.row, required this.column, required this.value, required this.landed});
  final int row;
  final int column;
  final int value;
  final bool landed;
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.text, required this.active, required this.finished});
  final String text;
  final bool active;
  final bool finished;
  @override
  Widget build(BuildContext context) {
    final color = finished ? AppTheme.gold : active ? AppTheme.coral : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 8)])), const SizedBox(width: 9), Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: active && !finished ? null : Theme.of(context).colorScheme.onSurfaceVariant)))]);
  }
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({required this.name, required this.color, required this.active});
  final String name;
  final Color color;
  final bool active;
  @override
  Widget build(BuildContext context) => Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(color: active ? color.withOpacity(.13) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: active ? color : Theme.of(context).dividerColor, width: active ? 1.8 : 1)),
          child: Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 5)])), const SizedBox(width: 7), Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)))]),
        ),
      );
}

class _Slot extends StatelessWidget {
  const _Slot({required this.value, required this.hidden, required this.highlighted});
  final int value;
  final bool hidden;
  final bool highlighted;
  @override
  Widget build(BuildContext context) {
    if (value == 0 || hidden) return Container(decoration: BoxDecoration(color: const Color(0xFF101B4D), shape: BoxShape.circle, border: Border.all(color: Colors.black.withOpacity(.45), width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 4, offset: const Offset(0, 2))]));
    return _Disc(value: value, highlighted: highlighted);
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.value, this.highlighted = false});
  final int value;
  final bool highlighted;
  @override
  Widget build(BuildContext context) {
    final color = value == 1 ? AppTheme.coral : AppTheme.gold;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-.35, -.4), radius: 1.15, colors: [Color.lerp(color, Colors.white, .5)!, color, Color.lerp(color, Colors.black, .3)!], stops: const [0, .55, 1]),
        border: Border.all(color: highlighted ? Colors.white : Colors.black26, width: highlighted ? 3 : 1),
        boxShadow: [if (highlighted) const BoxShadow(color: Colors.white70, blurRadius: 12) else const BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 2))],
      ),
      child: Stack(children: [Positioned(top: 12, left: 0, right: 0, child: Center(child: Container(width: 14, height: 7, decoration: BoxDecoration(color: Colors.white.withOpacity(.55), borderRadius: BorderRadius.circular(99)))))]),
    );
  }
}
