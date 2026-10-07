import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/export.dart';
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
                    _Row(
                      title: 'Fűtőérték',
                      subtitle: 'A szolgáltató gázminőség-oldalán',
                      onTap: () => _editNumber(
                        context,
                        'Fűtőérték',
                        settings.heatingValue,
                        suffix: 'MJ/m³',
                        onSave: (v) => set(AppSettings.kHeatingValue, v),
                      ),
                      trailing: _Chevron(text: '${Fmt.m3One(settings.heatingValue)} MJ/m³'),
                    ),
                    _Row(
                      title: 'Éves limit',
                      subtitle: 'Kedvezményes keret · ${Fmt.m3(settings.annualLimitMJ)} MJ',
                      onTap: () => _editNumber(
                        context,
                        'Éves kedvezményes keret',
                        settings.annualLimitMJ,
                        suffix: 'MJ',
                        integer: true,
                        onSave: (v) => set(AppSettings.kAnnualLimitMJ, v),
                      ),
                      trailing: _Chevron(text: '${Fmt.m3(settings.annualLimit)} m³'),
                    ),
                    _Row(
                      title: 'Havi kedvezményes keret',
                      subtitle: 'Jelleggörbe, augusztustól júliusig',
                      onTap: () => context.push('/havi-ertekek'),
                      trailing: _Chevron(text: targetSum == null ? null : '${Fmt.m3(targetSum / settings.heatingValue)} m³'),
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
                      subtitle: 'A keret felett · ~${Fmt.unitPrice(settings.marketPrice)} · ${Fmt.times(settings.pricing.multiplier)}',
                      onTap: () => _editNumber(
                        context,
                        'Piaci ár',
                        settings.marketPriceMJ,
                        suffix: 'Ft/MJ',
                        onSave: (v) => set(AppSettings.kMarketPriceMJ, v),
                      ),
                      trailing: _Chevron(text: '${Fmt.decimal(settings.marketPriceMJ)} Ft/MJ', color: AppColors.warn),
                    ),
                  ]),
                ),
                const SectionLabel('Adatok'),
                Rise(
                  delayMs: 100,
                  child: _Group(children: [
                    _Row(
                      title: 'Leolvasások exportálása (CSV)',
                      subtitle: 'Táblázatkezelőben megnyitható',
                      onTap: () => _export(context, ref, csv: true),
                      trailing: const Icon(Icons.file_download_outlined, size: 20, color: AppColors.accent),
                    ),
                    _Row(
                      title: 'Biztonsági mentés (JSON)',
                      subtitle: 'Leolvasások, beállítások és havi keretek',
                      onTap: () => _export(context, ref, csv: false),
                      trailing: const Icon(Icons.save_alt_rounded, size: 20, color: AppColors.accent),
                    ),
                  ]),
                ),
                const SectionLabel('Megjelenés'),
                Rise(
                  delayMs: 150,
                  child: _Group(children: [
                    _Row(
                      title: 'Animációk',
                      trailing: PillToggle(label: 'Animációk', value: settings.animations, onChanged: (v) => set(AppSettings.kAnimations, v)),
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

/// Export: összeállítja a fájlt, és a rendszer mentési ablakával megkérdezi,
/// hová mentse a felhasználó.
Future<void> _export(BuildContext context, WidgetRef ref, {required bool csv}) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(repositoryProvider);
  final now = DateTime.now();
  final readings = await repo.watchReadings().first;
  final String content;
  final String fileName;
  final String mimeType;
  if (csv) {
    content = buildReadingsCsv(readings);
    fileName = exportFileName('leolvasasok', 'csv', now);
    mimeType = 'text/csv';
  } else {
    content = buildBackupJson(
      readings: readings,
      settings: await repo.watchSettings().first,
      monthlyKeretMJ: await repo.watchMonthlyTargets().first,
      appVersion: ref.read(appVersionProvider).value ?? '',
      exportedAt: now,
    );
    fileName = exportFileName('mentes', 'json', now);
    mimeType = 'application/json';
  }
  try {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: mimeType,
      dialogTitle: 'Hová mentsem?',
    );
    if (uri == null) return; // A felhasználó megszakította.
    messenger.showSnackBar(SnackBar(content: Text('Mentve: $fileName (${readings.length} leolvasás)')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('A mentés nem sikerült: $e')));
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
