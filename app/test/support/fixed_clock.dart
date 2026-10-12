import 'package:billard_cfa/shared/lib/clock.dart';

/// Horloge figée : la date du jour est connue des tests.
class FixedClock implements Clock {
  FixedClock(this._now);

  final DateTime _now;

  @override
  DateTime now() => _now;
}
