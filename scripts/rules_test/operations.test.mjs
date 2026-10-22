// Opérations reprenables d'un club (FB8, partie A, ADR 0024 décision 19 ; ADR 0025) : le MARQUEUR
// D'OPÉRATION et l'EFFACEMENT d'un élève, joués contre l'émulateur Firestore et les VRAIES règles,
// avec les vrais rôles. Les écritures sont celles que `ClubStudentPurge`, `FirestoreOperationStore`
// et `OperationMarkerDocument` envoient (mêmes chemins, mêmes champs) ; le parcours complet de
// l'application est rejoué par scripts/emulator_e2e.
//
// Ce que ce fichier prouve, règles réelles à l'appui :
//   1. le marqueur `clubs/{c}/operations/{operationId}_{uid}` : un gestionnaire (directeur ou
//      administrateur) crée et avance SON marqueur seulement, d'exactement un lot, une étape à la
//      fois ; personne d'autre n'en pose, n'en lit ni n'en avance (un enseignant ne bloque pas le
//      directeur) ; aucune donnée personnelle ne s'y glisse (liste blanche de champs) ;
//   2. la fiche `erasing` : posée par un gestionnaire seul, irréversible, refusée à la création ;
//      elle refuse alors toute NOUVELLE donnée liée (passages, blocs acquis, bilans, acquittements),
//      de la part d'un gestionnaire comme d'un enseignant ; une fiche déjà effacée ne ressuscite pas ;
//   3. la purge : un gestionnaire supprime les données liées, retire l'élève des présents et coupe le
//      lien des comptes parent et élève (l'accès tombe aussitôt) ; un enseignant ne supprime ni la
//      fiche ni les données d'un autre groupe ;
//   4. le BUDGET : un lot de 400 écritures de purge, et un lot de clôture (groupes, appartenances,
//      fiches) de 400 écritures, passent les limites d'accès de documents des règles.
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

import {
  actorNames,
  allowed,
  complete,
  createEnv,
  dbOf,
  member,
  now,
  owned,
  put,
  remove,
  seed,
  student,
  ts,
  uids,
} from './support.mjs';

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

const KEY = 'a'.repeat(64);
const KEY2 = 'b'.repeat(64);
const MGR = ['director', 'admin'];
const roleOf = (actor) => (actor === 'admin' ? 'admin' : 'director');
const uidOf = (actor) => uids[actor] ?? `u-${actor}`;
const mine = (actor, key = KEY) => `clubs/c1/operations/${key}_${uidOf(actor)}`;
const pathOf = (uid, key = KEY) => `clubs/c1/operations/${key}_${uid}`;

const created = (role, createdBy, extra = {}) => ({
  operationId: KEY,
  kind: 'erasure',
  done: 1,
  stage: 1,
  role,
  createdBy,
  startedAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...extra,
});
const closureTerms = (extra = {}) => ({
  seasonId: 'se1',
  closedOn: '2026-10-12T00:00:00.000',
  prepareNext: true,
  dropPlanned: true,
  ...extra,
});
const stored = (role, createdBy, extra = {}) =>
  created(role, createdBy, { startedAt: ts(now() - 1000), updatedAt: ts(now() - 1000), ...extra });
const advance = (extra = {}) => ({ done: 2, stage: 1, updatedAt: serverTimestamp(), ...extra });

/** Pour chaque acteur : exécute et compare à la liste des autorisés (comme matrix.test.mjs). */
const check = async ({ expectAllowed, run, reset }) => {
  const wrong = [];
  if (reset) await reset();
  for (const actor of actorNames) {
    const ok = await allowed(() => run(dbOf(env, actor), actor));
    if (ok && reset) await reset();
    const expected = expectAllowed.includes(actor);
    if (ok !== expected) wrong.push(`${actor} : ${ok ? 'autorisé' : 'refusé'} (attendu ${expected ? 'autorisé' : 'refusé'})`);
  }
  assert.deepEqual(wrong, []);
};

const clearMarkers = async () => {
  for (const uid of Object.values(uids)) {
    await remove(env, pathOf(uid));
    await remove(env, pathOf(uid, KEY2));
  }
};
/** Un marqueur déjà là, pour chaque gestionnaire, à son nom. */
const seedMarkers = async (extra = {}) => {
  await clearMarkers();
  for (const actor of MGR) await put(env, mine(actor), stored(roleOf(actor), uids[actor], extra));
};

