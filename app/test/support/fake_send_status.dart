import 'package:billard_cfa/shared/lib/send_status.dart';

/// Le suivi des envois : seul « des écritures attendent » compte ici.
class FakeSendStatus implements SendStatus {
  bool unsent = false;

  @override
  Future<bool> hasUnsentWrites() async => unsent;

  @override
  int get pending => unsent ? 1 : 0;

  @override
  Future<void> refresh() async {}

  @override
  Stream<int> get pendingChanges => const Stream.empty();

  @override
  bool get hasFailure => false;

  @override
  void clearFailure() {}
}
