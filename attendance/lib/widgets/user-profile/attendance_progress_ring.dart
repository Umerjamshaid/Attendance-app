import 'package:flutter/material.dart';

import '../../config/ui_tokens.dart';

/// A bounded attendance percentage; unavailable data never looks like progress.
class AttendanceProgressRing extends StatelessWidget {
  const AttendanceProgressRing({
    super.key,
    required this.progress,
    required this.label,
    this.isLoading = false,
    this.dimension = 104,
  });

  final double? progress;
  final String label;
  final bool isLoading;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available = progress != null && progress!.isFinite && !isLoading;
    final target = available ? progress!.clamp(0.0, 1.0).toDouble() : 0.0;
    final status = isLoading ? 'Loading' : 'Unavailable';
    return Semantics(
      label: label,
      value: available ? '${(target * 100).round()} percent' : status,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: dimension,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 600),
          curve: AppMotion.enterCurve,
          builder: (context, value, child) => Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: colors.primary,
                  backgroundColor: colors.outlineVariant.withValues(alpha: .6),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        available ? '${(value * 100).round()}%' : '\u2014',
                        style: AppTypography.inter(
                          fontSize: 24,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        available ? label : status,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
