// Le navigateur est la valeur par défaut, le mobile et le bureau (`dart:io`)
// prennent le contrôleur natif.
import 'package:billard_cfa/app/platform/fullscreen_controller_web.dart'
    if (dart.library.io) 'package:billard_cfa/app/platform/fullscreen_controller_native.dart';
import 'package:billard_cfa/shared/lib/fullscreen_controller.dart';

/// Le contrôleur de plein écran de la plate-forme : API Fullscreen du
/// navigateur sur le web, mode immersif sur Android et iOS (ADR 0017).
FullscreenController createFullscreenController() =>
    createPlatformFullscreenController();
