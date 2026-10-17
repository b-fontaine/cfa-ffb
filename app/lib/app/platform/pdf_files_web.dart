import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:billard_cfa/app/platform/file_picker_pdf_files.dart';
import 'package:billard_cfa/features/export_sheet/domain/pdf_files.dart';

/// Le navigateur : téléchargement du fichier (`file_picker`) et impression du
/// PDF par une iframe cachée, sans dépendance ni ressource externe.
PdfFiles createPlatformPdfFiles() =>
    FilePickerPdfFiles(printer: _BrowserPdfPrinter(), savesByDownload: true);

@JS('document')
external _Document get _document;

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, _BlobOptions options);
}

@JS()
@anonymous
extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

@JS('URL')
extension type _Url._(JSObject _) implements JSObject {
  external static String createObjectURL(_Blob blob);
  external static void revokeObjectURL(String url);
}

extension type _Document._(JSObject _) implements JSObject {
  external _Element createElement(String tag);
  external _Element get body;
}

extension type _Element._(JSObject _) implements JSObject {
  external String get src;
  external set src(String value);
  external String get title;
  external set title(String value);
  external JSFunction? get onload;
  external set onload(JSFunction? value);
  external _Style get style;
  external _Window? get contentWindow;
  external JSObject appendChild(JSObject child);
  external void remove();
}

extension type _Style._(JSObject _) implements JSObject {
  external String get cssText;
  external set cssText(String value);
}

extension type _Window._(JSObject _) implements JSObject {
  external void focus();
  external void print();
}

/// Impression d'un PDF : une iframe cachée charge le fichier (URL d'objet,
/// locale), puis `print()` ouvre la boîte d'impression du navigateur. L'iframe
/// et l'URL sont retirées après un délai (la boîte peut rester ouverte).
class _BrowserPdfPrinter implements PdfPrinter {
  static const _cleanupDelay = Duration(minutes: 2);

  @override
  Future<void> print(Uint8List bytes, {required String title}) {
    final blob = _Blob(
      [bytes.toJS].toJS,
      _BlobOptions(type: 'application/pdf'),
    );
    final url = _Url.createObjectURL(blob);
    final frame = _document.createElement('iframe')
      ..title = title
      ..style.cssText =
          'position:fixed;right:0;bottom:0;width:0;height:0;border:0;'
      ..src = url;
    frame.onload = (() {
      final window = frame.contentWindow;
      window?.focus();
      window?.print();
    }).toJS;
    _document.body.appendChild(frame);
    Timer(_cleanupDelay, () {
      frame.remove();
      _Url.revokeObjectURL(url);
    });
    return Future<void>.value();
  }
}
