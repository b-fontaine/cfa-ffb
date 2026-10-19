import 'dart:js_interop';

/// Recharge la page : le SDK web ne rouvre pas une instance Firestore
/// terminée.
Future<void> reloadPlatformPage() async => _location.reload();

@JS('location')
external _Location get _location;

extension type _Location._(JSObject _) implements JSObject {
  external void reload();
}
