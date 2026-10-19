import 'package:billard_cfa/features/student_showcase/presentation/bloc/family_space_cubit.dart';
import 'package:billard_cfa/features/student_showcase/presentation/ui/family_space_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// L'espace d'un parent (« Mes enfants ») ou d'un élève (« Ma progression »),
/// en lecture seule : le parcours de l'élève choisi et les prochaines séances
/// de ses groupes, qui se mettent à jour sans rechargement. Aucune action
/// d'écriture. Le cubit est fourni par l'appelant.
class MyChildrenPage extends StatelessWidget {
  const MyChildrenPage({required this.studentOwnAccount, super.key});

  /// Vrai pour un élève (titre « Ma progression »), faux pour un parent.
  final bool studentOwnAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScrollPage(
      title: studentOwnAccount
          ? l10n.childrenTitleStudent
          : l10n.childrenTitleGuardian,
      children: [
        BlocBuilder<FamilySpaceCubit, FamilySpaceState>(
          builder: (context, state) => switch (state.status) {
            FamilyStatus.loading => const LoadingView(),
            FamilyStatus.failed => ErrorView(
              message: failureMessage(l10n, state.failure!),
              onRetry: context.read<FamilySpaceCubit>().load,
            ),
            FamilyStatus.denied => FamilyNotice(
              icon: Icons.lock_outline,
              title: l10n.familyDeniedTitle,
              body: l10n.familyDeniedBody,
            ),
            FamilyStatus.revoked => FamilyNotice(
              icon: Icons.link_off,
              title: l10n.familyRevokedTitle,
              body: l10n.familyRevokedBody(l10n.navMore),
            ),
            FamilyStatus.ready => FamilySpaceView(
              space: state.space!,
              selected: state.selected,
              stale: state.stale,
              onSelect: context.read<FamilySpaceCubit>().select,
            ),
          },
        ),
      ],
    );
  }
}
