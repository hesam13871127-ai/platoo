import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_components.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';

class GameRulesSheet extends StatelessWidget {
  const GameRulesSheet({super.key, required this.game});
  final GameDescriptor game;

  static void show(BuildContext context, GameDescriptor game) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameRulesSheet(game: game),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final fa = strings.isPersian;
    final info = _rulesData[game.id] ?? _defaultRules(game, fa);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: dark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(dark ? .3 : .15)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  GameLogo(gameId: game.id, accent: game.accent, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VibeText(game.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                        const SizedBox(height: 2),
                        VibeText(
                          fa ? 'راهنما و قوانین رسمی' : 'How to play & official rules',
                          style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.violet.withOpacity(.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: VibeText('${game.minPlayers}–${game.maxPlayers} ${fa ? 'بازیکن' : 'players'}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppTheme.violet),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RuleSection(
                        icon: Icons.flag_rounded,
                        color: AppTheme.mint,
                        title: fa ? 'هدف بازی' : 'Objective',
                        description: fa ? info.objectiveFa : info.objectiveEn,
                      ),
                      const SizedBox(height: 12),
                      _RuleSection(
                        icon: Icons.touch_app_rounded,
                        color: AppTheme.violet,
                        title: fa ? 'نحوه بازی و کنترل‌ها' : 'How to Play',
                        description: fa ? info.howToPlayFa : info.howToPlayEn,
                      ),
                      const SizedBox(height: 12),
                      _RuleSection(
                        icon: Icons.emoji_events_rounded,
                        color: AppTheme.gold,
                        title: fa ? 'شرایط پیروزی' : 'Winning Condition',
                        description: fa ? info.winningConditionFa : info.winningConditionEn,
                      ),
                      if (info.tipsEn.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _RuleSection(
                          icon: Icons.lightbulb_rounded,
                          color: AppTheme.coral,
                          title: fa ? 'نکات کلیدی و استراتژی' : 'Pro Tips',
                          description: fa ? info.tipsFa : info.tipsEn,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              VibePrimaryButton(
                onPressed: () => Navigator.of(context).pop(),
                label: fa ? 'متوجه شدم، بزن بریم!' : 'Got it, let’s play!',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({required this.icon, required this.color, required this.title, required this.description});
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => VibeCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VibeText(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
                  const SizedBox(height: 4),
                  VibeText(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _RuleInfo {
  const _RuleInfo({
    required this.objectiveEn,
    required this.objectiveFa,
    required this.howToPlayEn,
    required this.howToPlayFa,
    required this.winningConditionEn,
    required this.winningConditionFa,
    this.tipsEn = '',
    this.tipsFa = '',
  });

  final String objectiveEn;
  final String objectiveFa;
  final String howToPlayEn;
  final String howToPlayFa;
  final String winningConditionEn;
  final String winningConditionFa;
  final String tipsEn;
  final String tipsFa;
}

_RuleInfo _defaultRules(GameDescriptor game, bool isFa) => _RuleInfo(
      objectiveEn: 'Outscore or outplay your opponents in ${game.name}.',
      objectiveFa: 'امتیاز بیشتری نسبت به حریفان کسب کن و برنده میز شو.',
      howToPlayEn: 'Take turns according to the table timer. Tap valid board cells or controls to make your move.',
      howToPlayFa: 'در نوبت خود روی خانه‌ها یا دکمه‌های مجاز ضربه بزن تا حرکتت ثبت شود.',
      winningConditionEn: 'Meet the victory goal first or achieve the highest score at table close.',
      winningConditionFa: 'اولین بازیکنی باش که به هدف تعیین شده می‌رسد یا بیشترین امتیاز را دارد.',
      tipsEn: 'Watch your turn clock and keep an eye on opponent movements.',
      tipsFa: 'زمان نوبتت را مدیریت کن و حرکات حریف را زیر نظر بگیر.',
    );

final _rulesData = <String, _RuleInfo>{
  'ocho': const _RuleInfo(
    objectiveEn: 'Be the first player to discard all cards from your hand.',
    objectiveFa: 'اولین بازیکنی باش که تمام کارت‌های دستش را تمام می‌کند.',
    howToPlayEn: 'Match the top card on the discard pile by color or number. Play 8s anytime as wildcards to change the suit. Special action cards reverse order, skip turns, or make opponents draw +2 / +4.',
    howToPlayFa: 'کارت همرنگ یا هم‌شماره با کارت روی زمین را بینداز. کارت عدد ۸ حکم کارت وحشی (Wild) را دارد و رنگ بازی را تغییر می‌دهد.',
    winningConditionEn: 'Empty your hand before any other player at the table.',
    winningConditionFa: 'تمام کردن تمام کارت‌های دست پیش از رقبا.',
    tipsEn: 'Save your Wild 8s and +4 cards for when you are forced into a tight color match!',
    tipsFa: 'کارت‌های ۸ و +۴ را برای لحظات حساس و مسدود کردن حریف نگه دار!',
  ),
  'four_in_a_row': const _RuleInfo(
    objectiveEn: 'Connect four of your color discs in a row vertically, horizontally, or diagonally.',
    objectiveFa: 'چهار دیسک همرنگ را در یک ردیف افقی، عمودی یا مورب متصل کن.',
    howToPlayEn: 'Players take turns dropping a disc into one of the 7 columns. The disc falls to the lowest available slot in that column.',
    howToPlayFa: 'در هر نوبت یک دیسک در یکی از ۷ ستون بینداز تا در پایین‌ترین جای خالی بنشیند.',
    winningConditionEn: 'First player to form an uninterrupted line of 4 discs wins immediately.',
    winningConditionFa: 'تشکیل اولین خط پیوسته ۴تایی.',
    tipsEn: 'Control the center column (column 4) early to maximize winning diagonal branches.',
    tipsFa: 'کنترل ستون وسط (ستون ۴) بیشترین فرصت بردهای مورب را به تو می‌دهد.',
  ),
  'ludo': const _RuleInfo(
    objectiveEn: 'Navigate all 4 of your tokens from the base around the board into the home column.',
    objectiveFa: 'هر ۴ مهره خود را از خانه به دور صفحه بچرخان و وارد خانه نهایی کن.',
    howToPlayEn: 'Roll a 6 to bring a token onto the track. Advance tokens according to dice rolls. Landing on an opponent sends their token back to their base!',
    howToPlayFa: 'با تاس ۶ مهره را وارد زمین کن. در صورت فرود روی مهره حریف، مهره او زده شده و به خانه بازمی‌گردد.',
    winningConditionEn: 'First player or team to bring all 4 tokens home takes the trophy.',
    winningConditionFa: 'رساندن هر ۴ مهره به مقصد نهایی.',
    tipsEn: 'Keep safe tokens on star tiles and strike trailing opponents whenever possible.',
    tipsFa: 'از خانه‌های امن ستاره‌دار استفاده کن و مهره‌های حریف را شکار کن.',
  ),
  'chess': const _RuleInfo(
    objectiveEn: 'Checkmate the opponent’s King while defending your own pieces.',
    objectiveFa: 'شاه حریف را مات کن و از مهره‌های خودت دفاع کن.',
    howToPlayEn: 'Move pieces according to traditional FIDE rules. Tap a piece to highlight valid move paths, then tap the destination square.',
    howToPlayFa: 'بر اساس قوانین شطرنج استاندارد بازی کن. روی مهره ضربه بزن و خانه مقصد را انتخاب کن.',
    winningConditionEn: 'Checkmate, resignation by opponent, or timeout by opponent.',
    winningConditionFa: 'کیش و مات، تسلیم حریف، یا اتمام زمان نوبت حریف.',
    tipsEn: 'Develop your knights and bishops early and secure King safety with castling.',
    tipsFa: 'اسب‌ها و فیل‌ها را سریع گسترش بده و با قلعه رفتن شاهت را امن کن.',
  ),
  'pool_8_ball': const _RuleInfo(
    objectiveEn: 'Pocket all your designated balls (solids or stripes) and then legally pocket the 8-ball.',
    objectiveFa: 'تمام توپ‌های گروهت (تک‌رنگ یا دو‌رنگ) را پاکت کن و سپس توپ مشکی (۸) را بینداز.',
    howToPlayEn: 'Drag to adjust aim angle and power slider, then release to strike the cue ball.',
    howToPlayFa: 'با کشیدن زاویه چوب و لغزنده قدرت ضربه بزن.',
    winningConditionEn: 'Pocketing the 8-ball legally after clearing all assigned balls.',
    winningConditionFa: 'انداختن صحیح توپ ۸ پس از پاکت کردن تمام توپ‌های گروه خود.',
    tipsEn: 'Always plan your cue ball resting position for the next shot.',
    tipsFa: 'موقعیت توقف توپ سفید را برای ضربه بعدی برنامه‌ریزی کن.',
  ),
  'dominoes': const _RuleInfo(
    objectiveEn: 'Play matching domino tiles from your hand onto the table layout ends.',
    objectiveFa: 'دومینوهای هماهنگ را به دو سر باز زنجیره دومینو متصل کن.',
    howToPlayEn: 'Place a tile with a matching pip count to an open chain end. If you have no match, draw from the boneyard until a move is possible.',
    howToPlayFa: 'دومینویی که عدد نقطه‌ایش با سرهای باز یکی است را بازی کن. اگر حرکتی نداری از مخزن کارت بکش.',
    winningConditionEn: 'First player to empty their hand or have the lowest pip total when blocked.',
    winningConditionFa: 'اولین بازیکنی که دستش خالی شود یا در بن‌بست کمترین امتیاز را داشته باشد.',
    tipsEn: 'Try to play high-pip doubles early so you are not left with heavy points if blocked.',
    tipsFa: 'جفت‌های عددی سنگین را زودتر بازی کن تا در صورت بن‌بست جریمه نشوی.',
  ),
  'carrom': const _RuleInfo(
    objectiveEn: 'Pocket carrom coins (carrom men) using your striker and pocket the Queen coin.',
    objectiveFa: 'مهره‌های کرم را با استریکر پاکت کن و مهره ملکه (قرمز) را با کاور ببند.',
    howToPlayEn: 'Position your striker on the baseline, set direction and flick power to pocket your coins.',
    howToPlayFa: 'استریکر را روی خط بیس قرار بده و زاویه و قدرت پرتاب را تعیین کن.',
    winningConditionEn: 'Clear all assigned carrom pieces and cover the Queen for maximum points.',
    winningConditionFa: 'پاکت کردن تمام مهره‌ها و کاور کردن موفق ملکه.',
    tipsEn: 'Use board rebounds and bank shots to pocket difficult corner coins.',
    tipsFa: 'از ضربات بازگشتی از دیواره (بانک شات) برای گوشه‌ها استفاده کن.',
  ),
  'sea_battle': const _RuleInfo(
    objectiveEn: 'Locate and sink all hidden ships in the enemy fleet before they sink yours.',
    objectiveFa: 'تمام کشتی‌های ناوگان دشمن را قبل از غرق شدن ناوگان خودت پیدا و منهدم کن.',
    howToPlayEn: 'Tap a grid cell to fire a torpedo. "Hit" reveals ship damage and gives an extra shot.',
    howToPlayFa: 'روی مختصات دشمن شلیک کن. در صورت اصابت، یک شلیک جایزه دریافت می‌کنی.',
    winningConditionEn: 'Destroy every enemy vessel (Carrier, Battleship, Cruiser, Submarine, Destroyer).',
    winningConditionFa: 'غرق کردن تمامی کشتی‌های ناوگان حریف.',
    tipsEn: 'Fire in a checkerboard pattern to find large ships faster.',
    tipsFa: 'به صورت شطرنجی شلیک کن تا کشتی‌های بزرگ سریع‌تر پیدا شوند.',
  ),
  'backgammon': const _RuleInfo(
    objectiveEn: 'Move all 15 checkers around the board and bear them off before your opponent.',
    objectiveFa: 'تمام ۱۵ مهره‌ات را دور تخته به خانه برسان و زودتر از حریف خارج کن.',
    howToPlayEn: 'Roll two dice and move checkers forward along the triangular points. Hit single blot pieces to send them to the bar.',
    howToPlayFa: 'با تاس حرکت کن. مهره‌های تک حریف را بزن تا به روی بار بروند.',
    winningConditionEn: 'First player to bear off all 15 checkers wins the match.',
    winningConditionFa: 'اولین بازیکنی که هر ۱۵ مهره را از صفحه خارج کند.',
    tipsEn: 'Build anchors (2+ checkers) in your home board to block opponent entry.',
    tipsFa: 'در خانه خود خانه‌های جفت (۲ مهره یا بیشتر) بساز تا راه حریف بسته شود.',
  ),
  'checkers': const _RuleInfo(
    objectiveEn: 'Capture all opposing checkers or block all valid moves for your opponent.',
    objectiveFa: 'تمام مهره‌های حریف را بزن یا راه حرکت او را کاملاً مسدود کن.',
    howToPlayEn: 'Move diagonally forward onto dark squares. Jump over opposing pieces to capture them. Reach the last rank to crown a King with backward-moving power.',
    howToPlayFa: 'به صورت مورب به جلو حرکت کن. از روی مهره حریف بپری تا زده شود. با رسیدن به انتهای صفحه شاه شو.',
    winningConditionEn: 'Capture all opponent pieces or leave opponent with zero legal moves.',
    winningConditionFa: 'زدن تمام مهره‌های حریف یا قفل کردن کامل حریف.',
    tipsEn: 'Keep your back row intact to prevent opponent pieces from getting crowned Kings.',
    tipsFa: 'ردیف آخر خودت را تا حد امکان نگه دار تا حریف شاه نشود.',
  ),
  'mancala': const _RuleInfo(
    objectiveEn: 'Collect the most stones in your right-side Kalah (store pit).',
    objectiveFa: 'بیشترین تعداد مهره را در کالای (مخزن) سمت راست خود جمع‌آوری کن.',
    howToPlayEn: 'Pick up stones from one of your pits and sow one stone counter-clockwise in each pit. Landing the last stone in your Kalah grants an extra turn!',
    howToPlayFa: 'مهره‌های یک گودال را بردار و پادساعت‌گرد پخش کن. اگر آخرین مهره در کالایت بیفتد نوبت اضافه داری.',
    winningConditionEn: 'Having the highest stone count in your Kalah when one player’s side is empty.',
    winningConditionFa: 'بیشترین تعداد مهره در مخزن هنگام تمام شدن مهره‌های یک سمت.',
    tipsEn: 'Set up combo chains by planning moves where the last stone drops in your store.',
    tipsFa: 'حرکاتی را انتخاب کن که مهره آخر در مخزن بیفتد تا نوبت‌های متوالی بگیری.',
  ),
};
