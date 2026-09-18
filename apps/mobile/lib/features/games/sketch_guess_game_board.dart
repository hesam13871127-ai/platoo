import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class SketchGuessGameBoard extends StatefulWidget {
  const SketchGuessGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<SketchGuessGameBoard> createState() => _SketchGuessGameBoardState();
}

class _SketchGuessGameBoardState extends State<SketchGuessGameBoard> {
  final TextEditingController guess = TextEditingController();
  List<List<Offset>> localStrokes = <List<Offset>>[];
  List<Offset> currentStroke = <Offset>[];

  @override
  void didUpdateWidget(covariant SketchGuessGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) {
      localStrokes = <List<Offset>>[];
      currentStroke = <Offset>[];
      guess.clear();
    }
  }

  @override
  void dispose() {
    guess.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.state['phase']?.toString() ?? 'drawing';
    final drawerIndex = (widget.state['drawerIndex'] as num?)?.toInt() ?? 0;
    final isDrawer = widget.match.viewerSeat == drawerIndex;
    final viewer = _viewer;
    final isTurn = widget.match.status == 'active' && viewer != null && widget.state['turnPlayerId'] == viewer['id'];
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final scores = _numbers(widget.state['scores']);
    final drawing = isDrawer && phase == 'drawing' ? localStrokes : _serverStrokes;
    final prompt = widget.state['prompt']?.toString();
    final round = (widget.state['round'] as num?)?.toInt() ?? 1;
    final rounds = (widget.state['rounds'] as num?)?.toInt() ?? widget.match.players.length;
    final guesses = (widget.state['guesses'] as List? ?? const []).where((value) => value != null).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.14), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.brush_rounded, color: AppTheme.violet)),
            const SizedBox(width: 10),
            const Expanded(child: VibeText('Sketch & Guess', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            _SketchBadge(label: 'Round $round / $rounds'),
          ]),
          const SizedBox(height: 12),
          if (phase == 'drawing' && isDrawer && prompt != null) _PromptBanner(prompt: prompt),
          if (phase == 'drawing' && !isDrawer) VibeText('The drawer is sketching a secret prompt…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12)),
          if (phase == 'guessing') VibeText(isDrawer ? 'Your sketch is live · wait for the guesses.' : 'What did the drawer draw? First correct guess scores three points.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12)),
          if (phase == 'guessing') ...[const SizedBox(height: 8), VibeText('$guesses guess${guesses == 1 ? '' : 'es'} received', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))],
          const SizedBox(height: 12),
          _SketchPad(strokes: drawing, enabled: phase == 'drawing' && isDrawer && isTurn && !finished, onStrokesChanged: (value) => setState(() => localStrokes = value)),
          const SizedBox(height: 12),
          if (phase == 'drawing' && isDrawer && isTurn && !finished) Row(children: [
            OutlinedButton.icon(onPressed: () => setState(() => localStrokes = <List<Offset>>[]), icon: const Icon(Icons.delete_sweep_rounded), label: const VibeText('Clear')),
            const SizedBox(width: 9),
            Expanded(child: FilledButton.icon(onPressed: localStrokes.isEmpty ? null : () => widget.onAction({'type': 'draw', 'strokes': _wireStrokes(localStrokes)}), icon: const Icon(Icons.send_rounded), label: const VibeText('Submit sketch'))),
          ]),
          if (phase == 'drawing' && !isDrawer) VibeText('You will get the first guess when the sketch is submitted.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          if (phase == 'guessing' && !isDrawer && isTurn && !finished) ...[
            TextField(controller: guess, maxLength: 40, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendGuess(), decoration: const InputDecoration(hintText: 'Type your guess', counterText: '')),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _sendGuess, icon: const Icon(Icons.lightbulb_rounded), label: const VibeText('Submit guess'))),
          ],
          if (phase == 'guessing' && (isDrawer || !isTurn) && !finished) VibeText(isDrawer ? 'Guesses appear here as players try.' : 'Waiting for the next guess…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          if (finished) ...[const SizedBox(height: 4), VibeText('All prompts are complete. Highest score wins.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12))],
          const SizedBox(height: 14),
          _SketchScores(match: widget.match, scores: scores, viewerSeat: widget.match.viewerSeat),
        ]),
      ),
    );
  }

  void _sendGuess() {
    final value = guess.text.trim();
    if (value.isEmpty) return;
    widget.onAction({'type': 'guess', 'guess': value});
  }

  Map<String, dynamic>? get _viewer {
    final viewers = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    return viewers.isEmpty ? null : viewers.first;
  }

  List<List<Offset>> get _serverStrokes {
    final raw = widget.state['drawing'] as List? ?? const [];
    return raw.whereType<List>().map((stroke) => stroke.whereType<List>().map((point) {
      if (point.length < 2) return Offset.zero;
      return Offset(((point[0] as num?)?.toDouble() ?? 0) / 1000, ((point[1] as num?)?.toDouble() ?? 0) / 1000);
    }).toList()).where((stroke) => stroke.length > 1).toList();
  }

  List<int> _numbers(dynamic value) => (value as List? ?? const []).map((item) => (item as num?)?.toInt() ?? 0).toList();

  List<List<List<double>>> _wireStrokes(List<List<Offset>> strokes) => strokes.where((stroke) => stroke.length > 1).map((stroke) => stroke.map((point) => [math.max(0, math.min(1000, point.dx * 1000)).toDouble(), math.max(0, math.min(1000, point.dy * 1000)).toDouble()]).toList()).toList();
}

