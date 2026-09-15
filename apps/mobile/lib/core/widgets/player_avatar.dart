import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Cached network avatar with a loading indicator and an initial-letter
/// fallback, wrapped in the player's signature gradient ring.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, this.avatarUrl, required this.displayName, this.radius = 20});
  final String? avatarUrl;
  final String displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    final inner = ((radius - 2.5).clamp(8.0, radius)).toDouble();
    final Widget face = url.isEmpty
        ? _fallback(inner)
        : CachedNetworkImage(
            imageUrl: url,
            imageBuilder: (context, provider) => CircleAvatar(radius: inner, backgroundColor: AppTheme.violet.withOpacity(.15), backgroundImage: provider),
            placeholder: (context, _) => CircleAvatar(radius: inner, backgroundColor: AppTheme.violet.withOpacity(.15), child: SizedBox(width: inner, height: inner, child: const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.violet))),
            errorWidget: (context, _, __) => _fallback(inner),
          );
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.avatarGradient(displayName), boxShadow: AppTheme.glow(AppTheme.violet, strength: .18)),
      child: face,
    );
  }

  Widget _fallback(double inner) {
    final trimmed = displayName.trim();
    final initial = trimmed.isEmpty ? 'V' : trimmed.substring(0, 1).toUpperCase();
    return CircleAvatar(radius: inner, backgroundColor: AppTheme.violet.withOpacity(.15), child: Text(initial, style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.violet, fontSize: inner * .85)));
  }
}
