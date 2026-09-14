import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

const _quickYellow = Color(0xFFEAB308);

class QuickChallengesGameBoard extends StatefulWidget {
  const QuickChallengesGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<QuickChallengesGameBoard> createState() => _QuickChallengesGameBoardState();
}

class _QuickChallengesGameBoardState extends State<QuickChallengesGameBoard> with SingleTickerProviderStateMixin {
  late final AnimationController marker;

  @override
  void initState() {
    super.initState();
    marker = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    marker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scores = _ints(widget.state['scores']);
    final round = (widget.state['round'] as num?)?.toInt() ?? 1;
    final rounds = (widget.state['rounds'] as num?)?.toInt() ?? 7;
    final challenge = widget.state['challenge'] is Map ? Map<String, dynamic>.from(widget.state['challenge'] as Map) : <String, dynamic>{};
    final kind = challenge['kind']?.toString() ?? 'stop';
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final viewer = _viewer();
    final isTurn = !finished && widget.match.status == 'active' && viewer != null && widget.state['turnPlayerId'] == viewer['id'];
    final lastResult = widget.state['lastResult'] is Map ? Map<String, dynamic>.from(widget.state['lastResult'] as Map) : null;
    final history = (widget.state['history'] as List? ?? const []).reversed.take(6).toList();
    final leader = _leader(scores);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _quickYellow.withOpacity(.2), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.bolt_rounded, color: _quickYellow)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Quick Challenges', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _QuickBadge(label: finished ? 'Final' : 'Round $round / $rounds'),
          ]),
          const SizedBox(height: 6),
          Text(finished ? 'All seven rounds are done.' : 'A fresh mini-challenge every turn — most points wins.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          if (!finished) ...[
            const SizedBox(height: 12),
            if (kind == 'stop') _StopChallenge(challenge: challenge, marker: marker, isTurn: isTurn, turnName: _turnName(), onStop: (value) => widget.onAction({'type': 'play', 'value': value})),
            if (kind == 'highlow') _HighLowChallenge(challenge: challenge, isTurn: isTurn, turnName: _turnName(), onGuess: (guess) => widget.onAction({'type': 'play', 'guess': guess})),
            if (kind == 'cups') _CupsChallenge(isTurn: isTurn, turnName: _turnName(), onPick: (cup) => widget.onAction({'type': 'play', 'cup': cup})),
          ],
          if (lastResult != null) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: Text('${_name(lastResult['playerId']?.toString())}: ${lastResult['detail'] ?? ''} (+${lastResult['points'] ?? 0})', style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w800, fontSize: 12))),
          ],
          const SizedBox(height: 14),
          _QuickScores(match: widget.match, scores: scores, viewerSeat: widget.match.viewerSeat, leader: finished ? -1 : leader),
          if (history.isNotEmpty && !finished) ...[
            const SizedBox(height: 10),
            for (final entry in history)
              if (entry is Map)
                Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('Round ${entry['round'] ?? '–'} · ${_name(entry['playerId']?.toString())} · ${_kindLabel(entry['kind']?.toString())} · +${entry['points'] ?? 0}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700))),
          ],
        ]),
      ),
    );
  }

  Map<String, dynamic>? _viewer() {
    final viewers = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    return viewers.isEmpty ? null : viewers.first;
  }

  String _name(String? id) {
    if (id == null) return 'Someone';
    final found = widget.match.players.where((player) => player['id'] == id).toList();
    return found.isEmpty ? 'Someone' : found.first['displayName']?.toString() ?? 'Someone';
  }

  String _turnName() {
    final found = widget.match.players.where((player) => player['id'] == widget.state['turnPlayerId']).toList();
    return found.isEmpty ? 'the other player' : found.first['displayName']?.toString() ?? 'the other player';
  }

  String _kindLabel(String? kind) => switch (kind) { 'stop' => 'Bullseye stop', 'highlow' => 'High-Low', 'cups' => 'Lucky cups', _ => 'Challenge' };

  int _leader(List<int> scores) {
    var best = 0;
    for (var index = 1; index < widget.match.players.length; index += 1) {
      if ((scores.length > index ? scores[index] : 0) > (scores.length > best ? scores[best] : 0)) best = index;
    }
    return best;
  }

  List<int> _ints(dynamic value) => (value as List? ?? const []).map((item) => (item as num?)?.toInt() ?? 0).toList();
}

class _StopChallenge extends StatelessWidget {
  const _StopChallenge({required this.challenge, required this.marker, required this.isTurn, required this.turnName, required this.onStop});
  final Map<String, dynamic> challenge;
  final AnimationController marker;
  final bool isTurn;
  final String turnName;
  final ValueChanged<int> onStop;

