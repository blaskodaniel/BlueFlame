import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final targetSum = ref.watch(monthlyTargetsProvider).value?.fold<double>(0, (s, v) => s + v);
    final repo = ref.read(repositoryProvider);
    void set(String key, Object value) => repo.setSetting(key, value);

    Future<void> pickTime() async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: settings.reminderMinutes ~/ 60, minute: settings.reminderMinutes % 60),
        helpText: 'Emlékeztető időpontja',
      );
      if (t != null) set(AppSettings.kReminderMinutes, t.hour * 60 + t.minute);
    }

    final time = '${(settings.reminderMinutes ~/ 60).toString().padLeft(2, '0')}:${(settings.reminderMinutes % 60).toString().padLeft(2, '0')}';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          const ScreenTitle('Beállítások'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('Gázóra'),
                Rise(
                  child: _Group(children: [
                    _Row(title: 'Mértékegység', trailing: Text('m³', style: mono(14, weight: FontWeight.w400, color: AppColors.muted))),
                    _Row(
                      title: 'Éves limit',
                      subtitle: 'Kedvezményes keret egy gázévre',
                      onTap: () => _editNumber(
                        context,
                        'Éves limit (kedvezményes keret)',
                        settings.annualLimit,
                        suffix: 'm³',
                        integer: true,
                        onSave: (v) => set(AppSettings.kAnnualLimit, v),
                      ),
                      trailing: _Chevron(text: '${Fmt.m3(settings.annualLimit)} m³'),
                    ),
                    _Row(
                      title: 'Havi ajánlott értékek',
                      subtitle: 'Augusztustól júliusig',
                      onTap: () => context.push('/havi-ertekek'),
                      trailing: _Chevron(text: targetSum == null ? null : '${Fmt.m3(targetSum)} m³'),
                    ),
                  ]),
                ),
                const SectionLabel('Gázár'),
                Rise(
                  delayMs: 50,
                  child: _Group(children: [
                    _Row(
                      title: 'Kedvezményes ár',
                      subtitle: 'A keretig (${Fmt.m3(settings.annualLimit)} m³)',
                      onTap: () => _editNumber(context, 'Kedvezményes ár', settings.discountPrice, suffix: 'Ft/m³', onSave: (v) => set(AppSettings.kDiscountPrice, v)),
                      trailing: _Chevron(text: Fmt.unitPrice(settings.discountPrice)),
                    ),
                    _Row(
                      title: 'Piaci ár',
                      subtitle: 'A keret felett · ${Fmt.times(settings.pricing.multiplier)}',
                      onTap: () => _editNumber(context, 'Piaci ár', settings.marketPrice, suffix: 'Ft/m³', onSave: (v) => set(AppSettings.kMarketPrice, v)),
                      trailing: _Chevron(text: Fmt.unitPrice(settings.marketPrice), color: AppColors.warn),
                    ),
                  ]),
                ),
                const SectionLabel('Emlékeztetők'),
                Rise(
                  delayMs: 100,
                  child: _Group(children: [
                    _Row(
                      title: 'Napi leolvasás',
                      subtitle: 'Minden nap $time',
                      onTap: pickTime,
                      trailing: PillToggle(
                        label: 'Napi leolvasás emlékeztető',
                        value: settings.dailyReminder,
                        onChanged: (v) => set(AppSettings.kDailyReminder, v),
                      ),
                    ),
                    _Row(
                      title: 'Limit 80%-os elérésekor',
                      trailing: PillToggle(label: 'Értesítés 80%-nál', value: settings.notifyAt80, onChanged: (v) => set(AppSettings.kNotifyAt80, v)),
                    ),
                    _Row(
                      title: 'Limit 95%-os elérésekor',
                      trailing: PillToggle(label: 'Értesítés 95%-nál', value: settings.notifyAt95, onChanged: (v) => set(AppSettings.kNotifyAt95, v)),
                    ),
                    _Row(
                      title: 'Heti összefoglaló',
                      trailing: PillToggle(label: 'Heti összefoglaló', value: settings.weeklySummary, onChanged: (v) => set(AppSettings.kWeeklySummary, v)),
                    ),
                  ]),
                ),
                const SectionLabel('Megjelenés és adatok'),
                Rise(
                  delayMs: 200,
                  child: _Group(children: [
                    _Row(
                      title: 'Animációk',
                      trailing: PillToggle(label: 'Animációk', value: settings.animations, onChanged: (v) => set(AppSettings.kAnimations, v)),
                    ),
                    _Row(
                      title: 'Adatok exportálása (CSV)',
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A CSV-export hamarosan érkezik.'))),
                      trailing: const _Chevron(),
                    ),
                  ]),
                ),
                if (ref.watch(appVersionProvider).value case final version?)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text('Kékláng $version', textAlign: TextAlign.center, style: mono(12, weight: FontWeight.w400, color: AppColors.muted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Szám szerkesztése párbeszédablakban (ár, éves limit); tizedesvessző és
/// -pont is jó, `integer` esetén egészre kerekít.
Future<void> _editNumber(
  BuildContext context,
  String title,
  double current, {
  required String suffix,
  required ValueChanged<double> onSave,
  bool integer = false,
}) async {
  final result = await showDialog<double>(
    context: context,
    builder: (context) => _NumberDialog(title: title, initial: current, suffix: suffix, integer: integer),
  );
  if (result != null) onSave(integer ? result.roundToDouble() : result);
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({required this.title, required this.initial, required this.suffix, required this.integer});

  final String title;
  final double initial;
  final String suffix;
  final bool integer;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _controller = TextEditingController(
    text: widget.initial == widget.initial.roundToDouble()
        ? widget.initial.round().toString()
        : widget.initial.toString().replaceAll('.', ','),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _value {
    final v = double.tryParse(_controller.text.replaceAll(',', '.').replaceAll(' ', ''));
    return v != null && v > 0 ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: !widget.integer),
        onChanged: (_) => setState(() {}),
        style: mono(20),
        decoration: InputDecoration(
          suffixText: widget.suffix,
          errorText: value == null ? 'Adj meg egy pozitív számot' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mégse')),
        TextButton(
          onPressed: value == null ? null : () => Navigator.pop(context, value),
          child: const Text('Mentés'),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, this.trailing, this.onTap});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: sans(15)),
                    if (subtitle != null) Text(subtitle!, style: sans(12, color: AppColors.muted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({this.text, this.color = AppColors.accent});

  final String? text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text != null) ...[Text(text!, style: mono(14, weight: FontWeight.w400, color: color)), const SizedBox(width: 6)],
        Icon(Icons.chevron_right_rounded, size: 20, color: text != null ? color : AppColors.muted),
      ],
    );
  }
}
