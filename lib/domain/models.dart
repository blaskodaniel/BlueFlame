/// Egy gázóra-leolvasás: a nap és a számláló állása m³-ben.
class MeterReading {
  const MeterReading({required this.day, required this.value});

  final DateTime day;
  final double value;
}

/// A dizájnban szereplő alapértelmezett havi ajánlott értékek (m³), naptári
/// hónap szerint indexelve: január–december.
const defaultMonthlyTargets = <double>[320, 290, 220, 125, 60, 30, 25, 25, 65, 140, 190, 220];

/// A rezsicsökkentett (kedvezményes) éves keret m³-ben.
const defaultAnnualLimit = 1729.0;

/// Kedvezményes ár a keretig, Ft/m³.
const defaultDiscountPrice = 102.0;

/// Piaci ár a keret felett, Ft/m³.
const defaultMarketPrice = 747.0;

/// A gázév első hónapja: augusztus (a fordulónap július 31.).
const gasYearStartMonth = 8;

/// Kétsávos gázár: a keretig kedvezményes, felette piaci ár.
class GasPricing {
  const GasPricing({
    this.limit = defaultAnnualLimit,
    this.discountPrice = defaultDiscountPrice,
    this.marketPrice = defaultMarketPrice,
  });

  final double limit;
  final double discountPrice;
  final double marketPrice;

  /// A gázév elejétől számított `volume` m³ teljes ára forintban.
  double costOf(double volume) {
    if (volume <= 0) return 0;
    final discounted = volume < limit ? volume : limit;
    final over = volume > limit ? volume - limit : 0.0;
    return discounted * discountPrice + over * marketPrice;
  }

  /// A gázév elejétől már elfogyasztott `before` m³ után következő `amount` m³ ára.
  double costOfNext(double before, double amount) => costOf(before + amount) - costOf(before);

  /// Hányszorosa a piaci ár a kedvezményesnek.
  double get multiplier => discountPrice <= 0 ? 0 : marketPrice / discountPrice;
}

class AppSettings {
  const AppSettings({
    this.annualLimit = defaultAnnualLimit,
    this.discountPrice = defaultDiscountPrice,
    this.marketPrice = defaultMarketPrice,
    this.dailyReminder = true,
    this.reminderMinutes = 19 * 60,
    this.notifyAt80 = true,
    this.notifyAt95 = true,
    this.weeklySummary = false,
    this.animations = true,
  });

  final double annualLimit;
  final double discountPrice;
  final double marketPrice;
  final bool dailyReminder;

  /// Az emlékeztető időpontja éjfél óta eltelt percekben.
  final int reminderMinutes;
  final bool notifyAt80;
  final bool notifyAt95;
  final bool weeklySummary;
  final bool animations;

  GasPricing get pricing => GasPricing(limit: annualLimit, discountPrice: discountPrice, marketPrice: marketPrice);

  static const kAnnualLimit = 'annualLimit';
  static const kDiscountPrice = 'discountPrice';
  static const kMarketPrice = 'marketPrice';
  static const kDailyReminder = 'dailyReminder';
  static const kReminderMinutes = 'reminderMinutes';
  static const kNotifyAt80 = 'notifyAt80';
  static const kNotifyAt95 = 'notifyAt95';
  static const kWeeklySummary = 'weeklySummary';
  static const kAnimations = 'animations';

  factory AppSettings.fromMap(Map<String, String> m) {
    const d = AppSettings();
    bool b(String k, bool def) => m[k] == null ? def : m[k] == 'true';
    double n(String k, double def) => double.tryParse(m[k] ?? '') ?? def;
    return AppSettings(
      annualLimit: n(kAnnualLimit, d.annualLimit),
      discountPrice: n(kDiscountPrice, d.discountPrice),
      marketPrice: n(kMarketPrice, d.marketPrice),
      dailyReminder: b(kDailyReminder, d.dailyReminder),
      reminderMinutes: int.tryParse(m[kReminderMinutes] ?? '') ?? d.reminderMinutes,
      notifyAt80: b(kNotifyAt80, d.notifyAt80),
      notifyAt95: b(kNotifyAt95, d.notifyAt95),
      weeklySummary: b(kWeeklySummary, d.weeklySummary),
      animations: b(kAnimations, d.animations),
    );
  }
}
