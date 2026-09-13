import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class OchoGameBoard extends StatelessWidget {
  const OchoGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  Widget build(BuildContext context) {
    final hands = state['hands'] as List? ?? const [];
    final seat = match.viewerSeat;
    final hand = seat >= 0 && seat < hands.length ? hands[seat] as List? ?? const [] : const [];
    final discard = state['discard'] as List? ?? const [];
    final top = discard.isEmpty ? null : Map<String, dynamic>.from(discard.last as Map);
    final currentColor = state['currentColor']?.toString() ?? '';
    final pendingDraw = (state['pendingDraw'] as num?)?.toInt() ?? 0;
    final drawnIndex = (state['drawnCardIndex'] as num?)?.toInt();
    final awaitingColor = state['awaitingColor'] == true;
    final ownPlayers = match.players.where((player) => player['seat'] == seat).toList();
    final isTurn = match.status == 'active' && ownPlayers.isNotEmpty && state['turnPlayerId'] == ownPlayers.first['id'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.style_rounded, color: AppTheme.violet),
            const SizedBox(width: 8),
            const Text('Ocho', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            Text('${hand.length} cards', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Top discard', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              top == null ? const Text('—') : _OchoCardTile(card: top, onTap: () {}),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Current color', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              if (currentColor.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(width: 18, height: 18, decoration: BoxDecoration(color: _colorFor(currentColor), shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Text(currentColor, style: const TextStyle(fontWeight: FontWeight.w800)),
              ]) else const Text('Choose a color'),
            ])),
          ]),
          const SizedBox(height: 16),
          if (awaitingColor) ...[
            const Text('Choose the opening color', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            FilledButton.icon(onPressed: isTurn ? () async { final color = await _chooseColor(context, opening: true); if (color != null) onAction({'type': 'choose_color', 'color': color}); } : null, icon: const Icon(Icons.palette_outlined), label: const Text('Choose color')),
          ] else if (pendingDraw > 0) ...[
            Text(pendingDraw == 4 ? 'Draw four cards or challenge the Wild Draw Four.' : 'Draw $pendingDraw cards.', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            Row(children: [
              FilledButton.icon(onPressed: isTurn ? () => onAction({'type': 'draw'}) : null, icon: const Icon(Icons.download_rounded), label: Text('Draw $pendingDraw')),
              if (pendingDraw == 4) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: isTurn ? () => onAction({'type': 'challenge'}) : null, icon: const Icon(Icons.gavel_rounded), label: const Text('Challenge')),
              ],
            ]),
          ] else ...[
            Text(isTurn ? (drawnIndex == null ? 'Play a matching card or draw.' : 'You may play the card you drew.') : 'Waiting for the other players…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var index = 0; index < hand.length; index += 1)
                _OchoCardTile(
                  card: Map<String, dynamic>.from(hand[index] as Map),
                  enabled: _canPlayCard(hand, index, currentColor, top, isTurn, drawnIndex),
                  onTap: () => _playCard(context, index, Map<String, dynamic>.from(hand[index] as Map)),
                ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              OutlinedButton.icon(onPressed: isTurn && drawnIndex == null ? () => onAction({'type': 'draw'}) : null, icon: const Icon(Icons.add_rounded), label: const Text('Draw card')),
              if (drawnIndex != null) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: isTurn ? () => onAction({'type': 'pass'}) : null, child: const Text('Pass')),
              ],
            ]),
          ],
        ]),
      ),
    );
  }

  bool _canPlayCard(List hand, int index, String currentColor, Map<String, dynamic>? top, bool isTurn, int? drawnIndex) {
    if (!isTurn || (drawnIndex != null && drawnIndex != index)) return false;
    final card = Map<String, dynamic>.from(hand[index] as Map);
    return card['color'] == 'wild' || card['color'] == currentColor || card['value'] == top?['value'];
  }

  Future<void> _playCard(BuildContext context, int index, Map<String, dynamic> card) async {
    final hands = state['hands'] as List? ?? const [];
    final seat = match.viewerSeat;
    final hand = seat >= 0 && seat < hands.length ? hands[seat] as List? ?? const [] : const [];
    var callOcho = true;
    if (hand.length == 2) {
      final decision = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Call Ocho?'),
          content: const Text('You will have one card after this play. Call Ocho to avoid the two-card penalty.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Play without calling')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Call Ocho')),
          ],
        ),
      );
      if (decision == null) return;
      callOcho = decision;
    }
    String? color;
    if (card['color'] == 'wild') color = await _chooseColor(context);
    if (card['color'] == 'wild' && color == null) return;
    final action = <String, dynamic>{'type': 'play', 'index': index, 'call': callOcho};
    if (color != null) action['color'] = color;
    onAction(action);
  }

  Future<String?> _chooseColor(BuildContext context, {bool opening = false}) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(opening ? 'Choose the opening color' : 'Choose a color', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 12),
        for (final color in const ['red', 'yellow', 'green', 'blue'])
          ListTile(leading: CircleAvatar(backgroundColor: _colorFor(color)), title: Text(color, style: const TextStyle(fontWeight: FontWeight.w800)), onTap: () => Navigator.of(context).pop(color)),
      ]))),
    );
  }

  Color _colorFor(String color) => switch (color) {
    'red' => AppTheme.coral,
    'yellow' => AppTheme.gold,
    'green' => AppTheme.mint,
    _ => AppTheme.violet,
  };
}

class _OchoCardTile extends StatelessWidget {
  const _OchoCardTile({required this.card, required this.onTap, this.enabled = true});

  final Map<String, dynamic> card;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = switch (card['color']) {
      'red' => AppTheme.coral,
      'yellow' => AppTheme.gold,
      'green' => AppTheme.mint,
      _ => AppTheme.violet,
    };
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 52,
          height: 72,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 3))]),
          child: Center(child: Text('${card['value']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
        ),
      ),
    );
  }
}
