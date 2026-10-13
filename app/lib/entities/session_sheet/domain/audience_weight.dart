import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'audience_weight.freezed.dart';

/// Poids relatif d'un élément par public (base du minutage calculé).
///
/// Un poids absent signifie que l'élément n'est pas affiché pour ce public ;
/// il est affiché pour au moins un public, avec un poids entier d'au moins 1.
@freezed
abstract class AudienceWeight with _$AudienceWeight {
  factory AudienceWeight({int? children, int? adults}) = _AudienceWeight;

  AudienceWeight._() {
    final bad =
        (children != null && children! < 1) ||
        (adults != null && adults! < 1) ||
        (children == null && adults == null);
    if (bad) {
      throw const InvariantViolation(
        InvariantCode.invalidSheet,
        'poids : entier >= 1 pour au moins un public',
      );
    }
  }

  /// Poids pour [audience], ou `null` si l'élément n'y est pas affiché.
  int? of(Audience audience) => switch (audience) {
    Audience.children => children,
    Audience.adults => adults,
  };

  bool isShownFor(Audience audience) => of(audience) != null;
}
