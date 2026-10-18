import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:injectable/injectable.dart';

/// Expose le suivi des envois sous son port : l'interface (FB5) lit
/// [SendStatus] ; l'unité de travail Firestore reçoit le [SendTracker]
/// concret qui l'alimente (même instance).
@module
abstract class SendStatusModule {
  @lazySingleton
  SendStatus sendStatus(SendTracker tracker) => tracker;
}
