import 'dates.dart';
import 'models.dart';

/// Az a gázév kezdőnapja (augusztus 1.), amelybe `day` esik.
DateTime gasYearStartFor(DateTime day) =>
    day.month >= gasYearStartMonth ? DateTime(day.year, gasYearStartMonth) : DateTime(day.year - 1, gasYearStartMonth);

/// A leolvasásokból, a havi ajánlott értékekből és az éves limitből számolt
/// fogyasztási modell egy adott napra (`today`) nézve.
///
/// Minden éves érték a **gázévre** vonatkozik: augusztus 1-jétől a következő
/// év július 31-ig. Két leolvasás közti fogyasztást egyenletesen osztja szét
/// a köztes napokra, így a napi bontás akkor is folytonos, ha kimarad egy-egy
/// leolvasás.
class ConsumptionModel {
  ConsumptionModel({
    required List<MeterReading> readings,
    required List<double> monthlyTargets,
    required this.annualLimit,
    required DateTime today,
    this.discountPrice = defaultDiscountPrice,
    this.marketPrice = defaultMarketPrice,
  })  : assert(monthlyTargets.length == 12),
        readings = [...readings]..sort((a, b) => a.day.compareTo(b.day)),
        monthlyTargets = List.unmodifiable(monthlyTargets),
        today = dayOf(today) {
    for (var i = 1; i < this.readings.length; i++) {
      final a = this.readings[i - 1];
      final b = this.readings[i];
      final n = daysBetween(a.day, b.day);
      if (n <= 0) continue;
      final perDay = (b.value - a.value) / n;
      for (var k = 1; k <= n; k++) {
        _daily[addDays(a.day, k)] = perDay;
      }
    }
  }

  final List<MeterReading> readings;

  /// Naptári hónap szerint indexelve (0 = január).
  final List<double> monthlyTargets;
  final double annualLimit;
  final double discountPrice;
  final double marketPrice;
  final DateTime today;
  final Map<DateTime, double> _daily = {};

  GasPricing get pricing => GasPricing(limit: annualLimit, discountPrice: discountPrice, marketPrice: marketPrice);

  /// A mostani gázév első napja (augusztus 1.).
  DateTime get yearStart => gasYearStartFor(today);

  /// A mostani gázév utolsó napja (július 31.).
  DateTime get yearEnd => addDays(DateTime(yearStart.year + 1, gasYearStartMonth), -1);

  int get yearLength => daysBetween(yearStart, yearEnd) + 1;

  /// A gázév 12 hónapjának első napjai, augusztustól júliusig.
  List<DateTime> get yearMonths => [for (var i = 0; i < 12; i++) DateTime(yearStart.year, yearStart.month + i)];

  double get monthlyTargetSum => monthlyTargets.fold(0, (s, v) => s + v);

  /// Egy nap fogyasztása, vagy `null`, ha arra a napra nincs adat.
  double? usageOn(DateTime day) => _daily[dayOf(day)];

  double usedBetween(DateTime from, DateTime to) {
    var sum = 0.0;
    for (var d = dayOf(from); !d.isAfter(to); d = addDays(d, 1)) {
      sum += _daily[d] ?? 0;
    }
    return sum;
  }

  double recommendedOn(DateTime day) => monthlyTargets[day.month - 1] / daysInMonth(day.year, day.month);

  /// Az ajánlott fogyasztás összege a gázév elejétől `day`-ig (bezárólag).
  double recommendedCumulative(DateTime day) {
    if (day.isBefore(yearStart)) return 0;
    if (day.isAfter(yearEnd)) return monthlyTargetSum;
    var sum = 0.0;
    for (final m in yearMonths) {
      if (m.year == day.year && m.month == day.month) break;
      sum += monthlyTargets[m.month - 1];
    }
    return sum + monthlyTargets[day.month - 1] * day.day / daysInMonth(day.year, day.month);
  }

  MeterReading? get latestReading => readings.isEmpty ? null : readings.last;

  bool get hasReadingToday => readings.any((r) => r.day == today);

