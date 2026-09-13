import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/localization/app_strings.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'models/models.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/app_shell.dart';

void main() => runApp(const ProviderScope(child: VibeTableApp()));

class VibeTableApp extends ConsumerWidget {
  const VibeTableApp({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) { final settings = ref.watch(settingsProvider); return MaterialApp(title: 'VibeTable', debugShowCheckedModeBanner: false, theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: switch (settings.theme) { ThemeChoice.dark => ThemeMode.dark, ThemeChoice.light => ThemeMode.light, ThemeChoice.system => ThemeMode.system }, locale: Locale(settings.locale == AppLocale.fa ? 'fa' : 'en'), supportedLocales: const [Locale('en'), Locale('fa')], localizationsDelegates: const [AppLocalizationsDelegate(), GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], builder: (context, child) => Directionality(textDirection: settings.locale == AppLocale.fa ? TextDirection.rtl : TextDirection.ltr, child: child ?? const SizedBox.shrink()), home: const AuthGate()); }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) { final auth = ref.watch(authProvider); return auth.when(loading: () => const _Splash(), error: (error, _) => AuthScreen(errorMessage: error.toString()), data: (session) => session == null ? const AuthScreen() : const AppShell()); }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const VibeLogo(), const SizedBox(height: 28), SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Theme.of(context).colorScheme.primary))])));
}
