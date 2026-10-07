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
    this.heatingValue = defaultHeatingValue,
    this.discountPrice = defaultDiscountPrice,
    this.marketPrice = defaultMarketPriceMJ * defaultHeatingValue,
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

  /// A havi kedvezményes keret (jelleggörbe) m³-ben, naptári hónap szerint
  /// indexelve (0 = január).
  final List<double> monthlyTargets;

  /// Az éves kedvezményes keret m³-ben.
  final double annualLimit;

  /// Fűtőérték, MJ/m³ (csak megjelenítéshez; a többi érték már m³-ben van).
  final double heatingValue;

  /// Ft/m³.
  final double discountPrice;

  /// Ft/m³.
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
  // Költség – havi diktálás
  //
  // Havi diktálásnál minden hónapnak saját kedvezményes kerete van (jelleggörbe):
  // a havi keret feletti rész az adott havi számlán piaci áron szerepel. Az éves
  // elszámoláskor a teljes gázév fogyasztását az éves kerethez mérik, és ha az
  // éves szinten belefér, a havi számlákon kifizetett többlet visszajár.
  // ---------------------------------------------------------------------------

  /// Egy naptári hónap kedvezményes kerete m³-ben.
  double keretFor(DateTime month) => monthlyTargets[month.month - 1];

  /// Egy hónap számlája `used` m³ fogyasztásnál.
  double monthBill(DateTime month, double used) => pricing.billFor(used, keretFor(month));

  /// Egy hónapban a ténylegesen mért fogyasztás (az adatok végéig).
  double usedInMonth(DateTime month) {
    final end = dataEnd;
    final start = DateTime(month.year, month.month);
    if (end == null || end.isBefore(start)) return 0;
    final last = DateTime(month.year, month.month, daysInMonth(month.year, month.month));
    return usedBetween(start, end.isBefore(last) ? end : last);
  }

  /// Becsült kumulált fogyasztás a gázévben `day` napig; a gázév előtt 0.
  double? _cumulative(DateTime day) => day.isBefore(yearStart) ? 0 : estimatedCumulative(day);

  /// Egy hónap becsült teljes fogyasztása (múlt: tényleges, jövő: becslés).
  double? estimatedUsedInMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = _cumulative(DateTime(month.year, month.month, daysInMonth(month.year, month.month)));
    final before = _cumulative(addDays(start, -1));
    return end == null || before == null ? null : end - before;
  }

  /// A gázév havi számláinak összege eddig (az aktuális hónap eddigi részével).
  double get billsSoFar => [
        for (final m in yearMonths)
          if (!m.isAfter(today)) monthBill(m, usedInMonth(m)),
      ].fold(0.0, (s, v) => s + v);

  /// A gázév összes havi számlájának becsült összege.
  double? get estimatedBillsTotal {
    if (dataEnd == null) return null;
    var sum = 0.0;
    for (final m in yearMonths) {
      sum += monthBill(m, estimatedUsedInMonth(m)!);
    }
    return sum;
  }

  /// Az éves elszámolás szerinti költség eddig (az éves kerettel).
  double get costSoFar => pricing.costOf(yearUsed);

  /// Az éves elszámolás szerinti becsült költség a gázév végére.
  double? get estimatedCost {
    final e = estimatedYearEnd;
    return e == null ? null : pricing.costOf(e);
  }

  /// Az éves elszámoláskor várhatóan visszajáró összeg eddig: a havi
  /// számlákon piaci áron fizetett, de az éves keretbe még beleférő rész.
  double get refundSoFar => (billsSoFar - costSoFar).clamp(0, double.infinity).toDouble();

  /// A gázév végére becsült visszatérítés az éves elszámoláskor.
  double? get estimatedRefund {
    final bills = estimatedBillsTotal;
    final settled = estimatedCost;
    return bills == null || settled == null ? null : (bills - settled).clamp(0, double.infinity).toDouble();
  }

  /// A becslés szerint az éves keret fölé eső mennyiség (0, ha belefér).
  double? get estimatedOverLimit {
    final e = estimatedYearEnd;
    return e == null ? null : (e - annualLimit).clamp(0, double.infinity).toDouble();
  }

  /// Mennyivel kerül többe az éves keret feletti rész, mintha kedvezményes áron lenne.
  double? get estimatedExtraCost {
    final over = estimatedOverLimit;
    return over == null ? null : over * (marketPrice - discountPrice);
  }

  // ---------------------------------------------------------------------------
  // Az aktuális hónap
  // ---------------------------------------------------------------------------

  DateTime get monthStart => DateTime(today.year, today.month);

  DateTime get monthEnd => DateTime(today.year, today.month, daysInMonth(today.year, today.month));

  /// Az aktuális hónap kedvezményes kerete m³-ben.
  double get monthKeret => keretFor(monthStart);

  /// Az aktuális hónapban eddig elfogyasztott mennyiség.
  double get monthUsed => usedInMonth(monthStart);

  /// Az aktuális havi számla eddig.
  double get monthCostSoFar => monthBill(monthStart, monthUsed);

  /// Becsült fogyasztás a teljes aktuális hónapra.
  double? get estimatedMonthUsed => estimatedUsedInMonth(monthStart);

  /// Becsült havi számla a hónap végéig.
  double? get estimatedMonthCost {
    final used = estimatedMonthUsed;
    return used == null ? null : monthBill(monthStart, used);
  }

  /// A becslés szerint a havi keret fölé eső mennyiség (0, ha belefér).
  double get estimatedMonthOver => ((estimatedMonthUsed ?? monthUsed) - monthKeret).clamp(0, double.infinity).toDouble();

  /// Igaz, ha a becslés szerint a hónapban a havi keret felett, piaci áron is fogy gáz.
  bool get monthReachesMarketPrice => estimatedMonthOver > 0;

  /// A lezárt hónapokban fel nem használt (megmaradt) keret m³-ben: a követett
  /// napokra jutó havi keret mínusz a tényleges fogyasztás, az előző hónap
  /// végéig. Negatív, ha a lezárt hónapokban összesen a keret felett fogyott.
  ///
  /// Havi diktálásnál ezt a mennyiséget egy későbbi, hidegebb hónapban a havi
  /// keret felett is el lehet fogyasztani: a havi számlán ugyan piaci áron
  /// szerepel, de az éves elszámoláskor kedvezményes áron számolják el.
  double get savedKeret {
    final start = trackedStart;
    final data = dataEnd;
    if (start == null || data == null) return 0;
    final lastClosed = addDays(monthStart, -1);
    final end = data.isBefore(lastClosed) ? data : lastClosed;
    var sum = 0.0;
    for (var d = start; !d.isAfter(end); d = addDays(d, 1)) {
      sum += recommendedOn(d) - (_daily[d] ?? 0);
    }
    return sum;
  }

  /// Van-e már legalább részben követett, lezárt hónap a gázévben.
  bool get hasClosedTrackedMonth {
    final start = trackedStart;
    return start != null && start.isBefore(monthStart);
  }

  /// Ennyinél kellene tartani ma a havi keretek szerint (a gyűrű fehér jelölője).
  double get recommendedToDate => recommendedCumulative(today);

  /// A hónap keretéből a mai nappal bezárólag eltelt napokra jutó rész.
  double get monthKeretToDate => monthKeret * today.day / monthEnd.day;

  /// Az aktuális hónap keretéből elfogyasztott arány (1 felett: túllépés).
  double get monthUsedRatio => monthKeret <= 0 ? 0 : monthUsed / monthKeret;

  /// A `day` napig tartó, `prev` utáni leolvasási időszak `amount` m³-ének ára
  /// a havi számlán: a nap hónapjában korábban mért fogyasztás után következik.
  double readingCost(DateTime prev, DateTime day, double amount) {
    final month = DateTime(day.year, day.month);
    final before = prev.isBefore(month) ? 0.0 : usedBetween(month, prev);
    return monthBill(month, before + amount) - monthBill(month, before);
  }

  /// A `day` napi leolvasás hónapjában a `prev` utáni `amount` m³-ből mennyi esik a havi keret fölé.
  double readingOverKeret(DateTime prev, DateTime day, double amount) {
    final month = DateTime(day.year, day.month);
    final before = prev.isBefore(month) ? 0.0 : usedBetween(month, prev);
    return (before + amount - keretFor(month)).clamp(0.0, amount).toDouble();
  }

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
