import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class TriviaBattleGameBoard extends StatefulWidget {
  const TriviaBattleGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<TriviaBattleGameBoard> createState() => _TriviaBattleGameBoardState();
}

class _TriviaBattleGameBoardState extends State<TriviaBattleGameBoard> {
  int? selected;

  @override
  void didUpdateWidget(covariant TriviaBattleGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.state['currentQuestion'] is Map ? Map<String, dynamic>.from(widget.state['currentQuestion'] as Map) : <String, dynamic>{};
    final options = (question['options'] as List? ?? const []).map((option) => option.toString()).toList();
    final scores = _numbers(widget.state['scores']);
    final round = (widget.state['questionIndex'] as num?)?.toInt() ?? 0;
    final rounds = (widget.state['rounds'] as num?)?.toInt() ?? 10;
    final viewer = _viewer;
    final isTurn = widget.match.status == 'active' && viewer != null && widget.state['turnPlayerId'] == viewer['id'];
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final lastAnswer = widget.state['lastAnswer'] as Map?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.17), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.quiz_rounded, color: AppTheme.gold)),
            const SizedBox(width: 10),
            const Expanded(child: VibeText('Trivia Battle', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _TriviaBadge(label: '${round + 1} / $rounds'),
          ]),
          const SizedBox(height: 12),
          if (question['category'] != null) VibeText(question['category'].toString().toUpperCase(), style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 5),
          VibeText(question['prompt']?.toString() ?? (finished ? 'The final scores are in.' : 'Loading the next question…'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 13),
          if (options.isNotEmpty) ...[
            for (var index = 0; index < options.length; index += 1) ...[
              _AnswerOption(index: index, label: options[index], selected: selected == index, enabled: isTurn && !finished, onTap: () => setState(() => selected = index)),
              if (index < options.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: isTurn && selected != null && !finished ? () => widget.onAction({'type': 'answer', 'answer': selected}) : null, icon: const Icon(Icons.check_circle_rounded), label: VibeText(isTurn ? 'Lock in answer' : 'Waiting for turn'))),
          ] else VibeText(finished ? 'Match complete.' : 'The question will appear after the live state syncs.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
          if (!finished && !isTurn) ...[const SizedBox(height: 8), VibeText('The answer order is locked one player at a time so nobody can see another player\'s choice.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11))],
          if (lastAnswer != null && !finished) ...[const SizedBox(height: 10), VibeText('Previous round revealed · next question is live.', style: TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w800, fontSize: 11))],
          const SizedBox(height: 14),
          _TriviaScores(match: widget.match, scores: scores, viewerSeat: widget.match.viewerSeat),
        ]),
      ),
    );
  }

  Map<String, dynamic>? get _viewer {
    final viewers = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    return viewers.isEmpty ? null : viewers.first;
  }

  List<int> _numbers(dynamic value) => (value as List? ?? const []).map((item) => (item as num?)?.toInt() ?? 0).toList();
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({required this.index, required this.label, required this.selected, required this.enabled, required this.onTap});
  final int index;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(15),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(color: selected ? AppTheme.gold.withOpacity(.18) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? AppTheme.gold : Theme.of(context).dividerColor, width: selected ? 2 : 1)),
      child: Row(children: [
        Container(width: 29, height: 29, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? AppTheme.gold : AppTheme.gold.withOpacity(.14), shape: BoxShape.circle), child: VibeText(String.fromCharCode(65 + index), style: TextStyle(fontWeight: FontWeight.w900, color: selected ? Colors.white : AppTheme.gold))),
        const SizedBox(width: 10),
        Expanded(child: VibeText(label, style: const TextStyle(fontWeight: FontWeight.w800))),
        if (selected) const Icon(Icons.check_circle_rounded, color: AppTheme.gold),
      ]),
    ),
  );
}

class _TriviaBadge extends StatelessWidget {
  const _TriviaBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.16), borderRadius: BorderRadius.circular(12)), child: VibeText(label, style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w900, fontSize: 12)));
}

class _TriviaScores extends StatelessWidget {
  const _TriviaScores({required this.match, required this.scores, required this.viewerSeat});
  final MatchModel match;
  final List<int> scores;
  final int viewerSeat;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 7, runSpacing: 7, children: [for (var index = 0; index < match.players.length; index += 1) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: index == viewerSeat ? AppTheme.gold.withOpacity(.16) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: index == viewerSeat ? AppTheme.gold.withOpacity(.4) : Theme.of(context).dividerColor)), child: VibeText('${match.players[index]['displayName']?.toString() ?? 'Player'} · ${scores.length > index ? scores[index] : 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))]);
}
