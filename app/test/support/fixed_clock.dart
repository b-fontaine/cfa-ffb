import 'package:billard_cfa/shared/lib/clock.dart';

/// Horloge figée : la date du jour est connue des tests ; [advance] la fait
/// avancer à la demande.
class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);
}
