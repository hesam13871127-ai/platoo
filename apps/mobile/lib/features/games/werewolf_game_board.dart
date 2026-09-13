import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
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
    final viewerSeat = widget.match.viewerSeat.clamp(0, roles.isEmpty ? 0 : roles.length - 1).toInt();
    final viewer = widget.match.players.where((player) => player['seat'] == viewerSeat).toList();
    final viewerId = viewer.isEmpty ? null : viewer.first['id']?.toString();
    final role = roles.length > viewerSeat ? roles[viewerSeat] : 'hidden';
    final phase = widget.state['phase']?.toString() ?? 'night';
    final isTurn = widget.match.status == 'active' && viewerId != null && widget.state['turnPlayerId'] == viewerId;
    final seerResult = _seerResult(viewerSeat);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_roleIcon(role), color: _roleColor(role)),
            const SizedBox(width: 8),
            const Text('Werewolf', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            _PhaseChip(label: phase == 'night' ? 'Night ${widget.state['nightNumber'] ?? 1}' : 'Day', night: phase == 'night'),
          ]),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _roleColor(role).withOpacity(.12), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(_roleIcon(role), color: _roleColor(role)), const SizedBox(width: 9), Expanded(child: Text('Your role: ${_roleLabel(role)}', style: const TextStyle(fontWeight: FontWeight.w900))), if (widget.match.status == 'finished') Text(widget.match.winnerIds.contains(viewerId) ? 'Winner' : 'Defeated', style: const TextStyle(fontWeight: FontWeight.w800))])),
          if (seerResult != null) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.16), borderRadius: BorderRadius.circular(12)), child: Text('Seer vision: ${_playerName((seerResult['target'] as num).toInt())} is ${seerResult['isWerewolf'] == true ? 'a werewolf' : 'not a werewolf'}.', style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
          if (widget.state['lastEvent'] != null) ...[
            const SizedBox(height: 10),
            Text(widget.state['lastEvent'].toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 14),
          Text(_instruction(phase, role, isTurn), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _PlayerList(roles: roles, alive: alive, selectedTarget: selectedTarget, viewerSeat: viewerSeat, isTurn: isTurn, phase: phase, role: role, nightActed: _boolList(widget.state['nightActed']), votes: _nullableIntList(widget.state['votes']), onSelect: (seat) => setState(() => selectedTarget = selectedTarget == seat ? null : seat), playerName: _playerName),
          const SizedBox(height: 14),
          if (widget.match.status == 'finished')
            Text(widget.match.winnerIds.contains(viewerId) ? 'Your faction won the village.' : 'Your faction lost the village.', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.gold))
          else if (isTurn && phase == 'night' && role == 'villager')
            FilledButton.icon(onPressed: () => _submitNight(null), icon: const Icon(Icons.nightlight_round), label: const Text('Wait through the night'))
          else if (isTurn)
            FilledButton.icon(onPressed: selectedTarget == null ? null : () => phase == 'night' ? _submitNight(selectedTarget) : _submitVote(selectedTarget!), icon: Icon(phase == 'night' ? Icons.nightlight_round : Icons.how_to_vote_rounded), label: Text(phase == 'night' ? 'Submit night action' : 'Cast vote'))
          else
            Text('Waiting for ${_turnName()}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
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

  Color _roleColor(String role) => switch (role) {
    'werewolf' => const Color(0xFF8B5CF6),
    'seer' => AppTheme.gold,
    'doctor' => AppTheme.mint,
    'villager' => AppTheme.coral,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  IconData _roleIcon(String role) => switch (role) {
    'werewolf' => Icons.nightlife_rounded,
    'seer' => Icons.visibility_rounded,
    'doctor' => Icons.medical_services_rounded,
    'villager' => Icons.home_rounded,
    _ => Icons.help_outline_rounded,
  };

  String _roleLabel(String role) => switch (role) {
    'werewolf' => 'Werewolf',
    'seer' => 'Seer',
    'doctor' => 'Doctor',
    'villager' => 'Villager',
    _ => 'Hidden',
  };
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({required this.roles, required this.alive, required this.selectedTarget, required this.viewerSeat, required this.isTurn, required this.phase, required this.role, required this.nightActed, required this.votes, required this.onSelect, required this.playerName});
  final List<String> roles;
  final List<bool> alive;
  final int? selectedTarget;
  final int viewerSeat;
  final bool isTurn;
  final String phase;
  final String role;
  final List<bool> nightActed;
  final List<int?> votes;
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
    final roleText = visibleRole == 'hidden' ? 'role hidden' : _label(visibleRole);
    final acted = phase == 'night' ? (seat < nightActed.length && nightActed[seat]) : (seat < votes.length && votes[seat] != null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: selectable ? () => onSelect(seat) : null,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(color: selectedTarget == seat ? AppTheme.violet.withOpacity(.15) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: selectedTarget == seat ? AppTheme.violet : Theme.of(context).dividerColor, width: selectedTarget == seat ? 1.6 : .7)),
          child: Row(children: [
            CircleAvatar(radius: 17, backgroundColor: isAlive ? (seat.isEven ? AppTheme.coral : AppTheme.violet).withOpacity(.16) : Colors.black12, child: Icon(isAlive ? Icons.person_rounded : Icons.person_off_rounded, size: 18, color: isAlive ? (seat.isEven ? AppTheme.coral : AppTheme.violet) : Colors.black38)),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${playerName(seat)}${isSelf ? ' (you)' : ''}', style: TextStyle(fontWeight: FontWeight.w900, color: isAlive ? null : Theme.of(context).disabledColor)), Text(roleText, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))])),
            if (acted) const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.mint),
            if (!isAlive) const Text('out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }

  String _label(String value) => switch (value) {
    'werewolf' => 'werewolf',
    'seer' => 'seer',
    'doctor' => 'doctor',
    'villager' => 'villager',
    _ => 'role hidden',
  };
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.label, required this.night});
  final String label;
  final bool night;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: (night ? const Color(0xFF34235E) : AppTheme.gold).withOpacity(.18), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(night ? Icons.nightlight_round : Icons.wb_sunny_rounded, size: 15, color: night ? const Color(0xFF8B5CF6) : AppTheme.gold), const SizedBox(width: 5), Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))]));
}
