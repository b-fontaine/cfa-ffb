import 'package:billard_cfa/app/platform/no_app_update_source.dart';
import 'package:billard_cfa/shared/lib/app_update_source.dart';

/// Hors navigateur : aucune mise à jour proposée par l'application.
AppUpdateSource createPlatformAppUpdateSource() => const NoAppUpdateSource();
