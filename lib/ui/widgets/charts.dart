import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/consumption.dart';
import '../../domain/dates.dart';
import 'common.dart';
import 'motion.dart';

// ---------------------------------------------------------------------------
// Gyűrűs mutató (Főoldal)
// ---------------------------------------------------------------------------

/// Az éves keret felhasználtságát mutató gyűrű, az ajánlott ütem jelölőjével.
class RingGauge extends StatelessWidget {
  const RingGauge({super.key, required this.progress, required this.pace, required this.child, this.size = 240});

  /// Felhasznált arány (0–1, a túllépés is 1-nél áll meg a rajzon).
  final double progress;

  /// Az ajánlott ütem aránya (0–1).
  final double pace;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Entrance(
        delay: const Duration(milliseconds: 200),
        duration: const Duration(milliseconds: 1800),
        builder: (context, t, child) => CustomPaint(
          painter: _RingPainter(progress: progress.clamp(0, 1) * t, pace: pace.clamp(0, 1), over: progress > 1),
          child: child,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.pace, required this.over});

  final double progress;
  final double pace;
  final bool over;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 240;
    final c = size.center(Offset.zero);
    final r = 100 * scale;
    final stroke = 14 * scale;
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.track);

    final color = over ? AppColors.warn : AppColors.accent;
    if (progress > 0) {
      final rect = Rect.fromCircle(center: c, radius: r);
      final sweep = 2 * math.pi * progress;
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color);
    }

    // Ajánlott ütem jelölő: rövid vonal a gyűrűn keresztben.
    final a = -math.pi / 2 + 2 * math.pi * pace;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(c + dir * (r - 14 * scale), c + dir * (r + 14 * scale), Paint()
      ..color = AppColors.text
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.pace != pace || old.over != over;
}

// ---------------------------------------------------------------------------
// Oszlopdiagram ajánlott-érték jelölőkkel
// ---------------------------------------------------------------------------

class BarDatum {
  const BarDatum({required this.value, this.recommended, this.label, this.valueLabel, this.highlight = false});

  /// `null`: nincs adat (halvány csonk).
  final double? value;
  final double? recommended;
  final String? label;
  final String? valueLabel;
  final bool highlight;
}

/// Oszlopdiagram: az ajánlott érték feletti oszlop borostyán, a kiemelt
/// (legutóbbi) kék, a többi halványkék; opcionális ajánlott-szint jelölő.
class UsageBars extends StatelessWidget {
  const UsageBars({
    super.key,
    required this.bars,
    required this.height,
    this.gap = 3,
    this.radius = 3,
    this.showRecommended = true,
    this.solidRecommended = false,
    this.labelStyle,
    this.valueLabelSize = 10,
    this.baseDelayMs = 100,
    this.stepDelayMs = 25,
  });

  final List<BarDatum> bars;
  final double height;
  final double gap;
  final double radius;
  final bool showRecommended;
  final bool solidRecommended;
  final TextStyle? labelStyle;
  final double valueLabelSize;
  final int baseDelayMs;
  final int stepDelayMs;

  /// Mely oszlopok kapjanak értékfeliratot: kevés oszlopnál mind, sok
  /// oszlopnál csak a legnagyobb és az utolsó (ha nem lógnak egymásba).
  static Set<int> labelledIndices(List<double?> values, {int denseLimit = 14}) {
    final withData = [for (var i = 0; i < values.length; i++) if (values[i] != null) i];
    if (values.length <= denseLimit) return withData.toSet();
    if (withData.isEmpty) return {};
    final last = withData.last;
    final peak = withData.reduce((a, b) => values[b]! > values[a]! ? b : a);
    return {last, if ((peak - last).abs() >= 4) peak};
  }

  static double _barHeight(BarDatum b, double top, double plot) => b.value == null ? 3 : math.max(3, b.value! / top * plot);

