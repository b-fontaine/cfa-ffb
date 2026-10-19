import 'package:billard_cfa/app/auth/auth_cubit.dart';
import 'package:billard_cfa/app/auth/auth_state.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reconstruit ce qui est posé sous lui quand le club actif, le rôle ou le
/// périmètre (groupes, fiches) dans ce club change (ADR 0024, décision 22 ;
/// FB5b) : les dépôts sont sans état et lisent la portée à chaque appel, donc
/// aucun état d'écran du club précédent (saisie en cours, liste affichée,
/// défilement) ne doit survivre à la bascule. Tant que le club, le rôle et le
/// périmètre restent les mêmes, l'état de l'interface est conservé.
///
/// Il **ne referme pas** les abonnements aux flux (`watch…`) des pages
/// ouvertes : il est posé dans `MaterialApp.builder` et le `Navigator` de
/// go_router, à clé globale, survit à sa reconstruction, donc les blocs des
/// pages ouvertes restent en vie. Les défenses réelles sont ailleurs :
/// `ClubStore` ferme ses flux épinglés dès que `ActiveClubScope.changes`
/// signale une autre portée, et `LiveReload` rouvre le flux après cette erreur,
/// sous la nouvelle portée et ses règles.
class ClubScoped extends StatelessWidget {
  const ClubScoped({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<AuthCubit, AuthState, String?>(
        selector: (state) => state is AuthReady ? _scopeKey(state.club) : null,
        builder: (context, scope) =>
            KeyedSubtree(key: ValueKey(scope), child: child),
      );

  /// Toute la portée que `ClubStore` épingle à l'ouverture d'un flux : club,
  /// rôle, groupes et fiches. Un périmètre qui change à rôle égal (groupes
  /// d'un enseignant, fiches d'un parent) ferme les flux épinglés
  /// (`scope-changed`) : l'interface doit alors repartir d'abonnements neufs.
  static String _scopeKey(ClubMembership club) => scopeKeyOf(
    club: club.clubId,
    role: club.role,
    groups: club.groupIds,
    students: club.studentIds,
  );
}
