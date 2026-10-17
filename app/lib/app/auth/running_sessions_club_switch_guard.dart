import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/shared/lib/club_switch_guard.dart';
import 'package:injectable/injectable.dart';

/// La bascule de club est interdite tant qu'une séance guidée est commencée
/// (étape, compteurs, minuteur ou saisie ouverte depuis le guide, que
/// `RunSheetSessions` garde en mémoire et sur l'appareil, ADR 0020) : changer
/// de club reconstruirait l'interface et perdrait ce qui est en cours.
///
/// Une saisie ouverte **depuis le guide** est portée par sa séance guidée ; une
/// saisie ouverte seule est un écran de route que la bascule, qui se fait
/// depuis « Plus », ne peut pas atteindre sans le quitter.
@LazySingleton(as: ClubSwitchGuard)
class RunningSessionsClubSwitchGuard implements ClubSwitchGuard {
  RunningSessionsClubSwitchGuard(this._sessions);

  final RunSheetSessions _sessions;

  @override
  bool get isBlocked => _sessions.snapshot().isNotEmpty;
}
