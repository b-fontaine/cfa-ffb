// Le navigateur est la valeur par défaut, le mobile et le bureau (`dart:io`)
// n'ont aucune mise à jour à proposer.
import 'package:billard_cfa/app/platform/app_update_source_web.dart'
    if (dart.library.io) 'package:billard_cfa/app/platform/app_update_source_native.dart';
import 'package:billard_cfa/shared/lib/app_update_source.dart';

/// La source de mise à jour de la plate-forme : service worker du navigateur
/// sur le web, aucune ailleurs.
AppUpdateSource createAppUpdateSource() => createPlatformAppUpdateSource();
