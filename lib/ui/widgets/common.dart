import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/consumption.dart';
import '../../providers.dart';

/// Lekerekített, keretes kártya (a dizájn `section` elemei).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 24});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// 44×44-es négyzetes ikongomb (vissza, előzmények).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, required this.label, required this.onPressed, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 24, color: color ?? AppColors.text)),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: enabled ? const [BoxShadow(color: Color(0x475CCBFF), blurRadius: 28, offset: Offset(0, 10))] : null,
      ),
      child: Material(
        color: enabled ? AppColors.accent : AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 22, color: AppColors.onAccent), const SizedBox(width: 8)],
                Flexible(
                  child: Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(16, weight: FontWeight.w700, color: enabled ? AppColors.onAccent : AppColors.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fő képernyőcím (Statisztika, Éves limit, Beállítások).
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Text(title, style: sans(28, weight: FontWeight.w700, letterSpacing: -0.5)),
    );
  }
}

/// Vissza gombos fejléc (Rögzítés, Előzmények, Havi értékek).
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.title, this.subtitle, required this.onBack});

  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          SquareIconButton(icon: Icons.chevron_left_rounded, label: 'Vissza', onPressed: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: sans(22, weight: FontWeight.w700, letterSpacing: -0.3)),
                if (subtitle != null) Text(subtitle!, style: sans(13, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Text(text.toUpperCase(), style: sans(12, weight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.8)),
    );
  }
}

/// Kis statisztikai csempe: felirat, nagy szám, mértékegység.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.unit, this.footer, this.valueColor, this.valueSize = 20});

  final String label;
  final String value;
  final String? unit;
  final String? footer;
  final Color? valueColor;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: sans(11.5, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: value, style: mono(valueSize, color: valueColor)),
              if (unit != null && footer != null) TextSpan(text: ' $unit', style: sans(12, color: AppColors.muted)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (footer != null) Text(footer!, style: sans(11, color: AppColors.muted)),
          if (unit != null && footer == null) Text(unit!, style: sans(11, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// A [consumptionProvider] betöltési / hibaállapotait kezeli.
class ConsumptionBuilder extends ConsumerWidget {
  const ConsumptionBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ConsumptionModel model) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(consumptionProvider)) {
      AsyncData(:final value) => builder(context, value),
      AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Hiba az adatok betöltésekor:\n$error', style: sans(14, color: AppColors.warn), textAlign: TextAlign.center),
          ),
        ),
      _ => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
    };
  }
}

/// A dizájn kapcsolója (48×28-as pirula), legalább 44 px-es érintési területtel.
class PillToggle extends StatelessWidget {
  const PillToggle({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 56,
          height: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: value ? AppColors.accent : AppColors.toggleOff,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: value ? AppColors.onAccent : AppColors.muted),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Jelmagyarázat-elem: kis színminta és felirat.
class LegendItem extends StatelessWidget {
  const LegendItem({super.key, required this.swatch, required this.label});

  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [swatch, const SizedBox(width: 6), Flexible(child: Text(label, style: sans(12, color: AppColors.muted)))],
    );
  }
}

/// Szaggatott vízszintes vonal (jelmagyarázathoz és diagramokhoz).
class DashedLine extends StatelessWidget {
  const DashedLine({super.key, required this.color, this.width = 14, this.thickness = 2, this.dash = 3, this.gap = 2});

  final Color color;
  final double width;
  final double thickness;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, thickness), painter: _DashPainter(color, thickness, dash, gap));
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.thickness, this.dash, this.gap);

  final Color color;
  final double thickness;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thickness;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width), y), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.thickness != thickness;
}
