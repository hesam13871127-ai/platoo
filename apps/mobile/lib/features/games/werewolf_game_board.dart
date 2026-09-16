import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_components.dart';
import '../../models/models.dart';

class WerewolfGameBoard extends StatefulWidget {
  const WerewolfGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<WerewolfGameBoard> createState() => _WerewolfGameBoardState();
}

class _WerewolfGameBoardState extends State<WerewolfGameBoard> {
  int? selectedTarget;

  @override
  void didUpdateWidget(covariant WerewolfGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final alive = _alive;
    if (oldWidget.match.revision != widget.match.revision || (selectedTarget != null && (selectedTarget! >= alive.length || !alive[selectedTarget!]))) selectedTarget = null;
  }

  @override
  Widget build(BuildContext context) {
    final roles = (widget.state['roles'] as List? ?? const []).map((role) => role.toString()).toList();
    final alive = _alive;
    final aliveCount = alive.where((value) => value).length;
    final viewerSeat = widget.match.viewerSeat.clamp(0, roles.isEmpty ? 0 : roles.length - 1).toInt();
    final viewer = widget.match.players.where((player) => player['seat'] == viewerSeat).toList();
    final viewerId = viewer.isEmpty ? null : viewer.first['id']?.toString();
    final role = roles.length > viewerSeat ? roles[viewerSeat] : 'hidden';
    final phase = widget.state['phase']?.toString() ?? 'night';
    final night = phase == 'night';
    final isTurn = widget.match.status == 'active' && viewerId != null && widget.state['turnPlayerId'] == viewerId;
    final seerResult = _seerResult(viewerSeat);
    final votes = _nullableIntList(widget.state['votes']);
    final myVote = viewerSeat < votes.length ? votes[viewerSeat] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(gradient: night ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5B3FA8), Color(0xFF2A1B52)]) : AppTheme.goldGradient, borderRadius: BorderRadius.circular(13), boxShadow: AppTheme.glow(night ? const Color(0xFF8B5CF6) : AppTheme.gold, strength: .35)), child: Icon(night ? Icons.nightlight_round : Icons.wb_sunny_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          VibeText('Werewolf', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          _PhaseChip(label: night ? 'Night ${widget.state['nightNumber'] ?? 1}' : 'Day', night: night),
          const SizedBox(width: 7),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppTheme.mint.withOpacity(.3))), child: VibeText('$aliveCount alive', style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w900, fontSize: 12))),
        ]),
        const SizedBox(height: 11),
        _RoleCard(role: role, finished: widget.match.status == 'finished', won: widget.match.winnerIds.contains(viewerId)),
        if (seerResult != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.gold.withOpacity(.2), AppTheme.gold.withOpacity(.08)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.gold.withOpacity(.4))),
            child: Row(children: [Container(width: 34, height: 34, alignment: Alignment.center, decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle), child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 18)), const SizedBox(width: 10), Expanded(child: VibeText('Seer vision: ${_playerName((seerResult['target'] as num).toInt())} is ${seerResult['isWerewolf'] == true ? 'a WEREWOLF' : 'NOT a werewolf'}.', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)))]),
          ),
        ],
        if (widget.state['lastEvent'] != null) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.45), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(Icons.auto_stories_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 8), Expanded(child: VibeText(widget.state['lastEvent'].toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic, fontSize: 12.5)))])),
        ],
        const SizedBox(height: 13),
        _StatusDot(text: _instruction(phase, role, isTurn), active: isTurn, finished: widget.match.status == 'finished'),
        const SizedBox(height: 10),
        _PlayerList(roles: roles, alive: alive, selectedTarget: selectedTarget, viewerSeat: viewerSeat, isTurn: isTurn, phase: phase, role: role, finished: widget.match.status == 'finished', nightActed: _boolList(widget.state['nightActed']), votes: votes, myVote: myVote, onSelect: (seat) => setState(() => selectedTarget = selectedTarget == seat ? null : seat), playerName: _playerName),
        const SizedBox(height: 13),
        if (widget.match.status == 'finished')
          _ResultBanner(won: widget.match.winnerIds.contains(viewerId))
        else if (isTurn && night && role == 'villager')
          VibePrimaryButton(onPressed: () => _submitNight(null), icon: Icons.nightlight_round, label: 'Wait through the night')
        else if (isTurn)
          VibePrimaryButton(onPressed: selectedTarget == null ? null : () => night ? _submitNight(selectedTarget) : _submitVote(selectedTarget!), icon: night ? Icons.nightlight_round : Icons.how_to_vote_rounded, label: night ? 'Submit night action' : 'Cast vote')
        else
          VibeText('Waiting for ${_turnName()}…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  List<bool> get _alive => (widget.state['alive'] as List? ?? const []).map((value) => value == true).toList();

  List<bool> _boolList(dynamic value) => (value as List? ?? const []).map((item) => item == true).toList();

  List<int?> _nullableIntList(dynamic value) => (value as List? ?? const []).map((item) => item is num ? item.toInt() : null).toList();

  Map<String, dynamic>? _seerResult(int seat) {
    final results = widget.state['seerResults'] as List? ?? const [];
    if (seat >= results.length || results[seat] is! Map) return null;
    return Map<String, dynamic>.from(results[seat] as Map);
  }

  String _instruction(String phase, String role, bool isTurn) {
    if (widget.match.status == 'finished') return 'The village has reached a final verdict.';
    if (!isTurn) return 'The active player is making a decision.';
    if (phase == 'night' && role == 'villager') return 'You are a villager. Confirm that you are awake, then wait.';
    if (phase == 'night') return 'Choose a living player for your role, then submit your night action.';
    return 'Choose another living player to eliminate by vote.';
  }

  void _submitNight(int? target) {
    // Keep the target visible until a newer revision confirms the action.
    widget.onAction(target == null ? {'type': 'night'} : {'type': 'night', 'target': target});
  }

  void _submitVote(int target) {
    widget.onAction({'type': 'vote', 'target': target});
  }

  String _turnName() {
    final turn = widget.match.players.where((player) => player['id'] == widget.state['turnPlayerId']).toList();
    return turn.isEmpty ? 'the next player' : turn.first['displayName']?.toString() ?? 'the next player';
  }

  String _playerName(int seat) {
    final player = widget.match.players.where((candidate) => candidate['seat'] == seat).toList();
    return player.isEmpty ? 'Player ${seat + 1}' : player.first['displayName']?.toString() ?? 'Player ${seat + 1}';
  }
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.finished, required this.won});
  final String role;
  final bool finished;
  final bool won;

  Color get color => switch (role) {
        'werewolf' => const Color(0xFF8B5CF6),
        'seer' => AppTheme.gold,
        'doctor' => AppTheme.mint,
        'villager' => AppTheme.coral,
        _ => const Color(0xFF8B93A7),
      };

  IconData get icon => switch (role) {
        'werewolf' => Icons.nightlife_rounded,
        'seer' => Icons.visibility_rounded,
        'doctor' => Icons.medical_services_rounded,
        'villager' => Icons.home_rounded,
        _ => Icons.help_outline_rounded,
      };

  String get label => switch (role) {
        'werewolf' => 'Werewolf',
        'seer' => 'Seer',
        'doctor' => 'Doctor',
        'villager' => 'Villager',
        _ => 'Hidden',
      };

  String get blurb => switch (role) {
        'werewolf' => 'Each night, pick a victim with the pack. Survive the day votes.',
        'seer' => 'Each night, inspect one player to learn if they are a werewolf.',
        'doctor' => 'Each night, protect one player from the werewolf attack.',
        'villager' => 'No night power. Watch, reason, and vote by day.',
        _ => 'Your role is hidden.',
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, Color.lerp(color, Colors.black, .3)!]), borderRadius: BorderRadius.circular(18), boxShadow: AppTheme.glow(color, strength: .4)),
        child: Row(children: [
          Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white.withOpacity(.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.5), width: 1.5)), child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const VibeText('YOUR ROLE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)), VibeText(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)), VibeText(blurb, style: const TextStyle(color: Colors.white70, fontSize: 11.5))])),
          if (finished) Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(.22), borderRadius: BorderRadius.circular(99)), child: VibeText(won ? 'Winner' : 'Defeated', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
        ]),
      );
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({required this.roles, required this.alive, required this.selectedTarget, required this.viewerSeat, required this.isTurn, required this.phase, required this.role, required this.finished, required this.nightActed, required this.votes, required this.myVote, required this.onSelect, required this.playerName});
  final List<String> roles;
  final List<bool> alive;
  final int? selectedTarget;
  final int viewerSeat;
  final bool isTurn;
  final String phase;
  final String role;
  final bool finished;
  final List<bool> nightActed;
  final List<int?> votes;
  final int? myVote;
  final ValueChanged<int> onSelect;
  final String Function(int) playerName;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var seat = 0; seat < alive.length; seat += 1) _playerTile(context, seat),
      ]);

  Widget _playerTile(BuildContext context, int seat) {
    final isAlive = alive[seat];
    final isSelf = seat == viewerSeat;
    final selectable = isAlive && isTurn && (phase == 'day' ? !isSelf : role != 'villager' && (role != 'werewolf' || !isSelf));
    final visibleRole = roles.length > seat ? roles[seat] : 'hidden';
    final selected = selectedTarget == seat;
    final acted = phase == 'night' ? (seat < nightActed.length && nightActed[seat]) : (seat < votes.length && votes[seat] != null);
    final votedTarget = phase == 'day' && myVote == seat;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: PressableScale(
        onTap: selectable ? () => onSelect(seat) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.violet.withOpacity(.14) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: selected ? AppTheme.violet : votedTarget ? AppTheme.gold : Theme.of(context).dividerColor, width: selected || votedTarget ? 1.8 : .8),
            boxShadow: selected ? AppTheme.glow(AppTheme.violet, strength: .3) : null,
          ),
          child: Row(children: [
            _Avatar(name: playerName(seat), alive: isAlive),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Flexible(child: VibeText(playerName(seat), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: isAlive ? null : Theme.of(context).disabledColor))), if (isSelf) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.14), borderRadius: BorderRadius.circular(99)), child: const VibeText('you', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.violet)))]),
                  const SizedBox(height: 3),
                  _RoleLine(role: visibleRole, reveal: finished || isSelf),
                ],
              ),
            ),
            if (votedTarget) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.15), borderRadius: BorderRadius.circular(99)), child: const VibeText('your vote', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.gold))),
            if (acted && !votedTarget) const Icon(Icons.check_circle_rounded, size: 19, color: AppTheme.mint),
            if (!isAlive) ...[const SizedBox(width: 7), const VibeText('out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))],
          ]),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.alive});
  final String name;
  final bool alive;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: alive ? 1 : .45,
        child: Stack(alignment: Alignment.center, children: [
          VibeInitial(name: name, radius: 19),
          if (!alive) const Icon(Icons.close_rounded, size: 20, color: Colors.white),
        ]),
      );
}

