import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

/// Az alsó, 5 elemes navigációs sáv a középső kiemelt „+” gombbal.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _goBranch(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.navBg,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                children: [
                  _NavItem(icon: Icons.home_outlined, label: 'Főoldal', selected: shell.currentIndex == 0, onTap: () => _goBranch(0)),
                  _NavItem(icon: Icons.bar_chart_rounded, label: 'Statisztika', selected: shell.currentIndex == 1, onTap: () => _goBranch(1)),
                  Expanded(child: Center(child: _AddButton(onTap: () => context.push('/rogzites')))),
                  _NavItem(icon: Icons.speed_rounded, label: 'Limit', selected: shell.currentIndex == 2, onTap: () => _goBranch(2)),
                  _NavItem(icon: Icons.tune_rounded, label: 'Beállítások', selected: shell.currentIndex == 3, onTap: () => _goBranch(3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 4),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, weight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -18),
      child: Semantics(
        button: true,
        label: 'Állás rögzítése',
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x595CCBFF), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Material(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: const SizedBox(width: 56, height: 56, child: Icon(Icons.add_rounded, size: 30, color: AppColors.onAccent)),
            ),
          ),
        ),
      ),
    );
  }
}
