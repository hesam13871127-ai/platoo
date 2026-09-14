import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 64, height: 64, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 29)),
            const SizedBox(height: 13),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 13),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
