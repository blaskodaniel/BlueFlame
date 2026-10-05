// A README képernyőképeit készíti mintaadatokkal a docs/screenshots/ mappába.
// Futtatás: flutter test tool/screenshots_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:blueflame/data/database.dart';
import 'package:blueflame/domain/dates.dart';
import 'package:blueflame/domain/models.dart';
import 'package:blueflame/main.dart';
import 'package:blueflame/providers.dart';
import 'package:blueflame/router.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// Március eleje: a képeken a gázév (2025. aug. 1. – 2026. júl. 31.) téli része látszik.
const _today = (2026, 3, 5);
const _pixelRatio = 2.0;

/// A tesztkörnyezet alapból helyettesítő betűt használ; itt betöltjük a valódiakat
/// (Bricolage, PlexMono, MaterialIcons) a FontManifest alapján.
Future<void> _loadFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// A gázév napi leolvasásai: a havi ajánlott értékek kb. 94%-a, kis ingadozással.
/// Márc. 2. kimarad, hogy az előzményekben látszódjon egy kétnapos szakasz.
Future<void> _seed(AppDatabase db) async {
  final repo = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]).read(repositoryProvider);
  var value = 13800.0;
  var day = DateTime(2025, 7, 31);
  await repo.saveReading(day, value);
  final end = DateTime(_today.$1, _today.$2, _today.$3 - 1);
  var i = 0;
  while (day.isBefore(end)) {
    day = addDays(day, 1);
    i++;
    final base = defaultMonthlyTargets[day.month - 1] / daysInMonth(day.year, day.month);
    final noise = 1 + .22 * math.sin(i * 1.7) + .12 * math.cos(i * .53);
    value += base * .94 * noise;
    if (day != DateTime(2026, 3, 2)) await repo.saveReading(day, double.parse(value.toStringAsFixed(3)));
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('capture README screenshots', (tester) async {
    // A teszt alapból tömör sávként rajzolja az árnyékokat; itt a valódi kell.
    // A teszt végén visszaállítjuk, különben a keretrendszer hibát jelez.
    debugDisableShadows = false;
    Intl.defaultLocale = 'hu';
    await tester.runAsync(() async {
      await initializeDateFormatting('hu');
      await _loadFonts();
    });

    tester.view.physicalSize = const Size(390 * _pixelRatio, 844 * _pixelRatio);
    tester.view.devicePixelRatio = _pixelRatio;
    tester.view.padding = const FakeViewPadding(top: 47 * _pixelRatio, bottom: 20 * _pixelRatio);
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() => _seed(db));
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      todayProvider.overrideWithValue(DateTime(_today.$1, _today.$2, _today.$3)),
      appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
    ]);
    addTearDown(container.dispose);

    final boundary = GlobalKey();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(key: boundary, child: const KeklangApp()),
    ));

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: _pixelRatio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('docs/screenshots/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await capture('fooldal');
    for (final (location, name) in [
      ('/statisztika', 'statisztika'),
      ('/limit', 'limit'),
      ('/havi-ertekek','havi'),
      ('/elozmenyek', 'elozmenyek'),
      ('/beallitasok', 'beallitasok'),
    ]) {
      router.go(location);
      await capture(name);
      if (name == 'limit') {
        // A Gázár kártya a képernyő alján van: legörgetve is.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -1000));
        await capture('limit-gazar');
      }
    }

    // Rögzítés: az előző állás + 4,6 m³ beírása számjegyenként.
    router.go('/rogzites');
    await tester.pumpAndSettle();
    final model = container.read(consumptionProvider).value!;
    final digits = ((model.latestReading!.value + 4.6) * 1000).round().toString().padLeft(8, '0');
    for (var i = 0; i < 8; i++) {
      await tester.enterText(find.byType(EditableText).at(i), digits[i]);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await capture('rogzites');

    router.go('/');
    await tester.pumpAndSettle();
    await db.close();
    debugDisableShadows = true;
  });
}
