// Règle de conflit des données partagées (ADR 0024, B5 ; table dans les notes FB5b de l'ADR) :
// DEUX clients écrivent « en même temps » (Promise.all) sur l'émulateur, avec les VRAIES règles et
// les opérations exactes des dépôts Dart. Une ligne de la table, un test (C1 à C13) ; ce que le
// SDK et le serveur garantissent que le faux Firestore de Dart ne garantit pas : isolation des
// transactions, atomicité des unions de listes, refus d'une re-création, date du serveur.
//
// Le résultat dépend de l'ordre d'arrivée au serveur quand la règle est « dernier écrit gagne » :
// le test vérifie ce qui est vrai quel que soit l'ordre (l'une des deux écritures, ENTIÈRE ; les
// deux clients lisent la même chose). Les mêmes lignes jouées par les dépôts Dart sur un faux sont
// dans `app/test/contract/conflict_contract.dart`.
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  arrayUnion,
  deleteDoc,
  disableNetwork,
  enableNetwork,
  doc,
  getDoc,
  getDocs,
  collection,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

import { allowed, complete, createEnv, dbOf, seed, uids } from './support.mjs';

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

// Deux appareils du même club : le directeur et l'administrateur (tous deux gestionnaires).
const devices = () => [dbOf(env, 'director'), dbOf(env, 'admin')];
const read = async (db, path) => (await getDoc(doc(db, path))).data();

const recordDoc = (extra = {}) => ({
  groupId: 'g1',
  seasonId: 'se1',
  date: '2026-10-03T00:00:00.000',
  audience: 'children',
  mainBlockId: null,
  recallBlockId: null,
  sheetId: 'posture-1',
  tags: [],
  presentStudentIds: [],
  ...extra,
});

/** La création d'une saisie liée, comme `FirestoreSdkAccess.createDocument` : transaction. */
const createIfAbsent = (db, path, data) =>
  runTransaction(db, async (transaction) => {
    if ((await transaction.get(doc(db, path))).exists()) return false;
    transaction.set(doc(db, path), data);
    return true;
  });

describe('C1 fiche élève : dernier écrit gagne par document', () => {
  test('deux renommages : l\'un des deux gagne en entier, les groupes sont intacts, les deux clients lisent pareil', async () => {
    const [a, b] = devices();

    await Promise.all([
      setDoc(doc(a, `${C}/students/s1`), { firstName: 'Léa A', groupIds: arrayUnion() }, merge),
      setDoc(doc(b, `${C}/students/s1`), { firstName: 'Léa B', groupIds: arrayUnion() }, merge),
    ]);

    const seenByA = await read(a, `${C}/students/s1`);
    assert.ok(['Léa A', 'Léa B'].includes(seenByA.firstName));
    assert.deepEqual(seenByA.groupIds, ['g1']);
    assert.deepEqual(await read(b, `${C}/students/s1`), seenByA);
  });
});

describe('C2 groupes de la fiche : réunion atomique, jamais remplacement', () => {
  test('deux groupes ajoutés en même temps sont tous deux conservés', async () => {
    const [a, b] = devices();

    await Promise.all([
      updateDoc(doc(a, `${C}/students/s1`), { groupIds: arrayUnion('g2') }),
      updateDoc(doc(b, `${C}/students/s1`), { groupIds: arrayUnion('g3') }),
    ]);

    assert.deepEqual((await read(a, `${C}/students/s1`)).groupIds.sort(), ['g1', 'g2', 'g3']);
  });
});