  MeterReading? readingBefore(DateTime day) {
    for (final r in readings.reversed) {
      if (r.day.isBefore(day)) return r;
    }
    return null;
  }

  MeterReading? readingAfter(DateTime day) {
    for (final r in readings) {
      if (r.day.isAfter(day)) return r;
    }
    return null;
  }

  /// Az utolsó nap, amelyre van fogyasztási adat ebben a gázévben (legfeljebb ma).
  DateTime? get dataEnd {
    final last = latestReading;
    if (last == null || readings.length < 2) return null;
    final end = last.day.isAfter(today) ? today : last.day;
    return end.isBefore(yearStart) ? null : end;
  }

  /// Az első nap ebben a gázévben, amelyre van fogyasztási adat.
  DateTime? get trackedStart {
    if (dataEnd == null) return null;
    final first = addDays(readings.first.day, 1);
    return first.isBefore(yearStart) ? yearStart : first;
  }

  /// A gázévben eddig elfogyasztott mennyiség.
  double get yearUsed => dataEnd == null ? 0 : usedBetween(yearStart, dataEnd!);

  /// A gázév elejétől `day` előtti napig elfogyasztott mennyiség (a költségszámításhoz).
  double usedBeforeInYear(DateTime day) => day.isAfter(yearStart) ? usedBetween(yearStart, addDays(day, -1)) : 0;

  double get remaining => annualLimit - yearUsed;

  double get usedRatio => annualLimit <= 0 ? 0 : yearUsed / annualLimit;

  /// Hol kellene tartani ma az ajánlott havi értékek szerint, a limit arányában.
  double get recommendedPaceRatio => annualLimit <= 0 ? 0 : recommendedCumulative(today) / annualLimit;

  /// A tényleges és az ajánlott fogyasztás aránya a követett időszakban.
  double get paceFactor {
    final start = trackedStart;
    final end = dataEnd;
    if (start == null || end == null) return 1;
    final rec = recommendedCumulative(end) - recommendedCumulative(addDays(start, -1));
    if (rec <= 0) return 1;
    return usedBetween(start, end) / rec;
  }

  /// Becsült kumulált fogyasztás `day` napig: az adatok végéig a tényleges,
  /// utána az ajánlott havi arányok szerint, a követett tempóval skálázva.
  double? estimatedCumulative(DateTime day) {
    final end = dataEnd;
    if (end == null) return null;
    if (!day.isAfter(end)) return usedBetween(yearStart, day);
    return yearUsed + (recommendedCumulative(day) - recommendedCumulative(end)) * paceFactor;
  }

  double? get estimatedYearEnd => estimatedCumulative(yearEnd);

  double? get estimatedReserve {
    final e = estimatedYearEnd;
    return e == null ? null : annualLimit - e;
  }

  // ---------------------------------------------------------------------------
  // Költség (kétsávos ár)
  // ---------------------------------------------------------------------------

  /// A gázévben eddig elfogyasztott gáz ára forintban.
  double get costSoFar => pricing.costOf(yearUsed);

  /// A gázév végéig becsült teljes költség.
  double? get estimatedCost {
    final e = estimatedYearEnd;
    return e == null ? null : pricing.costOf(e);
  }

  /// A becslés szerint a keret fölé eső mennyiség (0, ha belefér).
  double? get estimatedOverLimit {
    final e = estimatedYearEnd;
    return e == null ? null : (e - annualLimit).clamp(0, double.infinity).toDouble();
  }

  /// Mennyivel kerül többe a keret feletti rész, mintha kedvezményes áron lenne.
  double? get estimatedExtraCost {
    final over = estimatedOverLimit;
    return over == null ? null : over * (marketPrice - discountPrice);
  }

  // ---------------------------------------------------------------------------
  // Az aktuális hónap
  // ---------------------------------------------------------------------------

  DateTime get monthStart => DateTime(today.year, today.month);

  DateTime get monthEnd => DateTime(today.year, today.month, daysInMonth(today.year, today.month));

