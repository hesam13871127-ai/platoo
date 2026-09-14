import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';

/// Small shared building blocks so every admin tab renders loading, empty and
/// error states the same way.
class AdminAsync<T> extends StatelessWidget {
  const AdminAsync({super.key, required this.value, required this.builder, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator())),
        error: (error, _) => AdminEmpty(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load this section',
          message: error.toString(),
          actionLabel: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        ),
        data: builder,
      );
}

class AdminEmpty extends StatelessWidget {
  const AdminEmpty({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 22),
        child: Column(children: [
          Container(width: 58, height: 58, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), shape: BoxShape.circle), child: Icon(icon, color: AppTheme.violet)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          if (actionLabel != null) ...[const SizedBox(height: 14), OutlinedButton(onPressed: onAction, child: Text(actionLabel!))],
        ]),
      );
}

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({super.key, required this.label, required this.value, required this.icon, required this.color, this.caption});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: color, size: 20),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (caption != null) Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
      );
}

/// A minimal dependency-free sparkline for the analytics dashboard.
class AdminSparkline extends StatelessWidget {
  const AdminSparkline({super.key, required this.values, required this.color});
  final List<num> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: 54, child: Center(child: Text('Not enough data yet', style: Theme.of(context).textTheme.bodySmall)));
    return SizedBox(height: 54, child: CustomPaint(size: Size.infinite, painter: _SparklinePainter(values, color)));
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);
  final List<num> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.reduce((a, b) => a > b ? a : b).toDouble();
    final minValue = values.reduce((a, b) => a < b ? a : b).toDouble();
    final span = (maxValue - minValue).abs() < 0.001 ? 1.0 : maxValue - minValue;
    final step = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = step * i;
      final y = size.height - ((values[i].toDouble() - minValue) / span) * (size.height - 6) - 3;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fill, Paint()..color = color.withOpacity(.12));
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.values != values || oldDelegate.color != color;
}

Color statusColor(String? status) => switch (status) {
      'active' => AppTheme.mint,
      'suspended' => AppTheme.coral,
      'deleted' => Colors.grey,
      'open' => AppTheme.coral,
      'investigating' => AppTheme.gold,
      'resolved' => AppTheme.mint,
      'dismissed' => Colors.grey,
      'scheduled' => AppTheme.gold,
      'finished' => Colors.grey,
      _ => AppTheme.violet,
    };

int asInt(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
bool asBool(Object? value) => value == true || value == 1 || value == '1';
String shortDate(Object? value) => value == null ? '—' : value.toString().replaceFirst('T', ' ').split('.').first;

Future<void> showAdminError(BuildContext context, Object error) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: AppTheme.coral));
}

Future<void> showAdminMessage(BuildContext context, String message) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
