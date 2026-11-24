import 'dart:math' as math;

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
                markerColor: available ? colors.primary : null,
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
                  indicatorSize: 0,
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
    required this.markerColor,
    required this.label,
    required this.formatter,
    required this.style,
  });
  final double target;
  final bool reduced;
  final Color? markerColor;
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
  Widget build(BuildContext context) {
    final value = widget.reduced || _revealed ? widget.target : 0.0;
    return TickerMode(
      enabled: !widget.reduced,
      child: Stack(
        fit: StackFit.expand,
        children: [
          portal.ScoreGauge(
            value: value,
            min: 0,
            max: 100,
            label: widget.label,
            calculatingLabel: 'Updating',
            valueFormatter: widget.formatter,
            style: widget.style,
          ),
          if (widget.markerColor case final color?)
            IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: value / 100),
                      duration: widget.style.animationDuration,
                      curve: const portal.PortalSpringCurve(
                        stiffness: 120,
                        damping: 18,
                      ),
                      builder: (context, fraction, _) =>
                          _marker(constraints.biggest, fraction, color),
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _marker(Size size, double fraction, Color color) {
    // Match Portal's arc geometry; its built-in tip is fixed at 12 o'clock.
    final style = widget.style;
    final outer = math.min(size.width, size.height) / 2;
    final scale = outer / 120;
    final radius =
        outer -
        scale *
            (math.max(
                  style.tickLength + style.tickGap,
                  style.trackThickness / 2,
                ) +
                style.trackThickness / 2 +
                style.indicatorGap +
                9);
    final angle =
        (style.startAngleDegrees +
            style.sweepAngleDegrees * fraction.clamp(0.0, 1.0)) *
        math.pi /
        180;
    return Center(
      child: Transform.translate(
        offset: Offset(
          math.cos(angle) * radius,
          math.sin(angle) * radius + outer * .18,
        ),
        child: Transform.rotate(
          angle: angle + math.pi / 2,
          child: CustomPaint(
            key: const ValueKey('attendance_gauge_marker'),
            size: Size(22 * scale, 16 * scale),
            painter: _GaugeTipPainter(color),
          ),
        ),
      ),
    );
  }
}

class _GaugeTipPainter extends CustomPainter {
  const _GaugeTipPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final tip = Path()
      ..moveTo(width * .41, height * .11)
      ..quadraticBezierTo(width * .5, -height * .06, width * .59, height * .11)
      ..lineTo(width * .96, height * .8)
      ..quadraticBezierTo(width * 1.05, height, width * .87, height)
      ..lineTo(width * .13, height)
      ..quadraticBezierTo(-width * .05, height, width * .04, height * .8)
      ..close();
    canvas.drawPath(tip, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GaugeTipPainter oldDelegate) =>
      oldDelegate.color != color;
}
