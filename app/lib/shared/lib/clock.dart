import 'package:injectable/injectable.dart';

/// Horloge injectable (horodatage de la persistance, testable).
abstract interface class Clock {
  DateTime now();
}

@LazySingleton(as: Clock)
class SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now();
}

/// Date du jour sans l'heure (minuit, fuseau local).
extension ClockToday on Clock {
  DateTime today() {
    final current = now();
    return DateTime(current.year, current.month, current.day);
  }
}
