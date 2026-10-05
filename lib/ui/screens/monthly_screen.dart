import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// A 12 havi ajánlott érték szerkesztése.
class MonthlyScreen extends ConsumerStatefulWidget {
  const MonthlyScreen({super.key});

  @override
  ConsumerState<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends ConsumerState<MonthlyScreen> {
  final _controllers = List.generate(12, (_) => TextEditingController());
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<double> get _values => [for (final c in _controllers) double.tryParse(c.text) ?? 0];

  void _fill(List<double> values) {
    for (var i = 0; i < 12; i++) {
      _controllers[i].text = values[i].round().toString();
    }
  }

  Future<void> _save() async {
    await ref.read(repositoryProvider).saveMonthlyTargets(_values);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Havi értékek mentve')));
    _close();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/beallitasok');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ConsumptionBuilder(builder: (context, m) {
          if (!_loaded) {
            _fill(m.monthlyTargets);
            _loaded = true;
          }
          final values = _values;
          final sum = values.fold<double>(0, (s, v) => s + v);
          final free = m.annualLimit - sum;
          final current = m.today.month - 1;
          // Gázév sorrend: augusztustól júliusig (naptári hónap indexek).
          final order = [for (final mo in m.yearMonths) mo.month - 1];
          return Column(
            children: [
              BackHeader(title: 'Havi ajánlott értékek', subtitle: 'Gázév: augusztustól júliusig (m³)', onBack: _close),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  children: [
                    Rise(
                      child: Panel(
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Ajánlott összeg a gázévre', style: sans(13, color: AppColors.muted)),
                                      Text.rich(TextSpan(children: [
                                        TextSpan(text: Fmt.m3(sum), style: mono(34, letterSpacing: -1, height: 1.15)),
                                        TextSpan(text: ' m³', style: sans(14, color: AppColors.muted)),
                                      ])),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('limit ${Fmt.m3(m.annualLimit)} m³', style: sans(12, color: AppColors.muted)),
                                    Text('havi átlag ${Fmt.m3(m.annualLimit / 12)} m³', style: sans(12, color: AppColors.muted)),
                                    Text(
                                      free >= 0 ? '${Fmt.m3(free)} m³ szabad keret' : '${Fmt.m3(-free)} m³-rel a limit felett',
                                      style: sans(12, weight: FontWeight.w700, color: free >= 0 ? AppColors.accent : AppColors.warn),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            UsageBars(
                              height: 60,
                              gap: 5,
                              radius: 4,
                              showRecommended: false,
                              baseDelayMs: 150,
                              stepDelayMs: 50,
                              valueLabelSize: 9,
                              labelStyle: sans(10, color: AppColors.muted),
                              bars: [
                                for (final i in order)
                                  BarDatum(value: values[i], label: Fmt.monthInitials[i], valueLabel: Fmt.m3(values[i]), highlight: i == current),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 171 / 60,
                      children: [
                        for (final (pos, i) in order.indexed)
                          Rise(
                            delayMs: 100 + pos * 45,
                            child: _MonthField(
                              name: Fmt.monthNames[i],
                              controller: _controllers[i],
                              current: i == current,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                      ],
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _fill(defaultMonthlyTargets)),
                        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                        child: Text('Alapértékek visszaállítása', style: sans(14, color: AppColors.muted)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: PrimaryButton(label: 'Mentés', onPressed: _save),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _MonthField extends StatelessWidget {
  const _MonthField({required this.name, required this.controller, required this.current, required this.onChanged});

  final String name;
  final TextEditingController controller;
  final bool current;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x1AFFFFFF)));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: current ? AppColors.accent : AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // A mértékegység (m³) a fejlécben szerepel, így a hónapnév teljes hosszában elfér.
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13.5, weight: FontWeight.w700, color: current ? AppColors.accent : AppColors.text)),
          ),
          SizedBox(
            width: 60,
            height: 44,
            child: Semantics(
              label: '$name ajánlott értéke m³-ben',
              child: TextField(
                controller: controller,
                onChanged: (_) => onChanged(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                textAlign: TextAlign.right,
                style: mono(17),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  filled: true,
                  fillColor: AppColors.surface2,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
