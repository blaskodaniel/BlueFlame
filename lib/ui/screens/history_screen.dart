import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../../router.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context, MeterReading r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leolvasás törlése'),
        content: Text('Törlöd a(z) ${Fmt.shortDate(r.day)} napi leolvasást (${Fmt.m3One(r.value)} m³)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Törlés', style: sans(14, weight: FontWeight.w700, color: AppColors.warn)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: ConsumptionBuilder(builder: (context, m) {
        final rows = m.readings.reversed.toList();
        final deltas = <double?>[
          for (var i = 0; i < rows.length; i++) i + 1 < rows.length ? rows[i].value - rows[i + 1].value : null,
        ];
        final maxDelta = deltas.whereType<double>().fold<double>(0, math.max);
        return Column(
          children: [
            BackHeader(title: 'Előzmények', subtitle: 'Napi leolvasások', onBack: () => context.go('/')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  if (!m.hasReadingToday)
                    Rise(
                      child: _MissingToday(today: m.today, onTap: () => context.push(recordLocation())),
                    ),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Text('Még nincs rögzített leolvasás.', textAlign: TextAlign.center, style: sans(14, color: AppColors.muted)),
                    ),
                  for (var i = 0; i < rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Rise(
                        delayMs: 80 + math.min(i, 12) * 70,
                        child: Dismissible(
                          key: ValueKey(rows[i].day),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(context, rows[i]),
                          onDismissed: (_) => ref.read(repositoryProvider).deleteReading(rows[i].day),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(color: AppColors.warn.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
                            child: const Icon(Icons.delete_outline_rounded, color: AppColors.warn),
                          ),
                          child: _ReadingRow(
                            reading: rows[i],
                            delta: deltas[i],
                            days: i + 1 < rows.length ? daysBetween(rows[i + 1].day, rows[i].day) : 0,
                            fraction: deltas[i] == null || maxDelta <= 0 ? 0 : deltas[i]! / (maxDelta * 1.15),
                            delayMs: 80 + math.min(i, 12) * 70,
                            onTap: () => context.push(recordLocation(rows[i].day)),
                          ),
                        ),
                      ),
                    ),
                  if (rows.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text('Koppints egy sorra a szerkesztéshez, húzd balra a törléshez.',
                          textAlign: TextAlign.center, style: sans(12, color: AppColors.muted)),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _MissingToday extends StatelessWidget {
  const _MissingToday({required this.today, required this.onTap});

  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.warn.withValues(alpha: .55), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Fmt.dateWithWeekday(today), style: sans(12, color: AppColors.muted)),
                      Text('Még nincs leolvasás', style: sans(15, weight: FontWeight.w700, color: AppColors.warn)),
                    ],
                  ),
                ),
                Text('Rögzítés', style: sans(14, weight: FontWeight.w700, color: AppColors.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({
    required this.reading,
    required this.delta,
    required this.days,
    required this.fraction,
    required this.delayMs,
    required this.onTap,
  });

  final MeterReading reading;
  final double? delta;
  final int days;
  final double fraction;
  final int delayMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Fmt.dateWithWeekday(reading.day), style: sans(12, color: AppColors.muted)),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: Fmt.m3One(reading.value), style: mono(17)),
                        TextSpan(text: ' m³', style: sans(12, color: AppColors.muted)),
                      ])),
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          if (days > 1) TextSpan(text: '$days nap · ', style: sans(11, color: AppColors.muted)),
                          TextSpan(
                            text: delta == null ? 'első' : Fmt.delta(delta!),
                            style: mono(14, color: delta == null ? AppColors.muted : AppColors.accent),
                          ),
                        ]),
                        maxLines: 1,
                        softWrap: false,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 5,
                        decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(3)),
                        alignment: Alignment.centerLeft,
                        child: Grow(
                          horizontal: true,
                          delayMs: delayMs,
                          durationMs: 900,
                          child: FractionallySizedBox(
                            widthFactor: fraction.clamp(0, 1),
                            child: Container(height: 5, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(3))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
