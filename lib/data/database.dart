import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/models.dart';

part 'database.g.dart';

/// Napi gázóra-leolvasások; naponta legfeljebb egy.
class Readings extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get day => dateTime().unique()();
  RealColumn get value => real()();
}

/// Havi ajánlott fogyasztás (m³), `month` 1–12.
class MonthlyTargets extends Table {
  IntColumn get month => integer()();
  RealColumn get value => real()();

  @override
  Set<Column> get primaryKey => {month};
}

/// Kulcs–érték beállítások (lásd [AppSettings]).
class SettingEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Readings, MonthlyTargets, SettingEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'keklang'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await batch((b) {
            b.insertAll(monthlyTargets, [
              for (var i = 0; i < 12; i++)
                MonthlyTargetsCompanion.insert(month: Value(i + 1), value: defaultMonthlyTargets[i]),
            ]);
          });
        },
      );
}
