import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_components.dart';
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
    final deckCount = (state['draw'] as List?)?.length ?? 0;
    final currentColor = state['currentColor']?.toString() ?? '';
    final direction = (state['direction'] as num?)?.toInt() ?? 1;
    final pendingDraw = (state['pendingDraw'] as num?)?.toInt() ?? 0;
    final drawnIndex = (state['drawnCardIndex'] as num?)?.toInt();
    final awaitingColor = state['awaitingColor'] == true;
    final turnPlayerId = state['turnPlayerId']?.toString();
    final ownPlayers = match.players.where((player) => player['seat'] == seat).toList();
    final isTurn = match.status == 'active' && ownPlayers.isNotEmpty && turnPlayerId == ownPlayers.first['id'];
    final opponents = match.players.where((player) => player['seat'] != seat).toList();
    final canDraw = isTurn && !awaitingColor && pendingDraw == 0 && drawnIndex == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OpponentStrip(opponents: opponents, hands: hands, turnPlayerId: turnPlayerId),
        const SizedBox(height: 12),
        _TableArea(
          top: top,
          discardCount: discard.length,
          deckCount: deckCount,
          currentColor: currentColor,
          direction: direction,
          pendingDraw: pendingDraw,
          canDraw: canDraw,
          onDraw: () => onAction({'type': 'draw'}),
        ),
        const SizedBox(height: 12),
        _StatusLine(isTurn: isTurn, drawnIndex: drawnIndex, awaitingColor: awaitingColor, pendingDraw: pendingDraw, finished: match.status != 'active'),
        const SizedBox(height: 12),
        if (awaitingColor) ...[
          VibePrimaryButton(onPressed: isTurn ? () async { final color = await _chooseColor(context, opening: true); if (color != null) onAction({'type': 'choose_color', 'color': color}); } : null, icon: Icons.palette_outlined, label: 'Choose the opening color'),
        ] else if (pendingDraw > 0) ...[
          _PenaltyPanel(pendingDraw: pendingDraw, isTurn: isTurn, onDraw: () => onAction({'type': 'draw'}), onChallenge: () => onAction({'type': 'challenge'})),
        ] else ...[
          Row(children: [
            Text('Your hand', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: Text('${hand.length}', style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w900, fontSize: 12))),
            const Spacer(),
            if (drawnIndex != null) TextButton(onPressed: isTurn ? () => onAction({'type': 'pass'}) : null, child: const Text('Pass')),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 118,
            child: hand.isEmpty
                ? Center(child: Text('No cards', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: hand.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final card = Map<String, dynamic>.from(hand[index] as Map);
                      final playable = _canPlayCard(hand, index, currentColor, top, isTurn, drawnIndex);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        transform: Matrix4.translationValues(0, playable ? -6 : 0, 0),
                        child: _OchoCardTile(card: card, enabled: playable || !isTurn ? playable : false, highlight: drawnIndex == index, onTap: () => _playCard(context, index, card)),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(onPressed: canDraw ? () => onAction({'type': 'draw'}) : null, icon: const Icon(Icons.add_rounded), label: Text(drawnIndex == null ? 'Draw card' : 'Card drawn — play it or pass')),
          ),
        ],
      ],
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
    const colors = ['red', 'yellow', 'green', 'blue'];
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(opening ? 'Choose the opening color' : 'Choose a color', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [for (final color in colors) _ColorTile(color: color, onTap: () => Navigator.of(context).pop(color))],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFor(String color) => switch (color) {
        'red' => AppTheme.coral,
        'yellow' => AppTheme.gold,
        'green' => AppTheme.mint,
        _ => AppTheme.violet,
      };
}

class _OpponentStrip extends StatelessWidget {
  const _OpponentStrip({required this.opponents, required this.hands, required this.turnPlayerId});
  final List<Map<String, dynamic>> opponents;
  final List hands;
  final String? turnPlayerId;

  @override
  Widget build(BuildContext context) {
    if (opponents.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final player in opponents)
          Builder(builder: (context) {
            final seat = (player['seat'] as num?)?.toInt() ?? -1;
            final count = seat >= 0 && seat < hands.length ? (hands[seat] as List? ?? const []).length : 0;
            final active = turnPlayerId != null && player['id']?.toString() == turnPlayerId;
            final name = player['displayName']?.toString() ?? 'Player';
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppTheme.mint.withOpacity(.14) : Theme.of(context).colorScheme.surfaceVariant.withOpacity(.5),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: active ? AppTheme.mint : Colors.transparent, width: 1.6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VibeInitial(name: name, radius: 14),
                  const SizedBox(width: 7),
                  Text(name.length > 10 ? '${name.substring(0, 10)}…' : name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: count == 1 ? AppTheme.coral : AppTheme.violet.withOpacity(.15), borderRadius: BorderRadius.circular(99)),
                    child: Text(count == 1 ? 'OCHO!' : '$count', style: TextStyle(color: count == 1 ? Colors.white : AppTheme.violet, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _TableArea extends StatelessWidget {
  const _TableArea({required this.top, required this.discardCount, required this.deckCount, required this.currentColor, required this.direction, required this.pendingDraw, required this.canDraw, required this.onDraw});
  final Map<String, dynamic>? top;
  final int discardCount;
  final int deckCount;
  final String currentColor;
  final int direction;
  final int pendingDraw;
  final bool canDraw;
  final VoidCallback onDraw;

  Color _colorFor(String color) => switch (color) {
        'red' => AppTheme.coral,
        'yellow' => AppTheme.gold,
        'green' => AppTheme.mint,
        _ => AppTheme.violet,
      };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = _colorFor(currentColor);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: dark ? [const Color(0xFF1B2140), const Color(0xFF141936)] : [const Color(0xFFEFEAFF), const Color(0xFFE3F5EF)]),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(dark ? .3 : .14)),
        boxShadow: AppTheme.softShadow(dark: dark),
      ),
      child: Row(
        children: [
          PressableScale(
            onTap: canDraw ? onDraw : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Transform.translate(offset: const Offset(4, 5), child: _deckBack()),
                    _deckBack(),
                  ],
                ),
                const SizedBox(height: 8),
                Text('$deckCount left', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
                  child: top == null
                      ? Container(key: const ValueKey('empty'), width: 78, height: 108, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.4), style: BorderStyle.solid)), child: const Text('—'))
                      : _OchoCardTile(key: ValueKey('$discardCount-${top!['color']}-${top!['value']}'), card: top!, width: 78, height: 108, onTap: () {}),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(direction == -1 ? Icons.rotate_left_rounded : Icons.rotate_right_rounded, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(direction == -1 ? 'Reversed' : 'Clockwise', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, .15)!, color]), boxShadow: AppTheme.glow(color, strength: .45), border: Border.all(color: Colors.white.withOpacity(.35), width: 2)),
              ),
              const SizedBox(height: 7),
              Text(currentColor.isEmpty ? 'Any color' : currentColor, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              if (pendingDraw > 0) ...[
                const SizedBox(height: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(gradient: AppTheme.coralGradient, borderRadius: BorderRadius.circular(99)), child: Text('+$pendingDraw', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _deckBack() => Container(
        width: 62,
        height: 86,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.violetDeep, AppTheme.violet]), border: Border.all(color: Colors.white.withOpacity(.3), width: 1.5), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))]),
        child: const Center(child: Icon(Icons.style_rounded, color: Colors.white70, size: 26)),
      );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.isTurn, required this.drawnIndex, required this.awaitingColor, required this.pendingDraw, required this.finished});
  final bool isTurn;
  final int? drawnIndex;
  final bool awaitingColor;
  final int pendingDraw;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final text = finished
        ? 'Match finished'
        : awaitingColor
            ? 'Choose the opening color to begin.'
            : pendingDraw > 0
                ? 'Penalty pending — draw or challenge.'
                : isTurn
                    ? (drawnIndex == null ? 'Your turn — play a matching card or draw.' : 'You drew a card — play it or pass.')
                    : 'Waiting for the other players…';
    final color = finished ? AppTheme.gold : isTurn ? AppTheme.mint : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 8)])),
      const SizedBox(width: 9),
      Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isTurn && !finished ? null : Theme.of(context).colorScheme.onSurfaceVariant))),
    ]);
  }
}