describe('marqueur d\'opération : clubs/{c}/operations/{operationId}_{uid}', () => {
  test('création (premier lot) de SON marqueur : le directeur et l\'administrateur, avec LEUR rôle', () =>
    check({
      expectAllowed: MGR,
      run: (db, actor) => setDoc(doc(db, mine(actor)), created(roleOf(actor), uidOf(actor))),
      reset: clearMarkers,
    }));

  test('ATTAQUE : un enseignant, un parent, un élève, un invité ne posent aucun marqueur (ils ne bloquent pas le directeur)', async () => {
    for (const actor of ['teacherA', 'teacherB', 'student', 'guardian', 'invited', 'teacherC2', 'anonymous', 'unverified']) {
      for (const role of ['director', 'admin', 'teacher']) {
        const ok = await allowed(() => setDoc(doc(dbOf(env, actor), mine(actor)), created(role, uids[actor] ?? 'u-x')));
        assert.equal(ok, false, `${actor} ne pose pas de marqueur (${role})`);
        // Pas davantage sous l'identifiant du directeur : il reste libre de poser le sien.
        const forged = await allowed(() => setDoc(doc(dbOf(env, actor), mine('director')), created(role, uids.director)));
        assert.equal(forged, false, `${actor} ne pose pas de marqueur au nom du directeur (${role})`);
      }
    }
    assert.equal(
      await allowed(() => setDoc(doc(dbOf(env, 'director'), mine('director')), created('director', uids.director))),
      true,
    );
  });

  test('ATTAQUE : personne ne crée un marqueur au nom d\'un autre auteur', async () => {
    const clearOf = (uid) => () => remove(env, pathOf(uid));
    await check({
      expectAllowed: ['director'],
      run: (db) => setDoc(doc(db, pathOf(uids.director)), created('director', uids.director)),
      reset: clearOf(uids.director),
    });
    // Le directeur ne pose pas le marqueur de l'administrateur, ni l'inverse.
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'director'), pathOf(uids.admin)), created('admin', uids.admin))), false);
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'admin'), pathOf(uids.director)), created('director', uids.director))), false);
    // Ni `createdBy` d'un autre, ni sous l'empreinte seule.
    await check({
      expectAllowed: [],
      run: (db, actor) => setDoc(doc(db, mine(actor)), created(roleOf(actor), 'u-autre')),
      reset: clearMarkers,
    });
    await check({
      expectAllowed: [],
      run: (db, actor) => setDoc(doc(db, `clubs/c1/operations/${KEY}`), created(roleOf(actor), uidOf(actor))),
      reset: clearMarkers,
    });
  });

  test('création : forme exigée (rôle, `done` 1, étape, nature, champs en trop et données personnelles refusés)', async () => {
    const refused = async (extra, why) =>
      check({
        expectAllowed: [],
        run: (db, actor) => setDoc(doc(db, mine(actor)), created(roleOf(actor), uidOf(actor), extra)),
        reset: clearMarkers,
      }).catch((error) => {
        error.message = `${why} : ${error.message}`;
        throw error;
      });
    await refused({ role: 'teacher' }, 'rôle enseignant');
    await refused({ done: 2 }, 'done 2');
    await refused({ done: 0 }, 'done 0');
    await refused({ stage: 2 }, 'étape 2 à la création');
    await refused({ stage: -1 }, 'étape négative');
    await refused({ kind: 'import' }, 'nature inconnue');
    await refused({ operationId: 'z'.repeat(64) }, 'empreinte non hexadécimale');
    await refused({ operationId: 'a'.repeat(63) }, 'empreinte trop courte');
    await refused({ operationId: KEY2 }, 'empreinte différente de l\'identifiant');
    await refused({ firstName: 'Léa' }, 'prénom glissé dans le marqueur');
    await refused({ studentId: 's1' }, 'identifiant d\'élève glissé dans le marqueur');
    await refused({ studentIds: ['s1'] }, 'liste d\'élèves glissée dans le marqueur');
    await refused({ seasonId: 'se1' }, 'saison sur un effacement');
    await refused({ done: '1' }, 'done en texte');
    await refused({ updatedAt: ts(now() - 60000) }, 'date de mise à jour du client');
    await refused({ startedAt: ts(now() - 60000) }, 'date de début du client');
  });

  test('création d\'une clôture : les termes (saison, jour, deux choix) sont exigés, rien d\'autre', async () => {
    const ok = (db, actor, extra = {}) =>
      setDoc(doc(db, mine(actor)), created(roleOf(actor), uidOf(actor), { kind: 'closure', ...closureTerms(), ...extra }));
    await check({ expectAllowed: MGR, run: (db, actor) => ok(db, actor), reset: clearMarkers });
    for (const extra of [
      { prepareNext: 'oui' },
      { dropPlanned: 1 },
      { closedOn: 'demain' },
      { seasonId: 'x'.repeat(65) },
      { seasonId: 7 },
      { studentIds: ['s1'] },
    ]) {
      await check({ expectAllowed: [], run: (db, actor) => ok(db, actor, extra), reset: clearMarkers });
    }
    // Sans les termes : refusé.
    await check({
      expectAllowed: [],
      run: (db, actor) => setDoc(doc(db, mine(actor)), created(roleOf(actor), uidOf(actor), { kind: 'closure' })),
      reset: clearMarkers,
    });
  });

  test('get (même d\'un document absent) : son propre marqueur seulement ; list : les siens seulement', async () => {
    await check({ expectAllowed: MGR, run: (db, actor) => getDoc(doc(db, mine(actor))) });
    await seedMarkers();
    await check({ expectAllowed: MGR, run: (db, actor) => getDoc(doc(db, mine(actor))) });
    // Le marqueur d'un autre ne se lit pas, pas même d'un gestionnaire.
    await check({ expectAllowed: ['director'], run: (db) => getDoc(doc(db, pathOf(uids.director))) });
    await check({ expectAllowed: ['admin'], run: (db) => getDoc(doc(db, pathOf(uids.admin))) });
    await check({
      expectAllowed: MGR,
      run: (db, actor) => getDocs(query(collection(db, 'clubs/c1/operations'), where('createdBy', '==', uidOf(actor)))),
    });
    // Sans filtre sur l'auteur, la liste est refusée : on ne voit pas les opérations d'un collègue.
    await check({ expectAllowed: [], run: (db) => getDocs(collection(db, 'clubs/c1/operations')) });
    await check({
      expectAllowed: [],
      run: (db) => getDocs(query(collection(db, 'clubs/c1/operations'), where('createdBy', '==', 'u-teacher-a'))),
    });
  });

  test('avancement de SON marqueur : d\'exactement un lot, d\'au plus une étape ; rejeu, saut, recul ou champ changé refusés', async () => {
    const mark = () => seedMarkers({ done: 3, stage: 1 });
    await mark();
    const adv = (extra) => (db, actor) => updateDoc(doc(db, mine(actor)), advance({ done: 4, ...extra }));
    await check({ expectAllowed: MGR, run: adv({}), reset: mark });
    await check({ expectAllowed: MGR, run: adv({ stage: 2 }), reset: mark });
    await check({ expectAllowed: [], run: adv({ done: 3 }), reset: mark });
    await check({ expectAllowed: [], run: adv({ done: 5 }), reset: mark });
    await check({ expectAllowed: [], run: adv({ stage: 3 }), reset: mark });
    await check({ expectAllowed: [], run: adv({ stage: 0 }), reset: mark });
    await check({ expectAllowed: [], run: adv({ createdBy: 'u-autre' }), reset: mark });
    await check({ expectAllowed: [], run: adv({ operationId: KEY2 }), reset: mark });
    await check({ expectAllowed: [], run: adv({ kind: 'closure', ...closureTerms() }), reset: mark });
    await check({ expectAllowed: [], run: (db, actor) => updateDoc(doc(db, mine(actor)), advance({ done: 4, role: actor === 'admin' ? 'director' : 'admin' })), reset: mark });
    await check({ expectAllowed: [], run: adv({ startedAt: serverTimestamp() }), reset: mark });
    await check({ expectAllowed: [], run: adv({ updatedAt: ts(now() - 60000) }), reset: mark });
    await check({ expectAllowed: [], run: adv({ firstName: 'Léa' }), reset: mark });
    await clearMarkers();
  });

  test('ATTAQUE : avancer ou supprimer le marqueur d\'un AUTRE est refusé pour tous, gestionnaires compris', async () => {
    const mark = () => seedMarkers({ done: 3, stage: 1 });
    await mark();
    await check({ expectAllowed: ['director'], run: (db) => updateDoc(doc(db, mine('director')), advance({ done: 4 })), reset: mark });
    await check({ expectAllowed: ['admin'], run: (db) => updateDoc(doc(db, mine('admin')), advance({ done: 4 })), reset: mark });
    await check({ expectAllowed: ['director'], run: (db) => deleteDoc(doc(db, mine('director'))), reset: mark });
    await check({ expectAllowed: ['admin'], run: (db) => deleteDoc(doc(db, mine('admin'))), reset: mark });
    await clearMarkers();
  });

  test('suppression de SON marqueur (le dernier lot) : le directeur et l\'administrateur ; personne d\'autre', async () => {
    const mark = () => seedMarkers({ done: 3, stage: 2 });
    await mark();
    await check({ expectAllowed: MGR, run: (db, actor) => deleteDoc(doc(db, mine(actor))), reset: mark });
    await clearMarkers();
  });

  test('périmètre : le directeur d\'un autre club n\'écrit rien dans les opérations de c1', async () => {
    assert.equal(
      await allowed(() => setDoc(doc(dbOf(env, 'directorOther'), `clubs/c1/operations/${KEY}_${uids.directorOther}`), created('director', uids.directorOther))),
      false,
    );
    assert.equal(
      await allowed(() => setDoc(doc(dbOf(env, 'directorOther'), `clubs/c2/operations/${KEY}_${uids.directorOther}`), created('director', uids.directorOther))),
      true,
    );
  });

  test('un lot atomique : les écritures d\'une opération ET son marqueur partent ensemble, ou rien', async () => {
    const db = dbOf(env, 'director');
    // Lot valide : fiche marquée + marqueur créé.
    const batch = writeBatch(db);
    batch.update(doc(db, 'clubs/c1/students/s1'), { erasing: true });
    batch.set(doc(db, mine('director')), created('director', uids.director));
    await batch.commit();
    assert.equal((await getDoc(doc(db, 'clubs/c1/students/s1'))).data().erasing, true);
    // Lot dont le marqueur est refusé (done 2 à la création) : la fiche n'est PAS marquée.
    const bad = writeBatch(db);
    bad.update(doc(db, 'clubs/c1/students/s2'), { erasing: true });
    bad.set(doc(db, mine('director', KEY2)), created('director', uids.director, { operationId: KEY2, done: 2 }));
    assert.equal(await allowed(() => bad.commit()), false);
    assert.equal((await getDoc(doc(db, 'clubs/c1/students/s2'))).data().erasing, undefined);
    // Rejeu : le même lot (marqueur à `done 1`) sur un marqueur déjà créé est refusé en bloc.
    const replay = writeBatch(db);
    replay.update(doc(db, 'clubs/c1/students/s2'), { erasing: true });
    replay.set(doc(db, mine('director')), created('director', uids.director));
    assert.equal(await allowed(() => replay.commit()), false);
    assert.equal((await getDoc(doc(db, 'clubs/c1/students/s2'))).data().erasing, undefined);
  });
});

