import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class CarromGameBoard extends StatefulWidget {
  const CarromGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<CarromGameBoard> createState() => _CarromGameBoardState();
}

class _CarromGameBoardState extends State<CarromGameBoard> {
  final Set<int> selectedCoins = <int>{};
  double power = 65;
  bool queen = false;

  @override
  void didUpdateWidget(covariant CarromGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final remaining = _numbers(widget.state['remainingCoins']);
    if (oldWidget.match.revision != widget.match.revision) {
      selectedCoins.clear();
      queen = false;
    } else {
      selectedCoins.removeWhere((coin) => !remaining.contains(coin));
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _numbers(widget.state['remainingCoins']);
    final groups = (widget.state['groups'] as List? ?? const []).map((value) => value?.toString()).toList();
    final scores = _numbers(widget.state['scores']);
    final viewerGroup = widget.match.viewerSeat < groups.length ? groups[widget.match.viewerSeat] : null;
    final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    final isTurn = widget.match.status == 'active' && viewer.isNotEmpty && widget.state['turnPlayerId'] == viewer.first['id'];
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final pendingCover = (widget.state['queenPendingFor'] as num?)?.toInt() == widget.match.viewerSeat;
    final queenCall = queen && widget.state['queenRemaining'] == true;
    final canStrike = isTurn && !finished && selectedCoins.length <= 3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.16), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.radio_button_checked_rounded, color: AppTheme.gold)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Carrom', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _CarromPill(label: viewerGroup == null ? 'Group open' : viewerGroup),
          ]),
          const SizedBox(height: 12),
          Text(finished ? 'The board is settled.' : isTurn ? pendingCover ? 'Your turn · cover the queen with one of your coins.' : 'Your turn · choose coins, then strike.' : 'Choose your color by pocketing a coin. The queen needs a cover.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _CarromBoard(remaining: remaining, queenAvailable: widget.state['queenRemaining'] == true, selected: selectedCoins, group: viewerGroup, enabled: isTurn && !finished, onToggle: (coin) => setState(() { if (selectedCoins.contains(coin)) selectedCoins.remove(coin); else if (selectedCoins.length < 3) selectedCoins.add(coin); })),
          const SizedBox(height: 13),
          Row(children: [
            const Text('Power', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            Expanded(child: Slider(value: power, min: 1, max: 100, divisions: 99, label: power.round().toString(), onChanged: isTurn && !finished ? (value) => setState(() => power = value) : null)),
            Text('${power.round()}', style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: canStrike ? _submit : null, icon: const Icon(Icons.sports_hockey_rounded), label: Text(queenCall ? 'Pocket queen' : pendingCover ? 'Cover queen' : 'Strike'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: isTurn && !finished ? _miss : null, icon: const Icon(Icons.close_rounded), label: const Text('Miss'))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ScoreStrip(match: widget.match, scores: scores, viewerSeat: widget.match.viewerSeat)),
          ]),
          if (widget.state['queenRemaining'] == true) ...[
            const SizedBox(height: 10),
            Row(children: [
              Checkbox(value: queen, onChanged: isTurn && !finished ? (value) => setState(() => queen = value ?? false) : null),
              const Expanded(child: Text('Call the queen on this strike', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
          ],
        ]),
      ),
    );
  }

  void _submit() {
    final coins = selectedCoins.toList()..sort();
    final calledQueen = queen && widget.state['queenRemaining'] == true;
    // Clear only after the server advances the revision; a failed request can
    // then be retried without rebuilding the strike from memory.
    widget.onAction({'type': 'strike', 'power': power.round(), 'pocketed': coins, 'queen': calledQueen});
  }

  void _miss() {
    widget.onAction({'type': 'strike', 'power': power.round(), 'pocketed': <int>[], 'queen': false});
  }

  List<int> _numbers(dynamic value) => (value as List? ?? const []).whereType<num>().map((number) => number.toInt()).toList();
}

class _CarromBoard extends StatelessWidget {
  const _CarromBoard({required this.remaining, required this.queenAvailable, required this.selected, required this.group, required this.enabled, required this.onToggle});
  final List<int> remaining;
  final bool queenAvailable;
  final Set<int> selected;
  final String? group;
  final bool enabled;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: const Color(0xFFD39A61), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF8E5933), width: 6), boxShadow: const [BoxShadow(color: Color(0x2F000000), blurRadius: 8, offset: Offset(0, 4))]),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF2D0A4), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFB77946), width: 2)),
      child: Column(children: [
        Row(children: [
          _Pocket(color: AppTheme.coral),
          const Spacer(),
          const Text('SELECT COINS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: Color(0xFF6B422D))),
          const Spacer(),
          _Pocket(color: AppTheme.coral),
        ]),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (final coin in remaining) _Coin(coin: coin, selected: selected.contains(coin), enabled: enabled && _allowed(coin), onTap: () => onToggle(coin)),
          if (queenAvailable) const _Queen(),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _Pocket(color: AppTheme.coral),
          const Spacer(),
          Container(width: 33, height: 33, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF9D6842), width: 2)), child: const Icon(Icons.add_rounded, color: Color(0xFF9D6842))),
          const Spacer(),
          _Pocket(color: AppTheme.coral),
        ]),
      ]),
    ),
  );

  bool _allowed(int coin) {
    if (group == null) return true;
    return group == 'white' ? coin <= 9 : coin >= 10;
  }
}

class _Coin extends StatelessWidget {
  const _Coin({required this.coin, required this.selected, required this.enabled, required this.onTap});
  final int coin;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final white = coin <= 9;
    final color = white ? const Color(0xFFF8E9CF) : const Color(0xFF3C2B2A);
    return GestureDetector(onTap: enabled ? onTap : null, child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: selected ? AppTheme.gold : white ? const Color(0xFFC2925C) : const Color(0xFF1D1515), width: selected ? 3 : 1.5), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))]), child: Text('$coin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: white ? const Color(0xFF583B2C) : Colors.white))));
  }
}

class _Queen extends StatelessWidget {
  const _Queen();
  @override
  Widget build(BuildContext context) => Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.coral, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))]), child: const Text('Q', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)));
}

class _Pocket extends StatelessWidget {
  const _Pocket({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 25, height: 25, decoration: BoxDecoration(color: const Color(0xFF271B1A), shape: BoxShape.circle, border: Border.all(color: color, width: 3)));
}

class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({required this.match, required this.scores, required this.viewerSeat});
  final MatchModel match;
  final List<int> scores;
  final int viewerSeat;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 7, runSpacing: 7, children: match.players.map((player) {
    final seat = (player['seat'] as num?)?.toInt() ?? 0;
    final score = seat < scores.length ? scores[seat] : 0;
    final active = seat == viewerSeat;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: active ? AppTheme.gold.withOpacity(.16) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? AppTheme.gold : Theme.of(context).dividerColor)), child: Text('${player['displayName'] ?? 'Player'}  $score', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)));
  }).toList());
}

class _CarromPill extends StatelessWidget {
  const _CarromPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.16), borderRadius: BorderRadius.circular(12)), child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)));
}
