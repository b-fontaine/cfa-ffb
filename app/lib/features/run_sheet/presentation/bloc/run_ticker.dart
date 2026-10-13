import 'package:injectable/injectable.dart';

/// Source des secondes du minuteur de séance (injectable : testable sans
/// attendre).
abstract interface class RunTicker {
  /// Un événement par seconde écoulée, tant que l'abonnement est actif.
  Stream<void> ticks();
}

@LazySingleton(as: RunTicker)
class PeriodicRunTicker implements RunTicker {
  @override
  Stream<void> ticks() => Stream<void>.periodic(const Duration(seconds: 1));
}