describe('fiche en cours d\'effacement (`erasing`)', () => {
  const flag = async (id = 's1') =>
    put(env, `clubs/c1/students/${id}`, { ...(id === 's1' ? student(['g1']) : student(['g2'], { firstName: 'Tom' })), erasing: true });
  const unflag = async (id = 's1') =>
    put(env, `clubs/c1/students/${id}`, id === 's1' ? student(['g1']) : student(['g2'], { firstName: 'Tom' }));

  test('marquer une fiche : le directeur et l\'administrateur seulement (jamais un enseignant, un parent, un autre club)', () =>
    check({
      expectAllowed: MGR,
      run: (db) => updateDoc(doc(db, 'clubs/c1/students/s1'), { erasing: true }),
      reset: unflag,
    }));

  test('le marquage est irréversible : `erasing` ne se retire ni se met à faux', async () => {
    await flag();
    await check({ expectAllowed: [], run: (db) => updateDoc(doc(db, 'clubs/c1/students/s1'), { erasing: false }), reset: flag });
    await check({ expectAllowed: [], run: (db) => setDoc(doc(db, 'clubs/c1/students/s1'), student(['g1'])), reset: flag });
    // Une mise à jour ordinaire qui garde la marque reste permise (le prénom, par exemple).
    await check({
      expectAllowed: MGR,
      run: (db) => updateDoc(doc(db, 'clubs/c1/students/s1'), { firstName: 'Léa B' }),
      reset: flag,
    });
  });

  test('une fiche ne se crée pas déjà « en cours d\'effacement »', async () => {
    await check({
      expectAllowed: [],
      run: (db) => setDoc(doc(db, 'clubs/c1/students/nouvelle'), { ...student(['g1']), erasing: true }),
      reset: () => remove(env, 'clubs/c1/students/nouvelle'),
    });
    await check({
      expectAllowed: [],
      run: (db) => setDoc(doc(db, 'clubs/c1/students/nouvelle'), { ...student(['g1']), erasing: 'oui' }),
      reset: () => remove(env, 'clubs/c1/students/nouvelle'),
    });
  });

  const newData = {
    attempts: (id) => ['clubs/c1/attempts/nouveau', complete('attempts', { ...owned('g1', id), createdAt: serverTimestamp() })],
    acquisitions: (id) => ['clubs/c1/acquisitions/nouveau', complete('acquisitions', owned('g1', id))],
    assessments: (id) => ['clubs/c1/assessments/nouveau', complete('assessments', owned('g1', id))],
    acknowledgements: (actor) => ['clubs/c1/acknowledgements/nouveau', complete('acknowledgements', { ...owned('g1', 's1'), createdBy: uids[actor] ?? 'u-x' })],
  };

  for (const name of ['attempts', 'acquisitions', 'assessments', 'acknowledgements']) {
    test(`${name} : une donnée NOUVELLE sur une fiche en cours d'effacement est refusée à tous ; acceptée sur une fiche ordinaire`, async () => {
      const make = (actor) => (name === 'acknowledgements' ? newData[name](actor) : newData[name]('s1'));
      const reset = () => remove(env, make('director')[0]);
      // Témoin : sur une fiche ordinaire, le directeur, l'administrateur et l'enseignant du groupe créent.
      await unflag();
      await check({
        expectAllowed: ['director', 'admin', 'teacherA'],
        run: (db, actor) => {
          const [path, data] = make(actor);
          return setDoc(doc(db, path), data);
        },
        reset,
      });
      // Fiche en cours d'effacement : plus personne.
      await flag();
      await check({
        expectAllowed: [],
        run: (db, actor) => {
          const [path, data] = make(actor);
          return setDoc(doc(db, path), data);
        },
        reset,
      });
    });
  }

  test('pas de résurrection : une donnée sur une fiche effacée est refusée (appareil retardataire)', async () => {
    await remove(env, 'clubs/c1/students/s1');
    await check({
      expectAllowed: [],
      run: (db) => {
        const [path, data] = newData.attempts('s1');
        return setDoc(doc(db, path), data);
      },
      reset: () => remove(env, 'clubs/c1/attempts/nouveau'),
    });
  });

  test('une mise à jour hors ligne d\'une fiche effacée ne la recrée pas (le directeur, l\'administrateur)', async () => {
    await remove(env, 'clubs/c1/students/s1');
    const exists = async () => (await getDoc(doc(dbOf(env, 'director'), 'clubs/c1/students/s1'))).exists();
    // L'édition rejouée par l'application (`FirestoreStudentRepository.save` : mise à jour, sans
    // `createdAt` ni `groupIds`) : l'écriture échoue sur le document absent.
    await check({
      expectAllowed: [],
      run: (db) => updateDoc(doc(db, 'clubs/c1/students/s1'), { firstName: 'Léa B', audience: 'children' }),
    });
    // Une écriture par fusion SANS `createdAt` (la forme d'une édition) n'est pas une création : la
    // règle exige la date du serveur à la création, que seule l'inscription pose.
    await check({
      expectAllowed: [],
      run: (db) => setDoc(doc(db, 'clubs/c1/students/s1'), { firstName: 'Léa B', audience: 'children', groupIds: arrayUnion() }, { merge: true }),
    });
    assert.equal(await exists(), false);
    // Témoin : l'inscription (date du serveur) reste permise au directeur et à l'administrateur.
    await check({
      expectAllowed: MGR,
      run: (db) => setDoc(doc(db, 'clubs/c1/students/s1'), { firstName: 'Léa', audience: 'children', groupIds: arrayUnion(), createdAt: serverTimestamp() }, { merge: true }),
      reset: () => remove(env, 'clubs/c1/students/s1'),
    });
  });

  test('les données déjà là restent lisibles et corrigibles pendant l\'effacement (rien à ressusciter)', async () => {
    await flag();
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'director'), 'clubs/c1/attempts/a-g1'))), true);
    assert.equal(await allowed(() => updateDoc(doc(dbOf(env, 'director'), 'clubs/c1/attempts/a-g1'), { potted: 1, total: 5, updatedAt: serverTimestamp() })), true);
  });

  test('LIMITE CONNUE : une règle ne parcourt pas une liste, la présence d\'un élève en cours d\'effacement peut encore être ajoutée à une saisie', async () => {
    await flag();
    // `presentStudentIds` est une liste : aucune règle ne peut y chercher l'élève marqué. L'effacement
    // contient ce risque en rejouant l'étape de purge juste avant de supprimer la fiche
    // (ClubStudentPurge) ; ce test fige la limite documentée dans l'ADR 0024 (notes FB8a).
    assert.equal(
      await allowed(() => updateDoc(doc(dbOf(env, 'teacherA'), 'clubs/c1/records/r-g1'), { presentStudentIds: ['s1'] })),
      true,
    );
  });
});

