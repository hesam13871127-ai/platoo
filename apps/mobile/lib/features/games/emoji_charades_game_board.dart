import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

const _emojiOrange = Color(0xFFF97316);

class EmojiCharadesGameBoard extends StatefulWidget {
  const EmojiCharadesGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<EmojiCharadesGameBoard> createState() => _EmojiCharadesGameBoardState();
}

class _EmojiCharadesGameBoardState extends State<EmojiCharadesGameBoard> {
  int? selected;

  @override
  void didUpdateWidget(covariant EmojiCharadesGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final round = (widget.state['round'] as num?)?.toInt() ?? 1;
    final rounds = (widget.state['rounds'] as num?)?.toInt() ?? 1;
    final presenterIndex = (widget.state['presenterIndex'] as num?)?.toInt() ?? 0;
    final phase = widget.state['phase']?.toString() ?? 'clue';
    final prompt = widget.state['prompt']?.toString();
    final clueOptions = (widget.state['clueOptions'] as List? ?? const []).map((item) => item.toString()).toList();
    final clue = widget.state['clue']?.toString();
    final options = (widget.state['options'] as List? ?? const []).map((item) => item.toString()).toList();
    final guesses = widget.state['guesses'] as List? ?? const [];
    final scores = _ints(widget.state['scores']);
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final viewer = _viewer();
    final isTurn = !finished && widget.match.status == 'active' && viewer != null && widget.state['turnPlayerId'] == viewer['id'];
    final isPresenter = widget.match.viewerSeat == presenterIndex;
    final myGuess = widget.match.viewerSeat < guesses.length ? (guesses[widget.match.viewerSeat] as num?)?.toInt() : null;
    final guessedCount = guesses.where((guess) => guess != null).length;
    final lastRound = widget.state['lastRound'] is Map ? Map<String, dynamic>.from(widget.state['lastRound'] as Map) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _emojiOrange.withOpacity(.17), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.emoji_emotions_rounded, color: _emojiOrange)),
            const SizedBox(width: 10),
            const Expanded(child: VibeText('Emoji Charades', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _EmojiBadge(label: finished ? 'Final' : 'Round $round / $rounds'),
          ]),
          const SizedBox(height: 10),
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: _emojiOrange.withOpacity(.08), borderRadius: BorderRadius.circular(12)), child: VibeText(finished ? 'The final round is revealed below.' : phase == 'clue' ? '🎭 ${_presenterName(presenterIndex)} is picking an emoji clue…' : '🔍 ${_presenterName(presenterIndex)} posted a clue — guess the word!', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
          const SizedBox(height: 12),
          if (!finished && isPresenter && phase == 'clue') ...[
            Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _emojiOrange.withOpacity(.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _emojiOrange.withOpacity(.4))), child: Column(children: [
              const VibeText('YOUR SECRET WORD', style: TextStyle(color: _emojiOrange, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
              const SizedBox(height: 4),
              VibeText(prompt?.toUpperCase() ?? '…', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
              const SizedBox(height: 4),
              VibeText(isTurn ? 'Pick the emoji that sells it.' : 'Waiting for your turn…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
            const SizedBox(height: 10),
            Row(children: [
              for (var index = 0; index < clueOptions.length; index += 1) ...[
                Expanded(child: FilledButton(onPressed: isTurn ? () => widget.onAction({'type': 'post_clue', 'emoji': clueOptions[index]}) : null, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)), child: VibeText(clueOptions[index], style: const TextStyle(fontSize: 26)))),
                if (index < clueOptions.length - 1) const SizedBox(width: 8),
              ],
            ]),
          ] else if (!finished && phase == 'guessing') ...[
            Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14), decoration: BoxDecoration(color: _emojiOrange.withOpacity(.1), borderRadius: BorderRadius.circular(18)), child: VibeText(clue ?? '…', style: const TextStyle(fontSize: 52)))),
            const SizedBox(height: 12),
            if (!isPresenter) ...[
              for (var index = 0; index < options.length; index += 1) ...[
                _GuessOption(index: index, label: options[index], selected: selected == index, locked: myGuess != null, enabled: isTurn && myGuess == null, onTap: () => setState(() => selected = index)),
                if (index < options.length - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: isTurn && myGuess == null && selected != null ? () => widget.onAction({'type': 'guess', 'answer': selected}) : null, icon: const Icon(Icons.check_circle_rounded), label: VibeText(myGuess != null ? 'Guess locked in' : isTurn ? 'Lock in guess' : 'Waiting for your turn'))),
            ] else ...[
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor)), child: VibeText('You posted $clue — $guessedCount of ${widget.match.players.length - 1} players guessed.', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            ],
          ] else if (!finished) ...[
            Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: VibeText('Waiting for ${_presenterName(presenterIndex)} to post the clue…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)))),
          ],
          if (lastRound != null) ...[
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: VibeText('${lastRound['clue'] ?? ''} was “${(lastRound['word']?.toString() ?? '').toUpperCase()}” — ${(lastRound['correctIds'] as List? ?? const []).length} guessed it!', style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w800, fontSize: 12))),
          ],
          const SizedBox(height: 14),
          _EmojiScores(match: widget.match, scores: scores, viewerSeat: widget.match.viewerSeat),
        ]),
      ),
    );
  }

  Map<String, dynamic>? _viewer() {
    final viewers = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    return viewers.isEmpty ? null : viewers.first;
  }

  String _presenterName(int seat) => seat < widget.match.players.length ? widget.match.players[seat]['displayName']?.toString() ?? 'Player' : 'Player';

  List<int> _ints(dynamic value) => (value as List? ?? const []).map((item) => (item as num?)?.toInt() ?? 0).toList();
}

