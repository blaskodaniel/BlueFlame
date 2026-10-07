/// Egy gázóra-leolvasás: a nap és a számláló állása m³-ben.
class MeterReading {
  const MeterReading({required this.day, required this.value});

  final DateTime day;
  final double value;
}

/// A hivatalos havi kedvezményes keret (jelleggörbe) MJ-ben, naptári hónap
/// szerint indexelve: január–december. Összege a teljes éves keret.
/// Forrás: MVM Next tájékoztató a földgázszámláról (2024. aug. 1-jétől rögzített).
const defaultMonthlyKeretMJ = <double>[12365, 10421, 8915, 5145, 1827, 635, 512, 565, 1109, 3724, 7490, 10937];

/// A rezsicsökkentett éves keret felhasználási helyenként, MJ-ben (≥ 1 729 m³).
const defaultAnnualLimitMJ = 63645.0;

/// Tájékoztató fűtőérték, MJ/m³; a pontos érték a szolgáltató gázminőség-oldalán.
const defaultHeatingValue = 34.8;

/// Kedvezményes ár, Ft/m³.
const defaultDiscountPrice = 102.0;

/// Lakossági piaci ár a keret felett, bruttó Ft/MJ.
const defaultMarketPriceMJ = 22.002;

/// A gázév első hónapja: augusztus (a fordulónap július 31.).
const gasYearStartMonth = 8;

/// Kétsávos gázár: a keretig kedvezményes, felette piaci ár. Minden érték
/// m³-ben és Ft/m³-ben (a fűtőértékkel már átszámolva).
class GasPricing {
  const GasPricing({
    required this.limit,
    this.discountPrice = defaultDiscountPrice,
    this.marketPrice = defaultMarketPriceMJ * defaultHeatingValue,
  });

  final double limit;
  final double discountPrice;
  final double marketPrice;

  /// `used` m³ ára egy `keret` m³-es kerettel: a keretig kedvezményes, felette
  /// piaci áron. Ez a havi diktálásos számla egy hónapja, és az éves elszámolás is.
  double billFor(double used, double keret) {
    if (used <= 0) return 0;
    final discounted = used < keret ? used : keret;
    final over = used > keret ? used - keret : 0.0;
    return discounted * discountPrice + over * marketPrice;
  }

  /// A gázév elejétől számított `volume` m³ ára az éves kerettel (éves elszámolás).
  double costOf(double volume) => billFor(volume, limit);

  /// Hányszorosa a piaci ár a kedvezményesnek.
  double get multiplier => discountPrice <= 0 ? 0 : marketPrice / discountPrice;
}

class AppSettings {
  const AppSettings({
    this.annualLimitMJ = defaultAnnualLimitMJ,
    this.heatingValue = defaultHeatingValue,
    this.discountPrice = defaultDiscountPrice,
    this.marketPriceMJ = defaultMarketPriceMJ,
    this.dailyReminder = true,
    this.reminderMinutes = 19 * 60,
    this.notifyAt80 = true,
    this.notifyAt95 = true,
    this.weeklySummary = false,
    this.animations = true,
  });

  /// Az éves kedvezményes keret MJ-ben.
  final double annualLimitMJ;

  /// Fűtőérték, MJ/m³: ezzel számolunk át energia és térfogat között.
  final double heatingValue;

  /// Kedvezményes ár, Ft/m³.
  final double discountPrice;

  /// Piaci ár, Ft/MJ.
  final double marketPriceMJ;
  final bool dailyReminder;

  /// Az emlékeztető időpontja éjfél óta eltelt percekben.
  final int reminderMinutes;
  final bool notifyAt80;
  final bool notifyAt95;
  final bool weeklySummary;
  final bool animations;

  /// Az éves keret m³-ben a fűtőérték alapján.
  double get annualLimit => annualLimitMJ / heatingValue;

  /// A piaci ár Ft/m³-ben a fűtőérték alapján.
  double get marketPrice => marketPriceMJ * heatingValue;

  GasPricing get pricing => GasPricing(limit: annualLimit, discountPrice: discountPrice, marketPrice: marketPrice);

  // Az MJ-alapú értékek új kulcsokat kaptak; a régi, m³-ben tárolt
  // `annualLimit` és `marketPrice` kulcsokat nem olvassuk.
  static const kAnnualLimitMJ = 'annualLimitMJ';
  static const kHeatingValue = 'heatingValue';
  static const kDiscountPrice = 'discountPrice';
  static const kMarketPriceMJ = 'marketPriceMJ';
  static const kDailyReminder = 'dailyReminder';
  static const kReminderMinutes = 'reminderMinutes';
  static const kNotifyAt80 = 'notifyAt80';
  static const kNotifyAt95 = 'notifyAt95';
  static const kWeeklySummary = 'weeklySummary';
  static const kAnimations = 'animations';

  factory AppSettings.fromMap(Map<String, String> m) {
    const d = AppSettings();
    bool b(String k, bool def) => m[k] == null ? def : m[k] == 'true';
    double n(String k, double def) {
      final v = double.tryParse(m[k] ?? '');
      return v != null && v > 0 ? v : def;
    }

    return AppSettings(
      annualLimitMJ: n(kAnnualLimitMJ, d.annualLimitMJ),
      heatingValue: n(kHeatingValue, d.heatingValue),
      discountPrice: n(kDiscountPrice, d.discountPrice),
      marketPriceMJ: n(kMarketPriceMJ, d.marketPriceMJ),
      dailyReminder: b(kDailyReminder, d.dailyReminder),
      reminderMinutes: int.tryParse(m[kReminderMinutes] ?? '') ?? d.reminderMinutes,
      notifyAt80: b(kNotifyAt80, d.notifyAt80),
      notifyAt95: b(kNotifyAt95, d.notifyAt95),
      weeklySummary: b(kWeeklySummary, d.weeklySummary),
      animations: b(kAnimations, d.animations),
    );
  }
}
