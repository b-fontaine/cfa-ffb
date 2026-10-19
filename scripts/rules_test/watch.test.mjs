// Flux temps réel de FB5b (`watch…` des dépôts) contre l'émulateur et les VRAIES règles : DEUX
// clients, l'un écrit, l'autre reçoit ; chaque écoute est une requête que le dépôt Dart ouvre pour
// son rôle (mêmes chemins, mêmes filtres que `FirestoreSdkAccess.watch…`).
//
// Ce que les doubles de Dart (`InMemoryDocumentStore`, faux Firestore) ne prouvent pas et que ce
// fichier prouve : la livraison réelle d'un lot en UN état, le refus d'une écoute par les règles
// (`permission-denied` sur le flux, qui se ferme), l'indépendance des flux, l'annulation, les
// métadonnées (`hasPendingWrites`, `fromCache`) et le rattrapage à la reconnexion.
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  Timestamp,
  collection,
  deleteDoc,
  disableNetwork,
  doc,
  enableNetwork,
  onSnapshot,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

import { createEnv, dbOf, put, remove, seed } from './support.mjs';

let env;
before(async () => {
  env = await createEnv();
});
after(async () => {
  await env?.cleanup();
});
beforeEach(async () => {
  await seed(env);
});

const C = 'clubs/c1';

const recordDoc = (extra = {}) => ({
  groupId: 'g1',
  seasonId: 'se1',
  date: '2026-10-03T00:00:00.000',
  audience: 'children',
  mainBlockId: 'a',
  recallBlockId: null,
  sheetId: null,
  tags: [],
  presentStudentIds: ['s1'],
  createdAt: serverTimestamp(),
  ...extra,
});

/**
 * Une écoute : tout ce qu'elle reçoit (états, erreurs), de quoi attendre une condition sans
 * dormir (`until`) et de quoi la fermer (`stop`).
 */
const listen = (reference, options = {}) => {
  const log = { events: [], errors: [], stopped: false };
  const waiters = [];
  const poke = () => waiters.slice().forEach((waiter) => waiter());
  log.stop = onSnapshot(
    reference,
    options,
    (snapshot) => {
      log.events.push(snapshot);
      poke();
    },
    (error) => {
      log.errors.push(error);
      poke();
    },
  );
  log.until = (predicate, label, timeoutMs = 8000) =>
    new Promise((resolve, reject) => {
      const check = () => {
        if (predicate(log)) {
          waiters.splice(waiters.indexOf(check), 1);
          clearTimeout(timer);
          resolve(log);
        }
      };
      const timer = setTimeout(() => {
        waiters.splice(waiters.indexOf(check), 1);
        reject(new Error(`délai dépassé : ${label} (${log.events.length} états, ${log.errors.length} erreurs)`));
      }, timeoutMs);
      waiters.push(check);
      check();
    });
  log.last = () => log.events.at(-1);
  log.ids = () => (log.last()?.docs ?? []).map((d) => d.id).sort();
  return log;
};

/** Laisse au serveur le temps de livrer ce qui serait à livrer (preuve qu'un événement n'arrive PAS). */
const quiet = (ms = 400) => new Promise((resolve) => setTimeout(resolve, ms));

const records = (actor, ...constraints) =>
  query(collection(dbOf(env, actor), `${C}/records`), ...constraints);
const byGroup = (actor, group) => records(actor, where('groupId', '==', group));

