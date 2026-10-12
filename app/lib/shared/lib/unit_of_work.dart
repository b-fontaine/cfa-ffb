/// Unité de travail : les écritures faites dans `run` réussissent toutes ou
/// aucune (import de sauvegarde transactionnel).
///
/// Si `body` lève une exception, les écritures déjà faites dans l'unité sont
/// annulées et l'exception est propagée.
abstract interface class UnitOfWork {
  Future<T> run<T>(Future<T> Function() body);
}
