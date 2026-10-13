import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';

/// Une séance de billard planifiée.
@freezed
abstract class Session with _$Session {
  const factory Session({
    required String id,
    required String title,
    required Audience audience,

    /// Séance du catalogue suivie (facultative : séance libre si `null`).
    /// Peut désigner une séance que le catalogue ne connaît plus : l'affichage
    /// le traite sans échouer.
    SheetId? sheetId,
  }) = _Session;

  const Session._();

  /// La durée est dérivée du public : 1h30 enfants, 2h adultes.
  Duration get duration => audience.sessionDuration;
}