describe('C3 groupe et C4 appartenance : dernier écrit gagne, appartenances distinctes réunies', () => {
  const membership = (student, extra = {}) => ({
    groupId: 'g1',
    seasonId: 'se1',
    studentId: student,
    from: '2026-10-01T00:00:00.000',
    to: null,
    ...extra,
  });
  const membershipPath = (student) => `${C}/memberships/g1_${student}_2026-10-01T00:00:00.000`;

  test('C3 un renommage et deux inscriptions de deux élèves se réunissent', async () => {
    const [a, b] = devices();

    await Promise.all([
      updateDoc(doc(a, `${C}/groups/g1`), { name: 'Mardi A' }),
      setDoc(doc(a, membershipPath('s3')), membership('s3')),
      setDoc(doc(b, membershipPath('s4')), membership('s4')),
    ]);

    assert.ok(['Mardi A', 'Mardi'].includes((await read(b, `${C}/groups/g1`)).name));
    for (const student of ['s3', 's4']) {
      assert.equal((await getDoc(doc(a, membershipPath(student)))).exists(), true, student);
    }
  });

  test('C4 la même appartenance écrite par les deux appareils est un seul document', async () => {
    const [a, b] = devices();

    await Promise.all([
      setDoc(doc(a, membershipPath('s3')), membership('s3')),
      setDoc(doc(b, membershipPath('s3')), membership('s3')),
    ]);

    const all = await getDocs(collection(a, `${C}/memberships`));
    assert.equal(all.docs.filter((d) => d.id === 'g1_s3_2026-10-01T00:00:00.000').length, 1);
    assert.deepEqual((await read(b, membershipPath('s3'))).studentId, 's3');
  });
});

describe('C5 saisie d\'une séance du catalogue : une création, présents réunis', () => {
  const path = `${C}/records/g1_20261003_posture-1`;

  test('deux appareils ouvrent la même saisie : une seule création, tous les présents, la date du premier', async () => {
    const teacher = dbOf(env, 'teacherA');
    const director = dbOf(env, 'director');
    const open = async (db, present, main) => {
      const created = await createIfAbsent(
        db,
        path,
        recordDoc({ presentStudentIds: present, mainBlockId: main, createdAt: serverTimestamp() }),
      );
      if (!created) await updateDoc(doc(db, path), { presentStudentIds: arrayUnion(...present) });
      return created;
    };

    const created = await Promise.all([open(teacher, ['s1'], 'a'), open(director, ['s2'], 'b')]);

    assert.equal(created.filter(Boolean).length, 1, 'exactement une création');
    const stored = await read(teacher, path);
    assert.deepEqual([...stored.presentStudentIds].sort(), ['s1', 's2']);
    assert.ok(['a', 'b'].includes(stored.mainBlockId));
    const seenByDirector = await read(director, path);
    assert.deepEqual(seenByDirector.presentStudentIds, stored.presentStudentIds, 'même ordre pour les deux clients');
    assert.equal(seenByDirector.mainBlockId, stored.mainBlockId);
  });

  test('la reprise écrite en simple SET sur un document qui existe est refusée (date de création figée)', async () => {
    const teacher = dbOf(env, 'teacherA');
    await createIfAbsent(teacher, path, recordDoc({ presentStudentIds: ['s1'], createdAt: serverTimestamp() }));

    const second = await allowed(() =>
      setDoc(doc(dbOf(env, 'director'), path), recordDoc({ presentStudentIds: ['s2'], createdAt: serverTimestamp() }), merge),
    );

    assert.equal(second, false, 'ré-écrire la date de création est refusé');
    assert.deepEqual((await read(teacher, path)).presentStudentIds, ['s1']);
  });
});

describe('C6 saisie : enregistrer remplace en bloc, dernier écrit gagne', () => {
  test('deux enregistrements : le résultat est l\'un des deux, jamais un mélange', async () => {
    const [a, b] = devices();
    await setDoc(doc(a, `${C}/records/r-new`), recordDoc({ createdAt: serverTimestamp() }));

    await Promise.all([
      setDoc(doc(a, `${C}/records/r-new`), { presentStudentIds: ['s1'], mainBlockId: 'a' }, merge),
      setDoc(doc(b, `${C}/records/r-new`), { presentStudentIds: ['s2', 's3'], mainBlockId: 'b' }, merge),
    ]);

    const stored = await read(a, `${C}/records/r-new`);
    const whole = (stored.mainBlockId === 'a' && stored.presentStudentIds.join() === 's1')
      || (stored.mainBlockId === 'b' && stored.presentStudentIds.join() === 's2,s3');
    assert.ok(whole, `${stored.mainBlockId} ${stored.presentStudentIds}`);
    assert.deepEqual(await read(b, `${C}/records/r-new`), stored);
  });
});

