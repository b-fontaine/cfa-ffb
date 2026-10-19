// Dépôts Firestore de FB4, partie 2 (saisons, séances planifiées, séances données, archives) : les
// MÊMES opérations que ceux de l'application, avec les mêmes chemins, champs et requêtes, contre
// l'émulateur et les VRAIES règles, jouées dans chaque rôle.
//
// Les formes ci-dessous sont COPIÉES des tests Dart (`firestore_planning_repositories_test`,
// « writes exactly the fields the rules allow »). Un refus attendu vient des règles, jamais d'une
// requête mal formée : chaque requête interdite à un rôle est celle que le dépôt Dart NE fait PAS
// pour ce rôle (il l'évite, le test prouve qu'elle serait refusée).
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  Timestamp,
  arrayRemove,
  arrayUnion,
  deleteField,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

import { allowed, createEnv, dbOf, seed } from './support.mjs';

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
const merge = { merge: true };

const seasonDoc = (extra = {}) => ({
  label: '2026-2027',
  startDate: '2026-09-01T00:00:00.000',
  endDate: '2027-06-30T00:00:00.000',
  closedOn: null,
  createdAt: serverTimestamp(),
  ...extra,
});
const sessionDoc = (extra = {}) => ({
  groupId: 'g1',
  seasonId: 'se1',
  title: 'Posture',
  date: '2026-10-05T00:00:00.000',
  audience: 'children',
  sheetId: 'posture-1',
  createdAt: serverTimestamp(),
  ...extra,
});
const recordDoc = (extra = {}) => ({
  groupId: 'g1',
  seasonId: 'se1',
  date: '2026-10-03T00:00:00.000',
  audience: 'children',
  mainBlockId: 'a',
  recallBlockId: null,
  sheetId: 'posture-1',
  tags: ['gameAppreciated', 'toRedo'],
  presentStudentIds: ['s1'],
  createdAt: serverTimestamp(),
  ...extra,
});
const summaryDoc = (extra = {}) => ({
  seasonId: 'se1',
  public: 'children',
  sessionCount: 2,
  presenceCount: 5,
  possiblePresenceCount: 6,
  studentCount: 3,
  attemptCount: 4,
  createdAt: serverTimestamp(),
  ...extra,
});
const exerciseDoc = (extra = {}) => ({
  seasonId: 'se1',
  public: 'children',
  blockId: 'a',
  exerciseNumber: 1,
  studentCount: 3,
  attemptCount: 4,
  potted: 6,
  total: 20,
  createdAt: serverTimestamp(),
  ...extra,
});

const list = (actor, path, ...constraints) =>
  allowed(() => getDocs(query(collection(dbOf(env, actor), `${C}/${path}`), ...constraints)));
const byGroup = (actor, path, group) => list(actor, path, where('groupId', '==', group));

