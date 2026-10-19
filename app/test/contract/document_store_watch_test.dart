import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'document_store_watch_contract.dart';

void main() {
  documentStoreWatchContract(
    'en mémoire',
    () async => (store: InMemoryDocumentStore(), close: () async {}),
  );

  documentStoreWatchContract('Firestore (faux en mémoire)', () async {
    final firestore = FakeFirebaseFirestore();
    return (
      store: FirestoreDocumentStore(
        access: FirestoreSdkAccess(firestore: () => firestore),
      ),
      close: () async {},
    );
  });
}
