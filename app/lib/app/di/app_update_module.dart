import 'package:billard_cfa/app/platform/app_update_source_factory.dart';
import 'package:billard_cfa/shared/lib/app_update_source.dart';
import 'package:injectable/injectable.dart';

/// Câblage de la mise à jour : une seule source pour toute l'application.
@module
abstract class AppUpdateModule {
  @singleton
  AppUpdateSource appUpdateSource() => createAppUpdateSource();
}
