import 'package:blueflame/data/database.dart';
import 'package:blueflame/data/repository.dart';
import 'package:blueflame/domain/models.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('v1 → v2: monthly values become the official MJ keret, readings are kept', () async {
    // Egy 1-es verziójú adatbázis: a havi értékek még m³-ben, a dizájn szerint.
    final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE readings (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          'day INTEGER NOT NULL UNIQUE, value REAL NOT NULL)');
      raw.execute('CREATE TABLE monthly_targets (month INTEGER NOT NULL, value REAL NOT NULL, PRIMARY KEY (month))');
      raw.execute('CREATE TABLE setting_entries (key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (key))');
      const old = [320, 290, 220, 125, 60, 30, 25, 25, 65, 140, 190, 220];
      for (var i = 0; i < 12; i++) {
        raw.execute('INSERT INTO monthly_targets (month, value) VALUES (?, ?)', [i + 1, old[i]]);
      }
      final day = DateTime(2026, 10, 5).millisecondsSinceEpoch ~/ 1000;
      raw.execute('INSERT INTO readings (day, value) VALUES (?, ?)', [day, 14900.5]);
      raw.userVersion = 1;
    }));
    final repo = GasRepository(db);

    expect(await repo.watchMonthlyTargets().first, defaultMonthlyKeretMJ);
    final readings = await repo.watchReadings().first;
    expect(readings, hasLength(1));
    expect(readings.single.value, 14900.5);
    expect(readings.single.day, DateTime(2026, 10, 5));

    await db.close();
  });

  test('a fresh database starts with the official keret', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(await GasRepository(db).watchMonthlyTargets().first, defaultMonthlyKeretMJ);
    await db.close();
  });
}
