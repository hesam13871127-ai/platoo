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

/// Premium 3D game tile: stacked depth layers, four-stop glossy gradient,
/// edge light, icon drop shadow, and an ambient halo. Same API everywhere,
/// so every game keeps a consistent high-end look in both themes.
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
          Center(child: Icon(_icon(gameId), color: Colors.white, size: size * .46, shadows: ghost ? null : [Shadow(color: Colors.black.withOpacity(.32), blurRadius: size * .06, offset: Offset(0, size * .03))])),
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