describe('purge d\'un élève : ce que le gestionnaire supprime et ce qu\'un enseignant ne peut pas', () => {
  test('la purge complète d\'un élève, lot par lot, est acceptée pour le directeur et l\'administrateur', async () => {
    for (const actor of MGR) {
      await seed(env);
      await put(env, 'clubs/c1/records/r-g1', { ...owned('g1'), presentStudentIds: ['s1', 's9'] });
      const db = dbOf(env, actor);
      // 1. Marquer + marqueur.
      let batch = writeBatch(db);
      batch.update(doc(db, 'clubs/c1/students/s1'), { erasing: true });
      batch.set(doc(db, mine(actor)), created(roleOf(actor), uidOf(actor), { stage: 1 }));
      await batch.commit();
      // 2. Purger : lien des comptes, présences, données, appartenances ; marqueur avancé.
      batch = writeBatch(db);
      batch.update(doc(db, 'clubs/c1/members/u-guardian'), { studentIds: arrayRemove('s1') });
      batch.update(doc(db, 'clubs/c1/members/u-student'), { studentIds: arrayRemove('s1') });
      batch.update(doc(db, 'clubs/c1/records/r-g1'), { presentStudentIds: arrayRemove('s1') });
      for (const path of [
        'clubs/c1/attempts/a-g1', 'clubs/c1/acquisitions/q-g1', 'clubs/c1/assessments/as-g1',
        'clubs/c1/acknowledgements/k-g1', 'clubs/c1/memberships/s1_2026-09-01',
      ]) batch.delete(doc(db, path));
      batch.update(doc(db, mine(actor)), advance({ done: 2, stage: 2 }));
      await batch.commit();
      // 3. Dernier lot : la fiche et le marqueur disparaissent ensemble.
      batch = writeBatch(db);
      batch.delete(doc(db, 'clubs/c1/students/s1'));
      batch.delete(doc(db, mine(actor)));
      await batch.commit();
      await env.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        for (const path of [
          'clubs/c1/students/s1', 'clubs/c1/attempts/a-g1', 'clubs/c1/acquisitions/q-g1', 'clubs/c1/assessments/as-g1',
          'clubs/c1/acknowledgements/k-g1', 'clubs/c1/memberships/s1_2026-09-01', mine(actor),
        ]) assert.equal((await getDoc(doc(fs, path))).exists(), false, path);
        assert.deepEqual((await getDoc(doc(fs, 'clubs/c1/records/r-g1'))).data().presentStudentIds, ['s9']);
        assert.deepEqual((await getDoc(doc(fs, 'clubs/c1/members/u-guardian'))).data().studentIds, []);
        // Les données de l'autre élève sont intactes.
        assert.equal((await getDoc(doc(fs, 'clubs/c1/attempts/a-g2'))).exists(), true);
        assert.equal((await getDoc(doc(fs, 'clubs/c1/students/s2'))).exists(), true);
      });
    }
  });

  test('le parent et l\'élève perdent l\'accès dès que le lien est retiré (fiche, passages)', async () => {
    for (const actor of ['guardian', 'student']) {
      await seed(env);
      const db = dbOf(env, actor);
      assert.equal(await allowed(() => getDoc(doc(db, 'clubs/c1/students/s1'))), true, `${actor} lit la fiche avant`);
      assert.equal(await allowed(() => getDoc(doc(db, 'clubs/c1/attempts/a-g1'))), true, `${actor} lit un passage avant`);
      await updateDoc(doc(dbOf(env, 'director'), `clubs/c1/members/${uids[actor]}`), { studentIds: arrayRemove('s1') });
      assert.equal(await allowed(() => getDoc(doc(db, 'clubs/c1/students/s1'))), false, `${actor} ne lit plus la fiche`);
      assert.equal(await allowed(() => getDoc(doc(db, 'clubs/c1/attempts/a-g1'))), false, `${actor} ne lit plus un passage`);
    }
  });

  test('qui peut retirer le lien d\'un compte à une fiche : le directeur et l\'administrateur, pas un enseignant, un parent ni un autre club', () =>
    check({
      expectAllowed: MGR,
      run: (db) => updateDoc(doc(db, 'clubs/c1/members/u-guardian'), { studentIds: arrayRemove('s1') }),
      reset: () => put(env, 'clubs/c1/members/u-guardian', member('u-guardian', 'guardian', { groupIds: ['g1'], studentIds: ['s1'] })),
    }));

  test('qui supprime le compte parent ou élève d\'un élève effacé : le directeur et l\'administrateur, pas un enseignant, un parent ni un autre club', async () => {
    for (const [uid, role] of [['u-guardian', 'guardian'], ['u-student', 'student']]) {
      await check({
        expectAllowed: MGR,
        run: (db) => deleteDoc(doc(db, `clubs/c1/members/${uid}`)),
        reset: () => put(env, `clubs/c1/members/${uid}`, member(uid, role, { groupIds: ['g1'], studentIds: ['s1'] })),
      });
    }
  });

  test('qui supprime une fiche, une donnée liée, une appartenance : les gestionnaires seulement', async () => {
    const targets = [
      ['clubs/c1/students/s1', student(['g1'])],
      ['clubs/c1/attempts/a-g1', owned('g1', 's1')],
      ['clubs/c1/acquisitions/q-g1', owned('g1', 's1')],
      ['clubs/c1/assessments/as-g1', owned('g1', 's1', { comment: 'ok' })],
      ['clubs/c1/acknowledgements/k-g1', owned('g1', 's1')],
      ['clubs/c1/memberships/s1_2026-09-01', owned('g1', 's1', { from: '2026-09-01T00:00:00.000' })],
    ];
    for (const [path, data] of targets) {
      await check({
        expectAllowed: path.includes('/students/') || path.includes('/memberships/') ? MGR : [...MGR, 'teacherA'],
        run: (db) => deleteDoc(doc(db, path)),
        reset: () => put(env, path, data),
      });
    }
  });

  test('retirer un élève des présents (arrayRemove) : les gestionnaires et l\'enseignant du groupe', () =>
    check({
      expectAllowed: [...MGR, 'teacherA'],
      run: (db) => updateDoc(doc(db, 'clubs/c1/records/r-g1'), { presentStudentIds: arrayRemove('s1') }),
      reset: () => put(env, 'clubs/c1/records/r-g1', { ...owned('g1'), presentStudentIds: ['s1'] }),
    }));
});

