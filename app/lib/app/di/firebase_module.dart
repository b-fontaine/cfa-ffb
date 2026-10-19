import 'package:billard_cfa/app/firebase_environment.dart';
import 'package:billard_cfa/app/firebase_gateway.dart';
import 'package:billard_cfa/app/firebase_startup.dart';
import 'package:billard_cfa/app/platform/connectivity_factory.dart';
import 'package:billard_cfa/app/platform/firebase_auth_sdk.dart';
import 'package:billard_cfa/app/platform/firebase_sdk_gateway.dart';
import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/app/platform/firestore_local_data_cache.dart';
import 'package:billard_cfa/app/platform/firestore_pending_writes_probe.dart';
import 'package:billard_cfa/app/platform/page_reload_factory.dart';
import 'package:billard_cfa/app/session_startup.dart';
import 'package:billard_cfa/entities/account/data/auth_sdk.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/local_data_cache.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:injectable/injectable.dart';

/// Câblage de Firebase en production (l'environnement `test` n'y touche pas).
///
/// La cible est décidée une fois, au lancement : un build release qui demande
/// l'émulateur échoue ici, avant le premier écran.
@module
abstract class FirebaseModule {
  @Environment(Environment.prod)
  @singleton
  FirebaseEnvironment firebaseEnvironment() => FirebaseEnvironment.fromBuild();

  @Environment(Environment.prod)
  @singleton
  FirebaseGateway firebaseGateway() => FirebaseSdkGateway();

  @Environment(Environment.prod)
  @singleton
  FirebaseStartup firebaseStartup(
    FirebaseEnvironment environment,
    FirebaseGateway gateway,
  ) => FirebaseStartup(environment: environment, gateway: gateway);

  /// `AuthCubit` n'attend que ce port (voir `SessionStartup`).
  @Environment(Environment.prod)
  @singleton
  SessionStartup sessionStartup(FirebaseStartup startup) => startup;

  @Environment(Environment.prod)
  @singleton
  AuthSdk authSdk() => FirebaseAuthSdk();

  /// Le stock de documents : Firestore (les règles s'appliquent côté serveur).
  /// Le SDK n'est lu qu'à l'appel, une fois Firebase initialisé.
  @Environment(Environment.prod)
  @singleton
  DocumentStore documentStore() => FirestoreDocumentStore();

  /// Le cache local de Firestore (persistance hors ligne, C4) : vidé par
  /// `LocalDataGuard` ; sur le web, la page est rechargée ensuite.
  @Environment(Environment.prod)
  @singleton
  LocalDataCache localDataCache() =>
      FirestoreLocalDataCache(reload: reloadPage);

  /// La file d'écritures du SDK (garde de déconnexion, pastille).
  @Environment(Environment.prod)
  @singleton
  PendingWritesProbe pendingWritesProbe() => FirestorePendingWritesProbe();

  /// Indice de réseau de la pastille de synchronisation (navigateur seulement).
  @Environment(Environment.prod)
  @singleton
  ConnectivityStatus connectivityStatus() => createConnectivityStatus();
}
