import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';
import 'vibe_components.dart';

/// Shared empty-state / offline-state panel used across Home, Shop, Social,
/// and Chat so every "nothing here" moment looks and behaves the same.
class StatePanel extends StatelessWidget {
  const StatePanel({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction, this.iconColor});
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.violet;
    final theme = Theme.of(context);
    final strings = AppStrings(Localizations.localeOf(context));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Entrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, .12)!, color, Color.lerp(color, Colors.black, .2)!], stops: const [0, .55, 1]),
                  boxShadow: AppTheme.glow(color, strength: .3),
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 16),
              VibeText(strings.translateText(title), style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 7),
              VibeText(strings.translateText(message), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: onAction, child: VibeText(strings.translateText(actionLabel!))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