class _SketchPad extends StatelessWidget {
  const _SketchPad({required this.strokes, required this.enabled, required this.onStrokesChanged});
  final List<List<Offset>> strokes;
  final bool enabled;
  final ValueChanged<List<List<Offset>>> onStrokesChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    const height = 220.0;
    final width = constraints.maxWidth;
    return GestureDetector(
      onPanStart: enabled ? (details) => onStrokesChanged([...strokes, [_point(details.localPosition, width, height)]]) : null,
      onPanUpdate: enabled ? (details) {
        if (strokes.isEmpty) return;
        final next = strokes.map((stroke) => [...stroke]).toList();
        next[next.length - 1] = [...next.last, _point(details.localPosition, width, height)];
        onStrokesChanged(next);
      } : null,
      onPanEnd: enabled ? (_) {
        if (strokes.isNotEmpty && strokes.last.length < 2) onStrokesChanged(strokes.sublist(0, strokes.length - 1));
      } : null,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(color: const Color(0xFFFCFBFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: enabled ? AppTheme.violet.withOpacity(.5) : Theme.of(context).dividerColor, width: 1.5)),
        child: CustomPaint(painter: _SketchPainter(strokes: strokes)),
      ),
    );
  });

  Offset _point(Offset point, double width, double height) => Offset((point.dx / width).clamp(0.0, 1.0).toDouble(), (point.dy / height).clamp(0.0, 1.0).toDouble());
}

class _SketchPainter extends CustomPainter {
  const _SketchPainter({required this.strokes});
  final List<List<Offset>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.ink..style = PaintingStyle.stroke..strokeWidth = 3.2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final point in stroke.skip(1)) path.lineTo(point.dx * size.width, point.dy * size.height);
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => oldDelegate.strokes != strokes;
}

class _PromptBanner extends StatelessWidget {
  const _PromptBanner({required this.prompt});
  final String prompt;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.16), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.gold.withOpacity(.45))), child: Row(children: [const Icon(Icons.visibility_off_rounded, size: 18, color: AppTheme.gold), const SizedBox(width: 8), const VibeText('Draw this:', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(width: 5), Expanded(child: VibeText(prompt, style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.gold)))]));
}

class _SketchBadge extends StatelessWidget {
  const _SketchBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.13), borderRadius: BorderRadius.circular(12)), child: VibeText(label, style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w900, fontSize: 12)));
}

class _SketchScores extends StatelessWidget {
  const _SketchScores({required this.match, required this.scores, required this.viewerSeat});
  final MatchModel match;
  final List<int> scores;
  final int viewerSeat;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 7, runSpacing: 7, children: [for (var index = 0; index < match.players.length; index += 1) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: index == viewerSeat ? AppTheme.violet.withOpacity(.13) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: index == viewerSeat ? AppTheme.violet.withOpacity(.3) : Theme.of(context).dividerColor)), child: VibeText('${match.players[index]['displayName']?.toString() ?? 'Player'} · ${scores.length > index ? scores[index] : 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))]);
}
