import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class MiniGolfGameBoard extends StatefulWidget {
  const MiniGolfGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<MiniGolfGameBoard> createState() => _MiniGolfGameBoardState();
}

class _MiniGolfGameBoardState extends State<MiniGolfGameBoard> {
  int strokes = 3;

  @override
  void didUpdateWidget(covariant MiniGolfGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) strokes = 3;
  }

  @override
  Widget build(BuildContext context) {
    final hole = (widget.state['hole'] as num?)?.toInt() ?? 1;
    final holes = (widget.state['holes'] as num?)?.toInt() ?? 9;
    final pars = _numbers(widget.state['pars']);
    final totals = _numbers(widget.state['strokes']);
    final holeStrokes = (widget.state['holeStrokes'] as List? ?? const []).map((value) => (value as num?)?.toInt()).toList();
    final viewer = _viewer;
    final isTurn = widget.match.status == 'active' && viewer != null && widget.state['turnPlayerId'] == viewer['id'];
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final par = hole > 0 && hole <= pars.length ? pars[hole - 1] : 4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.15), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.golf_course_rounded, color: AppTheme.mint)),
            const SizedBox(width: 10),
            const Expanded(child: VibeText('Mini Golf', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _GolfBadge(label: 'Hole $hole / $holes'),
          ]),
          const SizedBox(height: 12),
          VibeText(finished ? 'Lowest total score wins.' : isTurn ? 'Your turn · choose how many strokes this hole takes.' : 'Each player completes the hole before the next hole starts.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _Course(hole: hole, par: par, lastStroke: widget.state['lastStroke'] as Map?),
          const SizedBox(height: 13),
          _ScoreTable(match: widget.match, totals: totals, holeStrokes: holeStrokes, viewerSeat: widget.match.viewerSeat),
          const SizedBox(height: 13),
          if (isTurn && !finished) ...[
            Row(children: [
              const VibeText('Strokes', style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(onPressed: strokes > 1 ? () => setState(() => strokes -= 1) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
              Container(width: 48, alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.13), borderRadius: BorderRadius.circular(12)), child: VibeText('$strokes', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.mint))),
              IconButton(onPressed: strokes < 12 ? () => setState(() => strokes += 1) : null, icon: const Icon(Icons.add_circle_outline_rounded)),
            ]),
            FilledButton.icon(onPressed: () => widget.onAction({'type': 'putt', 'strokes': strokes}), icon: const Icon(Icons.sports_golf_rounded), label: VibeText('Putt in $strokes')),
          ] else if (!finished) VibeText('Waiting for the active player to finish this hole…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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

class _GolfBadge extends StatelessWidget {
  const _GolfBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.14), borderRadius: BorderRadius.circular(12)), child: VibeText(label, style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w900, fontSize: 12)));
}

class _Course extends StatelessWidget {
  const _Course({required this.hole, required this.par, required this.lastStroke});
  final int hole;
  final int par;
  final Map? lastStroke;

  @override
  Widget build(BuildContext context) => Container(
    height: 142,
    decoration: BoxDecoration(color: const Color(0xFF195E4B), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 7, offset: Offset(0, 3))]),
    child: Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _MiniGolfPainter(hole: hole))),
      Positioned(left: 15, top: 13, child: VibeText('PAR $par', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 11))),
      if (lastStroke != null) Positioned(right: 15, top: 13, child: VibeText('Last: ${lastStroke!['strokes'] ?? '-'}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11))),
    ]),
  );
}

class _MiniGolfPainter extends CustomPainter {
  const _MiniGolfPainter({required this.hole});
  final int hole;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final fairway = Paint()..color = const Color(0xFF7BCB77)..style = PaintingStyle.stroke..strokeWidth = 27..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(width * .13, height * .75)
      ..cubicTo(width * .30, height * .06, width * .63, height * .95, width * .85, height * .29);
    canvas.drawPath(path, fairway);
    final edge = Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawPath(path, edge);
    final holePaint = Paint()..color = const Color(0xFF123B32);
    canvas.drawCircle(Offset(width * .85, height * .29), 9, holePaint);
    final flag = Paint()..color = AppTheme.coral..strokeWidth = 2;
    canvas.drawLine(Offset(width * .85, height * .29), Offset(width * .85, height * .29 - 31), flag);
    final flagPath = Path()..moveTo(width * .85, height * .29 - 31)..lineTo(width * .85 + 18, height * .29 - 25)..lineTo(width * .85, height * .29 - 18)..close();
    canvas.drawPath(flagPath, Paint()..color = AppTheme.coral);
    canvas.drawCircle(Offset(width * .13, height * .75), 6, Paint()..color = Colors.white);
    final dots = Paint()..color = Colors.white24;
    for (var index = 0; index < 5; index += 1) canvas.drawCircle(Offset(width * (.2 + index * .14), height * (.18 + (index.isEven ? .03 : .0))), 2, dots);
  }

  @override
  bool shouldRepaint(covariant _MiniGolfPainter oldDelegate) => oldDelegate.hole != hole;
}

class _ScoreTable extends StatelessWidget {
  const _ScoreTable({required this.match, required this.totals, required this.holeStrokes, required this.viewerSeat});
  final MatchModel match;
  final List<int> totals;
  final List<int?> holeStrokes;
  final int viewerSeat;

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      const Expanded(child: VibeText('PLAYER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5))),
      const SizedBox(width: 60, child: VibeText('HOLE', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5))),
      const SizedBox(width: 60, child: VibeText('TOTAL', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5))),
    ]),
    const Divider(height: 14),
    for (var index = 0; index < match.players.length; index += 1) ...[
      Row(children: [
        Expanded(child: Row(children: [if (index == viewerSeat) const Icon(Icons.person_rounded, size: 16, color: AppTheme.mint), if (index == viewerSeat) const SizedBox(width: 4), Flexible(child: VibeText(match.players[index]['displayName']?.toString() ?? 'Player ${index + 1}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)))])),
        SizedBox(width: 60, child: VibeText(holeStrokes.length > index && holeStrokes[index] != null ? '${holeStrokes[index]}' : '—', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
        SizedBox(width: 60, child: VibeText(totals.length > index ? '${totals[index]}' : '0', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.mint))),
      ]),
      if (index < match.players.length - 1) const SizedBox(height: 9),
    ],
  ]);
}
