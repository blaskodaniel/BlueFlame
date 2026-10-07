import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/consumption.dart';
import '../../domain/dates.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

const _intDigits = 5;
const _decDigits = 3;
const _digitCount = _intDigits + _decDigits;

/// Új leolvasás rögzítése, vagy egy meglévő ([day]) szerkesztése.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key, this.day});

  final DateTime? day;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  late DateTime _day;
  final _controllers = List.generate(_digitCount, (_) => TextEditingController());
  final _focus = List.generate(_digitCount, (_) => FocusNode());
  bool _prefilled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _day = dayOf(widget.day ?? ref.read(todayProvider));
    for (var i = 0; i < _digitCount; i++) {
      _focus[i].addListener(() {
        if (_focus[i].hasFocus) {
          _controllers[i].selection = TextSelection(baseOffset: 0, extentOffset: _controllers[i].text.length);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  /// A kiválasztott nap meglévő leolvasásával, ennek hiányában az előzővel tölti ki a mezőket.
  void _prefill(ConsumptionModel m) {
    final existing = m.readings.where((r) => r.day == _day).firstOrNull;
    final source = existing ?? m.readingBefore(_day);
    final digits = source == null ? '0' * _digitCount : _toDigits(source.value);
    for (var i = 0; i < _digitCount; i++) {
      _controllers[i].text = digits[i];
    }
  }

  static String _toDigits(double v) {
    final thousandths = (v * 1000).round().clamp(0, math.pow(10, _digitCount).toInt() - 1);
    return thousandths.toString().padLeft(_digitCount, '0');
  }

  double get _value {
    final s = _controllers.map((c) => c.text.isEmpty ? '0' : c.text).join();
    return int.parse(s) / 1000;
  }

  void _onDigitChanged(int i, String v) {
    setState(() {
      if (v.length > 1) _controllers[i].text = v.substring(v.length - 1);
    });
    if (_controllers[i].text.isNotEmpty && i < _digitCount - 1) {
      _focus[i + 1].requestFocus();
    }
  }

  Future<void> _pickDate(ConsumptionModel m) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: m.today,
      helpText: 'Leolvasás napja',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = dayOf(picked);
      _prefill(m);
    });
  }

  String? _validate(ConsumptionModel m) {
    final prev = m.readingBefore(_day);
    final next = m.readingAfter(_day);
    if (prev != null && _value < prev.value) {
      return 'Kisebb, mint az előző állás (${Fmt.m3One(prev.value)} m³, ${Fmt.shortDate(prev.day)})';
    }
    if (next != null && _value > next.value) {
      return 'Nagyobb, mint a következő állás (${Fmt.m3One(next.value)} m³, ${Fmt.shortDate(next.day)})';
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(repositoryProvider).saveReading(_day, _value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Leolvasás mentve: ${Fmt.m3One(_value)} m³')));
    _close();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ConsumptionBuilder(builder: (context, m) {
          if (!_prefilled) {
            _prefill(m);
            _prefilled = true;
          }
          final editing = m.readings.any((r) => r.day == _day);
          final error = _validate(m);
          return Column(
            children: [
              BackHeader(title: editing ? 'Leolvasás szerkesztése' : 'Új leolvasás', onBack: _close),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  children: [
                    _DateCard(day: _day, isToday: _day == m.today, onTap: () => _pickDate(m)),
                    const SizedBox(height: 16),
                    _DigitsCard(controllers: _controllers, focus: _focus, onChanged: _onDigitChanged, error: error),
                    const SizedBox(height: 16),
                    Rise(delayMs: 500, child: _DeltaCard(model: m, day: _day, value: _value)),
                    const SizedBox(height: 16),
                    if (m.readingBefore(_day) case final prev?)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text.rich(TextSpan(style: sans(13, color: AppColors.muted), children: [
                          const TextSpan(text: 'Előző állás: '),
                          TextSpan(text: '${Fmt.m3One(prev.value)} m³', style: mono(13, weight: FontWeight.w400)),
                          TextSpan(text: ' · ${Fmt.shortDate(prev.day)}'),
                        ])),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    PrimaryButton(label: 'Mentés', onPressed: error != null || _saving ? null : _save),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _close,
                      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44), foregroundColor: AppColors.muted),
                      child: Text('Mégse', style: sans(15, color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.day, required this.isToday, required this.onTap});

  final DateTime day;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Text(Fmt.fullDate(day), style: sans(15, weight: FontWeight.w700))),
                Text(isToday ? 'Ma' : 'Módosítás', style: sans(12, weight: FontWeight.w700, color: AppColors.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DigitsCard extends StatelessWidget {
  const _DigitsCard({required this.controllers, required this.focus, required this.onChanged, required this.error});

  final List<TextEditingController> controllers;
  final List<FocusNode> focus;
  final void Function(int index, String value) onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('A gázóra számlálója (m³)', style: sans(13, color: AppColors.muted)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < _digitCount; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: _DigitField(
                    controller: controllers[i],
                    focusNode: focus[i],
                    decimal: i >= _intDigits,
                    label: '${i + 1}. számjegy',
                    onChanged: (v) => onChanged(i, v),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: error != null
                ? Text(error!, style: sans(12, color: AppColors.warn))
                : Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.warn, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Az utolsó három, borostyán számjegy a tizedes.', style: sans(12, color: AppColors.muted))),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DigitField extends StatelessWidget {
  const _DigitField({required this.controller, required this.focusNode, required this.decimal, required this.label, required this.onChanged});

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool decimal;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: decimal ? AppColors.warn.withValues(alpha: .3) : const Color(0x1AFFFFFF)),
    );
    return SizedBox(
      height: 68,
      child: Semantics(
        label: label,
        child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        expands: true,
        maxLines: null,
        showCursor: false,
        style: mono(30, color: decimal ? AppColors.warn : AppColors.text),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: decimal ? const Color(0xFF1D1B1A) : AppColors.surface2,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        ),
        ),
      ),
    );
  }
}

/// A mért mennyiség ára a havi számlán: a hónap kedvezményes keretéig
/// kedvezményes, felette piaci áron.
class _CostLine extends StatelessWidget {
  const _CostLine({required this.model, required this.prev, required this.day, required this.amount});

  final ConsumptionModel model;
  final DateTime prev;
  final DateTime day;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final p = model.pricing;
    final cost = model.readingCost(prev, day, amount);
    final overPart = model.readingOverKeret(prev, day, amount);
    final month = Fmt.monthNames[day.month - 1].toLowerCase();
    final String label;
    if (overPart <= 0) {
      label = 'kedvezményes áron (${Fmt.unitPrice(p.discountPrice)})';
    } else if (overPart >= amount) {
      label = 'piaci áron (${Fmt.unitPrice(p.marketPrice)}), a $month keret felett';
    } else {
      label = 'ebből ${Fmt.m3One(overPart)} m³ a $month keret felett, piaci áron';
    }
    final color = overPart > 0 ? AppColors.warn : AppColors.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('≈ ${Fmt.ft(cost)}', style: mono(15, color: overPart > 0 ? AppColors.warn : AppColors.text)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: sans(12, color: color))),
      ],
    );
  }
}

class _DeltaCard extends StatelessWidget {
  const _DeltaCard({required this.model, required this.day, required this.value});

  final ConsumptionModel model;
  final DateTime day;
  final double value;

  @override
  Widget build(BuildContext context) {
    final prev = model.readingBefore(day);
    if (prev == null) {
      return Panel(
        padding: const EdgeInsets.all(18),
        child: Text('Ez lesz az első leolvasás. A fogyasztást a következő leolvasástól számoljuk.', style: sans(14, color: AppColors.muted)),
      );
    }
    final days = math.max(1, daysBetween(prev.day, day));
    final delta = value - prev.value;
    final perDay = delta / days;
    final avg = model.averageOfLastDays(7);
    final above = avg != null && perDay > avg;
    final color = above ? AppColors.warn : AppColors.accent;
    final scaleMax = math.max(perDay, (avg ?? perDay) * 1.6);
    final fill = scaleMax <= 0 ? 0.0 : (perDay / scaleMax).clamp(0.0, 1.0);
    final marker = avg == null || scaleMax <= 0 ? null : (avg / scaleMax).clamp(0.0, 1.0);

    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(days == 1 ? 'Fogyasztás az előző nap óta' : 'Fogyasztás $days nap alatt', style: sans(13, color: AppColors.muted)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(Fmt.delta(delta), style: mono(40, letterSpacing: -1, color: color)),
              const SizedBox(width: 8),
              Flexible(child: Text(days == 1 ? 'm³' : 'm³  (${Fmt.m3One(perDay)} / nap)', style: sans(15, color: AppColors.muted))),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            return SizedBox(
              height: 16,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(height: 8, decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(4))),
                  Grow(
                    horizontal: true,
                    delayMs: 900,
                    durationMs: 1000,
                    child: Container(
                      height: 8,
                      width: c.maxWidth * fill,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  if (marker != null)
                    Positioned(
                      left: c.maxWidth * marker - 1.5,
                      child: Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(2))),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              Text(avg == null ? 'Napi átlag: —' : 'Napi átlag: ${Fmt.m3One(avg)} m³', style: sans(12, color: AppColors.muted)),
              if (avg != null) Text(above ? 'átlag feletti nap' : 'átlag alatti nap', style: sans(12, color: color)),
            ],
          ),
          if (!day.isBefore(model.yearStart) && delta > 0) ...[
            const SizedBox(height: 10),
            _CostLine(model: model, prev: prev.day, day: day, amount: delta),
          ],
        ],
      ),
    );
  }
}