  static Color _labelColor(BarDatum b) {
    if (b.value != null && b.recommended != null && b.value! > b.recommended! + 1e-9) return AppColors.warn;
    return b.highlight ? AppColors.accent : AppColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    final maxV = bars.fold<double>(0, (m, b) => math.max(m, math.max(b.value ?? 0, showRecommended ? b.recommended ?? 0 : 0)));
    final top = maxV <= 0 ? 1.0 : maxV;
    final hasValueLabels = bars.any((b) => b.valueLabel != null);
    // 16 px a felirat + tartalék, hogy az ajánlott-szint fölé tolt felirat is elférjen.
    final labelSpace = hasValueLabels ? 20.0 : 0.0;
    final plot = height - labelSpace;

    Color colorFor(BarDatum b, int i) {
      if (b.value == null) return AppColors.track;
      if (b.recommended != null && b.value! > b.recommended! + 1e-9) return AppColors.warn;
      if (b.highlight) return AppColors.accent;
      return AppColors.accent.withValues(alpha: .28 + (b.value! / top) * .3);
    }

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (bars[i].valueLabel != null)
                            // A felirat szélesebb lehet az oszlopnál, ezért nem zsugorítjuk.
                            SizedBox(
                              height: 16,
                              child: OverflowBox(
                                maxWidth: 64,
                                alignment: Alignment.topCenter,
                                child: Text(
                                  bars[i].valueLabel!,
                                  softWrap: false,
                                  style: mono(valueLabelSize, weight: FontWeight.w400, color: _labelColor(bars[i])),
                                ),
                              ),
                            ),
                          // Ha az ajánlott-szint jelölő az oszlop fölött van, a felirat fölé kerül.
                          if (bars[i].valueLabel != null && showRecommended && bars[i].recommended != null)
                            SizedBox(
                              height: math.max(0, bars[i].recommended! / top * plot + 3 - _barHeight(bars[i], top, plot)),
                            ),
                          Grow(
                            delayMs: baseDelayMs + i * stepDelayMs,
                            child: Container(
                              height: _barHeight(bars[i], top, plot),
                              decoration: BoxDecoration(color: colorFor(bars[i], i), borderRadius: BorderRadius.circular(radius)),
                            ),
                          ),
                        ],
                      ),
                      if (showRecommended && bars[i].recommended != null)
                        Positioned(
                          left: -gap / 2,
                          right: -gap / 2,
                          bottom: bars[i].recommended! / top * plot - 1,
                          child: solidRecommended
                              ? Container(height: 2, decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(1)))
                              : Opacity(opacity: .85, child: LayoutBuilder(builder: (context, c) => DashedLine(color: AppColors.text, width: c.maxWidth))),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (bars.any((b) => b.label != null)) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Text(bars[i].label ?? '',
                      textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.clip, style: labelStyle ?? sans(11, color: AppColors.muted)),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kumulált görbe (Éves limit)
// ---------------------------------------------------------------------------

/// Kumulált fogyasztás: eddigi (folytonos), becslés (pontozott), ajánlott
/// (szaggatott) és a limit (szaggatott borostyán) január–december.
class LimitChart extends StatelessWidget {
  const LimitChart({super.key, required this.model});

  final ConsumptionModel model;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 342 / 190,
      child: Semantics(
        label: 'Kumulált fogyasztás és becslés az éves limithez képest',
        child: Entrance(
          delay: const Duration(milliseconds: 300),
          duration: const Duration(milliseconds: 1800),
          curve: const Cubic(.3, .7, .2, 1),
          builder: (context, t, _) => CustomPaint(painter: _LimitPainter(model, t)),
        ),
      ),
    );
  }
}

class _LimitPainter extends CustomPainter {
  _LimitPainter(this.m, this.t);

  final ConsumptionModel m;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 14.0, right = 10.0, top = 20.0, bottom = 18.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final total = m.yearLength.toDouble();
    final estEnd = m.estimatedYearEnd ?? 0;
    final maxY = [m.annualLimit, estEnd, m.monthlyTargetSum].reduce(math.max) * 1.0;
    final yTop = maxY <= 0 ? 1.0 : maxY;

    // x: a gázév hányadik napja (aug. 1. = 1).
    double xOf(DateTime day) => left + (daysBetween(m.yearStart, day) + 1) / total * w;
    Offset pt(DateTime day, double v) => Offset(xOf(day), top + h - v / yTop * h);

    final monthEnds = [for (final mo in m.yearMonths) DateTime(mo.year, mo.month, daysInMonth(mo.year, mo.month))];
    final base = Offset(left, top + h);

    // Rácsvonalak
    canvas.drawLine(Offset(left, top + h), Offset(left + w, top + h), Paint()..color = const Color(0xFF232A38));
    canvas.drawLine(Offset(left, top + h / 2), Offset(left + w, top + h / 2), Paint()..color = AppColors.track);

