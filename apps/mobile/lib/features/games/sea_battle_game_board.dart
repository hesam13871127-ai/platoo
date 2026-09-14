import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

const _shipSizes = [5, 4, 3, 3, 2];

class SeaBattleGameBoard extends StatefulWidget {
  const SeaBattleGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<SeaBattleGameBoard> createState() => _SeaBattleGameBoardState();
}

class _SeaBattleGameBoardState extends State<SeaBattleGameBoard> {
  final picked = <int>{};

  @override
  void didUpdateWidget(covariant SeaBattleGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) picked.clear();
  }

  List<List<int>> _grid(dynamic value) {
    final raw = value is List ? value : const [];
    return List.generate(10, (r) {
      final row = r < raw.length && raw[r] is List ? raw[r] as List : const [];
      return List.generate(10, (c) => c < row.length ? (row[c] as num?)?.toInt() ?? 0 : 0);
    });
  }

  bool get _placing => widget.state['phase'] == 'placing';

  bool get _isTurn {
    final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    return widget.match.status == 'active' && viewer.isNotEmpty && widget.state['turnPlayerId'] == viewer.first['id'];
  }

  int get _placed {
    final fleets = widget.state['fleets'] as List? ?? const [];
    final seat = widget.match.viewerSeat;
    if (seat >= fleets.length || fleets[seat] is! List) return 0;
    return (fleets[seat] as List).length;
  }

  bool _validShip(Set<int> cells, int size) {
    if (cells.length != size) return false;
    final rows = cells.map((i) => i ~/ 10).toSet();
    final cols = cells.map((i) => i % 10).toSet();
    if (rows.length == 1) {
      final sorted = cols.toList()..sort();
      return sorted.last - sorted.first == size - 1;
    }
    if (cols.length == 1) {
      final sorted = rows.toList()..sort();
      return sorted.last - sorted.first == size - 1;
    }
    return false;
  }

  void _autoPlace(List<List<int>> board, int size) {
    final random = Random();
    for (var attempt = 0; attempt < 300; attempt += 1) {
      final horizontal = random.nextBool();
      final r = random.nextInt(10);
      final c = random.nextInt(10);
      final cells = <int>[];
      var fits = true;
      for (var i = 0; i < size; i += 1) {
        final rr = horizontal ? r : r + i;
        final cc = horizontal ? c + i : c;
        if (rr > 9 || cc > 9 || board[rr][cc] != 0) {
          fits = false;
          break;
        }
        cells.add(rr * 10 + cc);
      }
      if (fits) {
        setState(() {
          picked
            ..clear()
            ..addAll(cells);
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => _placing ? _buildPlacing(context) : _buildBattle(context);

  Widget _buildPlacing(BuildContext context) {
    final seat = widget.match.viewerSeat;
    final boards = widget.state['boards'] as List? ?? const [];
    final board = _grid(seat < boards.length ? boards[seat] : const []);
    final fleets = widget.state['fleets'] as List? ?? const [];
    final foeShips = 1 - seat >= 0 && 1 - seat < fleets.length && fleets[1 - seat] is List ? (fleets[1 - seat] as List).length : 0;
    final active = widget.match.status == 'active';
    final done = _placed >= _shipSizes.length;
    final size = done ? 0 : _shipSizes[_placed];
    final valid = !done && _validShip(picked, size);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.directions_boat_rounded, color: AppTheme.violet),
            const SizedBox(width: 8),
            const Text('Sea Battle', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            Text('Fleet ${_placed.clamp(0, 5)}/5', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              done ? 'Fleet ready — waiting for the enemy…' : 'Place ship ${_placed + 1} of 5 · $size cells in a straight line.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 2, mainAxisSpacing: 2),
                itemCount: 100,
                itemBuilder: (_, index) {
                  final r = index ~/ 10;
                  final c = index % 10;
                  final ship = board[r][c] != 0;
                  final isPicked = picked.contains(index);
                  return InkWell(
                    onTap: !active || done || ship
                        ? null
                        : () => setState(() {
                              if (!isPicked && picked.length >= size) return;
                              isPicked ? picked.remove(index) : picked.add(index);
                            }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isPicked
                            ? AppTheme.mint
                            : ship
                                ? AppTheme.violet
                                : const Color(0xFF58B7D2).withOpacity(.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!done) ...[
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: !active ? null : () => _autoPlace(board, size), icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Auto'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: !active || picked.isEmpty ? null : () => setState(picked.clear), icon: const Icon(Icons.clear_rounded), label: const Text('Clear'))),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: !active || !valid
                      ? null
                      : () => widget.onAction({
                            'type': 'place',
                            'cells': picked.map((i) => [i ~/ 10, i % 10]).toList(),
                          }),
                  icon: const Icon(Icons.anchor_rounded),
                  label: const Text('Place'),
                ),
              ),
            ]),
          ] else
            Text('Enemy fleet: $foeShips/5 ships placed.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }

  Widget _buildBattle(BuildContext context) {
    final seat = widget.match.viewerSeat;
    final shotsRaw = widget.state['shots'] as List? ?? const [];
    final shots = _grid(seat < shotsRaw.length ? shotsRaw[seat] : const []);
    final boards = widget.state['boards'] as List? ?? const [];
    final mine = _grid(seat < boards.length ? boards[seat] : const []);
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    var hits = 0;
    var misses = 0;
    for (final row in shots) {
      for (final cell in row) {
        if (cell == 1) hits += 1;
        if (cell == 0) misses += 1;
      }
    }
    final foeName = widget.match.players.where((player) => player['seat'] != seat).map((p) => p['displayName']?.toString() ?? 'Enemy').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.directions_boat_rounded, color: AppTheme.violet),
            const SizedBox(width: 8),
            const Text('Sea Battle', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            Text('🔥 $hits · ○ $misses', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              finished ? 'Battle over' : _isTurn ? 'Your turn — tap enemy waters to fire.' : 'Waiting for ${foeName.isEmpty ? 'the enemy' : foeName.first}…',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 2, mainAxisSpacing: 2),
                itemCount: 100,
                itemBuilder: (_, index) {
                  final r = index ~/ 10;
                  final c = index % 10;
                  final value = shots[r][c];
                  final canFire = _isTurn && !finished && value == -1;
                  return InkWell(
                    onTap: canFire ? () => widget.onAction({'type': 'fire', 'row': r, 'column': c}) : null,
                    child: Container(
                      decoration: BoxDecoration(color: value == 1 ? AppTheme.coral : const Color(0xFF1882A5).withOpacity(value == -1 ? .35 : .6), borderRadius: BorderRadius.circular(4)),
                      child: Center(
                        child: value == 1
                            ? const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 15)
                            : value == 0
                                ? Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                                : canFire
                                    ? const Icon(Icons.add_rounded, color: Colors.white70, size: 13)
                                    : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Your fleet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const Spacer(),
            Text('grey = ship · red = hit', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 2, mainAxisSpacing: 2),
                itemCount: 100,
                itemBuilder: (_, index) {
                  final value = mine[index ~/ 10][index % 10];
                  return Container(
                    decoration: BoxDecoration(
                      color: value < 0 ? AppTheme.coral : value > 0 ? AppTheme.violet.withOpacity(.75) : const Color(0xFF58B7D2).withOpacity(.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
