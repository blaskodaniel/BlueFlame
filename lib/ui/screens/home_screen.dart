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
    final over = m.usedRatio > 1;
    return Panel(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: [
          Semantics(
            label: 'Az éves keret ${Fmt.percent(m.usedRatio)}-a elfogyott',
            child: RingGauge(
              progress: m.usedRatio,
              pace: m.recommendedPaceRatio,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Fmt.m3(m.yearUsed), style: mono(46, letterSpacing: -1.5, height: 1)),
                  const SizedBox(height: 2),
                  Text('m³ a ${Fmt.m3(m.annualLimit)} m³-es keretből', style: sans(13, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (over ? AppColors.warn : AppColors.accent).withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(Fmt.percent(m.usedRatio), style: mono(12, color: over ? AppColors.warn : AppColors.accent)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 6,
            children: [
              LegendItem(
                swatch: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                label: 'Eddigi fogyasztás',
              ),
              LegendItem(
                swatch: Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(2))),
                label: 'Ajánlott ütem (${Fmt.percent(m.recommendedPaceRatio)})',
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

/// Eddigi és becsült gázköltség a kétsávos ár alapján, túllépési figyelmeztetéssel.
class _CostCard extends StatelessWidget {
  const _CostCard({required this.model});

  final ConsumptionModel model;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final est = m.estimatedCost;
    final over = m.estimatedOverLimit ?? 0;
    final alreadyOver = m.yearUsed > m.annualLimit;
    final warn = alreadyOver || over > 0;
    final String note;
    if (alreadyOver) {
      note = 'Túllépted a kedvezményes keretet. A további gáz ${Fmt.unitPrice(m.marketPrice)} '
          '(${Fmt.times(m.pricing.multiplier)} drágább).';
    } else if (over > 0) {
      note = 'A becslés szerint kb. ${Fmt.m3(over)} m³-rel lépnéd túl a keretet. Ez a rész '
          '${Fmt.unitPrice(m.marketPrice)} áron kb. +${Fmt.ft(m.estimatedExtraCost!)} többletköltség.';
    } else {
      note = '${Fmt.m3(m.annualLimit)} m³-ig ${Fmt.unitPrice(m.discountPrice)}, '
          'felette ${Fmt.unitPrice(m.marketPrice)} (${Fmt.times(m.pricing.multiplier)}).';
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gázköltség', style: sans(15, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          _CostTableRow(
            label: '',
            soFar: Text('Eddig', style: sans(11.5, color: AppColors.muted)),
            estimate: Text('Becsült, a végéig', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: AppColors.muted)),
          ),
          const SizedBox(height: 6),
          _CostTableRow(
            label: Fmt.monthNames[m.today.month - 1],
            soFar: _amount(Fmt.ft(m.monthCostSoFar)),
            estimate: _amount(
              m.estimatedMonthCost == null ? '—' : '~${Fmt.ft(m.estimatedMonthCost!)}',
              color: m.monthReachesMarketPrice ? AppColors.warn : AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          _CostTableRow(
            label: 'Gázév',
            soFar: _amount(Fmt.ft(m.costSoFar)),
            estimate: _amount(est == null ? '—' : '~${Fmt.ft(est)}', color: warn ? AppColors.warn : AppColors.accent),
          ),
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
