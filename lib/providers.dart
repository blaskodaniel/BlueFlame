import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'data/database.dart';
import 'data/repository.dart';
import 'domain/consumption.dart';
import 'domain/dates.dart';
import 'domain/models.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<GasRepository>((ref) => GasRepository(ref.watch(databaseProvider)));

final readingsProvider = StreamProvider<List<MeterReading>>((ref) => ref.watch(repositoryProvider).watchReadings());

final monthlyTargetsProvider = StreamProvider<List<double>>((ref) => ref.watch(repositoryProvider).watchMonthlyTargets());

final settingsProvider = StreamProvider<AppSettings>((ref) => ref.watch(repositoryProvider).watchSettings());

/// A telepített app verziója (a pubspec.yaml `version` sorából), pl. `0.1.0 (1)`.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// A mai nap; teszteknél felülírható.
final todayProvider = Provider<DateTime>((ref) => dayOf(DateTime.now()));

final animationsEnabledProvider = Provider<bool>((ref) => ref.watch(settingsProvider).value?.animations ?? true);

/// A teljes fogyasztási modell, ami a képernyők számait adja.
final consumptionProvider = Provider<AsyncValue<ConsumptionModel>>((ref) {
  final readings = ref.watch(readingsProvider);
  final targets = ref.watch(monthlyTargetsProvider);
  final settings = ref.watch(settingsProvider);
  for (final v in <AsyncValue<Object>>[readings, targets, settings]) {
    if (v case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  }
  final r = readings.value;
  final t = targets.value;
  final s = settings.value;
  if (r == null || t == null || s == null) return const AsyncLoading();
  return AsyncData(ConsumptionModel(
    readings: r,
    monthlyTargets: t,
    annualLimit: s.annualLimit,
    discountPrice: s.discountPrice,
    marketPrice: s.marketPrice,
    today: ref.watch(todayProvider),
  ));
});
