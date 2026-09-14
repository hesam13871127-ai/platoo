import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Cached network avatar with a loading indicator and an initial-letter
/// fallback, so profile pictures never pop in or break layout.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, this.avatarUrl, required this.displayName, this.radius = 20});
  final String? avatarUrl;
  final String displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    if (url.isEmpty) return _fallback();
    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, provider) => CircleAvatar(radius: radius, backgroundColor: AppTheme.violet.withOpacity(.15), backgroundImage: provider),
      placeholder: (context, _) => CircleAvatar(radius: radius, backgroundColor: AppTheme.violet.withOpacity(.15), child: SizedBox(width: radius, height: radius, child: const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.violet))),
      errorWidget: (context, _, __) => _fallback(),
    );
  }

  Widget _fallback() {
    final trimmed = displayName.trim();
    final initial = trimmed.isEmpty ? 'V' : trimmed.substring(0, 1).toUpperCase();
    return CircleAvatar(radius: radius, backgroundColor: AppTheme.violet.withOpacity(.15), child: Text(initial, style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.violet, fontSize: radius * .85)));
  }
}
