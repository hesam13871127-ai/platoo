import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_components.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';

class GameTutorial {
  const GameTutorial({required this.goalEn, required this.goalFa, required this.controlsEn, required this.controlsFa});
  final String goalEn;
  final String goalFa;
  final String controlsEn;
  final String controlsFa;

  static GameTutorial forGame(String id) => _tutorials[id] ?? const GameTutorial(
        goalEn: 'Reach the game objective before the other players.',
        goalFa: 'پیش از بازیکنان دیگر به هدف بازی برس.',
        controlsEn: 'Tap the highlighted board or action controls to play your turn.',
        controlsFa: 'برای انجام نوبت روی صفحه یا کنترل‌های مشخص‌شده ضربه بزن.',
      );

  static const _tutorials = <String, GameTutorial>{
    'ocho': GameTutorial(goalEn: 'Empty your hand first.', goalFa: 'اول دستت را خالی کن.', controlsEn: 'Tap a legal card, draw when needed, and choose a color for a wild card.', controlsFa: 'روی کارت مجاز بزن، در صورت نیاز کارت بکش و برای کارت وحشی رنگ انتخاب کن.'),
    'pool_8_ball': GameTutorial(goalEn: 'Pocket your group, then the 8-ball.', goalFa: 'مهره‌های گروهت و بعد توپ ۸ را وارد پاکت کن.', controlsEn: 'Set power, aim, call a pocket, and submit the shot.', controlsFa: 'قدرت و هدف را تنظیم کن، پاکت را انتخاب کن و ضربه را ثبت کن.'),
    'ludo': GameTutorial(goalEn: 'Move all four tokens home first.', goalFa: 'هر چهار مهره‌ات را زودتر به خانه برسان.', controlsEn: 'Roll, then tap a highlighted token. Pass when no move is legal.', controlsFa: 'تاس بینداز و مهره روشن‌شده را انتخاب کن؛ اگر حرکتی نداری رد کن.'),
    'chess': GameTutorial(goalEn: 'Checkmate the opposing king.', goalFa: 'شاه حریف را مات کن.', controlsEn: 'Tap a piece, then tap a legal destination square.', controlsFa: 'مهره را لمس کن و سپس خانه مقصد مجاز را لمس کن.'),
    'four_in_a_row': GameTutorial(goalEn: 'Connect four pieces in a line.', goalFa: 'چهار مهره را در یک خط به هم وصل کن.', controlsEn: 'Tap a column to drop your piece.', controlsFa: 'برای انداختن مهره روی یک ستون بزن.'),
    'werewolf': GameTutorial(goalEn: 'Your hidden team must survive and win the vote.', goalFa: 'تیم مخفی تو باید زنده بماند و رأی‌گیری را ببرد.', controlsEn: 'Choose a night action or vote during the day.', controlsFa: 'شب اقدام کن و روز به یک بازیکن رأی بده.'),
    'dominoes': GameTutorial(goalEn: 'Play all your tiles or finish with the lowest hand.', goalFa: 'همه مهره‌هایت را بازی کن یا با کمترین امتیاز تمام کن.', controlsEn: 'Tap a matching tile, choose a side, or draw when blocked.', controlsFa: 'مهره همسان را انتخاب کن، سمت آن را بزن یا هنگام بن‌بست بکش.'),
    'carrom': GameTutorial(goalEn: 'Pocket your coins and cover the queen.', goalFa: 'مهره‌هایت را وارد پاکت کن و ملکه را پوشش بده.', controlsEn: 'Select coins, set power, then strike.', controlsFa: 'مهره‌ها را انتخاب کن، قدرت را تنظیم کن و ضربه بزن.'),
    'backgammon': GameTutorial(goalEn: 'Bear all fifteen checkers off the board first.', goalFa: 'هر پانزده مهره را زودتر از تخته خارج کن.', controlsEn: 'Roll, tap a checker, then tap a legal point. Pass if blocked.', controlsFa: 'تاس بینداز، مهره و سپس خانه مجاز را لمس کن؛ اگر بسته بود رد کن.'),
    'checkers': GameTutorial(goalEn: 'Capture every opposing piece or block it.', goalFa: 'همه مهره‌های حریف را بگیر یا راهش را ببند.', controlsEn: 'Tap a piece, then its highlighted destination. Continue captures when required.', controlsFa: 'مهره و مقصد روشن را لمس کن؛ در زنجیره گرفتن ادامه بده.'),
    'bingo': GameTutorial(goalEn: 'Complete a line on your card.', goalFa: 'یک خط کامل روی کارتت بساز.', controlsEn: 'The active player draws; called numbers mark automatically.', controlsFa: 'بازیکن فعال شماره می‌کشد و شماره‌های اعلام‌شده خودکار علامت می‌خورند.'),
    'sea_battle': GameTutorial(goalEn: 'Sink the opponent fleet.', goalFa: 'ناوگان حریف را غرق کن.', controlsEn: 'Place five ships, then tap a square on the enemy grid to fire.', controlsFa: 'پنج کشتی را بچین و سپس برای شلیک خانه‌ای از شبکه حریف را بزن.'),
  };
}

class GameTutorialSheet extends StatelessWidget {
  const GameTutorialSheet({super.key, required this.game});
  final GameDescriptor game;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final info = GameTutorial.forGame(game.id);
    final fa = strings.isPersian;
    final gameName = strings.gameName(game.id, game.name);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 16),
            Row(children: [
              GameLogo(gameId: game.id, accent: game.accent, size: 48),
              const SizedBox(width: 12),
              Expanded(child: VibeText('${strings.tutorialTitle} · $gameName', style: Theme.of(context).textTheme.titleLarge)),
            ]),
            const SizedBox(height: 18),
            _GuideLine(icon: Icons.flag_rounded, color: AppTheme.mint, title: strings.tutorialGoal, body: fa ? info.goalFa : info.goalEn),
            const SizedBox(height: 10),
            _GuideLine(icon: Icons.touch_app_rounded, color: AppTheme.violet, title: strings.tutorialControls, body: fa ? info.controlsFa : info.controlsEn),
            const SizedBox(height: 10),
            _GuideLine(icon: Icons.timer_outlined, color: AppTheme.gold, title: strings.turnClock, body: strings.tutorialClock),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: VibeText(strings.tutorialGotIt)),
          ],
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.icon, required this.color, required this.title, required this.body});
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(.25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.16), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [VibeText(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), VibeText(body, style: TextStyle(fontSize: 12, height: 1.35, color: Theme.of(context).colorScheme.onSurfaceVariant))])),
        ]),
      );
}
