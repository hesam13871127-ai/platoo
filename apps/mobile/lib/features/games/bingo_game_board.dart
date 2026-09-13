import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class BingoGameBoard extends StatelessWidget {
  const BingoGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  Widget build(BuildContext context) {
    final cards = state['cards'] as List? ?? const [];
    final card = match.viewerSeat < cards.length && cards[match.viewerSeat] is Map ? Map<String, dynamic>.from(cards[match.viewerSeat] as Map) : <String, dynamic>{};
    final values = (card['values'] as List? ?? const []).map((value) => (value as num?)?.toInt() ?? 0).toList();
    final marked = (card['marked'] as List? ?? const []).map((value) => value == true).toList();
    final called = (state['called'] as List? ?? const []).map((value) => (value as num?)?.toInt() ?? 0).toList();
    final lastNumber = (state['lastNumber'] as num?)?.toInt();
    final viewer = match.players.where((player) => player['seat'] == match.viewerSeat).toList();
    final isTurn = match.status == 'active' && viewer.isNotEmpty && state['turnPlayerId'] == viewer.first['id'];
    final finished = state['finished'] == true || match.status == 'finished';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppTheme.coral.withOpacity(.13), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.grid_on_rounded, color: AppTheme.coral)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Bingo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            if (lastNumber != null) _NumberBadge(number: lastNumber),
          ]),
          const SizedBox(height: 12),
          Text(finished ? 'The cage is closed. Check the result above.' : isTurn ? 'Your turn · draw the next number.' : 'Numbers are marked automatically as they are called.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 13),
          _BingoCard(values: values, marked: marked),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: isTurn && !finished ? () => onAction({'type': 'draw'}) : null, icon: const Icon(Icons.casino_rounded), label: Text(isTurn ? 'Draw number' : 'Waiting for turn'))),
            const SizedBox(width: 10),
            Text('${called.length} / 75', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          if (called.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Called numbers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 7),
            SizedBox(height: 30, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: called.length, separatorBuilder: (_, __) => const SizedBox(width: 5), itemBuilder: (_, index) => _CalledNumber(number: called[index], current: index == called.length - 1))),
          ],
        ]),
      ),
    );
  }
}

class _BingoCard extends StatelessWidget {
  const _BingoCard({required this.values, required this.marked});
  final List<int> values;
  final List<bool> marked;

  @override
  Widget build(BuildContext context) {
    const headings = ['B', 'I', 'N', 'G', 'O'];
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFFFEFBF7), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.coral.withOpacity(.22))),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Column(children: [
          Row(children: headings.map((heading) => Expanded(child: Center(child: Text(heading, style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w900))))).toList()),
          const SizedBox(height: 4),
          AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 25,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 5, mainAxisSpacing: 5),
              itemBuilder: (_, index) {
                final isMarked = index < marked.length && marked[index];
                final value = index < values.length ? values[index] : 0;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(color: isMarked ? AppTheme.coral : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: isMarked ? AppTheme.coral : const Color(0xFFE8DCD2))),
                  child: Center(child: value == 0 ? const Icon(Icons.auto_awesome_rounded, size: 17, color: Colors.white) : Text('$value', style: TextStyle(fontWeight: FontWeight.w900, color: isMarked ? Colors.white : const Color(0xFF332A35), fontSize: 15))),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number});
  final int number;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: AppTheme.coral, borderRadius: BorderRadius.circular(13)), child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)));
}

class _CalledNumber extends StatelessWidget {
  const _CalledNumber({required this.number, required this.current});
  final int number;
  final bool current;
  @override
  Widget build(BuildContext context) => Container(width: 29, alignment: Alignment.center, decoration: BoxDecoration(color: current ? AppTheme.coral : Theme.of(context).colorScheme.surface, shape: BoxShape.circle, border: Border.all(color: current ? AppTheme.coral : Theme.of(context).dividerColor)), child: Text('$number', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: current ? Colors.white : null)));
}
