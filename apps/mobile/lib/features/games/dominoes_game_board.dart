import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_components.dart';
import '../../models/models.dart';

class DominoesGameBoard extends StatefulWidget {
  const DominoesGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<DominoesGameBoard> createState() => _DominoesGameBoardState();
}

class _DominoesGameBoardState extends State<DominoesGameBoard> {
  int? selectedIndex;
  int? _knownCount;
  Set<int> _fresh = <int>{};

  @override
  void didUpdateWidget(covariant DominoesGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) {
      selectedIndex = null;
      final length = _handOf(widget.state).length;
      final known = _knownCount ?? length;
      _fresh = length > known ? {for (var index = known; index < length; index += 1) index} : <int>{};
      _knownCount = length;
    }
  }

  List<List<int>> _handOf(Map<String, dynamic> state) {
    final hands = state['hands'] as List? ?? const [];
    if (widget.match.viewerSeat >= hands.length) return <List<int>>[];
    return _tiles(hands[widget.match.viewerSeat]);
  }

  @override
  Widget build(BuildContext context) {
    final chain = _numbers(widget.state['chain']);
    final hand = _handOf(widget.state);
    _knownCount ??= hand.length;
    final handSizes = _numbers(widget.state['handSizes']);
    final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    final isTurn = widget.match.status == 'active' && viewer.isNotEmpty && widget.state['turnPlayerId'] == viewer.first['id'];
    final legal = isTurn ? hand.asMap().entries.where((entry) => _matches(entry.value, chain)).map((entry) => entry.key).toSet() : <int>{};
    final boneyardCount = (widget.state['boneyard'] as List?)?.length ?? 0;
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final canDraw = isTurn && legal.isEmpty && boneyardCount > 0 && !finished;
    final canPass = isTurn && legal.isEmpty && boneyardCount == 0 && !finished;
    final selected = selectedIndex != null && selectedIndex! < hand.length ? hand[selectedIndex!] : null;
    final leftOpen = selected != null && chain.isNotEmpty && selected.contains(chain.first);
    final rightOpen = selected != null && chain.isNotEmpty && selected.contains(chain.last);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppTheme.oceanGradient, borderRadius: BorderRadius.circular(13), boxShadow: AppTheme.glow(AppTheme.violet, strength: .35)), child: const Icon(Icons.view_carousel_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          VibeText('Dominoes', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          _StatPill(icon: Icons.layers_rounded, label: '$boneyardCount draw'),
        ]),
        const SizedBox(height: 8),
        _StatusDot(text: _status(isTurn, legal, canDraw, finished), active: isTurn, finished: finished),
        const SizedBox(height: 11),
        _ChainView(chain: chain),
        const SizedBox(height: 11),
        _OpponentCounts(match: widget.match, handSizes: handSizes, viewerSeat: widget.match.viewerSeat, turnPlayerId: widget.state['turnPlayerId']?.toString()),
        const SizedBox(height: 13),
        Row(children: [
          VibeText('Your hand', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (selected != null) VibeText('${selected[0]}–${selected[1]}', style: const TextStyle(color: AppTheme.violet, fontSize: 13, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        if (hand.isEmpty)
          VibeText('Your dominoes are hidden until the table syncs.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          _HandView(hand: hand, legal: legal, fresh: _fresh, selectedIndex: selectedIndex, enabled: isTurn && !finished, onSelect: (index) => setState(() => selectedIndex = selectedIndex == index ? null : index)),
        const SizedBox(height: 12),
        if (selected != null && isTurn && !finished) ...[
          if (leftOpen && rightOpen)
            Row(children: [
              Expanded(child: _PlaceButton(label: 'Place left', icon: Icons.arrow_back_rounded, onTap: () => _place('left'))),
              const SizedBox(width: 8),
              Expanded(child: _PlaceButton(label: 'Place right', icon: Icons.arrow_forward_rounded, onTap: () => _place('right'))),
            ])
          else if (leftOpen)
            VibePrimaryButton(onPressed: () => _place('left'), icon: Icons.arrow_back_rounded, label: 'Place on the left')
          else if (rightOpen)
            VibePrimaryButton(onPressed: () => _place('right'), icon: Icons.arrow_forward_rounded, label: 'Place on the right'),
        ] else if (canDraw)
          VibePrimaryButton(onPressed: () => widget.onAction({'type': 'draw'}), icon: Icons.add_rounded, label: 'Draw a tile')
        else if (canPass)
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => widget.onAction({'type': 'pass'}), icon: const Icon(Icons.skip_next_rounded), label: const VibeText('Pass · block the round')))
        else if (!isTurn && !finished)
          VibeText('Waiting for the active player…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  void _place(String side) {
    final index = selectedIndex;
    if (index == null) return;
    widget.onAction({'type': 'play', 'index': index, 'side': side});
  }

  String _status(bool isTurn, Set<int> legal, bool canDraw, bool finished) {
    if (finished) {
      final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
      final viewerId = viewer.isEmpty ? null : viewer.first['id']?.toString();
      if (widget.match.draw) return 'Blocked round · tied lowest pips.';
      return widget.match.winnerIds.contains(viewerId) ? 'You took the round!' : 'The chain is complete.';
    }
    if (!isTurn) return 'Watch the chain and plan your next tile.';
    if (legal.isNotEmpty) return 'Your turn · choose a glowing tile.';
    if (canDraw) return 'No match · draw until you can play.';
    return 'No match · pass to block the round.';
  }

  List<List<int>> _tiles(dynamic value) => (value as List? ?? const []).whereType<List>().map((tile) => _numbers(tile)).where((tile) => tile.length == 2).toList();
  List<int> _numbers(dynamic value) => (value as List? ?? const []).whereType<num>().map((number) => number.toInt()).toList();
  bool _matches(List<int> tile, List<int> chain) => tile.length == 2 && chain.isNotEmpty && (tile.contains(chain.first) || tile.contains(chain.last));
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.text, required this.active, required this.finished});
  final String text;
  final bool active;
  final bool finished;
  @override
  Widget build(BuildContext context) {
    final color = finished ? AppTheme.gold : active ? AppTheme.violet : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 8)])), const SizedBox(width: 9), Expanded(child: VibeText(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: active && !finished ? null : Theme.of(context).colorScheme.onSurfaceVariant)))]);
  }
}