  @override
  Widget build(BuildContext context) {
    final zone = (challenge['zone'] as List? ?? const [45, 55]).map((item) => ((item as num?)?.toInt() ?? 50).clamp(0, 100)).toList();
    final lo = zone.isNotEmpty ? zone[0] : 45;
    final hi = zone.length > 1 ? zone[1] : 55;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _quickYellow.withOpacity(.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: _quickYellow.withOpacity(.35))),
      child: Column(children: [
        const Text('🎯 BULLSEYE STOP', style: TextStyle(color: _quickYellow, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(isTurn ? 'Stop the marker inside the zone!' : 'Waiting for $turnName…', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: marker,
          builder: (context, _) {
            final position = marker.value;
            return Column(children: [
              SizedBox(
                height: 44,
                child: LayoutBuilder(builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Stack(children: [
                    Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor))),
                    Positioned(left: width * lo / 100, width: width * (hi - lo) / 100, top: 0, bottom: 0, child: Container(decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.35), borderRadius: BorderRadius.circular(8)))),
                    Positioned(left: (width * position).clamp(0, width - 6), top: 4, bottom: 4, child: Container(width: 6, decoration: BoxDecoration(color: _quickYellow, borderRadius: BorderRadius.circular(3)))),
                  ]);
                }),
              ),
              const SizedBox(height: 6),
              Text('Marker: ${(position * 100).round()}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w800)),
            ]);
          },
        ),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: isTurn ? () => onStop((marker.value * 100).round()) : null, child: Text(isTurn ? 'STOP!' : 'Waiting…'))),
      ]),
    );
  }
}

class _HighLowChallenge extends StatelessWidget {
  const _HighLowChallenge({required this.challenge, required this.isTurn, required this.turnName, required this.onGuess});
  final Map<String, dynamic> challenge;
  final bool isTurn;
  final String turnName;
  final ValueChanged<String> onGuess;

  String _rank(int card) => card == 1 ? 'A' : card == 11 ? 'J' : card == 12 ? 'Q' : card == 13 ? 'K' : '$card';

  @override
  Widget build(BuildContext context) {
    final card = ((challenge['card'] as num?)?.toInt() ?? 7).clamp(1, 13);
    const suits = ['♥', '♦', '♣', '♠'];
    final suit = suits[card % 4];
    final red = suit == '♥' || suit == '♦';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _quickYellow.withOpacity(.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: _quickYellow.withOpacity(.35))),
      child: Column(children: [
        const Text('🃏 HIGH OR LOW', style: TextStyle(color: _quickYellow, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 10),
        Container(
          width: 84,
          height: 116,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_rank(card), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 30, color: red ? const Color(0xFFE04F5F) : const Color(0xFF1F2937))),
            Text(suit, style: TextStyle(fontSize: 22, color: red ? const Color(0xFFE04F5F) : const Color(0xFF1F2937))),
          ]),
        ),
        const SizedBox(height: 4),
        Text(isTurn ? 'Will the next card be higher or lower?' : 'Waiting for $turnName…', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: isTurn ? () => onGuess('high') : null, icon: const Icon(Icons.arrow_upward_rounded), label: const Text('Higher'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.tonalIcon(onPressed: isTurn ? () => onGuess('low') : null, icon: const Icon(Icons.arrow_downward_rounded), label: const Text('Lower'))),
        ]),
      ]),
    );
  }
}

class _CupsChallenge extends StatelessWidget {
  const _CupsChallenge({required this.isTurn, required this.turnName, required this.onPick});
  final bool isTurn;
  final String turnName;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _quickYellow.withOpacity(.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: _quickYellow.withOpacity(.35))),
        child: Column(children: [
          const Text('🥤 LUCKY CUPS', style: TextStyle(color: _quickYellow, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(isTurn ? 'One cup hides 100 points — pick!' : 'Waiting for $turnName…', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            for (var cup = 0; cup < 4; cup += 1) ...[
              Expanded(
                child: InkWell(
                  onTap: isTurn ? () => onPick(cup) : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: isTurn ? _quickYellow.withOpacity(.16) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: isTurn ? _quickYellow : Theme.of(context).dividerColor, width: isTurn ? 2 : 1)),
                    child: Column(children: [const Text('🥤', style: TextStyle(fontSize: 30)), const SizedBox(height: 2), Text('${cup + 1}', style: const TextStyle(fontWeight: FontWeight.w900))]),
                  ),
                ),
              ),
              if (cup < 3) const SizedBox(width: 8),
            ],
          ]),
        ]),
      );
}

class _QuickBadge extends StatelessWidget {
  const _QuickBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: _quickYellow.withOpacity(.2), borderRadius: BorderRadius.circular(12)), child: Text(label, style: const TextStyle(color: Color(0xFF92690E), fontWeight: FontWeight.w900, fontSize: 12)));
}

class _QuickScores extends StatelessWidget {
  const _QuickScores({required this.match, required this.scores, required this.viewerSeat, required this.leader});
  final MatchModel match;
  final List<int> scores;
  final int viewerSeat;
  final int leader;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 7, runSpacing: 7, children: [for (var index = 0; index < match.players.length; index += 1) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: index == viewerSeat ? _quickYellow.withOpacity(.2) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: index == leader ? _quickYellow : index == viewerSeat ? _quickYellow.withOpacity(.5) : Theme.of(context).dividerColor, width: index == leader ? 2 : 1)), child: Text('${match.players[index]['displayName']?.toString() ?? 'Player'} · ${scores.length > index ? scores[index] : 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))]);
}