describe('deux clients : l\'un écrit, l\'autre reçoit', () => {
  test('un directeur suit les saisies du club, un enseignant en crée une : le directeur la reçoit', async () => {
    const reader = listen(collection(dbOf(env, 'director'), `${C}/records`));
    await reader.until((l) => l.events.length >= 1, 'état de départ');
    assert.deepEqual(reader.ids(), ['r-g1', 'r-g2']);

    await setDoc(doc(dbOf(env, 'teacherA'), `${C}/records/r-new`), recordDoc());

    await reader.until((l) => l.ids().includes('r-new'), 'la saisie de l\'autre appareil');
    assert.deepEqual(reader.ids(), ['r-g1', 'r-g2', 'r-new']);
    reader.stop();
  });

  test('un enseignant suit SON groupe (égalité sur groupId) : il reçoit la saisie de son groupe, jamais celle d\'un autre', async () => {
    const reader = listen(byGroup('teacherA', 'g1'));
    await reader.until((l) => l.events.length >= 1, 'état de départ');

    await setDoc(doc(dbOf(env, 'director'), `${C}/records/r-other`), recordDoc({ groupId: 'g2' }));
    await setDoc(doc(dbOf(env, 'director'), `${C}/records/r-mine`), recordDoc());

    await reader.until((l) => l.ids().includes('r-mine'), 'la saisie de son groupe');
    assert.deepEqual(reader.ids(), ['r-g1', 'r-mine']);
    reader.stop();
  });

  test('un document suivi : création, mise à jour, suppression arrivent dans l\'ordre', async () => {
    const reader = listen(doc(dbOf(env, 'director'), `${C}/students/s9`));
    await reader.until((l) => l.events.length >= 1, 'état de départ');
    assert.equal(reader.last().exists(), false);

    const writer = dbOf(env, 'director');
    await setDoc(doc(writer, `${C}/students/s9`), { firstName: 'Zoé', groupIds: ['g1'] });
    await reader.until((l) => l.last().exists(), 'création');
    await updateDoc(doc(writer, `${C}/students/s9`), { firstName: 'Zoé B.' });
    await reader.until((l) => l.last().data()?.firstName === 'Zoé B.', 'mise à jour');
    await deleteDoc(doc(writer, `${C}/students/s9`));
    await reader.until((l) => !l.last().exists(), 'suppression');
    reader.stop();
  });

  test('un lot de deux documents arrive en UN seul état (jamais à moitié appliqué)', async () => {
    const reader = listen(collection(dbOf(env, 'director'), `${C}/students`));
    await reader.until((l) => l.events.length >= 1, 'état de départ');
    const before = reader.events.length;

    const writer = dbOf(env, 'director');
    const batch = writeBatch(writer);
    batch.set(doc(writer, `${C}/students/s7`), { firstName: 'Sept', groupIds: ['g1'] });
    batch.set(doc(writer, `${C}/students/s8`), { firstName: 'Huit', groupIds: ['g1'] });
    await batch.commit();

    await reader.until((l) => l.ids().includes('s8'), 'les deux fiches');
    assert.equal(reader.events.length, before + 1, 'un seul état pour le lot');
    assert.ok(reader.ids().includes('s7') && reader.ids().includes('s8'));
    reader.stop();
  });

  test('une fiche qui entre dans le groupe d\'un enseignant arrive dans sa liste (array-contains-any), une qui en sort disparaît', async () => {
    const watched = () =>
      query(collection(dbOf(env, 'teacherA'), `${C}/students`), where('groupIds', 'array-contains-any', ['g1']));
    const reader = listen(watched());
    await reader.until((l) => l.events.length >= 1, 'état de départ');
    assert.deepEqual(reader.ids(), ['s1']);

    const dir = dbOf(env, 'director');
    await setDoc(doc(dir, `${C}/students/s5`), { firstName: 'Cinq', groupIds: ['g1'] });
    await reader.until((l) => l.ids().includes('s5'), 'arrivée dans le groupe');
    await updateDoc(doc(dir, `${C}/students/s5`), { groupIds: ['g2'] });
    await reader.until((l) => !l.ids().includes('s5'), 'sortie du groupe');
    reader.stop();
  });
});

describe('les règles s\'appliquent aux flux', () => {
  test('un enseignant qui suit le groupe d\'un autre reçoit permission-denied, et le flux est fermé', async () => {
    const refused = listen(byGroup('teacherB', 'g1'));

    await refused.until((l) => l.errors.length >= 1, 'le refus');
    assert.equal(refused.errors[0].code, 'permission-denied');
    assert.equal(refused.events.length, 0, 'aucun document n\'a été livré');

    await setDoc(doc(dbOf(env, 'director'), `${C}/records/r-late`), recordDoc());
    await quiet();
    assert.equal(refused.events.length, 0, 'un flux refusé reste fermé');
    assert.equal(refused.errors.length, 1, 'une seule erreur');
    refused.stop();
  });

  test('un parent ne suit pas les saisies (jamais lisibles par la famille), un parent suit les passages de SA fiche', async () => {
    const hidden = listen(byGroup('guardian', 'g1'));
    await hidden.until((l) => l.errors.length >= 1, 'le refus des saisies');
    assert.equal(hidden.errors[0].code, 'permission-denied');

    const own = listen(
      query(collection(dbOf(env, 'guardian'), `${C}/attempts`), where('studentId', '==', 's1')),
    );
    await own.until((l) => l.events.length >= 1, 'les passages de sa fiche');
    assert.deepEqual(own.ids(), ['a-g1']);
    own.stop();
  });

  test('un refus n\'arrête pas les autres flux du même client', async () => {
    const db = dbOf(env, 'teacherA');
    const refused = listen(query(collection(db, `${C}/records`), where('groupId', '==', 'g2')));
    const kept = listen(query(collection(db, `${C}/records`), where('groupId', '==', 'g1')));
    await refused.until((l) => l.errors.length >= 1, 'le refus');
    await kept.until((l) => l.events.length >= 1, 'le flux permis');

    await setDoc(doc(dbOf(env, 'director'), `${C}/records/r-live`), recordDoc());

    await kept.until((l) => l.ids().includes('r-live'), 'le flux permis continue');
    assert.equal(kept.errors.length, 0);
    kept.stop();
    refused.stop();
  });

  test('un membre retiré du club perd ses flux : le refus arrive sur l\'écoute ouverte', async () => {
    const reader = listen(byGroup('teacherA', 'g1'));
    await reader.until((l) => l.events.length >= 1, 'état de départ');

    await remove(env, `${C}/members/u-teacher-a`);
    await put(env, `${C}/records/r-after`, recordDoc());

    await reader.until((l) => l.errors.length >= 1, 'le refus après le retrait', 15000);
    assert.equal(reader.errors[0].code, 'permission-denied');
    reader.stop();
  });
});