  /// A gázévben a hónap előtt elfogyasztott mennyiség; ebből tudjuk, melyik
  /// ársávban kezdődik a hónap.
  double get _usedBeforeMonth =>
      monthStart.isAfter(yearStart) ? (estimatedCumulative(addDays(monthStart, -1)) ?? usedBeforeInYear(monthStart)) : 0;

  /// Az aktuális hónapban eddig elfogyasztott mennyiség.
  double get monthUsed {
    final end = dataEnd;
    return end == null || end.isBefore(monthStart) ? 0 : usedBetween(monthStart, end);
  }

  /// Az aktuális hónap eddigi költsége (az árlépcsőt is figyelembe véve).
  double get monthCostSoFar => pricing.costOfNext(_usedBeforeMonth, monthUsed);

  /// Becsült fogyasztás a teljes aktuális hónapra.
  double? get estimatedMonthUsed {
    final e = estimatedCumulative(monthEnd);
    return e == null ? null : e - _usedBeforeMonth;
  }

  /// Becsült költség a hónap végéig.
  double? get estimatedMonthCost {
    final used = estimatedMonthUsed;
    return used == null ? null : pricing.costOfNext(_usedBeforeMonth, used);
  }

  /// Igaz, ha a becslés szerint a hónapban (részben) már piaci áron fogy a gáz.
  bool get monthReachesMarketPrice => _usedBeforeMonth + (estimatedMonthUsed ?? monthUsed) > annualLimit;

  // ---------------------------------------------------------------------------
  // Bontások a diagramokhoz
  // ---------------------------------------------------------------------------

  /// Az utolsó `n` nap (a mai nappal bezárólag) fogyasztása, régebbitől az újabbig.
  List<DailyUsage> lastDays(int n) => [
        for (var i = n - 1; i >= 0; i--)
          DailyUsage(addDays(today, -i), usageOn(addDays(today, -i)), recommendedOn(addDays(today, -i))),
      ];

  /// Az utolsó `n` nap átlaga azokra a napokra, amelyekre van adat.
  double? averageOfLastDays(int n) {
    final values = lastDays(n).map((d) => d.used).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// A gázévben hónaponként elfogyasztott mennyiség augusztustól a mai hónappal bezárólag.
  List<MonthUsage> monthlyUsage() => [
        for (final m in yearMonths)
          if (!m.isAfter(today))
            MonthUsage(
              m,
              usedBetween(m, m.year == today.year && m.month == today.month ? today : DateTime(m.year, m.month, daysInMonth(m.year, m.month))),
              monthlyTargets[m.month - 1],
            ),
      ];

  /// Heti összegek a gázév elejétől (hétfővel kezdődő hetek), a mai héttel bezárólag.
  List<PeriodUsage> weeklyUsageThisYear() {
    final result = <PeriodUsage>[];
    var start = yearStart;
    while (!start.isAfter(today)) {
      final weekEnd = addDays(start, 7 - start.weekday);
      final end = weekEnd.isAfter(today) ? today : weekEnd;
      var used = 0.0;
      var rec = 0.0;
      var hasData = false;
      for (var d = start; !d.isAfter(end); d = addDays(d, 1)) {
        final u = _daily[d];
        if (u != null) {
          used += u;
          hasData = true;
        }
        rec += recommendedOn(d);
      }
      result.add(PeriodUsage(start, end, hasData ? used : null, rec));
      start = addDays(end, 1);
    }
    return result;
  }
}

class DailyUsage {
  const DailyUsage(this.day, this.used, this.recommended);

  final DateTime day;
  final double? used;
  final double recommended;
}

class PeriodUsage {
  const PeriodUsage(this.start, this.end, this.used, this.recommended);

  final DateTime start;
  final DateTime end;
  final double? used;
  final double recommended;
}

class MonthUsage {
  const MonthUsage(this.month, this.used, this.recommended);

  /// A hónap első napja.
  final DateTime month;
  final double used;

  /// A teljes hónapra ajánlott érték.
  final double recommended;
}
