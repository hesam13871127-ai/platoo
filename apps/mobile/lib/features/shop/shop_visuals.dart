import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shop categories are the same six the database enum defines, so a card, a
/// filter chip and the admin panel always agree on labels and colors.
class ShopCategory {
  const ShopCategory({required this.key, required this.en, required this.fa, required this.icon, required this.accent});
  final String key; final String en; final String fa; final IconData icon; final Color accent;
  String label(bool persian) => persian ? fa : en;
}

const shopCategories = <ShopCategory>[
  ShopCategory(key: 'avatar', en: 'Avatars', fa: 'آواتار', icon: Icons.face_rounded, accent: AppTheme.violet),
  ShopCategory(key: 'frame', en: 'Frames', fa: 'قاب‌ها', icon: Icons.crop_square_rounded, accent: AppTheme.coral),
  ShopCategory(key: 'emote', en: 'Emotes', fa: 'ایموت‌ها', icon: Icons.emoji_emotions_rounded, accent: AppTheme.gold),
  ShopCategory(key: 'table', en: 'Tables', fa: 'میزها', icon: Icons.table_restaurant_rounded, accent: AppTheme.mint),
  ShopCategory(key: 'dice', en: 'Dice', fa: 'تاس‌ها', icon: Icons.casino_rounded, accent: AppTheme.sky),
  ShopCategory(key: 'bundle', en: 'Packs', fa: 'پک‌ها', icon: Icons.redeem_rounded, accent: AppTheme.fuchsia),
];

ShopCategory shopCategoryFor(String key) => shopCategories.firstWhere((category) => category.key == key, orElse: () => shopCategories.last);

String shopCategoryLabel(String key, bool persian) => shopCategoryFor(key).label(persian);
IconData shopCategoryIcon(String key) => shopCategoryFor(key).icon;
Color shopCategoryColor(String key) => shopCategoryFor(key).accent;

/// Glossy four-stop gradient per category: the same "premium 3D tile" language
/// the game logos use, so shop art sits naturally next to the boards.
LinearGradient shopCategoryGradient(String key) => _glossyGradient(shopCategoryColor(key));

LinearGradient _glossyGradient(Color color) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(color, Colors.white, .24)!, Color.lerp(color, Colors.white, .04)!, color, Color.lerp(color, Colors.black, .34)!],
      stops: const [0, .35, .68, 1],
    );

/// Asset keys are authored as `avatar_neon`, `dice_crystal`, ... so a friendly
/// keyword gives each item its own icon without shipping any new image assets.
IconData shopAssetIcon(String assetKey, String category) {
  final key = assetKey.toLowerCase();
  if (key.contains('neon') || key.contains('nova')) return Icons.auto_awesome_rounded;
  if (key.contains('fire') || key.contains('flame')) return Icons.local_fire_department_rounded;
  if (key.contains('crystal') || key.contains('diamond') || key.contains('gem')) return Icons.diamond_rounded;
  if (key.contains('aurora') || key.contains('glow')) return Icons.blur_on_rounded;
  if (key.contains('sunset') || key.contains('sun')) return Icons.wb_twilight_rounded;
  if (key.contains('night') || key.contains('moon')) return Icons.nightlight_round;
  if (key.contains('ocean') || key.contains('wave') || key.contains('sea')) return Icons.waves_rounded;
  if (key.contains('royal') || key.contains('crown')) return Icons.workspace_premium_rounded;
  if (key.contains('starter') || key.contains('pack')) return Icons.redeem_rounded;
  if (key.contains('star')) return Icons.star_rounded;
  return shopCategoryIcon(category);
}

/// `1,234,567` — prices and wallet balances read better with separators.
String shopNumber(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

/// The stacked, glossy product tile used everywhere an item is shown: cards,
/// spotlight rails, sheets and inventory rows.
class ShopItemArt extends StatelessWidget {
  const ShopItemArt({super.key, required this.category, this.assetKey = '', this.size = 64, this.icon});

  final String category;
  final String assetKey;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = shopCategoryColor(category);
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(left: -size * .2, top: -size * .2, child: Container(width: size * 1.4, height: size * 1.4, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withOpacity(.4), color.withOpacity(0)])))),
      Transform.translate(offset: Offset(size * .06, size * .1), child: _tile(color.withOpacity(.3), ghost: true)),
      Transform.translate(offset: Offset(size * .025, size * .045), child: _tile(color.withOpacity(.6), ghost: true)),
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
        gradient: _glossyGradient(color),
        border: ghost ? null : Border.all(color: Colors.white.withOpacity(.3), width: size * .02),
        boxShadow: ghost ? null : [BoxShadow(color: color.withOpacity(.5), blurRadius: size * .32, offset: Offset(0, size * .16)), BoxShadow(color: Colors.black.withOpacity(.26), blurRadius: size * .12, offset: Offset(0, size * .05))],
      ),
      child: Stack(
        children: [
          if (!ghost)
            Positioned(top: 0, left: 0, right: 0, child: Container(height: size * .44, decoration: BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(radius)), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withOpacity(.34), Colors.white.withOpacity(0)])))),
          if (!ghost) Positioned(top: size * .13, left: size * .17, child: Container(width: size * .3, height: size * .1, decoration: BoxDecoration(color: Colors.white.withOpacity(.5), borderRadius: BorderRadius.circular(99)))),
          if (!ghost) Positioned(bottom: size * .12, right: size * .13, child: Container(width: size * .16, height: size * .16, decoration: BoxDecoration(color: Colors.white.withOpacity(.18), shape: BoxShape.circle))),
          Center(child: Icon(icon ?? shopAssetIcon(assetKey, category), color: Colors.white, size: size * .46, shadows: ghost ? null : [Shadow(color: Colors.black.withOpacity(.3), blurRadius: size * .06, offset: Offset(0, size * .03))])),
        ],
      ),
    );
  }
}

