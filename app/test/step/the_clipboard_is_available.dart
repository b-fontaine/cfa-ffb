import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texte copié par l'application dans le presse-papiers simulé.
String? copiedText;

/// Usage: the clipboard is available
///
/// Branche un presse-papiers simulé sur le canal de plateforme et l'efface.
Future<void> theClipboardIsAvailable(WidgetTester tester) async {
  copiedText = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text']! as String;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}