class _GuessOption extends StatelessWidget {
  const _GuessOption({required this.index, required this.label, required this.selected, required this.locked, required this.enabled, required this.onTap});
  final int index;
  final String label;
  final bool selected;
  final bool locked;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          decoration: BoxDecoration(color: selected ? _emojiOrange.withOpacity(.18) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? _emojiOrange : Theme.of(context).dividerColor, width: selected ? 2 : 1)),
          child: Row(children: [
            Container(width: 29, height: 29, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? _emojiOrange : _emojiOrange.withOpacity(.14), shape: BoxShape.circle), child: VibeText(String.fromCharCode(65 + index), style: TextStyle(fontWeight: FontWeight.w900, color: selected ? Colors.white : _emojiOrange))),
            const SizedBox(width: 10),
            Expanded(child: VibeText(label, style: const TextStyle(fontWeight: FontWeight.w800))),
            if (selected) const Icon(Icons.check_circle_rounded, color: _emojiOrange),
            if (!selected && locked) Icon(Icons.lock_rounded, size: 16, color: Theme.of(context).disabledColor),
          ]),
        ),
      );
}

class _EmojiBadge extends StatelessWidget {
  const _EmojiBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: _emojiOrange.withOpacity(.16), borderRadius: BorderRadius.circular(12)), child: VibeText(label, style: const TextStyle(color: _emojiOrange, fontWeight: FontWeight.w900, fontSize: 12)));
}

class _EmojiScores extends StatelessWidget {
  const _EmojiScores({required this.match, required this.scores, required this.viewerSeat});
  final MatchModel match;
  final List<int> scores;
  final int viewerSeat;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 7, runSpacing: 7, children: [for (var index = 0; index < match.players.length; index += 1) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: index == viewerSeat ? _emojiOrange.withOpacity(.16) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: index == viewerSeat ? _emojiOrange.withOpacity(.4) : Theme.of(context).dividerColor)), child: VibeText('${match.players[index]['displayName']?.toString() ?? 'Player'} · ${scores.length > index ? scores[index] : 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))]);
}