class _PenaltyPanel extends StatelessWidget {
  const _PenaltyPanel({required this.pendingDraw, required this.isTurn, required this.onDraw, required this.onChallenge});
  final int pendingDraw;
  final bool isTurn;
  final VoidCallback onDraw;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.coral.withOpacity(.2), AppTheme.coral.withOpacity(.08)]), border: Border.all(color: AppTheme.coral.withOpacity(.4))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppTheme.coralGradient, shape: BoxShape.circle, boxShadow: AppTheme.glow(AppTheme.coral, strength: .4)), child: Text('+$pendingDraw', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
              const SizedBox(width: 12),
              Expanded(child: Text(pendingDraw == 4 ? 'Draw four cards or challenge the Wild Draw Four.' : 'Draw $pendingDraw cards.', style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: isTurn ? onDraw : null, icon: const Icon(Icons.download_rounded), label: Text('Draw $pendingDraw'))),
              if (pendingDraw == 4) ...[
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: isTurn ? onChallenge : null, icon: const Icon(Icons.gavel_rounded), label: const Text('Challenge'))),
              ],
            ]),
          ],
        ),
      );
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.color, required this.onTap});
  final String color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = switch (color) {'red' => AppTheme.coral, 'yellow' => AppTheme.gold, 'green' => AppTheme.mint, _ => AppTheme.violet};
    return PressableScale(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(base, Colors.white, .12)!, base, Color.lerp(base, Colors.black, .18)!]), borderRadius: BorderRadius.circular(18), boxShadow: AppTheme.glow(base, strength: .35)),
        child: Text(color.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      ),
    );
  }
}

