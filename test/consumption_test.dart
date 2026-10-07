import 'package:blueflame/domain/consumption.dart';
import 'package:blueflame/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Egyszerű, kerek havi keretek (m³) a számításokhoz: jan–dec, összesen 1 710.
const testTargets = <double>[320, 290, 220, 125, 60, 30, 25, 25, 65, 140, 190, 220];

ConsumptionModel model(List<(DateTime, double)> readings, {DateTime? today, double limit = 1729}) => ConsumptionModel(
      readings: [for (final (d, v) in readings) MeterReading(day: d, value: v)],
      monthlyTargets: testTargets,
      annualLimit: limit,
      today: today ?? DateTime(2026, 10, 4),
      discountPrice: 102,
      marketPrice: 747,
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
    const p = GasPricing(limit: 1729, discountPrice: 102, marketPrice: 747);

    test('annual settlement: discounted up to the limit, market price above', () {
      expect(p.costOf(0), 0);
      expect(p.costOf(100), 100 * 102);
      expect(p.costOf(1729), 1729 * 102);
      expect(p.costOf(1829), 1729 * 102 + 100 * 747);
      expect(p.multiplier, closeTo(7.32, .01));
    });

    test('a monthly bill uses the month keret', () {
      expect(p.billFor(100, 107), 100 * 102);
      expect(p.billFor(150, 107), 107 * 102 + 43 * 747);
    });

    test('annual over-limit estimate', () {
      // Okt. 1–4.: napi 20 m³, ami jóval a keret felett van.
      final m = model([(DateTime(2026, 9, 30), 0), (DateTime(2026, 10, 4), 80)]);
      expect(m.costSoFar, 80 * 102);
      expect(m.estimatedOverLimit, greaterThan(0));
      expect(m.estimatedExtraCost, closeTo(m.estimatedOverLimit! * (747 - 102), 1e-6));
      expect(m.estimatedCost, closeTo(p.costOf(m.estimatedYearEnd!), 1e-6));
    });
  });

  group('monthly reading (havi diktálás)', () {
    test('current month within its keret is billed at the discounted price', () {
      // Okt. 1–4.: napi 2 m³ → 8 m³, az októberi keret 140 m³.
      final m = model([(DateTime(2026, 9, 30), 0), (DateTime(2026, 10, 4), 8)]);
      expect(m.monthStart, DateTime(2026, 10));
      expect(m.monthEnd, DateTime(2026, 10, 31));
      expect(m.monthKeret, 140);
      expect(m.monthUsed, closeTo(8, 1e-9));
      expect(m.monthCostSoFar, closeTo(8 * 102, 1e-6));
      final estUsed = m.estimatedCumulative(DateTime(2026, 10, 31))!;
      expect(m.estimatedMonthUsed, closeTo(estUsed, 1e-6));
      expect(m.estimatedMonthCost, closeTo(estUsed * 102, 1e-6));
      expect(m.monthReachesMarketPrice, isFalse);
    });

    test('above the month keret the bill uses the market price, refunded at settlement', () {
      // Okt. 1–4.: 200 m³ a 140 m³-es októberi keret mellett.
      final m = model([(DateTime(2026, 9, 30), 0), (DateTime(2026, 10, 4), 200)]);
      expect(m.monthCostSoFar, closeTo(140 * 102 + 60 * 747, 1e-6));
      expect(m.monthReachesMarketPrice, isTrue);
      // Éves szinten (1 729 m³) bőven belefér: az éves elszámolás mindent kedvezményesen számol.
      expect(m.costSoFar, closeTo(200 * 102, 1e-6));
      expect(m.refundSoFar, closeTo(60 * (747 - 102), 1e-6));
    });

    test('bills add up month by month across the gas year', () {
      // Aug.: 50 m³ (keret 25), szept.: 65 m³ (keret 65), okt. 1–4.: 8 m³.
      final m = model([
        (DateTime(2026, 7, 31), 0),
        (DateTime(2026, 8, 31), 50),
        (DateTime(2026, 9, 30), 115),
        (DateTime(2026, 10, 4), 123),
      ]);
      expect(m.usedInMonth(DateTime(2026, 8)), closeTo(50, 1e-9));
      expect(m.usedInMonth(DateTime(2026, 9)), closeTo(65, 1e-9));
      expect(m.billsSoFar, closeTo((25 * 102 + 25 * 747) + 65 * 102 + 8 * 102, 1e-6));
      expect(m.costSoFar, closeTo(123 * 102, 1e-6));
      expect(m.refundSoFar, closeTo(25 * (747 - 102), 1e-6));
      expect(m.estimatedBillsTotal, greaterThanOrEqualTo(m.estimatedCost!));
      expect(m.estimatedRefund, greaterThanOrEqualTo(0));
    });

    test('estimated month usage of past months equals the measured usage', () {
      final m = model([(DateTime(2026, 7, 31), 0), (DateTime(2026, 8, 31), 50), (DateTime(2026, 10, 4), 120)]);
      expect(m.estimatedUsedInMonth(DateTime(2026, 8)), closeTo(50, 1e-9));
    });

    test('a reading is priced against what the month has already used', () {
      // Okt. 1–2.: 130 m³, okt. 3–4.: további 20 m³ → 10 m³ még a 140-es kereten belül.
      final m = model([(DateTime(2026, 9, 30), 0), (DateTime(2026, 10, 2), 130), (DateTime(2026, 10, 4), 150)]);
      expect(m.readingCost(DateTime(2026, 10, 2), DateTime(2026, 10, 4), 20), closeTo(10 * 102 + 10 * 747, 1e-6));
      expect(m.readingOverKeret(DateTime(2026, 10, 2), DateTime(2026, 10, 4), 20), closeTo(10, 1e-9));
    });

    test('saved keret counts only tracked days of closed months', () {
      // Szept. 15-től követett; szept. 15–30.: 16 nap × (65/30) keret, 20 m³ fogyott.
      final m = model([(DateTime(2026, 9, 14), 0), (DateTime(2026, 9, 30), 20), (DateTime(2026, 10, 4), 30)]);
      expect(m.hasClosedTrackedMonth, isTrue);
      expect(m.savedKeret, closeTo(16 * 65 / 30 - 20, 1e-9));
    });

    test('saved keret is negative after an over-keret month', () {
      final m = model([(DateTime(2026, 8, 31), 0), (DateTime(2026, 9, 30), 100), (DateTime(2026, 10, 4), 110)]);
      expect(m.savedKeret, closeTo(65 - 100, 1e-9));
    });

    test('no closed tracked month yet: nothing saved', () {
      final m = model([(DateTime(2026, 10, 1), 0), (DateTime(2026, 10, 4), 10)]);
      expect(m.hasClosedTrackedMonth, isFalse);
      expect(m.savedKeret, 0);
    });

    test('no data this month: zero so far, estimate from the pace', () {
      final m = model([(DateTime(2026, 8, 31), 0), (DateTime(2026, 9, 30), 60)]);
      expect(m.monthUsed, 0);
      expect(m.monthCostSoFar, 0);
      expect(m.estimatedMonthUsed, greaterThan(0));
    });
  });

  group('settings and official keret', () {
    test('the official monthly keret adds up to the annual limit', () {
      expect(defaultMonthlyKeretMJ.fold<double>(0, (s, v) => s + v), defaultAnnualLimitMJ);
    });

    test('MJ values are converted with the heating value', () {
      const d = AppSettings();
      expect(d.annualLimit, closeTo(63645 / 34.8, 1e-9));
      expect(d.marketPrice, closeTo(22.002 * 34.8, 1e-9));
      final s = AppSettings.fromMap({
        AppSettings.kHeatingValue: '36',
        AppSettings.kDiscountPrice: '110',
        AppSettings.kMarketPriceMJ: '25',
      });
      expect(s.annualLimit, closeTo(63645 / 36, 1e-9));
      expect(s.pricing.discountPrice, 110);
      expect(s.pricing.marketPrice, closeTo(25 * 36, 1e-9));
    });

    test('invalid stored numbers fall back to the defaults', () {
      final s = AppSettings.fromMap({AppSettings.kHeatingValue: '0', AppSettings.kAnnualLimitMJ: 'abc'});
      expect(s.heatingValue, 34.8);
      expect(s.annualLimitMJ, 63645);
    });
  });
}
