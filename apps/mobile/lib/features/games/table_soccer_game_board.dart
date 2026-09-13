import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class TableSoccerGameBoard extends StatefulWidget {
  const TableSoccerGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<TableSoccerGameBoard> createState() => _TableSoccerGameBoardState();
}

class _TableSoccerGameBoardState extends State<TableSoccerGameBoard> {
  double power = 70;
  double aim = 50;

  @override
  void didUpdateWidget(covariant TableSoccerGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) {
      power = 70;
      aim = 50;
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = _numbers(widget.state['goals']);
    final teamGoals = _numbers(widget.state['teamGoals']);
    final teamMode = widget.state['teamMode'] == true;
    final target = (widget.state['target'] as num?)?.toInt() ?? 5;
    final viewer = _viewer;
    final isTurn = widget.match.status == 'active' && viewer != null && widget.state['turnPlayerId'] == viewer['id'];
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final lastShot = widget.state['lastShot'] as Map?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppTheme.coral.withOpacity(.14), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.sports_soccer_rounded, color: AppTheme.coral)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Table Soccer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _SoccerBadge(label: 'First to $target'),
          ]),
          const SizedBox(height: 12),
          Text(finished ? 'The final whistle has blown.' : isTurn ? 'Your turn · line up the shot and fire.' : 'Aim for the center of the goal. First to $target goals wins.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _Scoreboard(match: widget.match, goals: goals, teamGoals: teamGoals, teamMode: teamMode, viewerSeat: widget.match.viewerSeat),
          const SizedBox(height: 12),
          Container(height: 162, decoration: BoxDecoration(color: const Color(0xFF237D5A), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF15563F), width: 5)), child: CustomPaint(painter: const _SoccerFieldPainter())),
          if (lastShot != null) ...[
            const SizedBox(height: 9),
            Row(children: [Icon(lastShot['scored'] == true ? Icons.sports_score_rounded : Icons.shield_outlined, size: 18, color: lastShot['scored'] == true ? AppTheme.mint : AppTheme.gold), const SizedBox(width: 6), Text(lastShot['scored'] == true ? 'Goal!' : 'Saved by the keeper', style: const TextStyle(fontWeight: FontWeight.w900))]),
          ],
          const SizedBox(height: 10),
          if (isTurn && !finished) ...[
            _SliderLine(label: 'Power', value: power, onChanged: (value) => setState(() => power = value), suffix: '${power.round()}%'),
            _SliderLine(label: 'Aim', value: aim, onChanged: (value) => setState(() => aim = value), suffix: aim < 40 ? 'Left' : aim > 60 ? 'Right' : 'Center'),
            FilledButton.icon(onPressed: () => widget.onAction({'type': 'shoot', 'power': power.round(), 'aim': aim.round()}), icon: const Icon(Icons.sports_soccer_rounded), label: const Text('Shoot')),
          ] else if (!finished) Text('Waiting for the active player to shoot…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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

class _SoccerBadge extends StatelessWidget {
  const _SoccerBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppTheme.coral.withOpacity(.14), borderRadius: BorderRadius.circular(12)), child: Text(label, style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w900, fontSize: 12)));
}

class _SliderLine extends StatelessWidget {
  const _SliderLine({required this.label, required this.value, required this.onChanged, required this.suffix});
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String suffix;
  @override
  Widget build(BuildContext context) => Row(children: [SizedBox(width: 49, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))), Expanded(child: Slider(value: value, min: 0, max: 100, divisions: 100, onChanged: onChanged)), SizedBox(width: 46, child: Text(suffix, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))]);
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.match, required this.goals, required this.teamGoals, required this.teamMode, required this.viewerSeat});
  final MatchModel match;
  final List<int> goals;
  final List<int> teamGoals;
  final bool teamMode;
  final int viewerSeat;

  @override
  Widget build(BuildContext context) => Row(children: [
    for (var index = 0; index < (teamMode ? 2 : match.players.length); index += 1) ...[
      if (index > 0) const SizedBox(width: 8),
      Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), decoration: BoxDecoration(color: index.isEven ? AppTheme.violet.withOpacity(.11) : AppTheme.coral.withOpacity(.11), borderRadius: BorderRadius.circular(13)), child: Column(children: [
        Text(teamMode ? 'TEAM ${index + 1}' : _name(index), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('${teamMode ? (teamGoals.length > index ? teamGoals[index] : 0) : (goals.length > index ? goals[index] : 0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        if (teamMode) Text(index == 0 ? 'Players 1 & 3' : 'Players 2 & 4', style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]))),
    ],
  ]);

  String _name(int seat) {
    final player = match.players.where((candidate) => candidate['seat'] == seat).toList();
    return player.isEmpty ? 'Player ${seat + 1}' : player.first['displayName']?.toString() ?? 'Player ${seat + 1}';
  }
}

class _SoccerFieldPainter extends CustomPainter {
  const _SoccerFieldPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = Colors.white70..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(10, 10, size.width - 20, size.height - 20), line);
    canvas.drawLine(Offset(size.width / 2, 10), Offset(size.width / 2, size.height - 10), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 27, line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 3, Paint()..color = Colors.white70);
    final boxHeight = size.height * .42;
    canvas.drawRect(Rect.fromLTWH(10, (size.height - boxHeight) / 2, 35, boxHeight), line);
    canvas.drawRect(Rect.fromLTWH(size.width - 45, (size.height - boxHeight) / 2, 35, boxHeight), line);
    final goal = Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 5;
    canvas.drawLine(Offset(8, size.height * .38), Offset(8, size.height * .62), goal);
    canvas.drawLine(Offset(size.width - 8, size.height * .38), Offset(size.width - 8, size.height * .62), goal);
    final ball = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width * .5, size.height * .5), 8, ball);
    canvas.drawCircle(Offset(size.width * .5, size.height * .5), 3, Paint()..color = const Color(0xFF237D5A));
  }
  @override
  bool shouldRepaint(covariant _SoccerFieldPainter oldDelegate) => false;
}
