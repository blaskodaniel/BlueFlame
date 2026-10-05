import 'package:blueflame/data/database.dart';
import 'package:blueflame/main.dart';
import 'package:blueflame/providers.dart';
import 'package:blueflame/router.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    Intl.defaultLocale = 'hu';
    await initializeDateFormatting('hu');
  });

  testWidgets('every screen renders with sample data', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      todayProvider.overrideWithValue(DateTime(2026, 10, 4)),
      appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
    ]);
    final repo = container.read(repositoryProvider);
    var value = 14000.0;
    for (var d = DateTime(2026, 9, 1); d.isBefore(DateTime(2026, 10, 4)); d = DateTime(d.year, d.month, d.day + 1)) {
      await repo.saveReading(d, value);
      value += 3.5;
    }

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const KeklangApp()));
    await tester.pumpAndSettle();
    expect(find.text('Kékláng'), findsOneWidget);
    expect(find.text('Gázköltség'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mai állás rögzítése'), 200);
    expect(find.text('Mai állás rögzítése'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final (location, text) in [
      ('/statisztika', 'Havi fogyasztás (gázév)'),
      ('/limit', 'Gázár'),
      ('/havi-ertekek','Ajánlott összeg a gázévre'),
      ('/beallitasok', 'Kékláng 0.1.0 (1)'),
      ('/elozmenyek', 'Még nincs leolvasás'),
      ('/rogzites', 'Új leolvasás'),
    ]) {
      router.go(location);
      await tester.pumpAndSettle();
      expect(find.text(text), findsWidgets, reason: location);
      expect(tester.takeException(), isNull, reason: location);
    }

    // A rögzítés az előző állással van kitöltve; mentés után megjelenik a mai sor.
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(container.read(consumptionProvider).value!.hasReadingToday, isTrue);

    // A havi értékek a Beállításokból is elérhetők, és a vissza gomb oda tér vissza.
    router.go('/beallitasok');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Havi ajánlott értékek'));
    await tester.pumpAndSettle();
    expect(find.text('Ajánlott összeg a gázévre'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Beállítások'), findsWidgets);
    expect(find.text('Ajánlott összeg a gázévre'), findsNothing);

    // A memóriabeli adatbázist nem zárjuk le: a db.close() a teszt szimulált
    // idejében végtelenül várna, és a teszt végén úgyis megszűnik.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    // A leállított adatfolyamok takarító időzítőinek lefuttatása.
    await tester.pump(const Duration(milliseconds: 1));
  });
}