describe('saisons : clubs/{c}/seasons/{id}', () => {
  test('le directeur crée (fusion, date du serveur) puis met à jour (clôture), tout membre lit', async () => {
    const dir = dbOf(env, 'director');
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/seasons/se2`), seasonDoc(), merge)), true, 'création');
    const { createdAt, ...update } = seasonDoc({ closedOn: '2027-06-30T00:00:00.000' });
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/seasons/se2`), update, merge)), true, 'clôture');
    for (const actor of ['teacherA', 'guardian', 'student', 'director']) {
      assert.equal(await list(actor, 'seasons'), true, `liste : ${actor}`);
      assert.equal(await allowed(() => getDoc(doc(dbOf(env, actor), `${C}/seasons/se1`))), true, `get : ${actor}`);
    }
  });

  test('un enseignant, un parent, un élève et un autre club n\'écrivent pas', async () => {
    for (const actor of ['teacherA', 'guardian', 'student', 'directorOther', 'invited']) {
      assert.equal(await allowed(() => setDoc(doc(dbOf(env, actor), `${C}/seasons/se2`), seasonDoc(), merge)), false, actor);
      assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, actor), `${C}/seasons/se1`))), false, actor);
    }
    assert.equal(await list('invited', 'seasons'), false, 'un invité sans member ne lit pas');
  });

  test('le libellé a au plus 80 caractères, et aucun champ hors liste', async () => {
    const dir = dbOf(env, 'director');
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/seasons/se2`), seasonDoc({ label: 'a'.repeat(80) }), merge)), true);
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/seasons/se2`), seasonDoc({ label: 'a'.repeat(81) }), merge)), false);
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/seasons/se2`), seasonDoc({ note: 'x' }), merge)), false);
  });

  test('le directeur supprime (suppression physique)', async () => {
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'director'), `${C}/seasons/se1`))), true);
  });
});

describe('séances planifiées : clubs/{c}/sessions/{id}', () => {
  test('un enseignant écrit dans SON groupe, pas dans celui d\'un autre ; le directeur partout', async () => {
    const a = dbOf(env, 'teacherA');
    assert.equal(await allowed(() => setDoc(doc(a, `${C}/sessions/p1`), sessionDoc(), merge)), true, 'g1 par son enseignant');
    assert.equal(await allowed(() => setDoc(doc(a, `${C}/sessions/p2`), sessionDoc({ groupId: 'g2' }), merge)), false, 'g2');
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'director'), `${C}/sessions/p2`), sessionDoc({ groupId: 'g2' }), merge)), true);
    for (const actor of ['guardian', 'student', 'teacherB', 'directorOther']) {
      assert.equal(await allowed(() => setDoc(doc(dbOf(env, actor), `${C}/sessions/p3`), sessionDoc(), merge)), false, actor);
    }
  });

  test('la lecture suit le groupe : staff, famille de ce groupe, jamais l\'autre', async () => {
    for (const [actor, group, ok] of [
      ['teacherA', 'g1', true], ['teacherA', 'g2', false],
      ['guardian', 'g1', true], ['guardian', 'g2', false],
      ['student', 'g1', true], ['student', 'g2', false],
      ['guardian2', 'g2', true], ['director', 'g2', true],
    ]) {
      assert.equal(await byGroup(actor, 'sessions', group), ok, `${actor} ${group}`);
    }
    assert.equal(await list('teacherA', 'sessions'), false, 'sans filtre par groupe, refusé pour un enseignant');
    assert.equal(await list('director', 'sessions'), true, 'le directeur liste le club');
  });

  test('un enseignant lit une séance ABSENTE de son club (lecture avant écriture), pas la famille', async () => {
    for (const actor of ['teacherA', 'teacherB', 'director']) {
      assert.equal(await allowed(() => getDoc(doc(dbOf(env, actor), `${C}/sessions/absent`))), true, actor);
    }
    for (const actor of ['guardian', 'student', 'directorOther', 'invited', 'teacherC2']) {
      assert.equal(await allowed(() => getDoc(doc(dbOf(env, actor), `${C}/sessions/absent`))), false, actor);
    }
  });

  test('ATTAQUE : lire une séance ABSENTE à identifiant déterministe d\'un autre groupe est refusé (oracle d\'existence)', async () => {
    const probe = (actor, id) => allowed(() => getDoc(doc(dbOf(env, actor), `${C}/sessions/${id}`)));
    assert.equal(await probe('teacherA', 'g1_20261003_posture-1'), true, 'son groupe');
    assert.equal(await probe('teacherB', 'g1_20261003_posture-1'), false, 'le groupe d\'un autre');
    assert.equal(await probe('teacherA', 'g2_20261003_posture-1'), false, 'le groupe d\'un autre (sens inverse)');
    assert.equal(await probe('teacherA', 'g3_20261003_posture-1'), false, 'un groupe qui n\'existe pas');
    assert.equal(await probe('director', 'g2_20261003_posture-1'), true, 'un gestionnaire lit tout');
    assert.equal(await probe('teacherA', '6f1d3c2e-9a4b-4c1d-8e5f-0a1b2c3d4e5f'), true, 'identifiant aléatoire : rien à deviner');
  });

  test('une séance sans groupe (que le dépôt Dart refuse en amont) serait refusée par les règles', async () => {
    const { groupId, ...bare } = sessionDoc();
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'director'), `${C}/sessions/p1`), bare, merge)), false);
  });

  test('titre de 120 caractères au plus, séance du catalogue facultative, champ inconnu refusé', async () => {
    const dir = dbOf(env, 'director');
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/sessions/p1`), sessionDoc({ title: 'a'.repeat(120) }), merge)), true);
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/sessions/p1`), sessionDoc({ title: 'a'.repeat(121) }), merge)), false);
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/sessions/p1`), sessionDoc({ sheetId: null }), merge)), true);
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/sessions/p1`), sessionDoc({ note: 'x' }), merge)), false);
  });

  test('la suppression : le directeur et l\'enseignant du groupe, pas la famille', async () => {
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'guardian'), `${C}/sessions/ss-g1`))), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'teacherB'), `${C}/sessions/ss-g1`))), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'teacherA'), `${C}/sessions/ss-g1`))), true);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'director'), `${C}/sessions/ss-g2`))), true);
  });

  test('le groupe et la saison d\'une séance ne changent pas après la création', async () => {
    const dir = dbOf(env, 'director');
    await setDoc(doc(dir, `${C}/sessions/p1`), sessionDoc(), merge);
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/sessions/p1`), { groupId: 'g2' }, merge)), false, 'groupe');
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/sessions/p1`), { seasonId: 'se2' }, merge)), false, 'saison');
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/sessions/p1`), { title: 'Autre' }, merge)), true, 'titre');
  });
});

