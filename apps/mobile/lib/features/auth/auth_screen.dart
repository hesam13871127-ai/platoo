import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_logo.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.errorMessage});
  final String? errorMessage;
  @override ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final phone = TextEditingController(); final code = TextEditingController(); String? challenge; String? devCode; String? localError; bool sending = false;
  @override void dispose() { phone.dispose(); code.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { final strings = AppStrings(Localizations.localeOf(context)); final busy = ref.watch(authProvider).isLoading || sending; return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const VibeLogo(), const SizedBox(height: 52), Text(strings.welcome, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.12)), const SizedBox(height: 12), Text(strings.isPersian ? 'با دوستانت بازی کن، رقابت کن و حال خوب بساز.' : 'Play, compete and make a little more room for good vibes.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 34), if (widget.errorMessage != null || localError != null) _ErrorBanner(localError ?? widget.errorMessage!), TextField(controller: phone, keyboardType: TextInputType.phone, enabled: challenge == null && !busy, decoration: InputDecoration(labelText: strings.phone, hintText: '+14155552671', prefixIcon: const Icon(Icons.phone_rounded))), if (challenge != null) ...[const SizedBox(height: 14), TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: strings.verificationCode, prefixIcon: const Icon(Icons.lock_outline_rounded), counterText: devCode == null ? null : 'Dev code: $devCode')),], const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : (challenge == null ? _sendCode : _verify), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(challenge == null ? strings.sendCode : strings.verify)))), if (challenge != null) Align(alignment: Alignment.center, child: TextButton(onPressed: busy ? null : () => setState(() { challenge = null; devCode = null; }), child: Text(strings.isPersian ? 'تغییر شماره' : 'Use another number'))), const SizedBox(height: 18), Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(strings.isPersian ? 'یا' : 'or')), const Expanded(child: Divider())]), const SizedBox(height: 18), OutlinedButton.icon(onPressed: busy ? null : _google, icon: const Icon(Icons.g_mobiledata_rounded, size: 28), label: Text(strings.isPersian ? 'ورود با گوگل' : 'Continue with Google'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52))), const SizedBox(height: 12), OutlinedButton.icon(onPressed: busy ? null : _apple, icon: const Icon(Icons.apple, size: 22), label: Text(strings.isPersian ? 'ورود با اپل' : 'Continue with Apple'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52))), const SizedBox(height: 28), Text(strings.isPersian ? 'با ادامه دادن، قوانین جامعه و حریم خصوصی VibeTable را می‌پذیری.' : 'By continuing, you agree to VibeTable’s community guidelines and privacy policy.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),]))))));
  }
  Future<void> _sendCode() async {
    final value = phone.text.trim();
    if (value.isEmpty) { setState(() => localError = 'Enter a phone number to continue.'); return; }
    setState(() { sending = true; localError = null; });
    try {
      final data = await ref.read(authProvider.notifier).requestOtp(value);
      if (!mounted) return;
      setState(() { challenge = data['challengeId'] as String?; devCode = data['devCode'] as String?; });
    } catch (error) {
      if (mounted) setState(() => localError = error.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
  Future<void> _verify() async {
    final value = code.text.trim();
    if (value.length < 4) { setState(() => localError = 'Enter the verification code.'); return; }
    setState(() => localError = null);
    await ref.read(authProvider.notifier).verifyOtp(challenge!, value);
    if (mounted && ref.read(authProvider).hasError) setState(() => localError = ref.read(authProvider).error.toString());
  }
  Future<void> _google() async { try { final account = await GoogleSignIn(scopes: ['email']).signIn(); if (account == null) return; final token = (await account.authentication).idToken; if (token == null) throw Exception('Google did not return an identity token.'); await ref.read(authProvider.notifier).social('google', token, displayName: account.displayName); } catch (error) { if (mounted) setState(() => localError = error.toString()); } }
  Future<void> _apple() async { try { final credential = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName]); final token = credential.identityToken; if (token == null) throw Exception('Apple did not return an identity token.'); final name = [credential.givenName, credential.familyName].whereType<String>().join(' '); await ref.read(authProvider.notifier).social('apple', token, displayName: name.isEmpty ? null : name); } catch (error) { if (mounted) setState(() => localError = error.toString()); } }
}

class _ErrorBanner extends StatelessWidget { const _ErrorBanner(this.message); final String message; @override Widget build(BuildContext context) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(14)), child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))); }
