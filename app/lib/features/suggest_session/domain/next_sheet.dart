import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'next_sheet.freezed.dart';

/// La séance suivante du catalogue proposée à un groupe (bilan de séance).
@freezed
abstract class NextSheet with _$NextSheet {
  const factory NextSheet({
    required Audience audience,

    /// Notion principale de la suggestion.
    required String mainBlockId,

    /// La séance du catalogue proposée ; `null` pour une notion sans séance
    /// (repli explicite, jamais de séance inventée).
    SheetSuggestion? sheet,
  }) = _NextSheet;
}