describe('abonnement et métadonnées', () => {
  test('annuler un abonnement : plus aucun état n\'arrive', async () => {
    const reader = listen(collection(dbOf(env, 'director'), `${C}/records`));
    await reader.until((l) => l.events.length >= 1, 'état de départ');
    reader.stop();
    const received = reader.events.length;

    await setDoc(doc(dbOf(env, 'director'), `${C}/records/r-after-stop`), recordDoc());
    await quiet();

    assert.equal(reader.events.length, received);
  });

  test('une écriture locale non encore acceptée est marquée hasPendingWrites, puis confirmée', async () => {
    const db = dbOf(env, 'director');
    const reader = listen(doc(db, `${C}/students/s6`), { includeMetadataChanges: true });
    await reader.until((l) => l.events.length >= 1, 'état de départ');

    const written = setDoc(doc(db, `${C}/students/s6`), { firstName: 'Six', groupIds: ['g1'] });
    await reader.until((l) => l.events.some((e) => e.exists() && e.metadata.hasPendingWrites), 'écriture en attente');
    await written;
    await reader.until(
      (l) => l.events.some((e) => e.exists() && !e.metadata.hasPendingWrites && !e.metadata.fromCache),
      'écriture confirmée par le serveur',
    );
    reader.stop();
  });

  test('hors ligne le client garde son dernier état ; à la reconnexion il reçoit ce qu\'un autre a écrit', async () => {
    const db = dbOf(env, 'director');
    const reader = listen(collection(db, `${C}/records`), { includeMetadataChanges: true });
    await reader.until((l) => l.events.length >= 1 && !l.last().metadata.fromCache, 'état de départ confirmé');

    await disableNetwork(db);
    await setDoc(doc(dbOf(env, 'teacherA'), `${C}/records/r-while-offline`), recordDoc());
    await quiet(600);
    assert.ok(!reader.ids().includes('r-while-offline'), 'rien n\'arrive hors ligne');
    assert.equal(reader.last().metadata.fromCache, true, 'l\'état est dit venir du cache');

    await enableNetwork(db);
    await reader.until((l) => l.ids().includes('r-while-offline'), 'le rattrapage à la reconnexion');
    assert.equal(reader.last().metadata.fromCache, false);
    reader.stop();
  });

  test('une écriture faite hors ligne par le lecteur part à la reconnexion et l\'autre client la reçoit', async () => {
    const offline = dbOf(env, 'teacherA');
    const watcher = listen(byGroup('director', 'g1'));
    await watcher.until((l) => l.events.length >= 1, 'état de départ');

    await disableNetwork(offline);
    const pending = setDoc(doc(offline, `${C}/records/r-queued`), recordDoc());
    await quiet(600);
    assert.ok(!watcher.ids().includes('r-queued'), 'rien n\'arrive tant que l\'appareil est hors ligne');

    await enableNetwork(offline);
    await pending;
    await watcher.until((l) => l.ids().includes('r-queued'), 'l\'écriture mise en file');
    watcher.stop();
  });
});

describe('séance supprimée', () => {
  test('la suppression d\'un document suivi arrive aux autres clients', async () => {
    const reader = listen(byGroup('teacherA', 'g1'));
    await reader.until((l) => l.ids().includes('r-g1'), 'état de départ');

    await deleteDoc(doc(dbOf(env, 'director'), `${C}/records/r-g1`));

    await reader.until((l) => !l.ids().includes('r-g1'), 'la suppression');
    reader.stop();
  });
});

// La date du serveur pose l'ordre des passages : un flux la livre déjà posée.
describe('date du serveur', () => {
  test('un flux livre une écriture à date du serveur avec la date posée', async () => {
    const reader = listen(doc(dbOf(env, 'director'), `${C}/records/r-dated`), { includeMetadataChanges: false });
    await reader.until((l) => l.events.length >= 1, 'état de départ');

    await setDoc(doc(dbOf(env, 'teacherA'), `${C}/records/r-dated`), recordDoc());

    await reader.until((l) => l.last().exists() && l.last().data().createdAt instanceof Timestamp, 'date posée');
    reader.stop();
  });
});
