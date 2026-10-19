// Le navigateur recharge sa page ; le mobile et le bureau (`dart:io`) n'ont
// rien à recharger.
import 'package:billard_cfa/app/platform/page_reload_web.dart'
    if (dart.library.io) 'package:billard_cfa/app/platform/page_reload_native.dart';

/// Remet l'application en service après l'effacement du cache local.
Future<void> reloadPage() => reloadPlatformPage();