describe('budget des règles : des lots de 400 écritures', () => {
  test('un lot de purge de 400 écritures (suppressions de passages et lien retiré) est accepté', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      for (let i = 0; i < 399; i++) {
        await setDoc(doc(ctx.firestore(), `clubs/c1/attempts/big-${i}`), owned('g1', 's1'));
      }
    });
    for (const actor of MGR) {
      const db = dbOf(env, actor);
      const batch = writeBatch(db);
      for (let i = 0; i < 399; i++) batch.delete(doc(db, `clubs/c1/attempts/big-${i}`));
      batch.update(doc(db, mine(actor)), advance({ done: 2 }));
      await put(env, mine(actor), stored(roleOf(actor), uids[actor], { done: 1, stage: 1 }));
      await batch.commit();
      await env.withSecurityRulesDisabled(async (ctx) => {
        for (let i = 0; i < 399; i++) await setDoc(doc(ctx.firestore(), `clubs/c1/attempts/big-${i}`), owned('g1', 's1'));
      });
    }
  });

  test('un lot de marquage de 390 fiches et du marqueur d\'une clôture est accepté', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      for (let i = 0; i < 390; i++) await setDoc(doc(ctx.firestore(), `clubs/c1/students/big-${i}`), student(['g1']));
    });
    const db = dbOf(env, 'director');
    const batch = writeBatch(db);
    for (let i = 0; i < 390; i++) batch.update(doc(db, `clubs/c1/students/big-${i}`), { erasing: true });
    batch.set(doc(db, mine('director')), created('director', uids.director, { kind: 'closure', stage: 1, ...closureTerms() }));
    await batch.commit();
  });

  test('un lot de reconduction de 400 écritures (appartenances créées et closes, fiches mises à jour) est accepté', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'clubs/c1/seasons/se2'), { label: '2027-2028' });
      for (let i = 0; i < 99; i++) {
        await setDoc(doc(ctx.firestore(), `clubs/c1/students/r-${i}`), student(['g1']));
        await setDoc(doc(ctx.firestore(), `clubs/c1/memberships/g1_r-${i}_2026-09-01`), owned('g1', `r-${i}`, { from: '2026-09-01T00:00:00.000' }));
      }
    });
    const db = dbOf(env, 'director');
    const batch = writeBatch(db);
    batch.set(doc(db, 'clubs/c1/groups/g3'), { seasonId: 'se2', name: 'Mardi', audience: 'children', teacherUids: [], createdAt: serverTimestamp() });
    for (let i = 0; i < 99; i++) {
      batch.set(doc(db, `clubs/c1/memberships/g1_r-${i}_2026-09-01`), owned('g1', `r-${i}`, { from: '2026-09-01T00:00:00.000', to: '2026-08-31T00:00:00.000' }));
      batch.set(doc(db, `clubs/c1/memberships/g3_r-${i}_2027-09-01`), owned('g3', `r-${i}`, { seasonId: 'se2', from: '2027-09-01T00:00:00.000' }));
      batch.update(doc(db, `clubs/c1/students/r-${i}`), { groupIds: ['g1', 'g3'] });
    }
    batch.set(doc(db, mine('director')), created('director', uids.director, { kind: 'closure', stage: 1, ...closureTerms() }));
    await batch.commit();
  });
});