describe('C7 étiquettes : la liste est remplacée en bloc', () => {
  test('deux listes d\'étiquettes : l\'une des deux, entière', async () => {
    const [a, b] = devices();

    await Promise.all([
      updateDoc(doc(a, `${C}/records/r-g1`), { tags: ['toRedo'] }),
      updateDoc(doc(b, `${C}/records/r-g1`), { tags: ['gameAppreciated'] }),
    ]);

    const tags = (await read(a, `${C}/records/r-g1`)).tags;
    assert.ok(['toRedo', 'gameAppreciated'].includes(tags.join()) && tags.length === 1, `${tags}`);
  });
});

describe('C8 passages : un document par passage, ajout seul', () => {
  const attempt = (extra = {}) => ({ ...complete('attempts', { groupId: 'g1', seasonId: 'se1', studentId: 's1' }), createdAt: serverTimestamp(), ...extra });

  test('quatre passages écrits ensemble par deux appareils sont tous conservés', async () => {
    const teacher = dbOf(env, 'teacherA');
    const director = dbOf(env, 'director');

    await Promise.all([
      setDoc(doc(teacher, `${C}/attempts/a-1`), attempt()),
      setDoc(doc(director, `${C}/attempts/a-2`), attempt()),
      setDoc(doc(teacher, `${C}/attempts/a-3`), attempt()),
      setDoc(doc(director, `${C}/attempts/a-4`), attempt()),
    ]);

    const all = await getDocs(collection(director, `${C}/attempts`));
    assert.deepEqual(
      all.docs.map((d) => d.id).filter((id) => id.startsWith('a-') && id.length === 3).sort(),
      ['a-1', 'a-2', 'a-3', 'a-4'],
    );
  });

  test('rejouer l\'identifiant d\'un passage par un autre appareil est refusé : on n\'écrase pas un passage', async () => {
    const teacher = dbOf(env, 'teacherA');
    await setDoc(doc(teacher, `${C}/attempts/a-dup`), attempt());

    const replay = await allowed(() => setDoc(doc(dbOf(env, 'director'), `${C}/attempts/a-dup`), attempt({ potted: 1 })));

    assert.equal(replay, false);
    assert.equal((await read(teacher, `${C}/attempts/a-dup`)).potted, 4);
  });
});

describe('C9 correction d\'un passage : dernier écrit gagne sur les billes seulement', () => {
  test('deux corrections : une paire de billes entière gagne', async () => {
    const [a, b] = devices();

    await Promise.all([
      updateDoc(doc(a, `${C}/attempts/a-g1`), { potted: 1, total: 5 }),
      updateDoc(doc(b, `${C}/attempts/a-g1`), { potted: 4, total: 5 }),
    ]);

    const stored = await read(a, `${C}/attempts/a-g1`);
    assert.ok([1, 4].includes(stored.potted));
    assert.equal(stored.total, 5);
  });

  test('une correction qui touche autre chose que les billes est refusée', async () => {
    assert.equal(
      await allowed(() => updateDoc(doc(dbOf(env, 'director'), `${C}/attempts/a-g1`), { studentId: 's2' })),
      false,
    );
  });
});

