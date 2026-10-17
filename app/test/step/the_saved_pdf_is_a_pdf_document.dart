import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the saved PDF is a PDF document
Future<void> theSavedPdfIsAPdfDocument(WidgetTester tester) async {
  final saved = UiWorld.pdfFiles.lastSaved;
  expect(saved, isNotNull, reason: 'aucun PDF enregistré');
  final bytes = saved!.bytes;
  expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  expect(
    ascii.decode(bytes.sublist(bytes.length - 6), allowInvalid: true),
    contains('%%EOF'),
  );
}
