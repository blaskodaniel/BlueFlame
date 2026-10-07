import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/consumption.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// A kedvezményes keret áttekintése. A keret értéke csak a Beállításokban
/// módosítható; itt egy link visz oda.
class LimitScreen extends StatelessWidget {
  const LimitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ConsumptionBuilder(builder: (context, m) {
        final limit = m.annualLimit;
        final estimate = m.estimatedYearEnd;
        final reserve = estimate == null ? null : limit - estimate;
        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            const ScreenTitle('Éves limit'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  Rise(
                    child: Panel(
                      radius: 28,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Kedvezményes keret egy gázévre', textAlign: TextAlign.center, style: sans(13, color: AppColors.muted)),
                          const SizedBox(height: 10),
                          Text(Fmt.m3(limit), textAlign: TextAlign.center, style: mono(46, letterSpacing: -1.5, height: 1)),
                          const SizedBox(height: 4),
                          Text('m³ / gázév · havi átlag ${Fmt.m3(limit / 12)} m³', textAlign: TextAlign.center, style: sans(13, color: AppColors.muted)),
                          Text(
                            '${Fmt.m3(limit * m.heatingValue)} MJ · ${Fmt.m3One(m.heatingValue)} MJ/m³ fűtőértékkel',
                            textAlign: TextAlign.center,
                            style: sans(12, color: AppColors.muted),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () => context.go('/beallitasok'),
                            style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: AppColors.accent),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: Text('Módosítás a Beállításokban', style: sans(14, weight: FontWeight.w700, color: AppColors.accent)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Rise(
                    delayMs: 150,
                    child: Panel(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('Várható alakulás', style: sans(15, weight: FontWeight.w700))),
                              Text('kumulált m³', style: mono(12, weight: FontWeight.w400, color: AppColors.muted)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LimitChart(model: m),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              LegendItem(swatch: Container(width: 14, height: 3, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))), label: 'Eddig'),
                              const LegendItem(swatch: DashedLine(color: AppColors.accent, thickness: 3, dash: 2, gap: 3), label: 'Becslés'),
                              const LegendItem(swatch: DashedLine(color: AppColors.text), label: 'Havi keretek'),
                              const LegendItem(swatch: DashedLine(color: AppColors.warn), label: 'Limit'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Rise(
                          delayMs: 300,
                          child: StatTile(
                            label: 'Becsült gázév vége',
                            value: estimate == null ? '—' : '~${Fmt.m3(estimate)}',
                            unit: 'm³',
                            footer: 'a havi keretek arányában',
                            valueSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Rise(
                          delayMs: 380,
                          child: StatTile(
                            label: reserve != null && reserve < 0 ? 'Várható túllépés' : 'Tartalék',
                            value: reserve == null ? '—' : '~${Fmt.m3(reserve.abs())}',
                            unit: 'm³',
                            footer: 'a limithez képest',
                            valueColor: reserve != null && reserve < 0 ? AppColors.warn : AppColors.accent,
                            valueSize: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Rise(delayMs: 420, child: _PriceCard(model: m)),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Az árlépcső szemléltetése: a keretig kedvezményes, felette piaci ár,
/// a becsült gázév végi fogyasztás jelölésével és a becsült költséggel.
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.model});

  final ConsumptionModel model;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final pricing = m.pricing;
    final limit = m.annualLimit;
    final est = m.estimatedYearEnd;
    final over = est == null ? 0.0 : (est - limit).clamp(0.0, double.infinity);
    // A sáv skálája: a keret + 25%, vagy a becslés, ha az nagyobb.
    final scale = [limit * 1.25, est ?? 0, m.yearUsed].reduce((a, b) => a > b ? a : b);
    double frac(double v) => scale <= 0 ? 0 : (v / scale).clamp(0.0, 1.0);

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gázár', style: sans(15, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 30,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 8,
                    width: w * frac(limit),
                    height: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: .35),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * frac(limit),
                    right: 0,
                    top: 8,
                    height: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.warn.withValues(alpha: .35),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                      ),
                    ),
                  ),
                  // Eddigi fogyasztás
                  Positioned(
                    left: 0,
                    top: 8,
                    width: w * frac(m.yearUsed),
                    height: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: m.yearUsed > limit ? AppColors.warn : AppColors.accent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                  // Becsült gázév vége
                  if (est != null)
                    Positioned(
                      left: w * frac(est) - 1.5,
                      top: 2,
                      child: Container(
                        width: 3,
                        height: 26,
                        decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${Fmt.m3(limit)} m³-ig', style: sans(12, color: AppColors.muted)),
                    Text(Fmt.unitPrice(m.discountPrice), style: mono(15, color: AppColors.accent)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('felette · ${Fmt.times(pricing.multiplier)}', style: sans(12, color: AppColors.muted)),
                    Text('~${Fmt.unitPrice(m.marketPrice)}', style: mono(15, color: AppColors.warn)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.line),
          Text(
            '${Fmt.monthNames[m.today.month - 1]} · havi keret ${Fmt.m3(m.monthKeret)} m³',
            style: sans(12, weight: FontWeight.w700, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          _CostRow(label: 'Havi számla eddig', value: Fmt.ft(m.monthCostSoFar)),
          const SizedBox(height: 6),
          _CostRow(
            label: 'Becsült havi számla',
            value: m.estimatedMonthCost == null ? '—' : '~${Fmt.ft(m.estimatedMonthCost!)}',
            color: m.monthReachesMarketPrice ? AppColors.warn : AppColors.accent,
          ),
          const SizedBox(height: 14),
          Text('Gázév', style: sans(12, weight: FontWeight.w700, color: AppColors.muted)),
          const SizedBox(height: 6),
          _CostRow(label: 'Havi számlák eddig', value: Fmt.ft(m.billsSoFar)),
          const SizedBox(height: 6),
          _CostRow(
            label: 'Havi számlák becsült összege',
            value: m.estimatedBillsTotal == null ? '—' : '~${Fmt.ft(m.estimatedBillsTotal!)}',
            color: over > 0 ? AppColors.warn : AppColors.accent,
          ),
          const SizedBox(height: 6),
          _CostRow(
            label: 'Éves elszámolás után',
            value: est == null ? '—' : '~${Fmt.ft(pricing.costOf(est))}',
            color: over > 0 ? AppColors.warn : AppColors.accent,
          ),
          if ((m.estimatedRefund ?? 0) > 0) ...[
            const SizedBox(height: 6),
            _CostRow(label: 'Várható visszatérítés', value: '~${Fmt.ft(m.estimatedRefund!)}'),
          ],
          if (over > 0) ...[
            const SizedBox(height: 6),
            _CostRow(
              label: 'Ebből a keret feletti ~${Fmt.m3(over)} m³ többletköltsége',
              value: '+${Fmt.ft(over * (m.marketPrice - m.discountPrice))}',
              color: AppColors.warn,
            ),
          ],
          const SizedBox(height: 10),
          LegendItem(
            swatch: Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(2))),
            label: 'becsült fogyasztás a gázév végén',
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(label, style: sans(13, color: AppColors.muted))),
        const SizedBox(width: 8),
        Text(value, style: mono(14, color: color)),
      ],
    );
  }
}