describe('C10 blocs acquis, C11 « Vu » partagé, C12 séances planifiées : un document chacun', () => {
  test('C10 deux appareils marquent le même bloc : deux documents, le calcul les fusionne', async () => {
    const [a, b] = devices();
    const acquisition = (extra) => complete('acquisitions', { groupId: 'g1', seasonId: 'se1', studentId: 's1', ...extra });

    await Promise.all([
      setDoc(doc(a, `${C}/acquisitions/q-a`), acquisition({ date: '2026-10-05T00:00:00.000' }), merge),
      setDoc(doc(b, `${C}/acquisitions/q-b`), acquisition({ date: '2026-10-09T00:00:00.000' }), merge),
    ]);

    const all = await getDocs(collection(a, `${C}/acquisitions`));
    assert.deepEqual(all.docs.map((d) => d.id).filter((id) => id.startsWith('q-') && id.length === 3).sort(), ['q-a', 'q-b']);
  });

  test('C11 deux animateurs donnent leur « Vu » : deux documents, chacun à son nom ; au nom d\'un collègue, refusé', async () => {
    const teacher = dbOf(env, 'teacherA');
    const director = dbOf(env, 'director');
    const vu = (uid, extra = {}) => ({
      ...complete('acknowledgements', { groupId: 'g1', seasonId: 'se1', studentId: 's1' }),
      createdBy: uid,
      ...extra,
    });

    await Promise.all([
      setDoc(doc(teacher, `${C}/acknowledgements/k-a`), vu(uids.teacherA), merge),
      setDoc(doc(director, `${C}/acknowledgements/k-b`), vu(uids.director), merge),
    ]);

    assert.equal((await read(director, `${C}/acknowledgements/k-a`)).createdBy, uids.teacherA);
    assert.equal((await read(teacher, `${C}/acknowledgements/k-b`)).createdBy, uids.director);
    assert.equal(
      await allowed(() => setDoc(doc(teacher, `${C}/acknowledgements/k-c`), vu(uids.director), merge)),
      false,
      'on n\'acquitte pas au nom d\'un collègue',
    );
  });

  test('C12 deux appareils planifient chacun une séance : les deux sont là, pour les deux', async () => {
    const [a, b] = devices();
    const session = (title) => ({
      groupId: 'g1', seasonId: 'se1', title, date: '2026-10-05T00:00:00.000', audience: 'children',
      sheetId: null, createdAt: serverTimestamp(),
    });

    await Promise.all([
      setDoc(doc(a, `${C}/sessions/p-a`), session('A'), merge),
      setDoc(doc(b, `${C}/sessions/p-b`), session('B'), merge),
    ]);

    for (const db of [a, b]) {
      const all = await getDocs(collection(db, `${C}/sessions`));
      assert.deepEqual(all.docs.map((d) => d.id).filter((id) => id.startsWith('p-')).sort(), ['p-a', 'p-b']);
    }
  });
});

describe('C13 suppression physique et documents uniques', () => {
  test('supprimer deux fois la même séance planifiée : sans erreur, disparue', async () => {
    const [a, b] = devices();

    await Promise.all([deleteDoc(doc(a, `${C}/sessions/ss-g1`)), deleteDoc(doc(b, `${C}/sessions/ss-g1`))]);

    assert.equal((await getDoc(doc(a, `${C}/sessions/ss-g1`))).exists(), false);
  });

  test('une mise à jour concurrente d\'une suppression ne ressuscite jamais le document (update)', async () => {
    const [a, b] = devices();

    const results = await Promise.allSettled([
      deleteDoc(doc(a, `${C}/attempts/a-g1`)),
      updateDoc(doc(b, `${C}/attempts/a-g1`), { potted: 2, total: 5 }),
    ]);

    assert.equal(results[0].status, 'fulfilled');
    assert.equal((await getDoc(doc(a, `${C}/attempts/a-g1`))).exists(), false);
  });

  test('une écriture d\'édition par fusion (sans date de création) après la suppression ne recrée pas la fiche', async () => {
    const [a, b] = devices();
    await deleteDoc(doc(a, `${C}/students/s2`));

    await assert.rejects(setDoc(doc(b, `${C}/students/s2`), { firstName: 'Tom B', groupIds: arrayUnion() }, merge));

    assert.equal((await getDoc(doc(a, `${C}/students/s2`))).exists(), false);
  });

  test('les réglages du club : une écriture entière gagne', async () => {
    const [a, b] = devices();
    const settings = (n) => ({ passesRequired: n, alertThreshold: 3, recallStaleSessions: 4, groupFailureSharePercent: 50 });

    await Promise.all([
      setDoc(doc(a, `${C}/settings/main`), settings(3)),
      setDoc(doc(b, `${C}/settings/main`), settings(7)),
    ]);

    const stored = await read(a, `${C}/settings/main`);
    assert.ok([3, 7].includes(stored.passesRequired));
    assert.deepEqual(await read(b, `${C}/settings/main`), stored);
  });
});

