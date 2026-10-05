import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/consumption.dart';
import '../../domain/dates.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

enum _Period { week, month, year }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ConsumptionBuilder(builder: (context, m) {
        final peak = _peakDay(m);
        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            const ScreenTitle('Statisztika'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  _Segmented(value: _period, onChanged: (p) => setState(() => _period = p)),
                  const SizedBox(height: 12),
                  Rise(key: ValueKey(_period), child: _PeriodChart(model: m, period: _period)),
                  const SizedBox(height: 12),
                  Rise(delayMs: 150, child: _MonthlyChart(model: m)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Rise(
                          delayMs: 300,
                          child: StatTile(
                            label: 'Csúcsnap',
                            value: peak == null ? '—' : Fmt.m3One(peak.used!),
                            unit: 'm³',
                            footer: peak == null ? 'nincs adat' : Fmt.shortDate(peak.day),
                            valueColor: AppColors.warn,
                            valueSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Rise(
                          delayMs: 380,
                          child: StatTile(
                            label: 'Gázévben összesen',
                            value: Fmt.m3(m.yearUsed),
                            unit: 'm³',
                            footer: '${Fmt.shortDate(m.yearStart)} óta',
                            valueColor: AppColors.accent,
                            valueSize: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  DailyUsage? _peakDay(ConsumptionModel m) {
    final days = switch (_period) {
      _Period.week => m.lastDays(7),
      _Period.month => m.lastDays(30),
      _Period.year => m.lastDays(daysBetween(m.yearStart, m.today) + 1),
    };
    DailyUsage? best;
    for (final d in days) {
      if (d.used != null && (best == null || d.used! > best.used!)) best = d;
    }
    return best;
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});

  final _Period value;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {_Period.week: 'Hét', _Period.month: 'Hónap', _Period.year: 'Év'};
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final p in _Period.values) ...[
            if (p != _Period.week) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                selected: p == value,
                button: true,
                child: Material(
                  color: p == value ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(p),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(labels[p]!, style: sans(14, weight: FontWeight.w700, color: p == value ? AppColors.onAccent : AppColors.muted)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodChart extends StatelessWidget {
  const _PeriodChart({required this.model, required this.period});

  final ConsumptionModel model;
  final _Period period;

  @override
  Widget build(BuildContext context) {
    final List<BarDatum> bars;
    final String title;
    final String startLabel;
    final String endLabel;
    switch (period) {
      case _Period.week || _Period.month:
        final days = model.lastDays(period == _Period.week ? 7 : 30);
        final labelled = UsageBars.labelledIndices([for (final d in days) d.used]);
        title = 'Napi fogyasztás';
        bars = [
          for (var i = 0; i < days.length; i++)
            BarDatum(
              value: days[i].used,
              recommended: days[i].recommended,
              highlight: i == days.length - 1,
              label: period == _Period.week ? Fmt.weekdayInitials[days[i].day.weekday - 1] : null,
              valueLabel: labelled.contains(i) ? Fmt.m3One(days[i].used!) : null,
            ),
        ];
        startLabel = Fmt.shortDate(days.first.day);
        endLabel = Fmt.shortDate(days.last.day);
      case _Period.year:
        final weeks = model.weeklyUsageThisYear();
        final labelled = UsageBars.labelledIndices([for (final w in weeks) w.used]);
        title = 'Heti fogyasztás';
        bars = [
          for (var i = 0; i < weeks.length; i++)
            BarDatum(
              value: weeks[i].used,
              recommended: weeks[i].recommended,
              highlight: i == weeks.length - 1,
              valueLabel: labelled.contains(i) ? Fmt.m3(weeks[i].used!) : null,
            ),
        ];
        startLabel = Fmt.shortDate(weeks.first.start);
        endLabel = Fmt.shortDate(weeks.last.end);
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          _CardHeader(title: title, legend: [
            const LegendItem(swatch: DashedLine(color: AppColors.text), label: 'ajánlott'),
            LegendItem(
              swatch: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.warn, borderRadius: BorderRadius.circular(2))),
              label: 'felette',
            ),
          ]),
          const SizedBox(height: 14),
          UsageBars(height: 146, bars: bars, gap: bars.length > 31 ? 2 : 3, stepDelayMs: bars.length > 31 ? 12 : 25),
          if (period != _Period.week) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(startLabel, style: sans(11, color: AppColors.muted)), Text(endLabel, style: sans(11, color: AppColors.muted))],
            ),
          ],
        ],
      ),
    );
  }
}

/// Kártyacím jobbra igazított jelmagyarázattal; keskeny kijelzőn tördelődik.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.legend});

  final String title;
  final List<Widget> legend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(title, style: sans(15, weight: FontWeight.w700)),
          Wrap(spacing: 10, runSpacing: 4, children: legend),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.model});

  final ConsumptionModel model;

  @override
  Widget build(BuildContext context) {
    final used = model.monthlyUsage();
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          _CardHeader(title: 'Havi fogyasztás (gázév)', legend: [
            LegendItem(swatch: Container(width: 14, height: 2, color: AppColors.text), label: 'ajánlott · m³'),
          ]),
          const SizedBox(height: 14),
          UsageBars(
            height: 140,
            gap: 6,
            radius: 6,
            solidRecommended: true,
            baseDelayMs: 300,
            stepDelayMs: 70,
            labelStyle: sans(10, color: AppColors.muted),
            bars: [
              for (var i = 0; i < used.length; i++)
                BarDatum(
                  value: used[i].used,
                  recommended: used[i].recommended,
                  label: Fmt.monthShort[used[i].month.month - 1],
                  valueLabel: Fmt.m3(used[i].used),
                  highlight: i == used.length - 1,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
