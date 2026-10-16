import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port : effacer physiquement un élève et tout ce qui le nomme, **sans**
/// ouvrir d'unité de travail (l'appelant en a déjà une, voir `CloseSeason`).
///
/// L'enchaînement des dépôts nominatifs n'existe qu'une fois, dans
/// `EraseStudent` ; la couche `app` relie ce port à lui (une feature
/// n'importe pas une autre feature). Parité vérifiée par
/// `erasure_parity_test`.
abstract interface class StudentEraser {
  Future<void> erase(StudentId studentId);
}