class _OchoCardTile extends StatelessWidget {
  const _OchoCardTile({super.key, required this.card, required this.onTap, this.enabled = true, this.highlight = false, this.width = 68, this.height = 96});

  final Map<String, dynamic> card;
  final VoidCallback onTap;
  final bool enabled;
  final bool highlight;
  final double width;
  final double height;

  String _label(String value) => switch (value) {'skip' => 'SKIP', 'reverse' => 'REV', 'draw2' => '+2', 'wild' => 'WILD', 'wild4' => '+4', _ => value};

  @override
  Widget build(BuildContext context) {
    final isWild = card['color'] == 'wild';
    final color = switch (card['color']) {'red' => AppTheme.coral, 'yellow' => AppTheme.gold, 'green' => AppTheme.mint, _ => AppTheme.violet};
    final label = _label('${card['value']}');
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isWild ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2B2F45), Color(0xFF171A2C)]) : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, .18)!, color, Color.lerp(color, Colors.black, .24)!], stops: const [0, .55, 1]),
            border: highlight ? Border.all(color: AppTheme.gold, width: 2.5) : Border.all(color: Colors.white.withOpacity(.25), width: 1.2),
            boxShadow: [if (enabled) BoxShadow(color: color.withOpacity(.4), blurRadius: 12, offset: const Offset(0, 5)) else const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 3))],
          ),
          child: Stack(
            children: [
              Positioned(top: 7, left: 9, child: Text(label, style: TextStyle(color: Colors.white.withOpacity(.9), fontSize: 10, fontWeight: FontWeight.w900))),
              Center(
                child: isWild
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [_pip(AppTheme.coral), const SizedBox(width: 3), _pip(AppTheme.gold)]),
                          const SizedBox(height: 3),
                          Row(mainAxisSize: MainAxisSize.min, children: [_pip(AppTheme.mint), const SizedBox(width: 3), _pip(AppTheme.violet)]),
                          const SizedBox(height: 6),
                          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                        ],
                      )
                    : Container(
                        width: width * .52,
                        height: height * .42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(.22), borderRadius: BorderRadius.circular(12)),
                        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: label.length <= 2 ? 21 : 11, fontWeight: FontWeight.w900)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pip(Color color) => Container(width: 15, height: 15, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)));
}