class _ChainView extends StatelessWidget {
  const _ChainView({required this.chain});
  final List<int> chain;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: dark ? const Color(0xFF23202E) : const Color(0xFFF5F1FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.violet.withOpacity(.25))),
      child: chain.length < 2
          ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 18), child: VibeText('The opening tile will appear here')))
          : Column(
              children: [
                Row(children: [
                  _EndBadge(value: chain.first, label: 'left'),
                  const Spacer(),
                  VibeText('${chain.length - 1} tiles', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  _EndBadge(value: chain.last, label: 'right'),
                ]),
                const SizedBox(height: 9),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (var index = 0; index < chain.length - 1; index += 1) ...[
                      _DominoTile(first: chain[index], second: chain[index + 1], compact: true),
                      if (index < chain.length - 2) const SizedBox(width: 4),
                    ],
                  ]),
                ),
              ],
            ),
    );
  }
}

class _EndBadge extends StatelessWidget {
  const _EndBadge({required this.value, required this.label});
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.14), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppTheme.violet.withOpacity(.35))),
        child: VibeText('$label · $value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.violet)),
      );
}

class _HandView extends StatelessWidget {
  const _HandView({required this.hand, required this.legal, required this.fresh, required this.selectedIndex, required this.enabled, required this.onSelect});
  final List<List<int>> hand;
  final Set<int> legal;
  final Set<int> fresh;
  final int? selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: hand.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final playable = enabled && legal.contains(index);
            final selected = selectedIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              transform: Matrix4.translationValues(0, selected ? -7 : 0, 0),
              child: PressableScale(
                onTap: playable ? () => onSelect(index) : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _DominoTile(first: hand[index][0], second: hand[index][1], selected: selected, enabled: playable, glow: enabled && legal.contains(index)),
                    if (fresh.contains(index)) Positioned(top: -7, right: -5, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]), child: const VibeText('new', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)))),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _DominoTile extends StatelessWidget {
  const _DominoTile({required this.first, required this.second, this.selected = false, this.enabled = true, this.compact = false, this.glow = false});
  final int first;
  final int second;
  final bool selected;
  final bool enabled;
  final bool compact;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pipColor = selected ? Colors.white : dark ? const Color(0xFFF2EDFF) : const Color(0xFF2B2440);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: compact ? 46 : 62,
      height: compact ? 66 : 92,
      padding: EdgeInsets.all(compact ? 5 : 7),
      decoration: BoxDecoration(
        color: selected ? AppTheme.violet : dark ? const Color(0xFF33304A) : Colors.white,
        borderRadius: BorderRadius.circular(compact ? 9 : 12),
        border: Border.all(color: selected ? AppTheme.violet : glow ? AppTheme.violet.withOpacity(.8) : enabled ? AppTheme.violet.withOpacity(.4) : Theme.of(context).dividerColor, width: selected || glow ? 2.2 : 1.1),
        boxShadow: [if (selected || glow) ...AppTheme.glow(AppTheme.violet, strength: .35) else const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(1, 2))],
      ),
      child: Opacity(
        opacity: enabled || selected ? 1 : .45,
        child: Column(children: [
          Expanded(child: _PipFace(value: first, color: pipColor, compact: compact)),
          Container(height: 1.2, margin: const EdgeInsets.symmetric(vertical: 2), color: selected ? Colors.white54 : Theme.of(context).dividerColor),
          Expanded(child: _PipFace(value: second, color: pipColor, compact: compact)),
        ]),
      ),
    );
  }
}

