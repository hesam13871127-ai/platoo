import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Consistent success/error toast used for every user-facing result message.
void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: isError ? AppTheme.coral : AppTheme.mint, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
}
