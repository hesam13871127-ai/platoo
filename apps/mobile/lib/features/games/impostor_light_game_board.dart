import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

const _impostorRed = Color(0xFFDC2626);

class ImpostorLightGameBoard extends StatefulWidget {
  const ImpostorLightGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<ImpostorLightGameBoard> createState() => _ImpostorLightGameBoardState();
}

class _ImpostorLightGameBoardState extends State<ImpostorLightGameBoard> {
  final clue = TextEditingController();
  int? suspect;

  @override
  void dispose() {
    clue.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ImpostorLightGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) suspect = null;
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.state['phase']?.toString() ?? 'clues';
    final word = widget.state['word']?.toString();
    final impostorSeat = (widget.state['impostor'] as num?)?.toInt();
    final clues = widget.state['clues'] as List? ?? const [];
    final votes = widget.state['votes'] as List? ?? const [];
    final voteCount = (widget.state['voteCount'] as num?)?.toInt() ?? votes.where((vote) => vote != null).length;
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final caught = widget.state['impostorCaught'] == true;
    final viewer = _viewer();
    final isTurn = !finished && widget.match.status == 'active' && viewer != null && widget.state['turnPlayerId'] == viewer['id'];
    final myClue = widget.match.viewerSeat < clues.length ? clues[widget.match.viewerSeat]?.toString() : null;
    final myVote = widget.match.viewerSeat < votes.length ? (votes[widget.match.viewerSeat] as num?)?.toInt() : null;
    final clueCount = clues.where((entry) => entry != null && entry.toString().isNotEmpty).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _impostorRed.withOpacity(.15), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.visibility_off_rounded, color: _impostorRed)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Impostor Light', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _ImpostorBadge(label: finished ? 'Revealed' : phase == 'clues' ? 'Clues $clueCount/${widget.match.players.length}' : 'Vote $voteCount/${widget.match.players.length}'),
          ]),
          const SizedBox(height: 12),
          _RoleCard(finished: finished, word: word, caught: caught, impostorName: impostorSeat == null ? null : _seatName(impostorSeat), isViewerImpostor: !finished && word == null),
          const SizedBox(height: 12),
          if (!finished && phase == 'clues') ...[
            for (var index = 0; index < widget.match.players.length; index += 1) ...[
              _ClueRow(name: _seatName(index), clue: index < clues.length ? clues[index]?.toString() : null, isViewer: index == widget.match.viewerSeat),
              if (index < widget.match.players.length - 1) const SizedBox(height: 7),
            ],
            const SizedBox(height: 12),
            if (myClue == null) ...[
              Row(children: [
                Expanded(child: TextField(controller: clue, enabled: isTurn, maxLength: 100, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendClue(isTurn), decoration: InputDecoration(hintText: isTurn ? 'Give a one-line clue…' : 'Waiting for your turn…', counterText: ''))),
                const SizedBox(width: 9),
                FilledButton(onPressed: isTurn ? () => _sendClue(true) : null, child: const Icon(Icons.send_rounded)),
              ]),
            ] else ...[
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: Text('Your clue is in: “$myClue”', style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w800, fontSize: 12))),
            ],
          ] else if (!finished) ...[
            Text(myVote != null ? 'Vote locked. Watching the table…' : isTurn ? 'Who is faking it? Study the clues, then strike.' : 'Waiting for the vote to reach you…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (var index = 0; index < widget.match.players.length; index += 1)
              if (index != widget.match.viewerSeat) ...[
                _SuspectRow(name: _seatName(index), clue: index < clues.length ? clues[index]?.toString() : null, selected: suspect == index, locked: myVote != null, voted: myVote == index, enabled: isTurn && myVote == null, onTap: () => setState(() => suspect = index)),
                const SizedBox(height: 7),
              ],
            const SizedBox(height: 4),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: isTurn && myVote == null && suspect != null ? () => widget.onAction({'type': 'vote', 'target': suspect}) : null, icon: const Icon(Icons.how_to_vote_rounded), label: Text(myVote != null ? 'Vote locked on ${_seatName(myVote)}' : 'Lock in vote'))),
          ] else ...[
            for (var index = 0; index < widget.match.players.length; index += 1) ...[
              _ClueRow(name: _seatName(index), clue: index < clues.length ? clues[index]?.toString() : null, isViewer: index == widget.match.viewerSeat, isImpostor: impostorSeat == index),
              if (index < widget.match.players.length - 1) const SizedBox(height: 7),
            ],
          ],
        ]),
      ),
    );
  }

  void _sendClue(bool canSend) {
    if (!canSend) return;
    final value = clue.text.trim();
    if (value.isEmpty) return;
    widget.onAction({'type': 'clue', 'clue': value});
    clue.clear();
  }

  Map<String, dynamic>? _viewer() {
    final viewers = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    return viewers.isEmpty ? null : viewers.first;
  }

  String _seatName(int seat) => seat >= 0 && seat < widget.match.players.length ? widget.match.players[seat]['displayName']?.toString() ?? 'Player' : 'Player';
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.finished, required this.word, required this.caught, required this.impostorName, required this.isViewerImpostor});
  final bool finished;
  final String? word;
  final bool caught;
  final String? impostorName;
  final bool isViewerImpostor;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;
    if (finished) {
      color = caught ? AppTheme.mint : _impostorRed;
      icon = caught ? Icons.verified_rounded : Icons.logout_rounded;
      title = caught ? 'Impostor caught!' : 'The impostor escapes!';
      subtitle = '${impostorName ?? 'Someone'} was the impostor · the word was “${(word ?? '').toUpperCase()}”';
    } else if (isViewerImpostor) {
      color = _impostorRed;
      icon = Icons.visibility_off_rounded;
      title = 'You are the IMPOSTOR 😈';
      subtitle = 'You do not know the word. Bluff a vague clue and dodge the vote.';
    } else {
      color = AppTheme.mint;
      icon = Icons.group_rounded;
      title = 'You are CREW · word: ${(word ?? '').toUpperCase()}';
      subtitle = 'Drop a clue only a crewmate would get. Do not make it too obvious.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(.4))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(.16), shape: BoxShape.circle), child: Icon(icon, color: color)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _ClueRow extends StatelessWidget {
  const _ClueRow({required this.name, required this.clue, required this.isViewer, this.isImpostor = false});
  final String name;
  final String? clue;
  final bool isViewer;
  final bool isImpostor;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: isImpostor ? _impostorRed.withOpacity(.1) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: isImpostor ? _impostorRed.withOpacity(.5) : Theme.of(context).dividerColor)),
        child: Row(children: [
          CircleAvatar(radius: 14, backgroundColor: isImpostor ? _impostorRed : _impostorRed.withOpacity(.14), child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isImpostor ? Colors.white : _impostorRed))),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${name}${isViewer ? ' (you)' : ''}${isImpostor ? ' 😈' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            Text(clue == null || clue!.isEmpty ? 'thinking…' : '“$clue”', style: TextStyle(color: clue == null || clue!.isEmpty ? Theme.of(context).disabledColor : Theme.of(context).colorScheme.onSurface, fontStyle: clue == null || clue!.isEmpty ? FontStyle.italic : FontStyle.normal, fontSize: 12)),
          ])),
        ]),
      );
}

class _SuspectRow extends StatelessWidget {
  const _SuspectRow({required this.name, required this.clue, required this.selected, required this.locked, required this.voted, required this.enabled, required this.onTap});
  final String name;
  final String? clue;
  final bool selected;
  final bool locked;
  final bool voted;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: selected || voted ? _impostorRed.withOpacity(.14) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected || voted ? _impostorRed : Theme.of(context).dividerColor, width: selected || voted ? 2 : 1)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              if (clue != null && clue!.isNotEmpty) Text('“$clue”', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
            ])),
            if (voted) const Icon(Icons.check_circle_rounded, color: _impostorRed),
            if (!voted && locked) Icon(Icons.lock_rounded, size: 16, color: Theme.of(context).disabledColor),
            if (!voted && !locked && selected) const Icon(Icons.radio_button_checked_rounded, color: _impostorRed),
          ]),
        ),
      );
}

class _ImpostorBadge extends StatelessWidget {
  const _ImpostorBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: _impostorRed.withOpacity(.14), borderRadius: BorderRadius.circular(12)), child: Text(label, style: const TextStyle(color: _impostorRed, fontWeight: FontWeight.w900, fontSize: 12)));
}