/// Idle-animated shop art for hero/spotlight moments. One controller drives a
/// gentle float plus a slight rock, exactly like [FloatingGameLogo].
class FloatingShopItemArt extends StatefulWidget {
  const FloatingShopItemArt({super.key, required this.category, this.assetKey = '', this.size = 84, this.floatRange = 5, this.period = const Duration(milliseconds: 2600)});
  final String category;
  final String assetKey;
  final double size;
  final double floatRange;
  final Duration period;

  @override
  State<FloatingShopItemArt> createState() => _FloatingShopItemArtState();
}

class _FloatingShopItemArtState extends State<FloatingShopItemArt> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final t = _curve.value * 2 - 1;
          return Transform.translate(offset: Offset(0, widget.floatRange * t), child: Transform.rotate(angle: .035 * t, child: child));
        },
        child: ShopItemArt(category: widget.category, assetKey: widget.assetKey, size: widget.size),
      );
}

/// Price chip: gold for coins, violet for pips, and a quiet "not enough" state.
class ShopPricePill extends StatelessWidget {
  const ShopPricePill({super.key, required this.price, required this.paysWithPips, this.affordable = true, this.dense = false});

  final int price;
  final bool paysWithPips;
  final bool affordable;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = paysWithPips ? AppTheme.violet : AppTheme.gold;
    final showWarning = !affordable;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 9.0 : 11.0, vertical: dense ? 5.0 : 7.0),
      decoration: BoxDecoration(
        color: (showWarning ? AppTheme.coral : color).withOpacity(.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: (showWarning ? AppTheme.coral : color).withOpacity(.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(paysWithPips ? Icons.brightness_1_rounded : Icons.circle, size: dense ? 12.0 : 14.0, color: showWarning ? AppTheme.coral : color),
        const SizedBox(width: 5),
        Text(shopNumber(price), style: TextStyle(fontWeight: FontWeight.w900, fontSize: dense ? 12.0 : 13.0, color: showWarning ? AppTheme.coral : null)),
      ]),
    );
  }
}

/// Small status chip used for LIMITED / OWNED / EQUIPPED / "only N left".
class ShopTag extends StatelessWidget {
  const ShopTag({super.key, required this.label, this.color = AppTheme.violet, this.icon, this.filled = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withOpacity(filled ? 1.0 : .4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: filled ? Colors.white : color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: .4, color: filled ? Colors.white : color)),
        ]),
      );
}

/// Shared bottom-sheet chrome: rounded premium surface, drag handle, keyboard
/// aware padding and a soft accent wash behind the header.
class ShopSheetShell extends StatelessWidget {
  const ShopSheetShell({super.key, required this.child, this.accent = AppTheme.violet, this.maxHeightFactor = .92, this.scrollable = true});

  final Widget child;
  final Color accent;
  final double maxHeightFactor;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 44, height: 5, margin: const EdgeInsets.only(top: 10, bottom: 4), decoration: BoxDecoration(color: scheme.outline.withOpacity(.5), borderRadius: BorderRadius.circular(99))),
        Flexible(child: scrollable ? SingleChildScrollView(child: child) : child),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * maxHeightFactor),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.28), blurRadius: 32, offset: const Offset(0, -8))],
        ),
        child: Stack(children: [
          Positioned(top: 0, left: 0, right: 0, child: Container(height: 150, decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [accent.withOpacity(.16), accent.withOpacity(0)])))),
          SafeArea(top: false, child: content),
        ]),
      ),
    );
  }
}

/// Compact "coins"/"pips" wallet read-out for sheet headers.
class ShopWalletRow extends StatelessWidget {
  const ShopWalletRow({super.key, required this.coins, required this.pips});

  final int coins;
  final int pips;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShopTag(label: shopNumber(coins), color: AppTheme.gold, icon: Icons.circle),
          const SizedBox(width: 8),
          ShopTag(label: shopNumber(pips), color: AppTheme.violet, icon: Icons.brightness_1_rounded),
        ],
      );
}
