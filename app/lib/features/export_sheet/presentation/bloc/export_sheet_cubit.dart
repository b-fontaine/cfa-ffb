import 'package:billard_cfa/features/export_sheet/domain/export_animator_sheet.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_results_sheets.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_source.dart';
import 'package:billard_cfa/features/export_sheet/domain/list_export_groups.dart';
import 'package:billard_cfa/features/export_sheet/domain/pdf_files.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'export_sheet_cubit.freezed.dart';

/// Le document à produire.
enum ExportKind { animator, results }

/// Où en est la préparation du document.
enum ExportStatus { loading, ready, notFound, failure }

/// Ce qui est arrivé à la dernière demande d'enregistrement ou d'impression.
enum ExportOutcome { none, saved, cancelled, saveFailed, printed, printFailed }

@freezed
abstract class ExportSheetState with _$ExportSheetState {
  const factory ExportSheetState({
    @Default(ExportStatus.loading) ExportStatus status,
    @Default(ExportKind.animator) ExportKind kind,
    @Default(Audience.children) Audience audience,

    /// Les groupes dont on peut imprimer les prénoms (fiches résultats).
    @Default(<GroupChoice>[]) List<GroupChoice> groups,
    GroupId? groupId,

    /// Imprimer les prénoms du groupe : jamais sans groupe choisi.
    @Default(false) bool includeNames,

    /// Le document prêt (l'aperçu et le fichier) ; l'ancien reste affiché
    /// pendant qu'un nouveau se prépare.
    ExportedDocument? exported,
    @Default(false) bool preparing,

    /// Page montrée par l'aperçu, à partir de 0.
    @Default(0) int page,
    @Default(ExportOutcome.none) ExportOutcome outcome,
    @Default(false) bool canPrint,
    Failure? failure,

    /// Échec de la liste des groupes : le choix du groupe reste vide, et
    /// l'écran le dit.
    Failure? groupsFailure,
  }) = _ExportSheetState;

  const ExportSheetState._();

  int get pageCount => exported?.document.pages.length ?? 0;
}

/// L'export PDF d'une séance du catalogue : feuille de l'animateur ou fiches
/// résultats, aperçu, enregistrement et impression (ADR 0021).
///
/// Le document est refait à chaque choix (public, document, groupe, prénoms) ;
/// le dernier choix gagne : la réponse d'un choix périmé est ignorée. Les
/// prénoms d'un groupe ne sont lus que pour les fiches résultats, quand un
/// groupe est choisi **et** que l'animateur l'a demandé.
@injectable
class ExportSheetCubit extends Cubit<ExportSheetState> {
  ExportSheetCubit(this._animator, this._results, this._listGroups, this._files)
    : super(ExportSheetState(canPrint: _files.canPrint));

  final ExportAnimatorSheet _animator;
  final ExportResultsSheets _results;
  final ListExportGroups _listGroups;
  final PdfFiles _files;

  ExportSource? _source;
  int _ticket = 0;

  /// Ouvre l'écran pour la source [source] et le public [audience].
  Future<void> started({
    required ExportSource source,
    required Audience audience,
  }) async {
    _source = source;
    emit(ExportSheetState(audience: audience, canPrint: _files.canPrint));
    final groups = await _listGroups();
    if (isClosed) return;
    switch (groups) {
      case Ok(:final value):
        emit(state.copyWith(groups: value));
      case Err(:final failure):
        emit(state.copyWith(groupsFailure: failure));
    }
    await _prepare();
  }

  /// Relance la préparation après un échec.
  Future<void> retried() => _prepare();

  Future<void> kindChanged(ExportKind kind) {
    if (kind == state.kind) return Future<void>.value();
    emit(state.copyWith(kind: kind));
    return _prepare();
  }

  Future<void> audienceChanged(Audience audience) {
    if (audience == state.audience) return Future<void>.value();
    emit(state.copyWith(audience: audience));
    return _prepare();
  }

  /// Choisit le groupe des prénoms ; `null` le retire, et les prénoms avec.
  Future<void> groupChosen(GroupId? id) {
    emit(
      state.copyWith(
        groupId: id,
        includeNames: id != null && state.includeNames,
      ),
    );
    return state.kind == ExportKind.results ? _prepare() : Future<void>.value();
  }

  /// Demande (ou retire) les prénoms du groupe choisi ; sans groupe, sans
  /// effet.
  Future<void> namesToggled({required bool value}) {
    if (state.groupId == null || value == state.includeNames) {
      return Future<void>.value();
    }
    emit(state.copyWith(includeNames: value));
    return state.kind == ExportKind.results ? _prepare() : Future<void>.value();
  }

  /// Montre la page [index] de l'aperçu, ramenée dans le document.
  void pageChanged(int index) {
    final last = state.pageCount - 1;
    if (last < 0) return;
    emit(state.copyWith(page: index.clamp(0, last)));
  }

  /// Propose d'enregistrer le PDF ; annuler n'écrit rien.
  Future<void> save() async {
    final exported = state.exported;
    if (exported == null) return;
    ExportOutcome outcome;
    try {
      final saved = await _files.save(
        fileName: exported.fileName,
        bytes: exported.bytes,
      );
      outcome = saved ? ExportOutcome.saved : ExportOutcome.cancelled;
    } on Exception {
      outcome = ExportOutcome.saveFailed;
    }
    if (!isClosed) emit(state.copyWith(outcome: outcome));
  }

  /// Envoie le PDF à l'impression de la plate-forme ; sans effet là où elle
  /// ne sait pas imprimer.
  Future<void> print() async {
    final exported = state.exported;
    if (exported == null || !_files.canPrint) return;
    ExportOutcome outcome;
    try {
      await _files.print(fileName: exported.fileName, bytes: exported.bytes);
      outcome = ExportOutcome.printed;
    } on Exception {
      outcome = ExportOutcome.printFailed;
    }
    if (!isClosed) emit(state.copyWith(outcome: outcome));
  }

  Future<void> _prepare() async {
    final source = _source;
    if (source == null) return;
    final ticket = ++_ticket;
    emit(
      state.copyWith(
        status: state.exported == null ? ExportStatus.loading : state.status,
        preparing: true,
        outcome: ExportOutcome.none,
        failure: null,
      ),
    );
    final result = await _build(source);
    if (isClosed || ticket != _ticket) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: ExportStatus.ready,
            exported: value,
            preparing: false,
            page: 0,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: failure is NotFound
                ? ExportStatus.notFound
                : ExportStatus.failure,
            exported: null,
            preparing: false,
            failure: failure,
          ),
        );
    }
  }

  Future<Result<ExportedDocument>> _build(ExportSource source) async {
    switch (state.kind) {
      case ExportKind.animator:
        return switch (await source.animator(state.audience)) {
          Ok(:final value) => await _animator(value),
          Err(:final failure) => Err(failure),
        };
      case ExportKind.results:
        final names = state.includeNames ? state.groupId : null;
        return switch (await source.results(state.audience)) {
          Ok(:final value) => await _results(
            ResultsSheetsRequest(
              title: value.title,
              fileName: value.fileName,
              series: value.series,
              columns: value.columns,
              labels: value.labels,
              groupId: names,
            ),
          ),
          Err(:final failure) => Err(failure),
        };
    }
  }
}