describe('séances données : clubs/{c}/records/{id}', () => {
  test('un enseignant écrit dans son groupe (id libre ou déterministe), le directeur partout', async () => {
    const a = dbOf(env, 'teacherA');
    assert.equal(await allowed(() => setDoc(doc(a, `${C}/records/x1`), recordDoc(), merge)), true, 'UUID');
    assert.equal(await allowed(() => setDoc(doc(a, `${C}/records/g1_20261005_posture-1`), recordDoc(), merge)), true, 'déterministe');
    assert.equal(await allowed(() => setDoc(doc(a, `${C}/records/x2`), recordDoc({ groupId: 'g2' }), merge)), false, 'g2');
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'director'), `${C}/records/x2`), recordDoc({ groupId: 'g2' }), merge)), true);
    for (const actor of ['guardian', 'student', 'teacherB', 'directorOther', 'invited']) {
      assert.equal(await allowed(() => setDoc(doc(dbOf(env, actor), `${C}/records/x3`), recordDoc(), merge)), false, actor);
    }
  });

  test('un parent et un élève ne lisent AUCUNE saisie (elle expose les camarades présents)', async () => {
    for (const actor of ['guardian', 'student', 'guardian2']) {
      assert.equal(await byGroup(actor, 'records', 'g1'), false, `${actor} par groupe`);
      assert.equal(await list(actor, 'records', where('presentStudentIds', 'array-contains-any', ['s1'])), false, `${actor} par présence`);
      assert.equal(await allowed(() => getDoc(doc(dbOf(env, actor), `${C}/records/r-g1`))), false, `${actor} get`);
    }
  });

  test('un enseignant interroge ses groupes un à un ; par élève seul, la requête serait refusée', async () => {
    assert.equal(await byGroup('teacherA', 'records', 'g1'), true);
    assert.equal(await byGroup('teacherA', 'records', 'g2'), false);
    assert.equal(await list('teacherA', 'records', where('presentStudentIds', 'array-contains-any', ['s1'])), false);
    assert.equal(await list('teacherA', 'records'), false, 'sans filtre');
  });

  test('le directeur liste le club et interroge par présence (array-contains-any, sans index composite)', async () => {
    assert.equal(await list('director', 'records'), true);
    assert.equal(await list('director', 'records', where('presentStudentIds', 'array-contains-any', ['s1'])), true);
    assert.equal(await byGroup('director', 'records', 'g2'), true);
  });

  test('étiquettes : la liste fermée, huit au plus ; aucun texte libre', async () => {
    const dir = dbOf(env, 'director');
    const set = (extra) => allowed(() => setDoc(doc(dir, `${C}/records/x1`), recordDoc(extra), merge));
    assert.equal(await set({ tags: [] }), true, 'aucune');
    assert.equal(await set({ tags: ['toRedo', 'free text'] }), false, 'texte libre');
    assert.equal(await set({ tags: ['x'] }), false, 'code inconnu');
  });

  test('60 élèves présents au plus, une borne que le domaine connaît', async () => {
    const dir = dbOf(env, 'director');
    const ids = (n) => Array.from({ length: n }, (_, i) => `s${i}`);
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/records/x1`), recordDoc({ presentStudentIds: ids(60) }), merge)), true);
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/records/x1`), recordDoc({ presentStudentIds: ids(61) }), merge)), false);
  });

  test('la date de création d\'une saisie est figée : une mise à jour ne la réécrit pas', async () => {
    const dir = dbOf(env, 'director');
    await setDoc(doc(dir, `${C}/records/x1`), recordDoc(), merge);
    const { createdAt, ...withoutCreation } = recordDoc();
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/records/x1`), recordDoc(), merge)), false, 'réécrite');
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/records/x1`), withoutCreation, merge)), true, 'conservée');
    assert.equal(await allowed(() => updateDoc(doc(dir, `${C}/records/x1`), { createdAt: null })), false, 'effacée');
  });

  // `FirestoreDocumentStore.createIfAbsent` puis, si le document existe, `ArrayUnion` seul : les
  // opérations de `FirestoreSessionRecordRepository.open`, jouées avec le SDK web.
  const openSitting = async (db, id, present) => {
    const ref = doc(db, `${C}/records/${id}`);
    const created = await runTransaction(db, async (tx) => {
      if ((await tx.get(ref)).exists()) return false;
      tx.set(ref, recordDoc({ presentStudentIds: present }));
      return true;
    });
    if (!created) await updateDoc(ref, { presentStudentIds: arrayUnion(...present) });
  };

  test('deux appareils ouvrent la même saisie en même temps : les deux réussissent et convergent', async () => {
    const a = dbOf(env, 'teacherA');
    const id = 'g1_20261003_posture-1';
    await Promise.all([openSitting(a, id, ['s1']), openSitting(dbOf(env, 'teacherA'), id, ['s2', 's3'])]);
    const stored = (await getDoc(doc(a, `${C}/records/${id}`))).data();
    assert.deepEqual([...stored.presentStudentIds].sort(), ['s1', 's2', 's3']);
    assert.ok(stored.createdAt, 'la date de création est posée par la création');
  });

  test('la reprise d\'une saisie REMPLACE les présents (un élève coché par erreur se décoche), sans date ni étiquettes', async () => {
    const a = dbOf(env, 'teacherA');
    const id = 'g1_20261003_posture-1';
    await openSitting(a, id, ['s1', 's2']);
    // `FirestoreSessionRecordRepository.resume` : `encodeResumed` = tout sauf `createdAt` (absent de l'encodage) et `tags`.
    const { createdAt, tags, ...resumed } = recordDoc({ presentStudentIds: ['s1'], mainBlockId: 'b' });
    assert.equal(await allowed(() => updateDoc(doc(a, `${C}/records/${id}`), resumed)), true, 'reprise');
    const stored = (await getDoc(doc(a, `${C}/records/${id}`))).data();
    assert.deepEqual(stored.presentStudentIds, ['s1']);
    assert.equal(stored.mainBlockId, 'b');
  });

  test('createdAt : exigé et daté du serveur à la création, jamais dans le diff d\'une mise à jour', async () => {
    const a = dbOf(env, 'teacherA');
    const { createdAt, ...bare } = recordDoc();
    assert.equal(await allowed(() => setDoc(doc(a, `${C}/records/n1`), bare)), false, 'création sans date');
    assert.equal(await allowed(() => setDoc(doc(a, `${C}/records/n1`), recordDoc({ createdAt: Timestamp.fromMillis(1000) }))), false, 'date du client');
    assert.equal(await allowed(() => setDoc(doc(a, `${C}/records/n1`), recordDoc())), true, 'date du serveur');
    const before = (await getDoc(doc(a, `${C}/records/n1`))).data().createdAt;
    const forger = dbOf(env, 'director');
    for (const [label, change] of [
      ['serveur', serverTimestamp()],
      ['passé', Timestamp.fromMillis(1000)],
      ['effacée', deleteField()],
    ]) {
      assert.equal(await allowed(() => updateDoc(doc(forger, `${C}/records/n1`), { createdAt: change })), false, label);
      assert.equal(await allowed(() => setDoc(doc(forger, `${C}/records/n1`), { createdAt: change }, merge)), false, `fusion ${label}`);
    }
    assert.equal(await allowed(() => updateDoc(doc(a, `${C}/records/n1`), { presentStudentIds: arrayUnion('s9') })), true, 'union seule');
    assert.deepEqual((await getDoc(doc(a, `${C}/records/n1`))).data().createdAt, before);
  });

  // FB5 : `FirestoreSessionRecordRepository._create` crée une saisie LIBRE par une écriture simple
  // (fusion, `createdAt` du serveur) quand le cache local ne la connaît pas, sans lire le serveur : hors
  // ligne c'est la seule voie. Si le document existait en fait sur le serveur, c'est une mise à jour
  // qui change `createdAt` : les règles la refusent, la date d'origine reste.
  test('création à l\'aveugle d\'une saisie libre déjà présente : refusée, la date d\'origine reste', async () => {
    const a = dbOf(env, 'teacherA');
    assert.equal(await allowed(() => setDoc(doc(a, `${C}/records/n2`), recordDoc(), merge)), true, 'création à l\'aveugle');
    const before = (await getDoc(doc(a, `${C}/records/n2`))).data().createdAt;
    assert.equal(
      await allowed(() => setDoc(doc(dbOf(env, 'director'), `${C}/records/n2`), recordDoc({ presentStudentIds: ['s9'] }), merge)),
      false,
      'deuxième création à l\'aveugle',
    );
    const stored = (await getDoc(doc(a, `${C}/records/n2`))).data();
    assert.deepEqual(stored.createdAt, before);
    assert.equal(stored.presentStudentIds.includes('s9'), false);
  });

  test('un enseignant lit une saisie ABSENTE de son club (lecture avant création), pas la famille', async () => {
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'teacherA'), `${C}/records/absent`))), true);
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'teacherB'), `${C}/records/absent`))), true);
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'director'), `${C}/records/absent`))), true);
    for (const actor of ['guardian', 'student', 'directorOther', 'invited', 'teacherC2']) {
      assert.equal(await allowed(() => getDoc(doc(dbOf(env, actor), `${C}/records/absent`))), false, actor);
    }
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'teacherB'), `${C}/records/r-g1`))), false, 'existante, autre groupe');
  });

  test('ATTAQUE : lire une saisie ABSENTE à identifiant déterministe d\'un autre groupe est refusé (oracle d\'existence)', async () => {
    const probe = (actor, id) => allowed(() => getDoc(doc(dbOf(env, actor), `${C}/records/${id}`)));
    assert.equal(await probe('teacherA', 'g1_20261003_posture-1'), true, 'son groupe');
    assert.equal(await probe('teacherB', 'g1_20261003_posture-1'), false, 'le groupe d\'un autre : « g1 a-t-il tenu une séance ? »');
    assert.equal(await probe('teacherA', 'g2_20261003_posture-1'), false, 'sens inverse');
    assert.equal(await probe('teacherA', 'g3_20261003_posture-1'), false, 'un groupe qui n\'existe pas');
    assert.equal(await probe('director', 'g2_20261003_posture-1'), true, 'un gestionnaire lit tout');
    for (const actor of ['guardian', 'student', 'directorOther', 'invited', 'teacherC2']) {
      assert.equal(await probe(actor, 'g1_20261003_posture-1'), false, actor);
    }
    assert.equal(await probe('teacherA', '6f1d3c2e-9a4b-4c1d-8e5f-0a1b2c3d4e5f'), true, 'saisie libre (UUID) : rien à deviner');
  });

  test('l\'ouverture concurrente d\'une saisie du groupe reste permise à son enseignant (transaction : lecture absente puis création)', async () => {
    const id = `${C}/records/g1_20261003_posture-1`;
    const open = (db, presents) => allowed(() => runTransaction(db, async (tx) => {
      const snap = await tx.get(doc(db, id));
      if (!snap.exists()) tx.set(doc(db, id), recordDoc({ presentStudentIds: presents }));
    }));
    assert.equal(await open(dbOf(env, 'teacherA'), ['s1']), true, 'création par son enseignant');
    assert.equal(await open(dbOf(env, 'teacherA'), ['s2']), true, 'second appareil : lecture d\'un document présent');
    assert.equal(await open(dbOf(env, 'teacherB'), ['s9']), false, 'l\'enseignant d\'un autre groupe ne le peut pas');
  });

  test('setTags (étiquettes seules) et eraseStudent (arrayRemove) passent en mise à jour', async () => {
    const a = dbOf(env, 'teacherA');
    await setDoc(doc(a, `${C}/records/x1`), recordDoc({ presentStudentIds: ['s1', 's9'] }), merge);
    assert.equal(await allowed(() => updateDoc(doc(a, `${C}/records/x1`), { tags: ['tooLong'] })), true, 'setTags');
    const dir = dbOf(env, 'director');
    assert.equal(await allowed(() => updateDoc(doc(dir, `${C}/records/x1`), { presentStudentIds: arrayRemove('s1') })), true, 'eraseStudent');
    assert.deepEqual((await getDoc(doc(dir, `${C}/records/x1`))).data().presentStudentIds, ['s9']);
  });

  test('le groupe d\'une saisie ne change pas ; un champ inconnu est refusé', async () => {
    const dir = dbOf(env, 'director');
    await setDoc(doc(dir, `${C}/records/x1`), recordDoc(), merge);
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/records/x1`), { groupId: 'g2' }, merge)), false);
    assert.equal(await allowed(() => setDoc(doc(dir, `${C}/records/x1`), { note: 'x' }, merge)), false);
  });

  test('la suppression : le directeur et l\'enseignant du groupe', async () => {
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'teacherB'), `${C}/records/r-g1`))), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'guardian'), `${C}/records/r-g1`))), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'teacherA'), `${C}/records/r-g1`))), true);
  });
});

describe('archives : clubs/{c}/archives/{id}', () => {
  test('le directeur écrit synthèse et exercices ; remplacer une archive = supprimer et réécrire en un lot', async () => {
    const dir = dbOf(env, 'director');
    const batch = writeBatch(dir);
    batch.delete(doc(dir, `${C}/archives/ar1`));
    batch.set(doc(dir, `${C}/archives/se1_children`), summaryDoc());
    batch.set(doc(dir, `${C}/archives/se1_children_a_1`), exerciseDoc());
    assert.equal(await allowed(() => batch.commit()), true);
    assert.equal(await list('director', 'archives', where('seasonId', '==', 'se1')), true);
  });

  test('un enseignant lit mais n\'écrit pas ; parent et élève ne lisent pas', async () => {
    assert.equal(await list('teacherA', 'archives'), true);
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'teacherA'), `${C}/archives/z`), summaryDoc())), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'teacherA'), `${C}/archives/ar1`))), false);
    for (const actor of ['guardian', 'student', 'invited', 'directorOther']) {
      assert.equal(await list(actor, 'archives'), false, actor);
    }
  });

  test('compteurs seulement : aucun identifiant d\'élève ni de groupe, bornes des compteurs', async () => {
    const dir = dbOf(env, 'director');
    const set = (extra) => allowed(() => setDoc(doc(dir, `${C}/archives/z`), summaryDoc(extra)));
    assert.equal(await set({ studentId: 's1' }), false, 'identifiant d\'élève');
    assert.equal(await set({ groupId: 'g1' }), false, 'identifiant de groupe');
    assert.equal(await set({ attemptCount: 1000000 }), true, 'borne');
    assert.equal(await set({ attemptCount: 1000001 }), false, 'au-dessus');
    assert.equal(await set({ public: 'seniors' }), false, 'public hors liste');
  });
});

// Garde de la graine : les documents utilisés ci-dessus existent bien.
test('la graine contient les documents que ces tests supposent', async () => {
  for (const path of [`${C}/seasons/se1`, `${C}/sessions/ss-g1`, `${C}/records/r-g1`, `${C}/archives/ar1`]) {
    assert.equal((await getDoc(doc(dbOf(env, 'director'), path))).exists(), true, path);
  }
});
