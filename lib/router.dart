import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ui/app_shell.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/limit_screen.dart';
import 'ui/screens/monthly_screen.dart';
import 'ui/screens/record_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/stats_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// `/rogzites?nap=2026-10-03` egy adott nap leolvasását nyitja meg szerkesztésre.
String recordLocation([DateTime? day]) =>
    day == null ? '/rogzites' : '/rogzites?nap=${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

final router = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
            routes: [GoRoute(path: 'elozmenyek', builder: (context, state) => const HistoryScreen())],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/statisztika', builder: (context, state) => const StatsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/limit', builder: (context, state) => const LimitScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/beallitasok', builder: (context, state) => const SettingsScreen()),
        ]),
      ],
    ),
    // Önálló képernyő, a Limit és a Beállítások oldalról is megnyitható; a vissza
    // gomb oda visz, ahonnan jöttünk.
    GoRoute(
      path: '/havi-ertekek',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const MonthlyScreen(),
    ),
    GoRoute(
      path: '/rogzites',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => RecordScreen(day: DateTime.tryParse(state.uri.queryParameters['nap'] ?? '')),
    ),
  ],
);
