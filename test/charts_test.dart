import 'package:blueflame/ui/widgets/charts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('few bars: every bar with data gets a label', () {
    expect(UsageBars.labelledIndices([1, null, 3]), {0, 2});
  });

  test('many bars: only the peak and the last one', () {
    final values = <double?>[for (var i = 0; i < 30; i++) 1]..[5] = 9;
    expect(UsageBars.labelledIndices(values), {29, 5});
  });

  test('many bars: peak next to the last one is skipped to avoid overlap', () {
    final values = <double?>[for (var i = 0; i < 30; i++) 1]..[27] = 9;
    expect(UsageBars.labelledIndices(values), {29});
  });

  test('many bars without data: no labels', () {
    expect(UsageBars.labelledIndices(List<double?>.filled(30, null)), isEmpty);
  });
}
