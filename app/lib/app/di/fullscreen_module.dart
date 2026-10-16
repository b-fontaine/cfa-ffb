import 'package:billard_cfa/app/platform/fullscreen_controller_factory.dart';
import 'package:billard_cfa/shared/lib/fullscreen_controller.dart';
import 'package:injectable/injectable.dart';

/// Câblage du plein écran (ADR 0017) : un seul contrôleur pour toute
/// l'application, partagé par la présentation et le guide, de sorte que le
/// plein écran survit à la navigation entre les deux.
@module
abstract class FullscreenModule {
  @singleton
  FullscreenController fullscreenController() => createFullscreenController();
}
