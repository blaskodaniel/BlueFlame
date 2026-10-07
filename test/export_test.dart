import 'dart:convert';

import 'package:blueflame/data/export.dart';
import 'package:blueflame/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  final readings = [
    MeterReading(day: DateTime(2026, 10, 4), value: 14908.0),
    MeterReading(day: DateTime(2026, 10, 1), value: 14890.9),
    MeterReading(day: DateTime(2026, 10, 2), value: 14901.125),
  ];

  test('CSV: BOM, header, sorted rows with decimal comma and deltas', () {
    final csv = buildReadingsCsv(readings);
    expect(csv.startsWith('﻿'), isTrue);
    final lines = csv.substring(1).trim().split(RegExp(r'\r?\n'));
    expect(lines.first, 'Dátum;Mérőállás (m³);Fogyasztás az előző leolvasás óta (m³);Napok');
    expect(lines[1], '2026-10-01;14890,900;;');
    expect(lines[2], '2026-10-02;14901,125;10,225;1');
    expect(lines[3], '2026-10-04;14908,000;6,875;2');
  });

  test('JSON backup contains everything and parses back', () {
    final json = buildBackupJson(
      readings: readings,
      settings: AppSettings.fromMap({AppSettings.kHeatingValue: '34.8', AppSettings.kAnimations: 'false'}),
      monthlyKeretMJ: defaultMonthlyKeretMJ,
      appVersion: '0.5.0 (6)',
      exportedAt: DateTime(2026, 10, 7, 9, 30),
    );
    final data = jsonDecode(json) as Map<String, dynamic>;
    expect(data['app'], 'Kékláng');
    expect(data['format'], 1);
    expect(data['appVersion'], '0.5.0 (6)');
    // Csak a gázhoz tartozó, működő beállítások kerülnek bele.
    expect(data['settings'], {
      'heatingValueMJPerM3': 34.8,
      'annualLimitMJ': 63645,
      'annualLimitM3': 1828.879,
      'discountPriceFtPerM3': 102,
      'marketPriceFtPerMJ': 22.002,
      'marketPriceFtPerM3': 765.67,
    });
    expect(json.contains('reminderMinutes'), isFalse);
    expect((data['monthlyKeretMJ'] as Map)['1'], 12365);
    expect((data['monthlyKeretM3'] as Map)['1'], 355.316);
    expect((data['monthlyKeretM3'] as Map)['10'], 107.011);
    final rows = data['readings'] as List;
    expect(rows.first, {'date': '2026-10-01', 'value': 14890.9});
    expect(rows, hasLength(3));
  });

  test('file names carry the date', () {
    expect(exportFileName('mentes', 'json', DateTime(2026, 10, 7)), 'keklang-mentes-2026-10-07.json');
  });
}
