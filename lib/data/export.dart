import 'dart:convert';

import 'package:intl/intl.dart';

import '../domain/dates.dart';
import '../domain/models.dart';

/// A leolvasások CSV-ben, magyar Excelhez: pontosvessző elválasztó,
/// tizedesvessző, UTF-8 BOM (hogy az ékezetek helyesen jelenjenek meg).
String buildReadingsCsv(List<MeterReading> readings) {
  final sorted = [...readings]..sort((a, b) => a.day.compareTo(b.day));
  final number = NumberFormat('0.000', 'hu');
  final buffer = StringBuffer('﻿')..writeln('Dátum;Mérőállás (m³);Fogyasztás az előző leolvasás óta (m³);Napok');
  for (var i = 0; i < sorted.length; i++) {
    final r = sorted[i];
    final prev = i > 0 ? sorted[i - 1] : null;
    final delta = prev == null ? '' : number.format(r.value - prev.value);
    final days = prev == null ? '' : '${daysBetween(prev.day, r.day)}';
    buffer.writeln('${_isoDate(r.day)};${number.format(r.value)};$delta;$days');
  }
  return buffer.toString();
}

/// Teljes biztonsági mentés JSON-ben: leolvasások, a gáz beállításai és a havi
/// keretek (MJ-ben és a fűtőértékkel átszámolva m³-ben is).
String buildBackupJson({
  required List<MeterReading> readings,
  required AppSettings settings,
  required List<double> monthlyKeretMJ,
  required String appVersion,
  required DateTime exportedAt,
}) {
  final sorted = [...readings]..sort((a, b) => a.day.compareTo(b.day));
  final hv = settings.heatingValue;
  double round3(double v) => (v * 1000).round() / 1000;
  final data = {
    'app': 'Kékláng',
    'format': 1,
    'appVersion': appVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'settings': {
      'heatingValueMJPerM3': hv,
      'annualLimitMJ': settings.annualLimitMJ,
      'annualLimitM3': round3(settings.annualLimit),
      'discountPriceFtPerM3': settings.discountPrice,
      'marketPriceFtPerMJ': settings.marketPriceMJ,
      'marketPriceFtPerM3': round3(settings.marketPrice),
    },
    'monthlyKeretMJ': {for (var i = 0; i < 12; i++) '${i + 1}': monthlyKeretMJ[i]},
    'monthlyKeretM3': {for (var i = 0; i < 12; i++) '${i + 1}': round3(monthlyKeretMJ[i] / hv)},
    'readings': [
      for (final r in sorted) {'date': _isoDate(r.day), 'value': r.value},
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}

/// Fájlnév a mentéshez, pl. `keklang-leolvasasok-2026-10-07.csv`.
String exportFileName(String kind, String extension, DateTime now) => 'keklang-$kind-${_isoDate(now)}.$extension';

String _isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String _two(int v) => v.toString().padLeft(2, '0');
