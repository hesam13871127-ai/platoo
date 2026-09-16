import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';

/// Consistent success/error toast used for every user-facing result message.
void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  final strings = AppStrings(Localizations.localeOf(context));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: isError ? AppTheme.coral : AppTheme.mint, size: 20),
            const SizedBox(width: 10),
            Expanded(child: VibeText(strings.translateText(message))),
          ],
        ),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
}
