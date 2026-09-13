import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VibeLogo extends StatelessWidget {
  const VibeLogo({super.key, this.compact = false});
  final bool compact;
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Stack(clipBehavior: Clip.none, children: [
      Transform.translate(offset: const Offset(3, 5), child: _mark(const Color(0xFF3B2B9F))),
      Transform.translate(offset: const Offset(1, 2), child: _mark(AppTheme.coral)),
      _mark(AppTheme.violet),
    ]),
    if (!compact) ...[const SizedBox(width: 12), Text('VibeTable', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.8))],
  ]);
  Widget _mark(Color color) => Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(.95), color.withOpacity(.55)]), boxShadow: [BoxShadow(color: color.withOpacity(.28), blurRadius: 9, offset: const Offset(0, 5))]), child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 23));
}

class GameLogo extends StatelessWidget {
  const GameLogo({super.key, required this.gameId, required this.accent, this.size = 58});
  final String gameId; final String accent; final double size;
  @override Widget build(BuildContext context) { final color = _color(accent); return Stack(clipBehavior: Clip.none, children: [
    Transform.translate(offset: const Offset(3, 5), child: _tile(color.withOpacity(.34))),
    Transform.translate(offset: const Offset(1, 2), child: _tile(color.withOpacity(.65))),
    _tile(color),
  ]); }
  Widget _tile(Color color) => Container(width: size, height: size, decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .27), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, Color.lerp(color, Colors.black, .27)!]), boxShadow: [BoxShadow(color: color.withOpacity(.3), blurRadius: 12, offset: const Offset(0, 7))]), child: Icon(_icon(gameId), color: Colors.white, size: size * .48));
  Color _color(String hex) { final value = hex.replaceFirst('#', ''); return Color(int.parse('FF$value', radix: 16)); }
  IconData _icon(String id) => switch (id) {
    'chess' => Icons.grid_on_rounded, 'checkers' => Icons.grid_4x4_rounded, 'four_in_a_row' => Icons.view_week_rounded, 'pool_8_ball' => Icons.sports_bar_rounded, 'ludo' => Icons.casino_rounded, 'dominoes' => Icons.view_module_rounded, 'backgammon' => Icons.casino_rounded, 'bingo' => Icons.confirmation_num_rounded, 'sea_battle' => Icons.directions_boat_rounded, 'mancala' => Icons.circle_rounded, 'mini_golf' => Icons.golf_course_rounded, 'table_soccer' => Icons.sports_soccer_rounded, 'archery' => Icons.gps_fixed_rounded, 'bowling' => Icons.sports_rounded, 'darts' => Icons.adjust_rounded, 'hearts' => Icons.favorite_rounded, 'spades' => Icons.style_rounded, 'werewolf' => Icons.nightlife_rounded, 'trivia_battle' => Icons.quiz_rounded, 'sketch_guess' => Icons.brush_rounded, 'emoji_charades' => Icons.emoji_emotions_rounded, 'word_chain' => Icons.translate_rounded, 'memory_race' => Icons.memory_rounded, 'impostor_light' => Icons.visibility_off_rounded, 'quick_challenges' => Icons.bolt_rounded, _ => Icons.style_rounded,
  };
}

class BalancePill extends StatelessWidget {
  const BalancePill({super.key, required this.value, required this.icon, required this.color});
  final int value; final IconData icon; final Color color;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(.11), borderRadius: BorderRadius.circular(14)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(_format(value), style: TextStyle(fontWeight: FontWeight.w800, color: color))]));
  String _format(int value) => value >= 1000000 ? '${(value / 1000000).toStringAsFixed(1)}M' : value >= 1000 ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K' : '$value';
}