class _RoleLine extends StatelessWidget {
  const _RoleLine({required this.role, required this.reveal});
  final String role;
  final bool reveal;
  @override
  Widget build(BuildContext context) {
    if (!reveal || role == 'hidden') return VibeText('role hidden', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant));
    final color = switch (role) {
      'werewolf' => const Color(0xFF8B5CF6),
      'seer' => AppTheme.gold,
      'doctor' => AppTheme.mint,
      'villager' => AppTheme.coral,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(99)), child: VibeText(role, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color)));
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.label, required this.night});
  final String label;
  final bool night;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: (night ? const Color(0xFF34235E) : AppTheme.gold).withOpacity(.2), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(night ? Icons.nightlight_round : Icons.wb_sunny_rounded, size: 15, color: night ? const Color(0xFF8B5CF6) : AppTheme.gold), const SizedBox(width: 5), VibeText(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))]));
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.won});
  final bool won;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(gradient: won ? AppTheme.goldGradient : null, color: won ? null : Theme.of(context).colorScheme.surfaceVariant.withOpacity(.5), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [Icon(won ? Icons.celebration_rounded : Icons.nights_stay_rounded, color: won ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 9), Expanded(child: VibeText(won ? 'Your faction won the village.' : 'Your faction lost the village.', style: TextStyle(fontWeight: FontWeight.w900, color: won ? Colors.white : null)))]),
      );
}
