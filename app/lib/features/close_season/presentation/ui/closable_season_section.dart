import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/closable_season_cubit.dart';
import 'package:billard_cfa/features/close_season/presentation/ui/closable_season_card.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// La carte « Clôturer la saison » de « Aujourd'hui », si une saison terminée
/// n'est pas close (le [ClosableSeasonCubit] est fourni par la couche app) ;
/// rien sinon.
class ClosableSeasonSection extends StatelessWidget {
  const ClosableSeasonSection({required this.onClose, super.key});

  final ValueChanged<SeasonId> onClose;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ClosableSeasonCubit, Season?>(
        builder: (context, season) => season == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ClosableSeasonCard(
                  season: season,
                  onClose: () => onClose(season.id),
                ),
              ),
      );
}
