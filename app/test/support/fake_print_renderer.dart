import 'dart:convert';

import 'package:billard_cfa/features/export_sheet/domain/print_renderer.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_measure.dart';

import 'fixed_text_measure.dart';

/// Rendu de test : mesure à chasse fixe, « PDF » réduit à une ligne de texte
/// qui compte les pages ; les documents rendus sont conservés.
class FakePrintRenderer implements PrintRenderer {
  FakePrintRenderer({this.measure = const FixedTextMeasure()});

  final TextMeasure measure;

  /// Documents rendus, dans l'ordre.
  final List<PrintDocument> rendered = [];

  /// Simule un échec du rendu (levé par `render`, un `Failure` en pratique).
  Exception? renderError;

  /// Nombre d'ouvertures (chargement de la fonte).
  int opened = 0;

  @override
  Future<PrintSession> open() async {
    opened++;
    return _Session(this);
  }
}

class _Session implements PrintSession {
  _Session(this._renderer);

  final FakePrintRenderer _renderer;

  @override
  TextMeasure get measure => _renderer.measure;

  @override
  Future<List<int>> render(PrintDocument document) async {
    final error = _renderer.renderError;
    if (error != null) throw error;
    _renderer.rendered.add(document);
    return utf8.encode('PDF ${document.pages.length}');
  }
}
