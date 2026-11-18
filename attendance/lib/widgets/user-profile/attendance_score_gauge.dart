import 'package:flutter/material.dart';
import 'package:portal_labs/portal_labs.dart' as portal;

import '../../config/ui_tokens.dart';
import 'profile_section_card.dart';

/// Portal's actual gauge, using existing fractions rather than a new score.
class AttendanceScoreGauge extends StatelessWidget {
  const AttendanceScoreGauge({
    super.key,
    required this.progress,
    required this.label,
    this.isLoading = false,
  });
  final double? progress;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final available = progress != null && progress!.isFinite && !isLoading;
    final target = available ? progress!.clamp(0.0, 1.0).toDouble() * 100 : 0.0;
    final status = isLoading ? 'Loading' : 'Unavailable';
    final reduced = MediaQuery.disableAnimationsOf(context);
    final large = MediaQuery.textScalerOf(context).scale(14) > 20;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      value: available ? '${target.round()} percent' : status,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 240,
              width: double.infinity,
              child: _GaugeBody(
                key: ValueKey(
                  reduced || !available
                      ? '$target:$available:$status'
                      : 'animated',
                ),
                target: target,
                reduced: reduced || !available,
                label: large
                    ? ''
                    : available
                    ? label
                    : status,
                formatter: large
                    ? (_) => ''
                    : available
                    ? (value) => '${value.round()}%'
                    : (_) => '\u2014',
                style: portal.ScoreGaugeStyle(
                  trackThickness: 24,
                  trackGradientColors: [
                    available ? colors.primary : colors.outlineVariant,
                  ],
                  valueTextStyle: AppTypography.inter(
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  labelTextStyle: ProfileUi.small(
                    context,
                    weight: FontWeight.w500,
                  ),
                  animationDuration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 1400),
                  enableHaptics: available && !reduced,
                ),
              ),
            ),
            if (large) ...[
              Text(
                available ? '${target.round()}%' : '\u2014',
                style: AppTypography.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              Text(available ? label : status, style: ProfileUi.small(context)),
            ],
          ],
        ),
      ),
    );
  }
}

class _GaugeBody extends StatefulWidget {
  const _GaugeBody({
    super.key,
    required this.target,
    required this.reduced,
    required this.label,
    required this.formatter,
    required this.style,
  });
  final double target;
  final bool reduced;
  final String label;
  final String Function(double) formatter;
  final portal.ScoreGaugeStyle style;
  @override
  State<_GaugeBody> createState() => _GaugeBodyState();
}

class _GaugeBodyState extends State<_GaugeBody> {
  bool _revealed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.reduced) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: !widget.reduced,
    child: portal.ScoreGauge(
      value: widget.reduced || _revealed ? widget.target : 0,
      min: 0,
      max: 100,
      label: widget.label,
      calculatingLabel: 'Updating',
      valueFormatter: widget.formatter,
      style: widget.style,
    ),
  );
}
