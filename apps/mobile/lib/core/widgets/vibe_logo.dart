import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VibeLogo extends StatelessWidget {
  const VibeLogo({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Transform.translate(offset: const Offset(3, 5), child: _mark(const Color(0xFF3B2B9F))),
          Transform.translate(offset: const Offset(1, 2), child: _mark(AppTheme.coral)),
          _mark(AppTheme.violet),
        ]),
        if (!compact) ...[
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
            child: const Text('VibeTable', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.9)),
          ),
        ],
      ]);
  Widget _mark(Color color) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, .16)!, color, Color.lerp(color, Colors.black, .22)!], stops: const [0, .55, 1]),
          boxShadow: [BoxShadow(color: color.withOpacity(.38), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Stack(children: [const Center(child: Icon(Icons.bolt_rounded, color: Colors.white, size: 22)), Positioned(top: 5, left: 7, child: Container(width: 13, height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(.4), borderRadius: BorderRadius.circular(99))))]),
      );
}

/// A single premium art system for the entire catalog.  It uses vector shapes
/// instead of remote bitmaps, so game art stays crisp, fast, and available
/// offline.  Each tile has the same depth treatment while the inset emblem is
/// specific to the game rather than a repeated generic icon.
class GameLogo extends StatelessWidget {
  const GameLogo({super.key, required this.gameId, required this.accent, this.size = 58});
  final String gameId;
  final String accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _color(accent);
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(left: -size * .22, top: -size * .22, child: Container(width: size * 1.44, height: size * 1.44, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withOpacity(.42), color.withOpacity(0)])))),
      Transform.translate(offset: Offset(size * .06, size * .1), child: _tile(color.withOpacity(.32), ghost: true)),
      Transform.translate(offset: Offset(size * .025, size * .045), child: _tile(color.withOpacity(.62), ghost: true)),
      _tile(color),
    ]);
  }

  Widget _tile(Color color, {bool ghost = false}) {
    final radius = size * .3;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, .24)!, Color.lerp(color, Colors.white, .04)!, color, Color.lerp(color, Colors.black, .34)!], stops: const [0, .35, .68, 1]),
        border: ghost ? null : Border.all(color: Colors.white.withOpacity(.3), width: size * .02),
        boxShadow: ghost
            ? null
            : [BoxShadow(color: color.withOpacity(.55), blurRadius: size * .32, offset: Offset(0, size * .16)), BoxShadow(color: Colors.black.withOpacity(.28), blurRadius: size * .12, offset: Offset(0, size * .05))],
      ),
      child: Stack(
        children: [
          if (!ghost)
            Positioned(top: 0, left: 0, right: 0, child: Container(height: size * .44, decoration: BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(radius)), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withOpacity(.32), Colors.white.withOpacity(0)])))),
          if (!ghost) Positioned(top: size * .13, left: size * .17, child: Container(width: size * .3, height: size * .1, decoration: BoxDecoration(color: Colors.white.withOpacity(.5), borderRadius: BorderRadius.circular(99)))),
          Center(
            child: _hasCustomArt(gameId)
                ? SizedBox(width: size * .64, height: size * .64, child: CustomPaint(painter: _GameArtPainter(gameId: gameId, color: Colors.white, shadow: !ghost)))
                : Icon(_icon(gameId), color: Colors.white, size: size * .46, shadows: ghost ? null : [Shadow(color: Colors.black.withOpacity(.32), blurRadius: size * .06, offset: Offset(0, size * .03))]),
          ),
        ],
      ),
    );
  }

  Color _color(String hex) {
    final value = hex.replaceFirst('#', '');
    final parsed = int.tryParse('FF$value', radix: 16);
    return parsed == null ? AppTheme.violet : Color(parsed);
  }

  IconData _icon(String id) => switch (id) {
        'chess' => Icons.grid_on_rounded,
        'checkers' => Icons.grid_4x4_rounded,
        'four_in_a_row' => Icons.view_week_rounded,
        'pool_8_ball' => Icons.sports_bar_rounded,
        'ludo' => Icons.casino_rounded,
        'dominoes' => Icons.view_module_rounded,
        'backgammon' => Icons.casino_rounded,
        'bingo' => Icons.confirmation_num_rounded,
        'sea_battle' => Icons.directions_boat_rounded,
        'mancala' => Icons.circle_rounded,
        'mini_golf' => Icons.golf_course_rounded,
        'table_soccer' => Icons.sports_soccer_rounded,
        'archery' => Icons.gps_fixed_rounded,
        'bowling' => Icons.sports_rounded,
        'darts' => Icons.adjust_rounded,
        'hearts' => Icons.favorite_rounded,
        'spades' => Icons.style_rounded,
        'werewolf' => Icons.nightlife_rounded,
        'trivia_battle' => Icons.quiz_rounded,
        'sketch_guess' => Icons.brush_rounded,
        'emoji_charades' => Icons.emoji_emotions_rounded,
        'word_chain' => Icons.translate_rounded,
        'memory_race' => Icons.memory_rounded,
        'impostor_light' => Icons.visibility_off_rounded,
        'quick_challenges' => Icons.bolt_rounded,
        _ => Icons.style_rounded,
      };
}

