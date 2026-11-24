import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:portal_labs/portal_labs.dart' as portal;

import '../../services/invite_email_activity.dart';

/// Shows confirmed device activity without claiming to know the server quota.
class InviteEmailMeter extends StatefulWidget {
  const InviteEmailMeter({
    super.key,
    required this.sentAt,
    this.now = DateTime.now,
  });

  final List<DateTime> sentAt;
  final DateTime Function() now;

  @override
  State<InviteEmailMeter> createState() => _InviteEmailMeterState();
}

class _InviteEmailMeterState extends State<InviteEmailMeter> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _startTick();
  }

  @override
  void didUpdateWidget(InviteEmailMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentAt != widget.sentAt) _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    if (InviteEmailActivity.withinWindow(widget.sentAt, widget.now()).isEmpty) {
      return;
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (InviteEmailActivity.withinWindow(
        widget.sentAt,
        widget.now(),
      ).isEmpty) {
        timer.cancel();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now();
    final sends = InviteEmailActivity.withinWindow(widget.sentAt, now);
    final label = sends.length == 1 ? 'email sent' : 'emails sent';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final digits = theme.textTheme.headlineLarge!.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 42,
      height: 1,
    );
    final seconds = sends.isEmpty ? null : _secondsLeft(now, sends.first);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final staticText =
        reduced || MediaQuery.textScalerOf(context).scale(32) > 40;

    Widget counter(Key key, String value, TextStyle style) => FittedBox(
      fit: BoxFit.scaleDown,
      child: staticText
          ? Text(value, key: key, style: style)
          : portal.PremiumFlipCounter(
              key: key,
              value: value,
              upward: false,
              style: style,
            ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (seconds != null) ...[
          Center(
            child: SizedBox.square(
              dimension: 204,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey(reduced),
                    tween: Tween(
                      begin: reduced ? null : 0,
                      end: ((seconds - 1) % 60 + 1) / 60,
                    ),
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 620),
                    curve: const portal.PortalSpringCurve(
                      stiffness: 145,
                      damping: 20,
                    ),
                    builder: (_, value, _) => CustomPaint(
                      painter: _CountdownDial(
                        secondsProgress: value.clamp(0.0, 1.0),
                        hourProgress:
                            seconds / InviteEmailActivity.window.inSeconds,
                        accent: colors.primary,
                        track: colors.outlineVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 29),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Oldest send clears in',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        counter(
                          const ValueKey('invite-time-left'),
                          _format(seconds),
                          digits,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          children: [
            counter(
              const ValueKey('invite-send-count'),
              '${sends.length}',
              theme.textTheme.titleMedium!.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text('$label in the last hour', style: theme.textTheme.bodyMedium),
          ],
        ),
        Text(
          'On this device',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  int _secondsLeft(DateTime now, DateTime oldest) {
    final left = oldest.add(InviteEmailActivity.window).difference(now);
    return math.max(1, (left.inMilliseconds + 999) ~/ 1000);
  }

  String _format(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _CountdownDial extends CustomPainter {
  const _CountdownDial({
    required this.secondsProgress,
    required this.hourProgress,
    required this.accent,
    required this.track,
  });

  final double secondsProgress, hourProgress;
  final Color accent, track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    const start = -math.pi / 2;
    const lap = 2 * math.pi;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var tick = 0; tick < 60; tick++) {
      final major = tick % 5 == 0;
      final radial = Offset.fromDirection(start + lap * tick / 60);
      paint
        ..color = tick < secondsProgress * 60 ? accent : track
        ..strokeWidth = major ? 2 : 1;
      canvas.drawLine(
        center + radial * (radius - (major ? 11 : 5)),
        center + radial * radius,
        paint,
      );
    }

    final inner = radius - 18;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = track;
    canvas.drawCircle(center, inner, paint);
    paint.color = accent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: inner),
      start,
      lap * hourProgress,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
      center + Offset.fromDirection(start + lap * hourProgress, inner),
      3.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CountdownDial oldDelegate) =>
      oldDelegate.secondsProgress != secondsProgress ||
      oldDelegate.hourProgress != hourProgress ||
      oldDelegate.accent != accent ||
      oldDelegate.track != track;
}
