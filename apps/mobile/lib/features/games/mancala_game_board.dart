import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class MancalaGameBoard extends StatelessWidget {
  const MancalaGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  List<int> _row(dynamic value) {
    final list = value is List ? value : const [];
    return List.generate(6, (i) => i < list.length ? (list[i] as num?)?.toInt() ?? 0 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final seat = match.viewerSeat;
    final pits = state['pits'] as List? ?? const [];
    final mine = _row(seat < pits.length ? pits[seat] : const []);
    final theirs = _row(1 - seat >= 0 && 1 - seat < pits.length ? pits[1 - seat] : const []);
    final stores = state['stores'] as List? ?? const [0, 0];
    final myStore = seat < stores.length ? (stores[seat] as num?)?.toInt() ?? 0 : 0;
    final theirStore = 1 - seat < stores.length ? (stores[1 - seat] as num?)?.toInt() ?? 0 : 0;
    final viewer = match.players.where((player) => player['seat'] == seat).toList();
    final isTurn = match.status == 'active' && viewer.isNotEmpty && state['turnPlayerId'] == viewer.first['id'];
    final finished = match.status == 'finished' || state['finished'] == true;
    final foeName = match.players.where((player) => player['seat'] != seat).map((p) => p['displayName']?.toString() ?? 'Opponent').toList();
    final status = finished
        ? 'Match complete'
        : isTurn
            ? 'Your turn — pick one of your pits.'
            : 'Waiting for ${foeName.isEmpty ? 'the other player' : foeName.first}…';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.circle_rounded, color: AppTheme.gold),
            const SizedBox(width: 8),
            const Text('Mancala', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            Text('$myStore · $theirStore', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 7),
          Align(alignment: Alignment.centerLeft, child: Text(status, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFB5651D).withOpacity(.12), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              _Store(count: theirStore, label: 'Foe'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(children: [
                  Row(children: [for (var i = 5; i >= 0; i -= 1) Expanded(child: _Pit(count: theirs[i], enabled: false, mine: false))]),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (var i = 0; i < 6; i += 1)
                      Expanded(child: _Pit(count: mine[i], enabled: isTurn && !finished && mine[i] > 0, mine: true, onTap: () => onAction({'type': 'sow', 'pit': i}))),
                  ]),
                ]),
              ),
              const SizedBox(width: 10),
              _Store(count: myStore, label: 'You'),
            ]),
          ),
          const SizedBox(height: 10),
          Text('Sow stones around the board — landing your last stone in your store earns another turn.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _Pit extends StatelessWidget {
  const _Pit({required this.count, required this.enabled, required this.mine, this.onTap});
  final int count;
  final bool enabled;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = mine ? AppTheme.violet : const Color(0xFFB5651D);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? color.withOpacity(.22) : color.withOpacity(mine ? .1 : .14),
            shape: BoxShape.circle,
            border: enabled ? Border.all(color: color, width: 2) : null,
          ),
          child: Text('$count', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: enabled || count > 0 ? color : Theme.of(context).disabledColor)),
        ),
      ),
    );
  }
}

class _Store extends StatelessWidget {
  const _Store({required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.18), borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.gold.withOpacity(.5))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.gold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.gold)),
        ]),
      );
}