bool _hasCustomArt(String id) => const {
      'ocho', 'pool_8_ball', 'ludo', 'chess', 'four_in_a_row', 'werewolf',
      'dominoes', 'carrom', 'backgammon', 'checkers', 'bingo', 'sea_battle',
      'mancala', 'hearts', 'spades', 'darts', 'bowling', 'archery', 'mini_golf',
    }.contains(id);

class _GameArtPainter extends CustomPainter {
  const _GameArtPainter({required this.gameId, required this.color, required this.shadow});
  final String gameId;
  final Color color;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 48;
    canvas.save();
    canvas.scale(scale, scale);
    final paint = Paint()..isAntiAlias = true;
    if (shadow) {
      paint.color = Colors.black.withOpacity(.24);
      canvas.drawCircle(const Offset(24, 26), 16, paint);
    }
    paint.color = color;
    paint.style = PaintingStyle.fill;
    switch (gameId) {
      case 'chess':
        _chess(canvas, paint);
        break;
      case 'checkers':
        _checkers(canvas, paint);
        break;
      case 'four_in_a_row':
        _connect(canvas, paint);
        break;
      case 'pool_8_ball':
        _pool(canvas, paint);
        break;
      case 'ocho':
        _cards(canvas, paint);
        break;
      case 'ludo':
        _ludo(canvas, paint);
        break;
      case 'dominoes':
        _domino(canvas, paint);
        break;
      case 'carrom':
        _carrom(canvas, paint);
        break;
      case 'backgammon':
        _backgammon(canvas, paint);
        break;
      case 'sea_battle':
        _sea(canvas, paint);
        break;
      case 'bingo':
        _bingo(canvas, paint);
        break;
      case 'mancala':
        _mancala(canvas, paint);
        break;
      case 'hearts':
        _heart(canvas, paint);
        break;
      case 'spades':
        _spade(canvas, paint);
        break;
      case 'werewolf':
        _moon(canvas, paint);
        break;
      case 'darts':
        _dart(canvas, paint);
        break;
      case 'bowling':
        _bowling(canvas, paint);
        break;
      case 'archery':
        _archery(canvas, paint);
        break;
      case 'mini_golf':
        _golf(canvas, paint);
        break;
    }
    canvas.restore();
  }

  void _chess(Canvas c, Paint p) {
    p.color = color.withOpacity(.92);
    final dark = color.withOpacity(.32);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        p.color = (row + col).isEven ? color : dark;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(8 + col * 8, 8 + row * 8, 8, 8), const Radius.circular(1.5)), p);
      }
    }
    p.color = color;
    c.drawCircle(const Offset(24, 23), 5, p);
    c.drawRect(const Rect.fromLTWH(19, 25, 10, 10), p);
    c.drawRect(const Rect.fromLTWH(17, 35, 14, 3), p);
  }

  void _checkers(Canvas c, Paint p) {
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        p.color = (row + col).isEven ? color.withOpacity(.22) : color;
        c.drawRect(Rect.fromLTWH(7 + col * 9, 7 + row * 9, 9, 9), p);
      }
    }
    p.color = color;
    c.drawCircle(const Offset(16, 16), 5, p);
    p.color = color.withOpacity(.42);
    c.drawCircle(const Offset(32, 32), 5, p);
  }

  void _connect(Canvas c, Paint p) {
    for (var column = 0; column < 4; column++) {
      for (var row = 0; row < 2; row++) {
        p.color = (column + row).isEven ? color : color.withOpacity(.38);
        c.drawCircle(Offset(11 + column * 8.7, 17 + row * 13), 3.2, p);
      }
    }
  }

  void _pool(Canvas c, Paint p) {
    p.color = color.withOpacity(.25);
    c.drawCircle(const Offset(16, 25), 7, p);
    p.color = color;
    c.drawCircle(const Offset(31, 20), 7, p);
    p.color = Colors.black.withOpacity(.72);
    c.drawCircle(const Offset(31, 20), 4, p);
    p.color = color.withOpacity(.85);
    c.drawCircle(const Offset(31, 20), 1.5, p);
    p.color = color;
    c.drawLine(const Offset(7, 37), const Offset(19, 27), Paint()..color = color..strokeWidth = 3.2..strokeCap = StrokeCap.round);
  }

  void _cards(Canvas c, Paint p) {
    final left = Path()..moveTo(11, 9)..lineTo(28, 9)..lineTo(28, 34)..lineTo(11, 34)..close();
    c.drawPath(left, p);
    p.color = color.withOpacity(.48);
    final right = Path()..moveTo(20, 14)..lineTo(37, 14)..lineTo(37, 39)..lineTo(20, 39)..close();
    c.drawPath(right, p);
    p.color = color;
    _heart(c, p, center: const Offset(19, 20), radius: 4);
  }

  void _ludo(Canvas c, Paint p) {
    p.color = color.withOpacity(.26);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, 8, 32, 32), const Radius.circular(7)), p);
    p.color = color;
    c.drawCircle(const Offset(15, 15), 4, p);
    p.color = color.withOpacity(.62);
    c.drawCircle(const Offset(33, 33), 4, p);
    p.color = color;
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(19, 19, 10, 10), const Radius.circular(2)), p);
    p.color = color.withOpacity(.35);
    for (final dot in [const Offset(22, 22), const Offset(26, 26)]) c.drawCircle(dot, 1.2, p);
  }

  void _domino(Canvas c, Paint p) {
    p.color = color;
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 6, 20, 36), const Radius.circular(5)), p);
    p.color = color.withOpacity(.3);
    c.drawRect(const Rect.fromLTWH(15, 23, 18, 2), p);
    p.color = Colors.black.withOpacity(.5);
    for (final dot in [const Offset(20, 14), const Offset(28, 18), const Offset(20, 31), const Offset(28, 35)]) c.drawCircle(dot, 2, p);
  }

  void _carrom(Canvas c, Paint p) {
    p.color = color.withOpacity(.25);
    c.drawCircle(const Offset(24, 24), 17, p);
    p.color = color;
    c.drawCircle(const Offset(24, 24), 5, p);
    p.color = color.withOpacity(.58);
    for (final point in [const Offset(12, 12), const Offset(36, 12), const Offset(12, 36), const Offset(36, 36)]) c.drawCircle(point, 3, p);
    p.color = color;
    c.drawCircle(const Offset(24, 40), 3, p);
  }

  void _backgammon(Canvas c, Paint p) {
    p.color = color.withOpacity(.27);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(7, 6, 34, 36), const Radius.circular(4)), p);
    p.color = color;
    for (var i = 0; i < 3; i++) {
      final path = Path()..moveTo(10 + i * 10, 9)..lineTo(15 + i * 10, 23)..lineTo(10 + i * 10, 39)..close();
      c.drawPath(path, p);
    }
    p.color = color.withOpacity(.5);
    for (var i = 0; i < 3; i++) c.drawCircle(Offset(32, 13 + i * 9.0), 3, p);
  }

  void _sea(Canvas c, Paint p) {
    p.color = color;
    final ship = Path()..moveTo(10, 24)..lineTo(38, 24)..lineTo(33, 33)..lineTo(16, 33)..close();
    c.drawPath(ship, p);
    c.drawRect(const Rect.fromLTWH(22, 12, 2, 13), p);
    final sail = Path()..moveTo(24, 13)..lineTo(35, 23)..lineTo(24, 23)..close();
    c.drawPath(sail, p);
    final wave = Paint()..color = color.withOpacity(.5)..style = PaintingStyle.stroke..strokeWidth = 2.2;
    for (var y = 37; y < 43; y += 4) c.drawArc(Rect.fromLTWH(8, y.toDouble() - 3, 32, 8), 0, math.pi, false, wave);
  }

  void _bingo(Canvas c, Paint p) {
    p.color = color;
    c.drawCircle(const Offset(24, 23), 14, p);
    p.color = Colors.black.withOpacity(.45);
    c.drawCircle(const Offset(24, 23), 9, p);
    _text(c, 'B', const Offset(24, 24), Colors.white, 14);
  }

  void _mancala(Canvas c, Paint p) {
    p.color = color.withOpacity(.24);
    c.drawOval(const Rect.fromLTWH(5, 14, 11, 20), p);
    c.drawOval(const Rect.fromLTWH(31, 14, 11, 20), p);
    p.color = color;
    for (var row = 0; row < 2; row++) for (var col = 0; col < 3; col++) c.drawCircle(Offset(18 + col * 6.5, 19 + row * 10), 2.5, p);
  }

  void _heart(Canvas c, Paint p, {Offset center = const Offset(24, 25), double radius = 10}) {
    final path = Path()..moveTo(center.dx, center.dy + radius)..cubicTo(center.dx - radius * 1.4, center.dy, center.dx - radius, center.dy - radius, center.dx - radius * .45, center.dy - radius * .45)..cubicTo(center.dx, center.dy - radius * 1.05, center.dx, center.dy - radius * 1.05, center.dx, center.dy - radius * .35)..cubicTo(center.dx, center.dy - radius * 1.05, center.dx, center.dy - radius * 1.05, center.dx + radius * .45, center.dy - radius * .45)..cubicTo(center.dx + radius, center.dy - radius, center.dx + radius * 1.4, center.dy, center.dx, center.dy + radius)..close();
    c.drawPath(path, p);
  }

  void _spade(Canvas c, Paint p) {
    p.color = color;
    final path = Path()..moveTo(24, 8)..cubicTo(10, 19, 12, 27, 21, 28)..lineTo(18, 38)..lineTo(30, 38)..lineTo(27, 28)..cubicTo(36, 27, 38, 19, 24, 8)..close();
    c.drawPath(path, p);
  }

  void _moon(Canvas c, Paint p) {
    p.color = color;
    c.drawCircle(const Offset(24, 23), 14, p);
    p.color = Colors.black.withOpacity(.28);
    c.drawCircle(const Offset(30, 18), 14, p);
    p.color = color;
    c.drawCircle(const Offset(19, 24), 1.7, p);
    c.drawCircle(const Offset(28, 24), 1.7, p);
    c.drawArc(const Rect.fromLTWH(18, 23, 12, 9), 0, math.pi, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8);
  }

  void _dart(Canvas c, Paint p) {
    p.color = color.withOpacity(.25);
    c.drawCircle(const Offset(26, 23), 13, p);
    p.color = color;
    c.drawCircle(const Offset(26, 23), 7, p);
    c.drawCircle(const Offset(26, 23), 2.3, Paint()..color = Colors.black.withOpacity(.45));
    c.drawLine(const Offset(8, 38), const Offset(25, 24), Paint()..color = color..strokeWidth = 3..strokeCap = StrokeCap.round);
  }

  void _bowling(Canvas c, Paint p) {
    p.color = color;
    c.drawCircle(const Offset(22, 27), 12, p);
    p.color = Colors.black.withOpacity(.45);
    c.drawCircle(const Offset(18, 23), 2.3, p);
    c.drawCircle(const Offset(24, 20), 2.3, p);
    c.drawCircle(const Offset(24, 27), 2.3, p);
  }

  void _archery(Canvas c, Paint p) {
    final ring = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3;
    c.drawCircle(const Offset(24, 24), 15, ring);
    ring.color = color.withOpacity(.5);
    c.drawCircle(const Offset(24, 24), 8, ring);
    p.color = color;
    c.drawCircle(const Offset(24, 24), 2.5, p);
    c.drawLine(const Offset(8, 39), const Offset(23, 25), Paint()..color = color..strokeWidth = 2.8..strokeCap = StrokeCap.round);
  }

  void _golf(Canvas c, Paint p) {
    p.color = color.withOpacity(.25);
    c.drawOval(const Rect.fromLTWH(9, 27, 30, 11), p);
    p.color = color;
    c.drawCircle(const Offset(31, 17), 6, p);
    c.drawLine(const Offset(29, 21), const Offset(18, 38), Paint()..color = color..strokeWidth = 2.4..strokeCap = StrokeCap.round);
  }

  void _text(Canvas c, String value, Offset center, Color textColor, double fontSize) {
    final painter = TextPainter(text: TextSpan(text: value, style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
    painter.paint(c, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GameArtPainter oldDelegate) => false;
}

/// Idle-animated game logo for hero moments (featured banner, match setup,
/// queue): one lightweight looping controller drives a gentle float plus a
/// barely-there rock. The logo subtree itself is built once and composited,
/// so the animation stays at 60fps. Keep it off dense grids.
class FloatingGameLogo extends StatefulWidget {
  const FloatingGameLogo({super.key, required this.gameId, required this.accent, this.size = 96, this.floatRange = 5, this.period = const Duration(milliseconds: 2600)});
  final String gameId;
  final String accent;
  final double size;
  final double floatRange;
  final Duration period;
  @override
  State<FloatingGameLogo> createState() => _FloatingGameLogoState();
}

class _FloatingGameLogoState extends State<FloatingGameLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final t = _curve.value * 2 - 1;
          return Transform.translate(offset: Offset(0, widget.floatRange * t), child: Transform.rotate(angle: .03 * t, child: child));
        },
        child: GameLogo(gameId: widget.gameId, accent: widget.accent, size: widget.size),
      );
}

class BalancePill extends StatelessWidget {
  const BalancePill({super.key, required this.value, required this.icon, required this.color});
  final int value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(.16), color.withOpacity(.07)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(.35)),
          boxShadow: [BoxShadow(color: color.withOpacity(.18), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(_format(value), style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14))]),
      );
  String _format(int value) => value >= 1000000 ? '${(value / 1000000).toStringAsFixed(1)}M' : value >= 1000 ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K' : '$value';
}
