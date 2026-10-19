import 'package:billard_cfa/shared/lib/connectivity_status.dart';

/// Hors navigateur : aucun signal fiable sans plugin de réseau (pas de
/// décision pour en ajouter un) ; toujours « en ligne », voir
/// [ConnectivityStatus].
ConnectivityStatus createPlatformConnectivityStatus() => const AlwaysOnline();