    // Limit
    final limitY = top + h - m.annualLimit / yTop * h;
    _dashed(canvas, [Offset(left, limitY), Offset(left + w, limitY)], AppColors.warn, 1.5, 5, 4);
    _text(canvas, 'limit ${Fmt.m3(m.annualLimit)}',Offset(left, limitY - 14), AppColors.warn);

    final fade = ((t - .6) / .4).clamp(0.0, 1.0);

    // Ajánlott
    if (fade > 0) {
      final rec = [base, for (final d in monthEnds) pt(d, m.recommendedCumulative(d))];
      _dashed(canvas, rec, AppColors.text.withValues(alpha: .75 * fade), 2, 6, 5);
    }

    final end = m.dataEnd;
    if (end != null) {
      // Eddigi
      final actual = <Offset>[base];
      for (final d in monthEnds) {
        if (!d.isBefore(end)) break;
        actual.add(pt(d, m.usedBetween(m.yearStart, d)));
      }
      final now = pt(end, m.yearUsed);
      actual.add(now);
      final path = _path(actual);
      final metric = path.computeMetrics().toList();
      final drawn = Path();
      for (final mt in metric) {
        drawn.addPath(mt.extractPath(0, mt.length * t), Offset.zero);
      }
      canvas.drawPath(drawn, _stroke(AppColors.accent.withValues(alpha: .5), 3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawPath(drawn, _stroke(AppColors.accent, 3));

      // Becslés
      if (fade > 0) {
        final est = [now, for (final d in monthEnds) if (d.isAfter(end)) pt(d, m.estimatedCumulative(d)!)];
        if (est.length > 1) {
          _dashed(canvas, est, AppColors.accent.withValues(alpha: .9 * fade), 2.5, 2, 6, round: true);
          canvas.drawCircle(est.last, 4, Paint()..color = AppColors.accent.withValues(alpha: fade));
          // Év végi becslés felirata a pont alatt, jobbra igazítva.
          _pill(canvas, '~${Fmt.m3(m.estimatedYearEnd!)}', est.last + const Offset(0, 10), size, alignRight: true, opacity: fade);
        }
      }
      canvas.drawCircle(now, 5, Paint()..color = AppColors.bg);
      canvas.drawCircle(now, 5, _stroke(AppColors.accent, 2.5));
      // A mai kumulált érték felirata a pont fölött.
      _pill(canvas, Fmt.m3(m.yearUsed), now + const Offset(0, -28), size, opacity: ((t - .5) / .5).clamp(0.0, 1.0));
    }

    // Tengelyfeliratok
    _text(canvas, 'aug', Offset(left, top + h + 4), AppColors.muted);
    _text(canvas, 'jan', Offset(xOf(DateTime(m.yearStart.year + 1)) - 10, top + h + 4), AppColors.muted);
    _text(canvas, 'júl', Offset(left + w - 20, top + h + 4), AppColors.muted);
  }

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;

  Path _path(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p;
  }

  void _dashed(Canvas canvas, List<Offset> pts, Color color, double width, double dash, double gap, {bool round = false}) {
    final paint = _stroke(color, width)..strokeCap = round ? StrokeCap.round : StrokeCap.butt;
    for (final metric in _path(pts).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
      }
    }
  }

  /// Kis, háttérrel kiemelt értékfelirat; `at` a felső közepe (vagy jobb
  /// felső sarka, ha [alignRight]); a vászonon belül tartjuk.
  void _pill(Canvas canvas, String s, Offset at, Size size, {bool alignRight = false, double opacity = 1}) {
    if (opacity <= 0) return;
    final tp = TextPainter(
      text: TextSpan(text: s, style: mono(11, color: AppColors.accent.withValues(alpha: opacity))),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    const padX = 6.0, padY = 2.0;
    final w = tp.width + padX * 2;
    final h = tp.height + padY * 2;
    final left = (alignRight ? at.dx - w + padX : at.dx - w / 2).clamp(0.0, size.width - w);
    final top = at.dy.clamp(0.0, size.height - h);
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(6));
    canvas.drawRRect(rect, Paint()..color = AppColors.surface2.withValues(alpha: .92 * opacity));
    canvas.drawRRect(rect, _stroke(AppColors.accent.withValues(alpha: .35 * opacity), 1));
    tp.paint(canvas, Offset(left + padX, top + padY));
  }

  void _text(Canvas canvas, String s, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: mono(10, weight: FontWeight.w400, color: color)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_LimitPainter old) => old.t != t || old.m != m;
}
