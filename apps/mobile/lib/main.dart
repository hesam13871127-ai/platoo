import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/localization/app_strings.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/vibe_logo.dart';
import 'models/models.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/app_shell.dart';

void main() => runApp(const ProviderScope(child: VibeTableApp()));

class VibeTableApp extends ConsumerWidget {
  const VibeTableApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'VibeTable',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (settings.theme) { ThemeChoice.dark => ThemeMode.dark, ThemeChoice.light => ThemeMode.light, ThemeChoice.system => ThemeMode.system },
      locale: Locale(settings.locale == AppLocale.fa ? 'fa' : 'en'),
      supportedLocales: const [Locale('en'), Locale('fa')],
      localizationsDelegates: const [AppLocalizationsDelegate(), GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      builder: (context, child) => Directionality(textDirection: settings.locale == AppLocale.fa ? TextDirection.rtl : TextDirection.ltr, child: child ?? const SizedBox.shrink()),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return auth.when(
      loading: () => const _Splash(),
      error: (error, _) => _BootstrapError(message: error.toString(), onRetry: () => ref.invalidate(authProvider)),
      data: (session) => session == null ? const AuthScreen() : const AppShell(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const VibeLogo(), const SizedBox(height: 24), Text('Setting up your table…', style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 18), SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: Theme.of(context).colorScheme.primary))]))));
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 64, height: 64, alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, shape: BoxShape.circle), child: Icon(Icons.cloud_off_rounded, color: Theme.of(context).colorScheme.onErrorContainer, size: 30)), const SizedBox(height: 17), Text('We could not open VibeTable', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center), const SizedBox(height: 8), Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center), const SizedBox(height: 18), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again'))])))));
}
