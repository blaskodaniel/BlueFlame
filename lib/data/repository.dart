import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/models.dart';
import 'database.dart';

class GasRepository {
  GasRepository(this._db);

  final AppDatabase _db;

  Stream<List<MeterReading>> watchReadings() {
    final q = _db.select(_db.readings)..orderBy([(t) => OrderingTerm.asc(t.day)]);
    return q.watch().map((rows) => [for (final r in rows) MeterReading(day: dayOf(r.day), value: r.value)]);
  }

  /// Rögzíti vagy felülírja az adott napi leolvasást.
  Future<void> saveReading(DateTime day, double value) {
    return _db.into(_db.readings).insert(
          ReadingsCompanion.insert(day: dayOf(day), value: value),
          onConflict: DoUpdate((_) => ReadingsCompanion(value: Value(value)), target: [_db.readings.day]),
        );
  }

  Future<void> deleteReading(DateTime day) {
    return (_db.delete(_db.readings)..where((t) => t.day.equals(dayOf(day)))).go();
  }

  Stream<List<double>> watchMonthlyTargets() {
    return _db.select(_db.monthlyTargets).watch().map((rows) {
      final values = [...defaultMonthlyKeretMJ];
      for (final r in rows) {
        if (r.month >= 1 && r.month <= 12) values[r.month - 1] = r.value;
      }
      return values;
    });
  }

  /// Havi kedvezményes keret mentése MJ-ben (naptári hónap szerint, 0 = január).
  Future<void> saveMonthlyTargets(List<double> values) {
    return _db.batch((b) {
      b.insertAllOnConflictUpdate(_db.monthlyTargets, [
        for (var i = 0; i < 12; i++) MonthlyTargetsCompanion.insert(month: Value(i + 1), value: values[i]),
      ]);
    });
  }

  Stream<AppSettings> watchSettings() {
    return _db.select(_db.settingEntries).watch().map((rows) => AppSettings.fromMap({for (final r in rows) r.key: r.value}));
  }

  Future<void> setSetting(String key, Object value) {
    return _db.into(_db.settingEntries).insertOnConflictUpdate(SettingEntriesCompanion.insert(key: key, value: '$value'));
  }
}
