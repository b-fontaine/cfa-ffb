import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/relay_stream.dart';

/// Exécute [body] et traduit un [StoreFailure] du stock de documents en
/// [ServiceFailure] du domaine : les dépôts n'en laissent sortir aucun autre.
Future<T> guardStore<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on StoreFailure catch (failure) {
    throw serviceFailureOf(failure);
  }
}

/// Le pendant de [guardStore] pour un **flux** (`watch…` des dépôts) :
/// ouvre le flux avec [open] et traduit chaque [StoreFailure] en
/// [ServiceFailure], livré sur le flux (jamais levé à l'ouverture : un club
/// absent ou un accès refusé arrive là où l'abonné écoute). Comme toute écoute
/// Firestore, **une erreur ferme le flux** ; les autres flux ne sont pas
/// touchés.
Stream<T> guardStoreStream<T>(Stream<T> Function() open) {
  try {
    return relayStream<T, T>(
      open(),
      data: (event) => event,
      error: (error) => error is StoreFailure ? serviceFailureOf(error) : error,
    );
  } on StoreFailure catch (failure) {
    return Stream<T>.error(serviceFailureOf(failure));
  } on ServiceFailure catch (failure) {
    return Stream<T>.error(failure);
  }
}

/// L'échec du domaine qui correspond à [failure].
ServiceFailure serviceFailureOf(StoreFailure failure) =>
    ServiceFailure(switch (failure.code) {
      StoreFailureCode.unavailable => ServiceFailureCode.unavailable,
      StoreFailureCode.permissionDenied => ServiceFailureCode.denied,
      StoreFailureCode.unsupported => ServiceFailureCode.unsupported,
      StoreFailureCode.notFound ||
      StoreFailureCode.batchTooLarge ||
      StoreFailureCode.failedPrecondition ||
      StoreFailureCode.other => ServiceFailureCode.other,
    }, failure.detail);
