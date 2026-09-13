import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
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

  @override
  void didUpdateWidget(covariant DominoesGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) selectedIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final chain = _numbers(widget.state['chain']);
    final hands = widget.state['hands'] as List? ?? const [];
    final hand = widget.match.viewerSeat < hands.length ? _tiles(hands[widget.match.viewerSeat]) : <List<int>>[];
    final handSizes = _numbers(widget.state['handSizes']);
    final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    final isTurn = widget.match.status == 'active' && viewer.isNotEmpty && widget.state['turnPlayerId'] == viewer.first['id'];
    final legal = isTurn ? hand.asMap().entries.where((entry) => _matches(entry.value, chain)).map((entry) => entry.key).toSet() : <int>{};
    final hasBoneyard = ((widget.state['boneyard'] as List?)?.length ?? 0) > 0;
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final canDraw = isTurn && legal.isEmpty && hasBoneyard && !finished;
    final canPass = isTurn && legal.isEmpty && !hasBoneyard && !finished;
    final selected = selectedIndex != null && selectedIndex! < hand.length ? hand[selectedIndex!] : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.13), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.view_carousel_rounded, color: AppTheme.violet)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Dominoes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _StatPill(icon: Icons.layers_rounded, label: '${(widget.state['boneyard'] as List?)?.length ?? 0} draw'),
          ]),
          const SizedBox(height: 12),
          Text(finished ? 'The chain is complete.' : isTurn ? legal.isNotEmpty ? 'Your turn · choose a matching tile.' : canDraw ? 'No match · draw until you can play.' : 'No match · pass to block the round.' : 'Watch the chain and keep your hand hidden from the table.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _ChainView(chain: chain),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ActionButton(label: 'Draw', icon: Icons.add_rounded, enabled: canDraw, onPressed: () { widget.onAction({'type': 'draw'}); })),
            const SizedBox(width: 8),
            Expanded(child: _ActionButton(label: 'Pass', icon: Icons.skip_next_rounded, enabled: canPass, onPressed: () { widget.onAction({'type': 'pass'}); })),
          ]),
          const SizedBox(height: 14),
          _OpponentCounts(match: widget.match, handSizes: handSizes, viewerSeat: widget.match.viewerSeat),
          const SizedBox(height: 14),
          Row(children: [
            const Text('Your hand', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const Spacer(),
            if (selected != null) Text('Selected ${selected[0]}–${selected[1]}', style: TextStyle(color: AppTheme.violet, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          if (hand.isEmpty) const Text('Your dominoes are hidden until the table syncs.', style: TextStyle(fontSize: 12)) else _HandView(hand: hand, legal: legal, selectedIndex: selectedIndex, enabled: isTurn && !finished, onSelect: (index) => setState(() => selectedIndex = selectedIndex == index ? null : index)),
          if (selected != null && isTurn && !finished) ...[
            const SizedBox(height: 12),
            _PlacementControls(left: chain.isNotEmpty && selected.contains(chain.first), right: chain.isNotEmpty && selected.contains(chain.last), onPlace: (side) { final index = selectedIndex; if (index == null) return; widget.onAction({'type': 'play', 'index': index, 'side': side}); }),
          ],
          if (widget.state['lastDrawn'] is List) ...[
            const SizedBox(height: 10),
            Text('Last draw: ${_tileText(_numbers(widget.state['lastDrawn']))}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }

  List<List<int>> _tiles(dynamic value) => (value as List? ?? const []).whereType<List>().map((tile) => _numbers(tile)).where((tile) => tile.length == 2).toList();
  List<int> _numbers(dynamic value) => (value as List? ?? const []).whereType<num>().map((number) => number.toInt()).toList();
  bool _matches(List<int> tile, List<int> chain) => tile.length == 2 && chain.isNotEmpty && (tile.contains(chain.first) || tile.contains(chain.last));
  String _tileText(List<int> tile) => tile.length == 2 ? '${tile[0]}–${tile[1]}' : 'none';
}

class _ChainView extends StatelessWidget {
  const _ChainView({required this.chain});
  final List<int> chain;

  @override
  Widget build(BuildContext context) => Container(
    height: 92,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFFF5F1FF), borderRadius: BorderRadius.circular(17), border: Border.all(color: AppTheme.violet.withOpacity(.18))),
    child: chain.isEmpty ? const Center(child: Text('The opening tile will appear here')) : SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      for (var index = 0; index < chain.length - 1; index += 1) ...[
        _DominoTile(first: chain[index], second: chain[index + 1], compact: true),
        if (index < chain.length - 2) const SizedBox(width: 3),
      ],
    ])),
  );
}

class _HandView extends StatelessWidget {
  const _HandView({required this.hand, required this.legal, required this.selectedIndex, required this.enabled, required this.onSelect});
  final List<List<int>> hand;
  final Set<int> legal;
  final int? selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 72,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: hand.length,
      separatorBuilder: (_, __) => const SizedBox(width: 7),
      itemBuilder: (_, index) => GestureDetector(onTap: enabled && legal.contains(index) ? () => onSelect(index) : null, child: _DominoTile(first: hand[index][0], second: hand[index][1], selected: selectedIndex == index, enabled: enabled && legal.contains(index))),
    ),
  );
}

class _DominoTile extends StatelessWidget {
  const _DominoTile({required this.first, required this.second, this.selected = false, this.enabled = true, this.compact = false});
  final int first;
  final int second;
  final bool selected;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    width: compact ? 44 : 54,
    height: compact ? 62 : 68,
    decoration: BoxDecoration(color: selected ? AppTheme.violet : enabled ? Colors.white : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: selected ? AppTheme.violet : enabled ? AppTheme.violet.withOpacity(.45) : Theme.of(context).dividerColor, width: selected ? 2.5 : 1.1), boxShadow: enabled ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(1, 2))] : null),
    child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Text('$first', style: TextStyle(fontWeight: FontWeight.w900, fontSize: compact ? 12 : 15, color: selected ? Colors.white : null)),
      Container(height: 1, color: selected ? Colors.white54 : Theme.of(context).dividerColor),
      Text('$second', style: TextStyle(fontWeight: FontWeight.w900, fontSize: compact ? 12 : 15, color: selected ? Colors.white : null)),
    ]),
  );
}

class _PlacementControls extends StatelessWidget {
  const _PlacementControls({required this.left, required this.right, required this.onPlace});
  final bool left;
  final bool right;
  final ValueChanged<String> onPlace;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: FilledButton.tonalIcon(onPressed: left ? () => onPlace('left') : null, icon: const Icon(Icons.arrow_back_rounded), label: const Text('Left'))),
    const SizedBox(width: 8),
    Expanded(child: FilledButton.tonalIcon(onPressed: right ? () => onPlace('right') : null, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Right'))),
  ]);
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.enabled, required this.onPressed});
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: enabled ? onPressed : null, icon: Icon(icon, size: 18), label: Text(label));
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: AppTheme.violet), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))]));
}

class _OpponentCounts extends StatelessWidget {
  const _OpponentCounts({required this.match, required this.handSizes, required this.viewerSeat});
  final MatchModel match;
  final List<int> handSizes;
  final int viewerSeat;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 7, runSpacing: 7, children: match.players.where((player) => player['seat'] != viewerSeat).map((player) {
    final seat = (player['seat'] as num?)?.toInt() ?? 0;
    final count = seat < handSizes.length ? handSizes[seat] : 0;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: Theme.of(context).dividerColor)), child: Text('${player['displayName'] ?? 'Player'} · $count tiles', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)));
  }).toList());
}
