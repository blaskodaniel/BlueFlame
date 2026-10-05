// Az app ikonjának képfájljait generálja az assets/icon/ mappába.
// Futtatás: flutter test tool/generate_icon_test.dart
// Utána: dart run flutter_launcher_icons
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _bg = Color(0xFF080A0F);
const _bgGlow = Color(0xFF12324A);
const _accent = Color(0xFF5CCBFF);
const _flameTop = Color(0xFF9BE3FF);
const _flameBottom = Color(0xFF2E9FE6);
const _core = Color(0xFFE6F7FF);

/// A dizájn láng-ikonja (24×24-es viewBox), SVG-ből átírva.
Path _flame() => Path()
  ..moveTo(12, 2.5)
  ..cubicTo(13.1, 6.2, 17.5, 8.4, 17.5, 13.1)
  ..arcToPoint(const Offset(6.5, 13.1), radius: const Radius.circular(5.5))
  ..cubicTo(6.5, 10.9, 7.6, 9.6, 8.7, 8.5)
  ..cubicTo(9.0, 9.8, 9.8, 10.7, 10.7, 10.9)
  ..cubicTo(10.4, 8.4, 10.8, 5.4, 12, 2.5)
  ..close();

/// A láng `height` magasságúra skálázva, a vászon közepére igazítva.
Path _flameAt(double height, {double dy = 0}) {
  const top = 2.5, bottom = 18.6, cx = 12.0;
  final s = height / (bottom - top);
  final tx = _size / 2 - s * cx;
  final ty = _size / 2 + dy - s * (top + bottom) / 2;
  return _flame().transform(Float64List.fromList([s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1]));
}

void _background(Canvas c) {
  c.drawRect(const Rect.fromLTWH(0, 0, _size, _size), Paint()..color = _bg);
  c.drawRect(
    const Rect.fromLTWH(0, 0, _size, _size),
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(_size / 2, _size * .56),
        _size * .55,
        [_bgGlow, _bg],
      ),
  );
}

void _flameArt(Canvas c, double height) {
  final flame = _flameAt(height);
  final bounds = flame.getBounds();
  c.drawPath(
    flame,
    Paint()
      ..color = _accent.withValues(alpha: .55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, height * .09),
  );
  c.drawPath(
    flame,
    Paint()..shader = ui.Gradient.linear(bounds.topCenter, bounds.bottomCenter, [_flameTop, _flameBottom]),
  );
  // Világos mag a láng alsó részében.
  final core = _flameAt(height * .42, dy: height * .26);
  c.drawPath(core, Paint()..color = _core.withValues(alpha: .9));
}

Future<void> _save(String name, void Function(Canvas c) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('assets/icon/$name')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate app icon images', () async {
    // Teljes ikon (régi Androidokhoz): háttér + láng.
    await _save('icon.png', (c) {
      _background(c);
      _flameArt(c, _size * .62);
    });
    // Adaptív ikon rétegei: a láng a 66/108-as biztonsági zónán belül marad.
    await _save('background.png', _background);
    await _save('foreground.png', (c) => _flameArt(c, _size * .44));
    // Egyszínű (témázott) ikon Android 13+-hoz.
    await _save('monochrome.png', (c) => c.drawPath(_flameAt(_size * .44), Paint()..color = const Color(0xFFFFFFFF)));
  });
}
