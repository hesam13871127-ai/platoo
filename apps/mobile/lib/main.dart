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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings(Localizations.localeOf(context));
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: dark ? AppTheme.darkPageGradient : AppTheme.lightPageGradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 120, height: 120, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppTheme.violet.withOpacity(.25), AppTheme.violet.withOpacity(0)])), child: const VibeLogo(compact: true)),
              const SizedBox(height: 20),
              VibeText('VibeTable', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              VibeText(strings.translateText('Setting up your table…'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 22),
              const SizedBox(width: 120, child: ClipRRect(borderRadius: BorderRadius.all(Radius.circular(99)), child: LinearProgressIndicator(minHeight: 6))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings(Localizations.localeOf(context));
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 78, height: 78, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [scheme.error, Color.lerp(scheme.error, Colors.black, .25)!]), boxShadow: AppTheme.glow(scheme.error, strength: .3)), child: const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 34)),
              const SizedBox(height: 18),
              VibeText(strings.translateText('We could not open VibeTable'), style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              VibeText(strings.translateText(message), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: VibeText(strings.retry)),
            ]),
          ),
        ),
      ),
    );
  }
}
