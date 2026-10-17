import 'package:billard_cfa/app/auth/auth_cubit.dart';
import 'package:billard_cfa/app/auth/auth_state.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reconstruit toute l'interface quand le club actif change (ADR 0024,
/// décision 22) : les dépôts sont sans état et lisent la portée à chaque
/// appel, donc aucun état d'écran du club précédent (saisie en cours, liste
/// affichée, défilement) ne doit survivre à la bascule. Tant que le club reste
/// le même, l'état de l'interface est conservé.
class ClubScoped extends StatelessWidget {
  const ClubScoped({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<AuthCubit, AuthState, ClubId?>(
        selector: (state) => state is AuthReady ? state.club.clubId : null,
        builder: (context, club) =>
            KeyedSubtree(key: ValueKey(club), child: child),
      );
}