class _PipFace extends StatelessWidget {
  const _PipFace({required this.value, required this.color, required this.compact});
  final int value;
  final Color color;
  final bool compact;

  static const _layouts = <int, List<int>>{
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final pips = _layouts[value] ?? const <int>[];
    return GridView.count(crossAxisCount: 3, physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero, children: [for (var index = 0; index < 9; index += 1) Center(child: pips.contains(index) ? Container(width: compact ? 5 : 7, height: compact ? 5 : 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)) : const SizedBox.shrink())]);
  }
}

class _PlaceButton extends StatelessWidget {
  const _PlaceButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressableScale(
        onTap: onTap,
        child: Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.13), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.violet.withOpacity(.45))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: AppTheme.violet), const SizedBox(width: 7), VibeText(label, style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.violet))])),
      );
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.violet.withOpacity(.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: AppTheme.violet), const SizedBox(width: 5), VibeText(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))]));
}

class _OpponentCounts extends StatelessWidget {
  const _OpponentCounts({required this.match, required this.handSizes, required this.viewerSeat, required this.turnPlayerId});
  final MatchModel match;
  final List<int> handSizes;
  final int viewerSeat;
  final String? turnPlayerId;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: match.players.where((player) => player['seat'] != viewerSeat).map((player) {
          final seat = (player['seat'] as num?)?.toInt() ?? 0;
          final count = seat < handSizes.length ? handSizes[seat] : 0;
          final active = player['id']?.toString() == turnPlayerId;
          return AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: active ? AppTheme.violet.withOpacity(.13) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: active ? AppTheme.violet : Theme.of(context).dividerColor, width: active ? 1.8 : 1)), child: VibeText('${player['displayName'] ?? 'Player'} · $count tiles', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)));
        }).toList(),
      );
}
