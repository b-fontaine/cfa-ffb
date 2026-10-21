import 'package:billard_cfa/features/backup_data/presentation/bloc/local_data_notice_cubit.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bandeau sobre : des données de l'appareil n'ont pas encore été exportées ou
/// importées dans le club (FB7c). Il porte l'action d'export ; [onAcknowledge]
/// (« J'ai importé mes données dans le club ») n'existe qu'avec un compte
/// connecté et une base lue, et c'est la seule façon de le faire disparaître.
class LocalDataBanner extends StatelessWidget {
  const LocalDataBanner({
    required this.inventory,
    required this.onExport,
    this.onAcknowledge,
    super.key,
  });

  final LocalDataInventory inventory;
  final VoidCallback onExport;
  final VoidCallback? onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = inventory.counts;
    final message = inventory.isReadable
        ? l10n.localDataBannerMessage(
            l10n.backupStudents(counts.students),
            l10n.backupAttempts(counts.attempts),
          )
        : l10n.localDataBannerUnknown;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppAlert(level: AlertLevel.attention, message: message),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton.tonal(
                onPressed: onExport,
                child: Text(l10n.localDataBannerExport),
              ),
              if (!inventory.isReadable)
                // Rien n'est lisible : on ne peut pas confirmer un import,
                // on propose de relire (l'écran d'export relit la base).
                TextButton(
                  onPressed: onExport,
                  child: Text(l10n.localExportRetry),
                )
              else if (onAcknowledge != null)
                TextButton(
                  onPressed: onAcknowledge,
                  child: Text(l10n.localDataBannerDone),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pose le bandeau au-dessus d'un écran tant qu'il y a des données locales à
/// protéger. La place du contenu ne change pas quand le bandeau apparaît ou
/// disparaît (l'écran ne se reconstruit pas). [safeArea] : l'écran n'est pas
/// dans le cadre de navigation, le bandeau passe sous l'encoche et le contenu
/// n'en réserve plus.
class LocalDataNoticeFrame extends StatelessWidget {
  const LocalDataNoticeFrame({
    required this.cubit,
    required this.onExport,
    required this.child,
    this.onAcknowledge,
    this.safeArea = false,
    super.key,
  });

  final LocalDataNoticeCubit cubit;
  final VoidCallback onExport;

  /// Absent hors d'une session ouverte. Rend `false` quand le repère est
  /// refusé (écritures pas encore envoyées au club).
  final Future<bool> Function()? onAcknowledge;
  final bool safeArea;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalDataNoticeCubit, LocalDataNoticeState>(
      bloc: cubit,
      builder: (context, state) {
        final visible = state.visible;
        final banner = !visible
            ? const SizedBox.shrink()
            : LocalDataBanner(
                inventory: state.inventory,
                onExport: onExport,
                onAcknowledge: onAcknowledge == null
                    ? null
                    : () => _confirm(context),
              );
        return Column(
          children: [
            SafeArea(top: safeArea && visible, bottom: false, child: banner),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: safeArea && visible,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.localDataDoneTitle),
        content: Text(l10n.localDataDoneBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.localDataDoneConfirm),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return;
    final done = await onAcknowledge!();
    if (done || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.localDataDoneUnsentTitle),
        content: Text(l10n.localDataDoneUnsentBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.localDataDoneUnsentOk),
          ),
        ],
      ),
    );
  }
}