// Convergence entre deux auteurs (directeur et administrateur) qui purgent en même temps la même
// fiche : le second lot supprime des documents que le premier a déjà supprimés (`resource` nul).
describe('deux auteurs purgent la même fiche en même temps', () => {
  const linked = [
    'clubs/c1/attempts/a-g1',
    'clubs/c1/acquisitions/q-g1',
    'clubs/c1/assessments/as-g1',
    'clubs/c1/acknowledgements/k-g1',
    'clubs/c1/memberships/s1_2026-09-01',
  ];

  test('un lot qui supprime des documents DÉJÀ supprimés par l\'autre auteur est accepté (il converge)', async () => {
    for (const actor of MGR) {
      await seed(env);
      await put(env, mine(actor), stored(roleOf(actor), uids[actor], { stage: 1 }));
      // L'autre auteur a déjà tout purgé.
      for (const path of linked) await remove(env, path);
      const db = dbOf(env, actor);
      const batch = writeBatch(db);
      for (const path of linked) batch.delete(doc(db, path));
      batch.delete(doc(db, 'clubs/c1/students/s1'));
      batch.update(doc(db, mine(actor)), advance({ done: 2, stage: 2 }));
      assert.equal(await allowed(() => batch.commit()), true, `${actor} converge`);
    }
  });

  test('supprimer un document ABSENT reste réservé aux gestionnaires (un enseignant ne sonde rien)', async () => {
    for (const path of linked.slice(0, 4)) {
      await remove(env, path);
      await check({ expectAllowed: MGR, run: (db) => deleteDoc(doc(db, path)) });
    }
  });
});

describe('appartenance créée par un gestionnaire sur une fiche en cours d\'effacement', () => {
  const path = 'clubs/c1/memberships/g1_s1_2026-10-01';
  const data = () => owned('g1', 's1', { from: '2026-10-01T00:00:00.000' });
  const reset = () => remove(env, path);

  test('fiche ordinaire : acceptée (témoin)', () =>
    check({ expectAllowed: MGR, run: (db) => setDoc(doc(db, path), data()), reset }));

  test('fiche `erasing` : refusée à tous', async () => {
    await put(env, 'clubs/c1/students/s1', student(['g1'], { erasing: true }));
    await check({ expectAllowed: [], run: (db) => setDoc(doc(db, path), data()), reset });
  });

  test('LIMITE CONNUE : une fiche déjà supprimée ne se distingue pas d\'une fiche jamais créée, l\'appartenance est acceptée', async () => {
    await remove(env, 'clubs/c1/students/s1');
    await check({ expectAllowed: MGR, run: (db) => setDoc(doc(db, path), data()), reset });
  });
});
