import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/consumption.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ConsumptionBuilder(builder: (context, m) {
        final avg = m.averageOfLastDays(7);
        final estimate = m.estimatedYearEnd;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            _Header(today: m.today),
            const SizedBox(height: 16),
            Rise(child: _RingCard(model: m)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Rise(delayMs: 120, child: StatTile(label: 'Hátralévő', value: Fmt.m3(m.remaining), unit: 'm³', valueColor: m.remaining < 0 ? AppColors.warn : null))),
                const SizedBox(width: 10),
                Expanded(child: Rise(delayMs: 200, child: StatTile(label: 'Napi átlag', value: avg == null ? '—' : Fmt.m3One(avg), unit: 'm³ / nap'))),
                const SizedBox(width: 10),
                Expanded(
                  child: Rise(
                    delayMs: 280,
                    child: StatTile(
                      label: 'Gázév végére',
                      value: estimate == null ? '—' : '~${Fmt.m3(estimate)}',
                      unit: 'm³ becsült',
                      valueColor: estimate != null && estimate > m.annualLimit ? AppColors.warn : AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Rise(delayMs: 320, child: _CostCard(model: m)),
            const SizedBox(height: 12),
            Rise(delayMs: 360, child: _LastWeekCard(model: m)),
            const SizedBox(height: 12),
            Rise(
              delayMs: 440,
              child: PrimaryButton(
                icon: Icons.add_rounded,
                label: m.hasReadingToday ? 'Mai állás módosítása' : 'Mai állás rögzítése',
                onPressed: () => context.push('/rogzites'),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: const Icon(Icons.local_fire_department_rounded, color: AppColors.accent, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kékláng', style: sans(20, weight: FontWeight.w700, letterSpacing: -0.3)),
              Text(Fmt.headerDate(today), style: sans(13, color: AppColors.muted)),
            ],
          ),
        ),
        SquareIconButton(icon: Icons.schedule_rounded, label: 'Előzmények', onPressed: () => context.go('/elozmenyek')),
      ],
    );
  }
}

class _RingCard extends StatelessWidget {
  const _RingCard({required this.model});

  final ConsumptionModel model;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final monthName = Fmt.monthNames[m.today.month - 1];
    return Panel(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MiniRing(
                  title: 'Gázév',
                  semantics: 'Az éves keret ${Fmt.percent(m.usedRatio)}-a elfogyott',
                  used: m.yearUsed,
                  keret: m.annualLimit,
                  ratio: m.usedRatio,
                  pace: m.recommendedPaceRatio,
                  paceValue: m.recommendedToDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniRing(
                  title: monthName,
                  semantics: 'A $monthName keret ${Fmt.percent(m.monthUsedRatio)}-a elfogyott',
                  used: m.monthUsed,
                  keret: m.monthKeret,
                  ratio: m.monthUsedRatio,
                  pace: m.monthKeret <= 0 ? 0 : m.monthKeretToDate / m.monthKeret,
                  paceValue: m.monthKeretToDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 6,
            children: [
              LegendItem(
                swatch: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                label: 'eddigi fogyasztás',
              ),
              LegendItem(
                swatch: Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(2))),
                label: 'ahol a keret szerint ma tartanod kellene',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Gázév: ${Fmt.range(m.yearStart, m.yearEnd)}', textAlign: TextAlign.center, style: sans(12, color: AppColors.muted)),
          if (m.dataEnd == null) ...[
            const SizedBox(height: 12),
            Text(
              m.readings.isEmpty
                  ? 'Rögzítsd az első leolvasást! A fogyasztást a második leolvasástól tudjuk számolni.'
                  : 'Még egy leolvasás kell, hogy a fogyasztást számolni tudjuk.',
              textAlign: TextAlign.center,
              style: sans(13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Egy kisebb gyűrű a kártyán: cím, `used / keret`, százalék, és alatta a fehér
/// jelölő értéke (hol kellene ma tartani a keret szerint).
class _MiniRing extends StatelessWidget {
  const _MiniRing({
    required this.title,
    required this.semantics,
    required this.used,
    required this.keret,
    required this.ratio,
    required this.pace,
    required this.paceValue,
  });

  final String title;
  final String semantics;
  final double used;
  final double keret;
  final double ratio;
  final double pace;
  final double paceValue;

  @override
  Widget build(BuildContext context) {
    final over = ratio > 1;
    final color = over ? AppColors.warn : AppColors.accent;
    return Column(
      children: [
        Text(title, style: sans(14, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Semantics(
          label: semantics,
          child: LayoutBuilder(builder: (context, c) {
            final size = c.maxWidth.clamp(110.0, 160.0);
            return RingGauge(
              size: size,
              progress: ratio,
              pace: pace,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(child: Text(Fmt.m3(used), style: mono(size * .2, letterSpacing: -1, height: 1, color: over ? AppColors.warn : null))),
                  const SizedBox(height: 2),
                  Text('/ ${Fmt.m3(keret)} m³', style: mono(11, weight: FontWeight.w400, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(999)),
                    child: Text(Fmt.percent(ratio), style: mono(11, color: color)),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text('ma: ${Fmt.m3(paceValue)} m³', style: mono(12, weight: FontWeight.w400, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}

/// Havi diktálás szerinti gázköltség: a hónap kerete, a havi számla, a gázév
/// havi számláinak összege és az éves elszámolás utáni összeg.
class _CostCard extends StatelessWidget {
  const _CostCard({required this.model});

  final ConsumptionModel model;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final monthName = Fmt.monthNames[m.today.month - 1];
    final yearOver = m.estimatedOverLimit ?? 0;
    final alreadyOver = m.yearUsed > m.annualLimit;
    final yearWarn = alreadyOver || yearOver > 0;
    final monthWarn = m.monthReachesMarketPrice;
    final warn = yearWarn || monthWarn;
    final refund = m.estimatedRefund ?? 0;
    final String note;
    if (alreadyOver) {
      note = 'Túllépted az éves kedvezményes keretet. A további gáz ${Fmt.unitPrice(m.marketPrice)} '
          '(${Fmt.times(m.pricing.multiplier)} drágább), és ezt az éves elszámolás sem hozza vissza.';
    } else if (yearOver > 0) {
      note = 'A becslés szerint kb. ${Fmt.m3(yearOver)} m³-rel lépnéd túl az éves keretet. Ez a rész '
          '${Fmt.unitPrice(m.marketPrice)} áron kb. +${Fmt.ft(m.estimatedExtraCost!)}, és nem jár vissza.';
    } else if (monthWarn) {
      note = 'A $monthName keret ${Fmt.m3(m.monthKeret)} m³, a becslés szerint kb. '
          '${Fmt.m3(m.estimatedMonthOver)} m³ piaci áron kerül a havi számlára '
          '(+${Fmt.ft(m.estimatedMonthOver * (m.marketPrice - m.discountPrice))}). '
          'Ha éves szinten a keret alatt maradsz, ez az éves elszámoláskor visszajár.';
    } else {
      note = 'A havi keret felett a havi számlán ${Fmt.unitPrice(m.marketPrice)} '
          '(${Fmt.times(m.pricing.multiplier)}) a kedvezményes ${Fmt.unitPrice(m.discountPrice)} helyett.';
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('Gázköltség', style: sans(15, weight: FontWeight.w700))),
              Text('havi diktálás', style: sans(12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          _MonthKeretBar(model: m),
          const SizedBox(height: 12),
          _SavedKeretRow(model: m),
          const SizedBox(height: 14),
          _CostTableRow(
            label: '',
            soFar: Text('Eddig', style: sans(11.5, color: AppColors.muted)),
            estimate: Text('Becsült, a végéig', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: AppColors.muted)),
          ),
          const SizedBox(height: 6),
          _CostTableRow(
            label: monthName,
            soFar: _amount(Fmt.ft(m.monthCostSoFar)),
            estimate: _amount(
              m.estimatedMonthCost == null ? '—' : '~${Fmt.ft(m.estimatedMonthCost!)}',
              color: monthWarn ? AppColors.warn : AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          _CostTableRow(
            label: 'Gázév',
            soFar: _amount(Fmt.ft(m.billsSoFar)),
            estimate: _amount(
              m.estimatedBillsTotal == null ? '—' : '~${Fmt.ft(m.estimatedBillsTotal!)}',
              color: warn ? AppColors.warn : AppColors.accent,
            ),
          ),
          if (refund > 0) ...[
            const SizedBox(height: 6),
            _CostTableRow(
              label: 'Elszámolás',
              soFar: Text('éves elszámolás után', style: sans(11.5, color: AppColors.muted)),
              estimate: _amount('~${Fmt.ft(m.estimatedCost!)}', color: AppColors.accent),
            ),
            const SizedBox(height: 4),
            Text('Várhatóan visszajár: ~${Fmt.ft(refund)}', style: sans(12, color: AppColors.muted)),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (warn ? AppColors.warn : AppColors.accent).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(note, style: sans(12.5, color: warn ? AppColors.warn : AppColors.muted)),
          ),
        ],
      ),
    );
  }
}

/// A lezárt hónapokból megmaradt (fel nem használt) keret: ennyivel lehet egy
/// hidegebb hónapban a havi keret felett fogyasztani úgy, hogy az éves
/// elszámoláskor még kedvezményes áron számolják el.
class _SavedKeretRow extends StatelessWidget {
  const _SavedKeretRow({required this.model});

  final ConsumptionModel model;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final saved = m.savedKeret;
    final hasData = m.hasClosedTrackedMonth;
    final positive = saved >= 0;
    final color = !hasData ? AppColors.muted : (positive ? AppColors.accent : AppColors.warn);
    final String note;
    if (!hasData) {
      note = 'Az első lezárt hónap után látszik, mennyi keret maradt meg.';
    } else if (positive) {
      note = 'Ennyivel fogyaszthatsz többet egy hidegebb hónapban: a havi számlán piaci áron '
          'szerepel, de az éves elszámoláskor visszajár.';
    } else {
      note = 'Az eddigi hónapokban összesen ennyivel fogyott több a keretnél.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('Korábbi hónapokból megmaradt keret', style: sans(13, color: AppColors.muted))),
              Text(
                hasData ? '${positive ? '+' : '−'}${Fmt.m3(saved.abs())} m³' : '—',
                style: mono(16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(note, style: sans(12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Az aktuális hónap kedvezményes keretének kihasználtsága: eddigi fogyasztás
/// sávként, a hónap végére becsült fogyasztás jelölővel.
class _MonthKeretBar extends StatelessWidget {
  const _MonthKeretBar({required this.model});

  final ConsumptionModel model;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final keret = m.monthKeret;
    final used = m.monthUsed;
    final est = m.estimatedMonthUsed;
    final scale = [keret, used, est ?? 0].reduce((a, b) => a > b ? a : b) * 1.05;
    double frac(double v) => scale <= 0 ? 0 : (v / scale).clamp(0.0, 1.0);
    final over = used > keret;
    final monthName = Fmt.monthNames[m.today.month - 1];
    final daily = keret / (m.monthEnd.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text('$monthName kerete', style: sans(13, color: AppColors.muted))),
            Text.rich(TextSpan(children: [
              TextSpan(text: Fmt.m3(used), style: mono(15, color: over ? AppColors.warn : AppColors.text)),
              TextSpan(text: ' / ${Fmt.m3(keret)} m³', style: mono(13, weight: FontWeight.w400, color: AppColors.muted)),
            ])),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return SizedBox(
            height: 22,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 6,
                  height: 10,
                  child: Container(decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(5))),
                ),
                // A keret feletti tartomány halvány borostyánnal.
                Positioned(
                  left: w * frac(keret),
                  right: 0,
                  top: 6,
                  height: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.warn.withValues(alpha: .22),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 6,
                  height: 10,
                  width: w * frac(used),
                  child: Container(
                    decoration: BoxDecoration(color: over ? AppColors.warn : AppColors.accent, borderRadius: BorderRadius.circular(5)),
                  ),
                ),
                if (est != null)
                  Positioned(
                    left: w * frac(est) - 1.5,
                    top: 0,
                    child: Container(
                      width: 3,
                      height: 22,
                      decoration: BoxDecoration(
                        color: est > keret ? AppColors.warn : AppColors.text,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            if (est != null)
              LegendItem(
                swatch: Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(color: est > keret ? AppColors.warn : AppColors.text, borderRadius: BorderRadius.circular(2)),
                ),
                label: 'hónap végére becsült: ~${Fmt.m3(est)} m³',
              ),
            Text('napi keret: ~${Fmt.m3One(daily)} m³', style: sans(12, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}

Widget _amount(String text, {Color? color}) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, style: mono(17, color: color)),
    );

/// A költségtáblázat egy sora: időszak neve, eddigi és becsült összeg.
class _CostTableRow extends StatelessWidget {
  const _CostTableRow({required this.label, required this.soFar, required this.estimate});

  final String label;
  final Widget soFar;
  final Widget estimate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, color: AppColors.muted))),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: soFar)),
        const SizedBox(width: 8),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: estimate)),
      ],
    );
  }
}

class _LastWeekCard extends StatelessWidget {
  const _LastWeekCard({required this.model});

  final ConsumptionModel model;

  @override
  Widget build(BuildContext context) {
    final days = model.lastDays(7);
    final avg = model.averageOfLastDays(7);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('Elmúlt 7 nap', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(15, weight: FontWeight.w700))),
              const SizedBox(width: 8),
              Text(avg == null ? 'nincs adat' : 'átl. ${Fmt.m3One(avg)} m³', style: mono(12, weight: FontWeight.w400, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          UsageBars(
            height: 74,
            gap: 8,
            radius: 6,
            showRecommended: false,
            baseDelayMs: 500,
            stepDelayMs: 70,
            bars: [
              for (var i = 0; i < days.length; i++)
                BarDatum(
                  value: days[i].used,
                  label: Fmt.weekdayInitials[days[i].day.weekday - 1],
                  valueLabel: days[i].used == null ? null : Fmt.m3One(days[i].used!),
                  highlight: i == days.length - 1,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
