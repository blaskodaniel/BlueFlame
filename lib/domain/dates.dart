/// Naptári napokkal dolgozó segédfüggvények. Minden dátum helyi éjfélre
/// van normalizálva; a napok közti különbséget UTC-ben számoljuk, így az
/// óraátállítás nem zavar be.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

int daysInYear(int year) => daysBetween(DateTime(year), DateTime(year + 1));

/// Az év hányadik napja (január 1. = 1).
int dayOfYear(DateTime d) => daysBetween(DateTime(d.year), d) + 1;
