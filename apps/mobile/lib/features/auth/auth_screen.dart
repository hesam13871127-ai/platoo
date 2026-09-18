import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_components.dart';
import '../../core/widgets/vibe_logo.dart';
import '../admin/admin_screen.dart';

const _devAdminPassword = 'vibetable-admin';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.errorMessage});
  final String? errorMessage;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  String? challenge;
  String? devCode;
  String? localError;
  bool sending = false;

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final busy = ref.watch(authProvider).isLoading || sending;
    return Scaffold(
      body: VibePageBackground(
        child: Stack(
          children: [
            Positioned(right: -70, top: -70, child: Container(width: 220, height: 220, decoration: BoxDecoration(color: AppTheme.violet.withOpacity(dark ? .22 : .12), shape: BoxShape.circle))),
            Positioned(left: -60, top: 180, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: AppTheme.coral.withOpacity(dark ? .14 : .1), shape: BoxShape.circle))),
            Positioned(right: -50, bottom: -60, child: Container(width: 190, height: 190, decoration: BoxDecoration(color: AppTheme.mint.withOpacity(dark ? .12 : .1), shape: BoxShape.circle))),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Entrance(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: scheme.outline.withOpacity(dark ? .3 : .12)),
                          boxShadow: [...AppTheme.softShadow(dark: dark), BoxShadow(color: AppTheme.violet.withOpacity(dark ? .18 : .1), blurRadius: 44, offset: const Offset(0, 22))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(child: VibeLogo()),
                            const SizedBox(height: 26),
                            VibeText(strings.welcome, style: Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 10),
                            VibeText(strings.isPersian ? 'با دوستانت بازی کن، رقابت کن و حال خوب بساز.' : 'Play, compete and make a little more room for good vibes.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 26),
                            if (widget.errorMessage != null || localError != null) _ErrorBanner(localError ?? widget.errorMessage!),
                            TextField(controller: phone, keyboardType: TextInputType.phone, enabled: challenge == null && !busy, decoration: InputDecoration(labelText: strings.phone, hintText: '+14155552671', prefixIcon: const Icon(Icons.phone_rounded))),
                            if (challenge != null) ...[
                              const SizedBox(height: 14),
                              TextField(
                                controller: code,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: InputDecoration(labelText: strings.verificationCode, prefixIcon: const Icon(Icons.lock_outline_rounded), counterText: devCode == null ? null : 'Dev code: $devCode'),
                              ),
                            ],
                            const SizedBox(height: 18),
                            VibePrimaryButton(onPressed: busy ? null : (challenge == null ? _sendCode : _verify), busy: busy, icon: challenge == null ? Icons.sms_rounded : Icons.verified_rounded, label: challenge == null ? strings.sendCode : strings.verify),
                            if (challenge != null)
                              Align(alignment: Alignment.center, child: TextButton(onPressed: busy ? null : () => setState(() { challenge = null; devCode = null; }), child: VibeText(strings.isPersian ? 'تغییر شماره' : 'Use another number'))),
                            const SizedBox(height: 16),
                            Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: VibeText(strings.isPersian ? 'یا' : 'or', style: Theme.of(context).textTheme.bodySmall)), const Expanded(child: Divider())]),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(onPressed: busy ? null : _google, icon: const Icon(Icons.g_mobiledata_rounded, size: 26), label: VibeText(strings.isPersian ? 'ورود با گوگل' : 'Continue with Google')),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(onPressed: busy ? null : _apple, icon: const Icon(Icons.apple, size: 22), label: VibeText(strings.isPersian ? 'ورود با اپل' : 'Continue with Apple')),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonalIcon(
                                onPressed: busy ? null : _openAdminEntry,
                                icon: const Icon(Icons.admin_panel_settings_rounded),
                                label: VibeText(strings.adminStaffEntry),
                              ),
                            ),
                            if (kDebugMode) ...[
                              const SizedBox(height: 7),
                              Center(
                                child: VibeText(
                                  '${strings.developmentPassword}: $_devAdminPassword',
                                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            VibeText(strings.isPersian ? 'با ادامه دادن، قوانین جامعه و حریم خصوصی VibeTable را می‌پذیری.' : 'By continuing, you agree to VibeTable’s community guidelines and privacy policy.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdminEntry() async {
    final strings = AppStrings(Localizations.localeOf(context));
    final username = TextEditingController(text: 'admin');
    final password = TextEditingController(text: _devAdminPassword);
    final credentials = await showDialog<({String username, String password})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: VibeText(strings.adminStaffEntry),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: username, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: strings.username, prefixIcon: const Icon(Icons.person_outline_rounded))),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: strings.developmentPassword, prefixIcon: const Icon(Icons.key_rounded))),
            const SizedBox(height: 10),
            VibeText(strings.staffRoleHint, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: VibeText(strings.cancel)),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop((username: username.text.trim(), password: password.text)), child: VibeText(strings.enterAdminPanel)),
        ],
      ),
    );
    username.dispose();
    password.dispose();
    if (credentials == null || !mounted) return;
    setState(() {
      sending = true;
      localError = null;
    });
    await ref.read(authProvider.notifier).devAdmin(credentials.username, credentials.password);
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.hasError) {
      setState(() => localError = auth.error.toString());
    } else if (auth.value?.user.role == 'admin' || auth.value?.user.role == 'moderator') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen()));
    } else {
      setState(() => localError = strings.staffRoleHint);
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _sendCode() async {
    final value = phone.text.trim();
    if (value.isEmpty) {
      setState(() => localError = 'Enter a phone number to continue.');
      return;
    }
    setState(() {
      sending = true;
      localError = null;
    });
    try {
      final data = await ref.read(authProvider.notifier).requestOtp(value);
      if (!mounted) return;
      final id = data['challengeId'] as String?;
      if (id == null || id.isEmpty) throw Exception('The server did not return a verification challenge. Please try again.');
      setState(() {
        challenge = id;
        devCode = data['devCode'] as String?;
      });
    } catch (error) {
      if (mounted) setState(() => localError = error.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _verify() async {
    final value = code.text.trim();
    if (value.length < 4) {
      setState(() => localError = 'Enter the verification code.');
      return;
    }
    setState(() => localError = null);
    await ref.read(authProvider.notifier).verifyOtp(challenge!, value);
    if (mounted && ref.read(authProvider).hasError) setState(() => localError = ref.read(authProvider).error.toString());
  }

  Future<void> _google() async {
    try {
      final account = await GoogleSignIn(scopes: ['email']).signIn();
      if (account == null) return;
      final token = (await account.authentication).idToken;
      if (token == null) throw Exception('Google did not return an identity token.');
      await ref.read(authProvider.notifier).social('google', token, displayName: account.displayName);
    } catch (error) {
      if (mounted) setState(() => localError = error.toString());
    }
  }

  Future<void> _apple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName]);
      final token = credential.identityToken;
      if (token == null) throw Exception('Apple did not return an identity token.');
      final name = [credential.givenName, credential.familyName].whereType<String>().join(' ');
      await ref.read(authProvider.notifier).social('apple', token, displayName: name.isEmpty ? null : name);
    } catch (error) {
      if (mounted) setState(() => localError = error.toString());
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Theme.of(context).colorScheme.errorContainer, Theme.of(context).colorScheme.errorContainer.withOpacity(.7)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(.25)),
        ),
        child: Row(children: [Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.onErrorContainer, size: 20), const SizedBox(width: 10), Expanded(child: VibeText(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontWeight: FontWeight.w600)))]),
      );
}
