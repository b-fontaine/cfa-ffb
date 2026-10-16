import 'package:billard_cfa/shared/lib/app_update_source.dart';

/// Aucune mise à jour à proposer : les boutiques (Android, iOS) et le
/// navigateur sans service worker gèrent les versions eux-mêmes.
class NoAppUpdateSource implements AppUpdateSource {
  const NoAppUpdateSource();

  @override
  bool get isAvailable => false;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();

  @override
  Future<void> apply() => Future<void>.value();
}
