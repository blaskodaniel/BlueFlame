import 'package:blueflame/domain/consumption.dart';
import 'package:blueflame/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

ConsumptionModel model(List<(DateTime, double)> readings, {DateTime? today, double limit = 1729}) => ConsumptionModel(
      readings: [for (final (d, v) in readings) MeterReading(day: d, value: v)],
      monthlyTargets: defaultMonthlyTargets,
      annualLimit: limit,
      today: today ?? DateTime(2026, 10, 4),
    );

void main() {
  group('gas year', () {
    test('runs from Aug 1 to Jul 31', () {
      expect(gasYearStartFor(DateTime(2026, 10, 4)), DateTime(2026, 8));
      expect(gasYearStartFor(DateTime(2026, 8, 1)), DateTime(2026, 8));
      expect(gasYearStartFor(DateTime(2026, 7, 31)), DateTime(2025, 8));
      expect(gasYearStartFor(DateTime(2027, 3, 5)), DateTime(2026, 8));
      final m = model([], today: DateTime(2027, 3, 5));
      expect(m.yearStart, DateTime(2026, 8));
      expect(m.yearEnd, DateTime(2027, 7, 31));
      expect(m.yearLength, 365);
      expect(m.yearMonths.first, DateTime(2026, 8));
      expect(m.yearMonths.last, DateTime(2027, 7));
    });

    test('only usage inside the current gas year counts', () {
      final m = model([(DateTime(2026, 7, 29), 0), (DateTime(2026, 8, 2), 40)]);
      // 4 nap, napi 10: júl. 30–31. az előző gázév, aug. 1–2. az idei → 20.
      expect(m.yearUsed, closeTo(20, 1e-9));
      expect(m.trackedStart, DateTime(2026, 8));
    });

    test('recommended cumulative starts in August', () {
      final m = model([]);
      expect(m.recommendedCumulative(DateTime(2026, 7, 31)), 0);
      expect(m.recommendedCumulative(DateTime(2026, 8, 31)), closeTo(25, 1e-9));
      expect(m.recommendedCumulative(DateTime(2026, 9, 30)), closeTo(90, 1e-9));
      expect(m.recommendedCumulative(DateTime(2027, 7, 31)), closeTo(1710, 1e-9));
    });

    test('monthly usage lists months from August to the current one', () {
      final m = model([(DateTime(2026, 7, 31), 0), (DateTime(2026, 10, 4), 65)]);
      final months = m.monthlyUsage();
      expect([for (final x in months) x.month.month], [8, 9, 10]);
      expect(months.first.recommended, 25);
      expect(months.fold<double>(0, (s, x) => s + x.used), closeTo(65, 1e-9));
    });

    test('weekly buckets start on Monday and cover the gas year so far', () {
      final m = model([]);
      final weeks = m.weeklyUsageThisYear();
      expect(weeks.first.start, DateTime(2026, 8));
      expect(weeks.last.end, DateTime(2026, 10, 4));
      for (final w in weeks.skip(1)) {
        expect(w.start.weekday, DateTime.monday);
      }
      final recSum = weeks.fold<double>(0, (s, w) => s + w.recommended);
      expect(recSum, closeTo(m.recommendedCumulative(DateTime(2026, 10, 4)), 1e-6));
    });
  });

  group('consumption', () {
    test('no readings: zero usage, no estimate', () {
      final m = model([]);
      expect(m.yearUsed, 0);
      expect(m.dataEnd, isNull);
      expect(m.estimatedYearEnd, isNull);
      expect(m.estimatedCost, isNull);
      expect(m.averageOfLastDays(7), isNull);
    });

    test('a gap between readings is spread evenly over the days', () {
      final m = model([(DateTime(2026, 10, 1), 100), (DateTime(2026, 10, 4), 106)]);
      expect(m.usageOn(DateTime(2026, 10, 1)), isNull);
      expect(m.usageOn(DateTime(2026, 10, 2)), closeTo(2, 1e-9));
      expect(m.usageOn(DateTime(2026, 10, 4)), closeTo(2, 1e-9));
      expect(m.yearUsed, closeTo(6, 1e-9));
      expect(m.averageOfLastDays(7), closeTo(2, 1e-9));
    });

    test('daily spreading is correct across the DST switch', () {
      final m = model([(DateTime(2026, 3, 28), 0), (DateTime(2026, 3, 31), 3)], today: DateTime(2026, 4, 1));
      expect(m.usageOn(DateTime(2026, 3, 29)), closeTo(1, 1e-9));
      expect(m.usageOn(DateTime(2026, 3, 30)), closeTo(1, 1e-9));
      expect(m.usageOn(DateTime(2026, 3, 31)), closeTo(1, 1e-9));
    });

    test('estimate follows recommended shape when on pace', () {
      final m0 = model([]);
      final used = m0.recommendedCumulative(DateTime(2026, 10, 4));
      final m = model([(DateTime(2026, 7, 31), 0), (DateTime(2026, 10, 4), used)]);
      expect(m.paceFactor, closeTo(1, 1e-9));
      expect(m.estimatedYearEnd, closeTo(1710, 1e-6));
      expect(m.estimatedReserve, closeTo(19, 1e-6));
      expect(m.estimatedOverLimit, 0);
    });

    test('estimate scales with the tracked pace', () {
      // Okt. 1–4. között az ajánlott dupláját fogyasztja.
      final m0 = model([]);
      final rec = m0.recommendedCumulative(DateTime(2026, 10, 4)) - m0.recommendedCumulative(DateTime(2026, 9, 30));
      final m = model([(DateTime(2026, 9, 30), 0), (DateTime(2026, 10, 4), rec * 2)]);
      expect(m.paceFactor, closeTo(2, 1e-9));
      final remainingRec = 1710 - m0.recommendedCumulative(DateTime(2026, 10, 4));
      expect(m.estimatedYearEnd, closeTo(rec * 2 + remainingRec * 2, 1e-6));
    });

    test('reading lookup before and after a day', () {
      final m = model([(DateTime(2026, 10, 1), 1), (DateTime(2026, 10, 3), 3)]);
      expect(m.readingBefore(DateTime(2026, 10, 3))!.value, 1);
      expect(m.readingAfter(DateTime(2026, 10, 1))!.value, 3);
      expect(m.readingBefore(DateTime(2026, 10, 1)), isNull);
      expect(m.hasReadingToday, isFalse);
    });
  });

  group('pricing', () {
    const p = GasPricing();

    test('discounted price up to the limit, market price above', () {
      expect(p.costOf(0), 0);
      expect(p.costOf(100), 100 * 102);
      expect(p.costOf(1729), 1729 * 102);
      expect(p.costOf(1829), 1729 * 102 + 100 * 747);
      expect(p.multiplier, closeTo(7.32, .01));
    });

    test('cost of the next amount straddling the limit', () {
      expect(p.costOfNext(1720, 10), 9 * 102 + 1 * 747);
      expect(p.costOfNext(1800, 5), 5 * 747);
    });

    test('model cost and over-limit estimate', () {
      // Okt. 1–4.: napi 20 m³, ami jóval az ajánlott felett van.
      final m = model([(DateTime(2026, 9, 30), 0), (DateTime(2026, 10, 4), 80)]);
      expect(m.costSoFar, 80 * 102);
      expect(m.estimatedOverLimit, greaterThan(0));
      expect(m.estimatedExtraCost, closeTo(m.estimatedOverLimit! * (747 - 102), 1e-6));
      expect(m.estimatedCost, closeTo(p.costOf(m.estimatedYearEnd!), 1e-6));
    });

    test('current month cost so far and estimate', () {
      // Okt. 1–4.: napi 2 m³ → 8 m³ eddig, kedvezményes áron.
      final m = model([(DateTime(2026, 9, 30), 0), (DateTime(2026, 10, 4), 8)]);
      expect(m.monthStart, DateTime(2026, 10));
      expect(m.monthEnd, DateTime(2026, 10, 31));
      expect(m.monthUsed, closeTo(8, 1e-9));
      expect(m.monthCostSoFar, closeTo(8 * 102, 1e-6));
      final estUsed = m.estimatedCumulative(DateTime(2026, 10, 31))!;
      expect(m.estimatedMonthUsed, closeTo(estUsed, 1e-6));
      expect(m.estimatedMonthCost, closeTo(estUsed * 102, 1e-6));
      expect(m.monthReachesMarketPrice, isFalse);
    });

    test('month cost switches to market price above the limit', () {
      // Szept. 30-ig 1 725 m³ (aug. 1-jétől), okt. 1–4. további 8 m³: 4 m³ még kedvezményes.
      final m = model([(DateTime(2026, 7, 31), 0), (DateTime(2026, 9, 30), 1725), (DateTime(2026, 10, 4), 1733)]);
      expect(m.monthUsed, closeTo(8, 1e-9));
      expect(m.monthCostSoFar, closeTo(4 * 102 + 4 * 747, 1e-6));
      expect(m.monthReachesMarketPrice, isTrue);
    });

    test('no data this month: zero so far, estimate from the pace', () {
      final m = model([(DateTime(2026, 8, 31), 0), (DateTime(2026, 9, 30), 60)]);
      expect(m.monthUsed, 0);
      expect(m.monthCostSoFar, 0);
      expect(m.estimatedMonthUsed, greaterThan(0));
    });

    test('settings provide the configured prices', () {
      final s = AppSettings.fromMap({AppSettings.kDiscountPrice: '110', AppSettings.kMarketPrice: '800.5'});
      expect(s.pricing.discountPrice, 110);
      expect(s.pricing.marketPrice, 800.5);
      expect(s.pricing.limit, 1729);
    });
  });
}
