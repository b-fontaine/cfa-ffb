import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';

/// Une séance de billard planifiée : un titre, un jour, un public et, au
/// choix, le groupe qui la suivra et la séance du catalogue suivie (ADR 0007).
@freezed
abstract class Session with _$Session {
  const factory Session({
    required String id,
    required String title,

    /// Jour de la séance (l'heure est ignorée).
    required DateTime date,
    required Audience audience,

    /// Groupe qui suivra la séance ; `null` : séance planifiée sans groupe
    /// (club sans groupe, public choisi à la main). Le public d'une séance
    /// avec groupe est celui du groupe (règle de `PlanSession`).
    GroupId? groupId,

    /// Séance du catalogue suivie (facultative : séance libre si `null`).
    /// Peut désigner une séance que le catalogue ne connaît plus : l'affichage
    /// le traite sans échouer.
    SheetId? sheetId,
  }) = _Session;

  const Session._();

  /// La durée est dérivée du public : 1h30 enfants, 2h adultes.
  Duration get duration => audience.sessionDuration;
}
