import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';

/// Exécute [body] et traduit un [StoreFailure] du stock de documents en
/// [ServiceFailure] du domaine : les dépôts n'en laissent sortir aucun autre.
Future<T> guardStore<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on StoreFailure catch (failure) {
    throw ServiceFailure(switch (failure.code) {
      StoreFailureCode.unavailable => ServiceFailureCode.unavailable,
      StoreFailureCode.permissionDenied => ServiceFailureCode.denied,
      StoreFailureCode.unsupported => ServiceFailureCode.unsupported,
      StoreFailureCode.notFound ||
      StoreFailureCode.batchTooLarge ||
      StoreFailureCode.failedPrecondition ||
      StoreFailureCode.other => ServiceFailureCode.other,
    }, failure.detail);
  }
}