// E (FB5b) : la saisie liée à une séance du catalogue, créée HORS LIGNE. La transaction
// `createIfAbsent` est impossible ; l'application écrit alors une écriture simple (`createdAt` du
// serveur, fusion). Les règles l'acceptent si la saisie n'existe pas (création) et la REFUSENT si
// elle existe (elle changerait la date de création, figée) ; le refus déclenche la reprise : les
// présents sont réunis. Le SDK ne livre le refus qu'à la reconnexion.
describe('E saisie liée créée hors ligne : une création ou une reprise, jamais une perte', () => {
  const path = `${C}/records/g1_20261003_posture-1`;
  const plain = (present) =>
    setDoc(
      doc(offlineDb, path),
      recordDoc({ presentStudentIds: present, createdAt: serverTimestamp() }),
      merge,
    );
  let offlineDb;

  test('E1 personne d\'autre n\'a créé la saisie : l\'écriture simple est acceptée à la reconnexion (création)', async () => {
    offlineDb = dbOf(env, 'teacherA');
    await disableNetwork(offlineDb);
    const queued = plain(['s1']);

    await enableNetwork(offlineDb);
    await queued;

    const stored = await read(dbOf(env, 'director'), path);
    assert.deepEqual(stored.presentStudentIds, ['s1']);
    assert.ok(stored.createdAt, 'la date de création est posée par le serveur');
  });

  test('E2 un autre appareil l\'a créée entre-temps : l\'écriture simple est refusée, la reprise réunit les présents', async () => {
    offlineDb = dbOf(env, 'teacherA');
    const director = dbOf(env, 'director');
    await disableNetwork(offlineDb);
    const queued = plain(['s1']).then(() => 'accepted', (error) => error.code);

    await createIfAbsent(director, path, recordDoc({ presentStudentIds: ['s2'], createdAt: serverTimestamp() }));
    const createdAt = (await read(director, path)).createdAt;
    await enableNetwork(offlineDb);

    assert.equal(await queued, 'permission-denied', 'le refus arrive à la reconnexion');
    await updateDoc(doc(offlineDb, path), { presentStudentIds: arrayUnion('s1') });
    const stored = await read(director, path);
    assert.deepEqual([...stored.presentStudentIds].sort(), ['s1', 's2']);
    assert.deepEqual(stored.createdAt, createdAt, 'la date de création est celle de la première écriture');
  });

  test('E3 deux appareils créent la même saisie hors ligne : le premier reconnecté crée, le second est refusé puis réunit', async () => {
    const first = dbOf(env, 'teacherA');
    const second = dbOf(env, 'director');
    await Promise.all([disableNetwork(first), disableNetwork(second)]);
    offlineDb = first;
    const queuedFirst = plain(['s1']).then(() => 'accepted', (error) => error.code);
    offlineDb = second;
    const queuedSecond = plain(['s2']).then(() => 'accepted', (error) => error.code);

    await enableNetwork(first);
    assert.equal(await queuedFirst, 'accepted');
    await enableNetwork(second);
    assert.equal(await queuedSecond, 'permission-denied');
    await updateDoc(doc(second, path), { presentStudentIds: arrayUnion('s2') });

    const stored = await read(dbOf(env, 'director'), path);
    assert.deepEqual([...stored.presentStudentIds].sort(), ['s1', 's2']);
  });

  test('E4 les présents ne dépassent pas 60 : la reprise est refusée par les règles, sans écraser la saisie', async () => {
    offlineDb = dbOf(env, 'teacherA');
    const director = dbOf(env, 'director');
    const many = Array.from({ length: 40 }, (_, i) => `a${i}`);
    await createIfAbsent(director, path, recordDoc({ presentStudentIds: many, createdAt: serverTimestamp() }));

    const refused = await allowed(() =>
      updateDoc(doc(offlineDb, path), { presentStudentIds: arrayUnion(...Array.from({ length: 30 }, (_, i) => `b${i}`)) }),
    );

    assert.equal(refused, false);
    assert.equal((await read(director, path)).presentStudentIds.length, 40);
  });
});
