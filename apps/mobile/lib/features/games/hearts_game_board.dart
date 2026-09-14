import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

/// Shared board for Hearts and Spades — both use the trick-taking protocol
/// ({hands, trick, leadSuit, scores, targetScore}, {type: 'play', index}).
class HeartsGameBoard extends StatelessWidget {
  const HeartsGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  bool get _isHearts => match.gameId != 'spades';

  String _playerName(int side) {
    final found = match.players.where((player) => player['seat'] == side).toList();
    return found.isEmpty ? 'Player ${side + 1}' : found.first['displayName']?.toString() ?? 'Player ${side + 1}';
  }

  String _turnName() {
    final found = match.players.where((player) => player['id'] == state['turnPlayerId']).toList();
    return found.isEmpty ? 'the other player' : found.first['displayName']?.toString() ?? 'the other player';
  }

  int _trickPoints(List trick) {
    var total = 0;
    for (final entry in trick) {
      final card = entry is Map ? entry['card'] : null;
      if (card is! Map) continue;
      if (card['suit'] == 'H') total += 1;
      if (card['suit'] == 'S' && (card['rank'] as num?)?.toInt() == 12) total += 13;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final hands = state['hands'] as List? ?? const [];
    final seat = match.viewerSeat;
    final mine = seat < hands.length && hands[seat] is List ? hands[seat] as List : const [];
    final trick = state['trick'] as List? ?? const [];
    final scores = state['scores'] as List? ?? const [];
    final leadSuit = state['leadSuit']?.toString();
    final target = (state['targetScore'] as num?)?.toInt() ?? (_isHearts ? 100 : 500);
    final viewer = match.players.where((player) => player['seat'] == seat).toList();
    final isTurn = match.status == 'active' && viewer.isNotEmpty && state['turnPlayerId'] == viewer.first['id'];
    final finished = match.status == 'finished' || state['finished'] == true;
    final hasLead = leadSuit != null && mine.any((card) => card is Map && card['suit'] == leadSuit);
    final mustFollow = leadSuit != null && hasLead;
    final points = _isHearts ? _trickPoints(trick) : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_isHearts ? Icons.favorite_rounded : Icons.style_rounded, color: _isHearts ? AppTheme.coral : AppTheme.violet),
            const SizedBox(width: 8),
            Text(_isHearts ? 'Hearts' : 'Spades', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            Text('Target $target', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < match.players.length; i++)
                _ScoreChip(
                  name: _playerName(i),
                  score: i < scores.length ? '${scores[i]}' : '0',
                  mine: i == seat,
                  turn: !finished && state['turnPlayerId'] == match.players[i]['id'],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            finished ? 'Match complete' : isTurn ? (mustFollow ? 'Your turn — follow ${_suitName(leadSuit!)}.' : 'Your turn — play a card.') : 'Waiting for ${_turnName()}…',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
          if (trick.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.08), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('On the table', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  if (_isHearts && points > 0) Text('worth $points pts', style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final entry in trick) _TrickCard(entry: entry is Map ? entry : const {}, name: entry is Map ? _playerName((entry['player'] as num?)?.toInt() ?? -1) : '')],
                ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          if (mine.isEmpty)
            Text(finished ? 'No cards left.' : 'Your hand is hidden until the deal reaches you.', style: Theme.of(context).textTheme.bodySmall)
          else ...[
            const Text('Your hand', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < mine.length; i += 1)
                  Builder(builder: (context) {
                    final card = mine[i] is Map ? mine[i] as Map : const {};
                    final playable = isTurn && !finished && (!mustFollow || card['suit'] == leadSuit);
                    return _HandCard(card: card, enabled: playable, onTap: () => onAction({'type': 'play', 'index': i}));
                  }),
              ],
            ),
          ],
          if (_isHearts) ...[
            const SizedBox(height: 10),
            Text('Avoid hearts and the Q♠ — lowest score wins.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }

  String _suitName(String suit) => switch (suit) { 'H' => 'hearts ♥', 'D' => 'diamonds ♦', 'S' => 'spades ♠', 'C' => 'clubs ♣', _ => 'suit' };
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.name, required this.score, required this.mine, required this.turn});
  final String name;
  final String score;
  final bool mine;
  final bool turn;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: turn ? AppTheme.mint.withOpacity(.2) : Theme.of(context).colorScheme.surfaceVariant.withOpacity(.6),
          borderRadius: BorderRadius.circular(99),
          border: turn ? Border.all(color: AppTheme.mint) : null,
        ),
        child: Text('$name · $score${mine ? ' (you)' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

class _TrickCard extends StatelessWidget {
  const _TrickCard({required this.entry, required this.name});
  final Map entry;
  final String name;

  @override
  Widget build(BuildContext context) {
    final card = entry['card'];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _HandCard(card: card is Map ? card : const {}, enabled: false, onTap: null),
      const SizedBox(height: 3),
      SizedBox(width: 64, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({required this.card, required this.enabled, required this.onTap});
  final Map card;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final suit = card['suit']?.toString() ?? '';
    final rank = (card['rank'] as num?)?.toInt() ?? 0;
    final face = switch (rank) { 11 => 'J', 12 => 'Q', 13 => 'K', 14 => 'A', _ => '$rank' };
    final pip = switch (suit) { 'H' => '♥', 'D' => '♦', 'S' => '♠', 'C' => '♣', _ => '·' };
    final red = suit == 'H' || suit == 'D';
    final color = red ? AppTheme.coral : Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(enabled ? .16 : .06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(enabled ? .7 : .25), width: enabled ? 2 : 1),
        ),
        child: Text('$face$pip', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: enabled || onTap == null ? color : Theme.of(context).disabledColor)),
      ),
    );
  }
}
