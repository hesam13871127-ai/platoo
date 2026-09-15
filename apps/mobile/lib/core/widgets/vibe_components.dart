import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Staggered entrance micro-animation: fades in while sliding up, once.
/// Used on headers, heroes, and list items so every screen settles smoothly.
class Entrance extends StatefulWidget {
  const Entrance({super.key, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 450), required this.child});
  final Duration delay;
  final Duration duration;
  final Widget child;
  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: _shown ? Offset.zero : const Offset(0, .12),
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      );
}

/// Press-down scale feedback for tappable cards and custom buttons.
/// Renders nothing visual on its own; disabled taps stay perfectly still.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.onTap, required this.child, this.scale = .96});
  final VoidCallback? onTap;
  final Widget child;
  final double scale;
  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: widget.onTap != null,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
          onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
          onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? widget.scale : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      );
}

/// The standard premium surface: soft shadow, hairline border, big radius.
/// Pass [onTap] to make the whole card pressable with scale feedback.
class VibeCard extends StatelessWidget {
  const VibeCard({super.key, this.child, this.padding = const EdgeInsets.all(16), this.margin, this.onTap, this.gradient, this.borderRadius = 24});
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? scheme.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: scheme.outline.withOpacity(dark ? .3 : .14)),
        boxShadow: AppTheme.softShadow(dark: dark),
      ),
      child: child,
    );
    return onTap == null ? card : PressableScale(onTap: onTap, child: card);
  }
}

/// Gradient page backdrop: a soft wash that melts into the scaffold color.
class VibePageBackground extends StatelessWidget {
  const VibePageBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: dark ? AppTheme.darkPageGradient : AppTheme.lightPageGradient),
      child: child,
    );
  }
}

/// Section heading with an optional subtitle and trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction, this.trailing});
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: theme.textTheme.bodySmall)],
            ],
          ),
        ),
        if (trailing != null) trailing!,
        if (actionLabel != null && onAction != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Hero call-to-action: full-width gradient button with glow and busy state.
class VibePrimaryButton extends StatelessWidget {
  const VibePrimaryButton({super.key, required this.onPressed, required this.label, this.icon, this.busy = false});
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !busy;
    final leadingIcon = icon;
    return PressableScale(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: enabled ? AppTheme.primaryGradient : null,
          color: enabled ? null : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          boxShadow: enabled ? AppTheme.glow(AppTheme.violet) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            else if (leadingIcon != null) ...[Icon(leadingIcon, color: Colors.white, size: 20), const SizedBox(width: 9)],
            Text(label, style: TextStyle(color: enabled ? Colors.white : scheme.onSurfaceVariant, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -.2)),
          ],
        ),
      ),
    );
  }
}

/// Gradient initial-letter avatar with a violet glow. The gradient is stable
/// per name, so every player keeps their own recognizable color.
class VibeInitial extends StatelessWidget {
  const VibeInitial({super.key, required this.name, this.radius = 22});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.avatarGradient(name), boxShadow: AppTheme.glow(AppTheme.violet, strength: .2)),
      child: Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: radius * .9)),
    );
  }
}

/// Shimmering skeleton block for loading states. Compose rows, grids, and
/// avatar placeholders from this instead of bare spinners where possible.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width, this.height = 16, this.borderRadius = const BorderRadius.all(Radius.circular(14))});
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;
  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF222845) : const Color(0xFFE7E3F1);
    final shine = dark ? const Color(0xFF323B63) : const Color(0xFFFFFFFF);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final width = bounds.width <= 0 ? 1.0 : bounds.width;
          final dx = (_controller.value * 2 - 1) * width * 1.25;
          return LinearGradient(colors: [base, shine, base], stops: const [0, .5, 1]).createShader(Rect.fromLTWH(dx - width, 0, width * 2, bounds.height));
        },
        child: Container(width: widget.width, height: widget.height, decoration: BoxDecoration(color: base, borderRadius: widget.borderRadius)),
      ),
    );
  }
}
