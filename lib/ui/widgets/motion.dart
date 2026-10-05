import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

const _ease = Cubic(.2, .8, .2, 1);

/// Késleltetett belépő animáció 0→1 értékkel. Kikapcsolt animációknál
/// (beállítás vagy rendszerszintű „animációk csökkentése”) azonnal 1.
class Entrance extends ConsumerStatefulWidget {
  const Entrance({
    super.key,
    required this.builder,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
    this.curve = _ease,
    this.child,
  });

  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Widget? child;

  @override
  ConsumerState<Entrance> createState() => _EntranceState();
}

class _EntranceState extends ConsumerState<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _c = AnimationController(vsync: this, duration: total);
    final start = total.inMicroseconds == 0 ? 0.0 : widget.delay.inMicroseconds / total.inMicroseconds;
    _a = CurvedAnimation(parent: _c, curve: Interval(start, 1, curve: widget.curve));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = ref.read(animationsEnabledProvider) && !MediaQuery.disableAnimationsOf(context);
    if (!enabled) {
      _c.value = 1;
    } else if (_c.status == AnimationStatus.dismissed) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _a, child: widget.child, builder: (context, child) => widget.builder(context, _a.value, child));
  }
}

/// Felúszó és beúszó belépés (a dizájn `rise` animációja).
class Rise extends StatelessWidget {
  const Rise({super.key, required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Entrance(
      delay: Duration(milliseconds: delayMs),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
    );
  }
}

/// Alulról (vagy balról) kinövő sáv.
class Grow extends StatelessWidget {
  const Grow({super.key, required this.child, this.delayMs = 0, this.horizontal = false, this.durationMs = 800});

  final Widget child;
  final int delayMs;
  final int durationMs;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    return Entrance(
      delay: Duration(milliseconds: delayMs),
      duration: Duration(milliseconds: durationMs),
      child: child,
      builder: (context, t, child) => Transform(
        alignment: horizontal ? Alignment.centerLeft : Alignment.bottomCenter,
        transform: horizontal ? Matrix4.diagonal3Values(t, 1, 1) : Matrix4.diagonal3Values(1, t, 1),
        child: child,
      ),
    );
  }
}
