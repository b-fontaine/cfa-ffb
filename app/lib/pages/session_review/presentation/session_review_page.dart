import 'dart:async';

import 'package:billard_cfa/features/plan_session/presentation/bloc/plan_next_session_cubit.dart';
import 'package:billard_cfa/features/review_session/domain/next_session_date.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/features/review_session/presentation/bloc/session_review_bloc.dart';
import 'package:billard_cfa/features/review_session/presentation/ui/session_review_view.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/next_sheet_cubit.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/next_sheet_card.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bilan de fin de séance : relu depuis la saisie persistée (il survit à un
/// rechargement et se partage par son adresse).
///
/// La page compose le bilan, la séance suivante du catalogue (règle du lot 8)
/// et « Planifier », qui crée une séance planifiée datée pour le groupe. Les
/// trois blocs sont fournis par la couche `app`, qui compose aussi la
/// navigation.
class SessionReviewPage extends StatelessWidget {
  const SessionReviewPage({
    required this.today,
    required this.onBackToday,
    required this.onOpenRecord,
    required this.onEnterResults,
    required this.onOpenStudent,
    required this.onOpenPlanner,
    required this.onOpenPlanned,
    super.key,
  });

  /// Jour courant (horloge injectée) : borne basse du choix de date.
  final DateTime Function() today;
  final VoidCallback onBackToday;
  final ValueChanged<SessionId> onOpenRecord;
  final ValueChanged<SessionId> onEnterResults;
  final ValueChanged<StudentId> onOpenStudent;

  /// Ouvre le planificateur, séance du catalogue (si connue) présélectionnée.
  final void Function(SheetId? sheet, GroupId group) onOpenPlanner;
  final VoidCallback onOpenPlanned;

  void _loadNext(BuildContext context, SessionReview review) {
    final group = review.group;
    if (group == null || review.outcome.isEmpty) return;
    unawaited(
      context.read<NextSheetCubit>().load(
        groupId: group.id,
        present: review.record.present,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<SessionReviewBloc, SessionReviewState>(
      listenWhen: (before, after) =>
          before.status != after.status &&
          after.status == SessionReviewStatus.ready,
      listener: (context, state) => _loadNext(context, state.review!),
      builder: (context, state) {
        switch (state.status) {
          case SessionReviewStatus.loading:
            return const Scaffold(body: LoadingView());
          case SessionReviewStatus.failure:
            final failure = state.failure;
            if (failure is NotFound) {
              return MissingPageView(onHome: onBackToday);
            }
            return Scaffold(
              body: ErrorView(
                message: failureMessage(
                  l10n,
                  failure ?? const NotFound('session', ''),
                ),
                onBack: onBackToday,
              ),
            );
          case SessionReviewStatus.ready:
            final review = state.review!;
            final id = review.record.id;
            return Scaffold(
              body: SafeArea(
                child: ResponsiveBody(
                  child: SingleChildScrollView(
                    child: SessionReviewView(
                      review: review,
                      onEnterResults: () => onEnterResults(id),
                      onOpenRecord: () => onOpenRecord(id),
                      onOpenStudent: onOpenStudent,
                      onBackToday: onBackToday,
                      tagsNotSaved: state.tagsFailure != null,
                      onTagsChanged: (tags) => context
                          .read<SessionReviewBloc>()
                          .add(SessionReviewEvent.tagsChanged(tags)),
                      next: review.group == null
                          ? null
                          : _NextSession(
                              review: review,
                              today: today,
                              onOpenPlanner: onOpenPlanner,
                              onOpenPlanned: onOpenPlanned,
                              onRetry: () => _loadNext(context, review),
                            ),
                    ),
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}

/// La séance suivante proposée et sa planification ; garde la date choisie.
class _NextSession extends StatefulWidget {
  const _NextSession({
    required this.review,
    required this.today,
    required this.onOpenPlanner,
    required this.onOpenPlanned,
    required this.onRetry,
  });

  final SessionReview review;
  final DateTime Function() today;
  final void Function(SheetId? sheet, GroupId group) onOpenPlanner;
  final VoidCallback onOpenPlanned;
  final VoidCallback onRetry;

  @override
  State<_NextSession> createState() => _NextSessionState();
}

class _NextSessionState extends State<_NextSession> {
  DateTime? _chosen;

  DateTime get _date => _chosen ?? widget.review.proposedDate;

  Future<void> _pickDate() async {
    final range = plannableDates(widget.today());
    final picked = await showDatePicker(
      context: context,
      initialDate: range.clamp(_date),
      firstDate: range.first,
      lastDate: range.last,
    );
    if (picked != null && mounted) setState(() => _chosen = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nextState = context.watch<NextSheetCubit>().state;
    final planState = context.watch<PlanNextSessionCubit>().state;
    switch (nextState.status) {
      case NextSheetStatus.loading:
        return const SizedBox.shrink();
      case NextSheetStatus.failure:
        return SectionCard(
          title: l10n.reviewNextTitle,
          emphasis: SectionEmphasis.medium,
          child: Row(
            children: [
              Expanded(child: Text(l10n.homeSectionFailed)),
              TextButton(
                onPressed: widget.onRetry,
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        );
      case NextSheetStatus.ready:
        final next = nextState.next!;
        final sheet = next.sheet;
        final existing = sheet == null
            ? null
            : widget.review.plannedFor(sheet.option.id);
        final (planning, date) = switch (planState) {
          PlanNextPlanned(:final session) => (
            NextSheetPlanning.planned,
            session.date,
          ),
          PlanNextPlanning() => (NextSheetPlanning.planning, _date),
          _ when existing != null => (NextSheetPlanning.already, existing.date),
          _ => (NextSheetPlanning.idle, _date),
        };
        return NextSheetCard(
          sheet: sheet,
          date: date,
          planning: planning,
          failureMessage: switch (planState) {
            PlanNextFailed(:final failure) => failureMessage(l10n, failure),
            _ => null,
          },
          onPlan: () {
            if (sheet == null) return;
            final option = sheet.option;
            unawaited(
              context.read<PlanNextSessionCubit>().plan(
                title: l10n.sheetFullTitle(
                  option.title,
                  option.part,
                  option.partCount,
                ),
                date: _date,
                sheetId: option.id,
                groupId: widget.review.record.groupId,
              ),
            );
          },
          onChangeDate: () => unawaited(_pickDate()),
          onOpenPlanner: () => widget.onOpenPlanner(
            sheet?.option.id,
            widget.review.record.groupId,
          ),
          onOpenPlanned: widget.onOpenPlanned,
        );
    }
  }
}
