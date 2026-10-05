import 'package:intl/intl.dart';

/// Magyar szám- és dátumformázás (szóközös ezres tagolás, tizedesvessző).
/// Az intl ezres elválasztója nem törhető szóköz, így a számok nem törnek el.
abstract final class Fmt {
  static final _int = NumberFormat('#,##0', 'hu');
  static final _one = NumberFormat('#,##0.0', 'hu');
  static final _short = DateFormat('MMM d.', 'hu');
  static final _weekday = DateFormat('EEEE', 'hu');
  static final _full = DateFormat('y. MMM d.', 'hu');

  /// Egész m³, pl. `1 077`.
  static String m3(num v) => _int.format(v.round());

  /// Egy tizedes, pl. `3,9` vagy `14 855,0`.
  static String m3One(num v) => _one.format(v);

  /// Előjeles egy tizedes, pl. `+6,4`.
  static String delta(num v) => '${v >= 0 ? '+' : '−'}${m3One(v.abs())}';

  static String percent(double ratio) => '${m3One(ratio * 100)}%';

  /// Forint egészre kerekítve, pl. `113 016 Ft`.
  static String ft(num v) => '${_int.format(v.round())} Ft';

  /// Egységár, pl. `102 Ft/m³`; tizedes csak ha van.
  static String unitPrice(num v) => '${v == v.roundToDouble() ? _int.format(v) : _one.format(v)} Ft/m³';

  /// Szorzó, pl. `7,3×`.
  static String times(double v) => '${_one.format(v)}×';

  /// `okt. 4.`
  static String shortDate(DateTime d) => _short.format(d);

  /// `okt. 4., vasárnap`
  static String dateWithWeekday(DateTime d) => '${_short.format(d)}, ${_weekday.format(d)}';

  /// `2026. okt. 4., vasárnap`
  static String fullDate(DateTime d) => '${_full.format(d)}, ${_weekday.format(d)}';

  /// `2026. aug. 1. – 2027. júl. 31.`
  static String range(DateTime from, DateTime to) => '${_full.format(from)} – ${_full.format(to)}';

  /// `vasárnap, okt. 4.`
  static String headerDate(DateTime d) => '${_weekday.format(d)}, ${_short.format(d)}';

  /// Hétfőtől vasárnapig, `DateTime.weekday - 1` szerint indexelve.
  static const weekdayInitials = ['H', 'K', 'Sze', 'Cs', 'P', 'Szo', 'V'];
  static const monthNames = [
    'Január', 'Február', 'Március', 'Április', 'Május', 'Június',
    'Július', 'Augusztus', 'Szeptember', 'Október', 'November', 'December',
  ];
  static const monthShort = ['Jan', 'Feb', 'Már', 'Ápr', 'Máj', 'Jún', 'Júl', 'Aug', 'Szep', 'Okt', 'Nov', 'Dec'];
  static const monthInitials = ['J', 'F', 'M', 'Á', 'M', 'J', 'J', 'A', 'Sz', 'O', 'N', 'D'];
}
