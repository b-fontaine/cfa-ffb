// Le navigateur est la valeur par défaut, le mobile et le bureau (`dart:io`)
// n'ont pas de signal de réseau.
import 'package:billard_cfa/app/platform/connectivity_web.dart'
    if (dart.library.io) 'package:billard_cfa/app/platform/connectivity_native.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';

/// L'état du réseau de la plate-forme.
ConnectivityStatus createConnectivityStatus() =>
    createPlatformConnectivityStatus();
