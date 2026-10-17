import 'package:billard_cfa/app/firebase_environment.dart';
import 'package:billard_cfa/app/firebase_gateway.dart';
import 'package:billard_cfa/app/firebase_startup.dart';
import 'package:billard_cfa/app/platform/firebase_auth_sdk.dart';
import 'package:billard_cfa/app/platform/firebase_sdk_gateway.dart';
import 'package:billard_cfa/app/session_startup.dart';
import 'package:billard_cfa/entities/account/data/auth_sdk.dart';
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
}
