// Dépôts Firestore de FB4, partie 3 (passages, blocs acquis, bilans, acquittements) : les MÊMES
// opérations que ceux de l'application, avec les mêmes chemins, champs et requêtes, contre
// l'émulateur et les VRAIES règles, jouées dans chaque rôle.
//
// Les formes sont COPIÉES des tests Dart (`firestore_progress_repositories_test`, « writes exactly
// the fields the rules allow »). Un refus attendu vient des règles, jamais d'une requête mal
// formée : chaque requête interdite à un rôle est celle que le dépôt Dart NE fait PAS pour ce rôle
// (il l'évite, le test prouve qu'elle serait refusée).
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  Timestamp,
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

import { allowed, createEnv, dbOf, seed } from './support.mjs';
import { deleteField } from 'firebase/firestore';

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

// `FirestoreAttemptRepository.add` : un passage NEUF, `createdAt` du serveur, aucun `passIndex`.
const attemptDoc = (extra = {}) => ({
  groupId: 'g1',
  seasonId: 'se1',
  studentId: 's1',
  sessionId: 'x1',
  blockId: 'puissance',
  exerciseNumber: 1,
  date: '2026-10-03T00:00:00.000',
  potted: 4,
  total: 5,
  createdAt: serverTimestamp(),
  recordedAt: Timestamp.fromMillis(Date.now()),
  ...extra,
});
const acquisitionDoc = (extra = {}) => ({
  groupId: 'g1',
  seasonId: 'se1',
  studentId: 's1',
  blockId: 'puissance',
  date: '2026-09-15T00:00:00.000',
  source: 'placement',
  ...extra,
});
const assessmentDoc = (extra = {}) => ({
  groupId: 'g1',
  seasonId: 'se1',
  studentId: 's1',
  date: '2026-10-05T00:00:00.000',
  concentration: 3,
  endurance: 2,
  frustration: 4,
  comment: null,
  ...extra,
});
// `FirestoreAcknowledgementRepository.add` : `createdBy` = uid du compte, à la création seulement.
const acknowledgementDoc = (extra = {}) => ({
  groupId: 'g1',
  seasonId: 'se1',
  studentId: 's1',
  blockId: 'puissance',
  exerciseNumber: 1,
  lastAttemptId: 'a1',
  date: '2026-10-05T00:00:00.000',
  createdBy: 'u-teacher-a',
  ...extra,
});

const list = (actor, path, ...constraints) =>
  allowed(() => getDocs(query(collection(dbOf(env, actor), `${C}/${path}`), ...constraints)));
const where2 = (a, b) => [where(a[0], '==', a[1]), where(b[0], '==', b[1])];

describe('passages : clubs/{c}/attempts/{id}, un document par passage', () => {
  test('création : l\'enseignant du groupe (élève du groupe) ou le directeur, jamais un autre', async () => {
    const create = (actor, data, id = 'n1') =>
      allowed(() => setDoc(doc(dbOf(env, actor), `${C}/attempts/${id}`), data));
    assert.equal(await create('teacherA', attemptDoc()), true, 'enseignant du groupe');
    assert.equal(await create('director', attemptDoc({ groupId: 'g2', studentId: 's2' }), 'n2'), true, 'directeur');
    assert.equal(await create('teacherB', attemptDoc(), 'n3'), false, 'enseignant d\'un autre groupe');
    assert.equal(await create('teacherA', attemptDoc({ studentId: 's2' }), 'n4'), false, 'élève hors du groupe');
    for (const actor of ['guardian', 'student', 'directorOther', 'invited', 'teacherC2']) {
      assert.equal(await create(actor, attemptDoc(), `n-${actor}`), false, actor);
    }
  });

  test('`createdAt` est la date du SERVEUR, exigée : ni absente, ni antidatée', async () => {
    const create = (data) => allowed(() => setDoc(doc(dbOf(env, 'teacherA'), `${C}/attempts/n1`), data));
    const { createdAt, ...bare } = attemptDoc();
    assert.equal(await create(bare), false, 'absente');
    assert.equal(await create(attemptDoc({ createdAt: Timestamp.fromMillis(Date.now() - 86_400_000) })), false, 'antidatée');
    assert.equal(await create(attemptDoc({ createdAt: '2026-10-03T00:00:00.000' })), false, 'texte du client');
    assert.equal(await create(attemptDoc()), true, 'serveur');
  });

  test('plus de `passIndex` : le rang est dérivé, un champ stocké serait refusé', async () => {
    const create = (data) => allowed(() => setDoc(doc(dbOf(env, 'teacherA'), `${C}/attempts/n1`), data));
    assert.equal(await create(attemptDoc({ passIndex: 1 })), false);
    assert.equal(await create(attemptDoc()), true);
  });

  test('ajout seul : rejouer un identifiant existant (mise à jour de `createdAt`) est refusé', async () => {
    const a = dbOf(env, 'teacherA');
    await setDoc(doc(a, `${C}/attempts/n1`), attemptDoc());
    assert.equal(await allowed(() => setDoc(doc(a, `${C}/attempts/n1`), attemptDoc())), false, 'réécrit');
  });

  test('la correction en place ne change que `potted` et `total`', async () => {
    const a = dbOf(env, 'teacherA');
    await setDoc(doc(a, `${C}/attempts/n1`), attemptDoc());
    const update = (actor, patch) => allowed(() => updateDoc(doc(dbOf(env, actor), `${C}/attempts/n1`), patch));
    assert.equal(await update('teacherA', { potted: 5, total: 5 }), true, 'billes');
    assert.equal(await update('director', { potted: 3 }), true, 'directeur');
    for (const patch of [
      { sessionId: 'x2' }, { blockId: 'autre' }, { exerciseNumber: 2 }, { date: '2026-10-04T00:00:00.000' },
      { studentId: 's2' }, { groupId: 'g2' }, { seasonId: 'se2' }, { createdAt: serverTimestamp() }, { note: 'x' },
    ]) {
      assert.equal(await update('teacherA', patch), false, JSON.stringify(Object.keys(patch)));
    }
    for (const actor of ['teacherB', 'guardian', 'student', 'directorOther']) {
      assert.equal(await update(actor, { potted: 1 }), false, actor);
    }
  });

  test('billes bornées : 0 à total, total de 1 à 16 (les bornes du domaine)', async () => {
    const create = (extra, id) => allowed(() => setDoc(doc(dbOf(env, 'teacherA'), `${C}/attempts/${id}`), attemptDoc(extra)));
    assert.equal(await create({ potted: 16, total: 16 }, 'n1'), true);
    assert.equal(await create({ potted: 17, total: 17 }, 'n1b'), false, 'total au-delà de 16');
    // La borne haute de `total` ISOLÉE : `potted` reste dans ses bornes et sous `total`.
    assert.equal(await create({ potted: 5, total: 17 }, 'n1c'), false, 'total = 17 seul hors borne');
    assert.equal(await create({ potted: 17, total: 16 }, 'n1d'), false, 'potted = total + 1');
    assert.equal(await create({ potted: 0, total: 1 }, 'n1e'), true, 'bornes basses');
    assert.equal(await create({ potted: 101 }, 'n2'), false);
    assert.equal(await create({ potted: -1 }, 'n3'), false);
    assert.equal(await create({ total: 101 }, 'n4'), false);
    assert.equal(await create({ potted: 6, total: 5 }, 'n5'), false, 'plus de billes que de tentatives');
    assert.equal(await create({ potted: 0, total: 0 }, 'n6'), false, 'total nul');
  });

  test('un passage est COMPLET à la création : chaque champ que le codec lit est exigé', async () => {
    const create = (data, id) => allowed(() => setDoc(doc(dbOf(env, 'teacherA'), `${C}/attempts/${id}`), data));
    const minimal = { groupId: 'g1', seasonId: 'se1', studentId: 's1', createdAt: serverTimestamp() };
    assert.equal(await create(minimal, 'm0'), false, 'passage minimal');
    for (const field of ['sessionId', 'blockId', 'exerciseNumber', 'date', 'potted', 'total', 'recordedAt']) {
      const { [field]: _omitted, ...without } = attemptDoc();
      assert.equal(await create(without, `m-${field}`), false, `sans ${field}`);
      assert.equal(await create(attemptDoc({ [field]: null }), `n-${field}`), false, `${field} nul`);
    }
    assert.equal(await create(attemptDoc(), 'ok'), true);
  });

  test('`recordedAt` (ordre de saisie de l\'appareil) est figé après la création', async () => {
    const a = dbOf(env, 'teacherA');
    await setDoc(doc(a, `${C}/attempts/n1`), attemptDoc());
    const update = (patch) => allowed(() => updateDoc(doc(a, `${C}/attempts/n1`), patch));
    assert.equal(await update({ recordedAt: Timestamp.fromMillis(1) }), false);
  });

  test('une mise à jour ne vide, ne supprime ni n\'invalide `potted` / `total`', async () => {
    const a = dbOf(env, 'teacherA');
    await setDoc(doc(a, `${C}/attempts/n1`), attemptDoc());
    const update = (patch) => allowed(() => updateDoc(doc(a, `${C}/attempts/n1`), patch));
    assert.equal(await update({ potted: null }), false, 'potted nul');
    assert.equal(await update({ potted: deleteField() }), false, 'potted supprimé');
    assert.equal(await update({ total: deleteField() }), false, 'total supprimé');
    assert.equal(await update({ potted: 50, total: 1 }), false, 'plus de billes que de tentatives');
    assert.equal(await update({ potted: 5 }), true, 'une correction valide');
  });

  test('un document ABSENT se lit (lecture avant écriture) : directeur, enseignant du groupe ; jamais la famille', async () => {
    for (const name of ['attempts', 'acquisitions', 'assessments', 'acknowledgements']) {
      const get = (actor) => allowed(() => getDoc(doc(dbOf(env, actor), `${C}/${name}/ghost`)));
      assert.equal(await get('director'), true, `${name} : directeur`);
      assert.equal(await get('teacherA'), true, `${name} : enseignant`);
      assert.equal(await get('guardian'), false, `${name} : parent`);
      assert.equal(await get('student'), false, `${name} : élève`);
      assert.equal(await get('directorOther'), false, `${name} : autre club`);
    }
  });

  test('un enseignant lit puis crée un bloc acquis, un bilan ou un « Vu » (le chemin du dépôt)', async () => {
    const t = dbOf(env, 'teacherA');
    const flow = async (name, data) => {
      const ref = doc(t, `${C}/${name}/fresh`);
      assert.equal(await allowed(() => getDoc(ref)), true, `${name} : lecture de l'absent`);
      assert.equal(await allowed(() => setDoc(ref, data, merge)), true, `${name} : création`);
    };
    await flow('acquisitions', acquisitionDoc());
    await flow('assessments', assessmentDoc());
    await flow('acknowledgements', acknowledgementDoc());
  });

  test('bloc acquis, bilan, « Vu » : complets à la création, jamais vidés ensuite', async () => {
    const t = dbOf(env, 'teacherA');
    const create = (name, data, id) => allowed(() => setDoc(doc(t, `${C}/${name}/${id}`), data, merge));
    const base = { groupId: 'g1', seasonId: 'se1', studentId: 's1' };
    assert.equal(await create('acquisitions', base, 'z1'), false, 'bloc acquis minimal');
    assert.equal(await create('assessments', base, 'z2'), false, 'bilan minimal');
    assert.equal(await create('acknowledgements', { ...base, createdBy: 'u-teacher-a' }, 'z3'), false, '« Vu » minimal');
    assert.equal(await create('acquisitions', acquisitionDoc({ source: null }), 'z4'), false, 'source nulle');
    assert.equal(await create('assessments', assessmentDoc({ concentration: null }), 'z5'), false, 'note nulle');
    assert.equal(await create('acknowledgements', acknowledgementDoc({ lastAttemptId: null }), 'z6'), false, 'dernier passage nul');
    await setDoc(doc(t, `${C}/acquisitions/z7`), acquisitionDoc());
    assert.equal(await allowed(() => updateDoc(doc(t, `${C}/acquisitions/z7`), { blockId: deleteField() })), false, 'champ supprimé');
    assert.equal(await allowed(() => updateDoc(doc(t, `${C}/acquisitions/z7`), { date: null })), false, 'champ nul');
  });

  test('une mise à jour ne supprime ni ne vide un champ d\'un bilan ou d\'un « Vu » (`noFieldLost`)', async () => {
    const t = dbOf(env, 'teacherA');
    await setDoc(doc(t, `${C}/assessments/nf1`), assessmentDoc({ comment: 'Concentré' }));
    await setDoc(doc(t, `${C}/acknowledgements/nf2`), acknowledgementDoc());
    const update = (name, id, patch) => allowed(() => updateDoc(doc(t, `${C}/${name}/${id}`), patch));
    for (const field of ['date', 'concentration', 'endurance', 'frustration', 'comment']) {
      assert.equal(await update('assessments', 'nf1', { [field]: deleteField() }), false, `bilan : ${field} supprimé`);
    }
    for (const field of ['blockId', 'exerciseNumber', 'lastAttemptId', 'date', 'createdBy']) {
      assert.equal(await update('acknowledgements', 'nf2', { [field]: deleteField() }), false, `« Vu » : ${field} supprimé`);
    }
    // Une mise à jour qui garde tous les champs reste permise.
    assert.equal(await update('assessments', 'nf1', { concentration: 1 }), true, 'bilan : note changée');
    assert.equal(await update('acknowledgements', 'nf2', { lastAttemptId: 'a9' }), true, '« Vu » : remplacé');
  });

  test('lecture par rôle : l\'enseignant par groupe (avec élève ou séance), la famille par fiche liée', async () => {
    const a = dbOf(env, 'teacherA');
    await setDoc(doc(a, `${C}/attempts/n1`), attemptDoc());
    // Le directeur : tout le club, ou une égalité.
    assert.equal(await list('director', 'attempts'), true, 'directeur : liste');
    assert.equal(await list('director', 'attempts', where('studentId', '==', 's1')), true, 'directeur : élève');
    assert.equal(await list('director', 'attempts', where('sessionId', '==', 'x1')), true, 'directeur : séance');
    // L'enseignant : jamais sans prouver le groupe.
    assert.equal(await list('teacherA', 'attempts', where('groupId', '==', 'g1')), true, 'groupe');
    assert.equal(await list('teacherA', 'attempts', ...where2(['groupId', 'g1'], ['studentId', 's1'])), true, 'groupe et élève');
    assert.equal(await list('teacherA', 'attempts', ...where2(['groupId', 'g1'], ['sessionId', 'x1'])), true, 'groupe et séance');
    assert.equal(await list('teacherA', 'attempts', where('groupId', '==', 'g2')), false, 'groupe d\'un autre');
    assert.equal(await list('teacherA', 'attempts', where('studentId', '==', 's1')), false, 'élève seul : refusé');
    assert.equal(await list('teacherA', 'attempts', where('sessionId', '==', 'x1')), false, 'séance seule : refusé');
    assert.equal(await list('teacherA', 'attempts'), false, 'sans filtre');
    // La famille : sa fiche liée seulement.
    for (const actor of ['guardian', 'student']) {
      assert.equal(await list(actor, 'attempts', where('studentId', '==', 's1')), true, `${actor} : sa fiche`);
      assert.equal(await list(actor, 'attempts', ...where2(['studentId', 's1'], ['sessionId', 'x1'])), true, `${actor} : fiche et séance`);
      assert.equal(await list(actor, 'attempts', where('studentId', '==', 's2')), false, `${actor} : une autre fiche`);
      assert.equal(await list(actor, 'attempts', where('groupId', '==', 'g1')), false, `${actor} : par groupe`);
      assert.equal(await list(actor, 'attempts'), false, `${actor} : sans filtre`);
    }
    assert.equal(await list('guardian2', 'attempts', where('studentId', '==', 's2')), true);
    assert.equal(await list('invited', 'attempts', where('studentId', '==', 's1')), false, 'un invité');
    assert.equal(await list('directorOther', 'attempts'), false, 'un autre club');
  });

  test('suppression : le directeur et l\'enseignant du groupe ; aucun autre passage n\'est réécrit', async () => {
    const a = dbOf(env, 'teacherA');
    await setDoc(doc(a, `${C}/attempts/n1`), attemptDoc());
    await setDoc(doc(a, `${C}/attempts/n2`), attemptDoc({ potted: 3 }));
    const before2 = (await getDoc(doc(a, `${C}/attempts/n2`))).data();
    for (const actor of ['guardian', 'student', 'teacherB', 'directorOther']) {
      assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, actor), `${C}/attempts/n1`))), false, actor);
    }
    assert.equal(await allowed(() => deleteDoc(doc(a, `${C}/attempts/n1`))), true);
    assert.deepEqual((await getDoc(doc(a, `${C}/attempts/n2`))).data(), before2, 'le rang est dérivé : rien à renuméroter');
  });

  test('deux passages enregistrés au même instant ont la même date : l\'identifiant seul les ordonne', async () => {
    // Un même lot : `request.time` identique (le cas limite de deux appareils simultanés).
    const a = dbOf(env, 'teacherA');
    const batch = writeBatch(a);
    batch.set(doc(a, `${C}/attempts/zz`), attemptDoc({ potted: 1 }));
    batch.set(doc(a, `${C}/attempts/aa`), attemptDoc({ potted: 2 }));
    await batch.commit();
    const read = async (actor) =>
      (await getDocs(query(collection(dbOf(env, actor), `${C}/attempts`), where('studentId', '==', 's1'), where('groupId', '==', 'g1'))))
        .docs.filter((d) => d.id === 'zz' || d.id === 'aa');
    const first = await read('teacherA');
    const stamps = first.map((d) => d.data().createdAt.toMillis());
    assert.equal(stamps[0], stamps[1], 'même instant du serveur');
    // Le tri (createdAt, id) des deux appareils est celui des identifiants.
    const order = (docs) => docs.map((d) => [d.data().createdAt.toMillis(), d.id]).sort((x, y) => x[0] - y[0] || x[1].localeCompare(y[1])).map((x) => x[1]);
    assert.deepEqual(order(first), ['aa', 'zz']);
    assert.deepEqual(order(await read('teacherA')), order(first));
  });
});

describe('dates : le texte exact des codecs, jamais un texte quelconque (perte silencieuse sinon)', () => {
  const t = () => dbOf(env, 'teacherA');
  const make = (name, doc_, id) => allowed(() => setDoc(doc(t(), `${C}/${name}/${id}`), doc_, merge));
  const shapes = {
    attempts: (date) => attemptDoc({ date }),
    acquisitions: (date) => acquisitionDoc({ date }),
    assessments: (date) => assessmentDoc({ date }),
    acknowledgements: (date) => acknowledgementDoc({ date }),
  };

  test('`date` : ISO 8601 de `toIso8601String` (local, UTC, microsecondes) ou horodatage', async () => {
    for (const [name, build] of Object.entries(shapes)) {
      let i = 0;
      for (const ok of ['2026-10-03T00:00:00.000', '2026-10-03T08:15:30.123456Z', '2026-10-03T08:15:30', '2026-12-31T23:59:59', '2026-01-01T00:00:00Z', Timestamp.fromMillis(1_790_000_000_000)]) {
        assert.equal(await make(name, build(ok), `d-${i++}`), true, `${name} : ${String(ok)}`);
      }
      i = 0;
      for (const bad of ['zz', '2026-10-03', 'hier', '2026-10-03T00:00:00+02:00', '2026-10-03 00:00:00.000', '2026-10-03T00:00:00.1234567', ' 2026-10-03T00:00:00', 'x'.repeat(41), '2026-13-01T00:00:00', '2026-00-10T00:00:00', '2026-10-32T00:00:00', '2026-10-00T00:00:00', '2026-10-03T24:00:00', '2026-10-03T10:60:00', '2026-10-03T10:00:60', 7, true]) {
        assert.equal(await make(name, build(bad), `e-${i++}`), false, `${name} : ${String(bad)}`);
      }
    }
  });

  test('`recordedAt` est une date lisible, pas un texte quelconque', async () => {
    const create = (recordedAt, id) => allowed(() => setDoc(doc(t(), `${C}/attempts/${id}`), attemptDoc({ recordedAt })));
    assert.equal(await create('zz', 'r1'), false);
    assert.equal(await create('2026-10-03T00:00:00.000', 'r2'), true);
  });

  test('une mise à jour ne remplace pas la date d\'un bilan par un texte quelconque', async () => {
    await setDoc(doc(t(), `${C}/assessments/dd1`), assessmentDoc());
    assert.equal(await allowed(() => updateDoc(doc(t(), `${C}/assessments/dd1`), { date: 'zz' })), false);
    assert.equal(await allowed(() => updateDoc(doc(t(), `${C}/assessments/dd1`), { date: '2026-10-06T00:00:00.000' })), true);
  });
});

describe('blocs acquis : clubs/{c}/acquisitions/{id}', () => {
  test('écriture : l\'enseignant du groupe (élève du groupe) ou le directeur ; remplacement chez le même propriétaire', async () => {
    const create = (actor, data, id = 'q1') => allowed(() => setDoc(doc(dbOf(env, actor), `${C}/acquisitions/${id}`), data, merge));
    assert.equal(await create('teacherA', acquisitionDoc()), true);
    assert.equal(await create('teacherA', acquisitionDoc({ blockId: 'posture' })), true, 'remplacement (fusion)');
    assert.equal(await create('director', acquisitionDoc({ groupId: 'g2', studentId: 's2' }), 'q2'), true);
    assert.equal(await create('teacherB', acquisitionDoc(), 'q3'), false, 'autre groupe');
    assert.equal(await create('teacherA', acquisitionDoc({ studentId: 's2' }), 'q4'), false, 'élève hors groupe');
    assert.equal(await create('teacherA', acquisitionDoc({ groupId: 'g2' }), 'q1'), false, 'le propriétaire ne change pas');
    assert.equal(await create('teacherA', acquisitionDoc({ source: 'autre' }), 'q5'), false, 'source inconnue');
    for (const actor of ['guardian', 'student']) assert.equal(await create(actor, acquisitionDoc(), 'q6'), false, actor);
  });

  test('lecture : la famille lit les blocs acquis de SA fiche liée (GetStudentShowcase), jamais d\'une autre', async () => {
    assert.equal(await list('guardian', 'acquisitions', where('studentId', '==', 's1')), true);
    assert.equal(await list('student', 'acquisitions', where('studentId', '==', 's1')), true);
    assert.equal(await list('guardian', 'acquisitions', where('studentId', '==', 's2')), false);
    assert.equal(await list('guardian', 'acquisitions'), false, 'sans filtre');
    assert.equal(await list('teacherA', 'acquisitions', ...where2(['groupId', 'g1'], ['studentId', 's1'])), true);
    assert.equal(await list('teacherA', 'acquisitions', where('studentId', '==', 's1')), false, 'élève seul pour un enseignant');
    assert.equal(await list('teacherB', 'acquisitions', where('groupId', '==', 'g1')), false);
    assert.equal(await list('director', 'acquisitions'), true);
  });

  test('suppression : le directeur et l\'enseignant du groupe', async () => {
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'guardian'), `${C}/acquisitions/q-g1`))), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'teacherB'), `${C}/acquisitions/q-g1`))), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'teacherA'), `${C}/acquisitions/q-g1`))), true);
  });
});

describe('bilans : clubs/{c}/assessments/{id}', () => {
  test('écriture : l\'enseignant du groupe ou le directeur ; remarque effacée par fusion de `null`', async () => {
    const write = (actor, data, id = 'b1') => allowed(() => setDoc(doc(dbOf(env, actor), `${C}/assessments/${id}`), data, merge));
    assert.equal(await write('teacherA', assessmentDoc({ comment: 'Concentré' })), true);
    assert.equal(await write('teacherA', assessmentDoc({ comment: null })), true, 'remarque retirée');
    assert.equal((await getDoc(doc(dbOf(env, 'teacherA'), `${C}/assessments/b1`))).data().comment, null);
    assert.equal(await write('director', assessmentDoc({ groupId: 'g2', studentId: 's2' }), 'b2'), true);
    assert.equal(await write('teacherB', assessmentDoc(), 'b3'), false);
    assert.equal(await write('teacherA', assessmentDoc({ concentration: 5 }), 'b4'), false, 'note de 1 à 4');
    assert.equal(await write('teacherA', assessmentDoc({ comment: 'a'.repeat(501) }), 'b5'), false, '500 caractères au plus');
    for (const actor of ['guardian', 'student']) assert.equal(await write(actor, assessmentDoc(), 'b6'), false, actor);
  });

  test('lecture : JAMAIS la famille (bilans exclus, B2), l\'enseignant par groupe', async () => {
    for (const actor of ['guardian', 'student', 'guardian2']) {
      assert.equal(await list(actor, 'assessments', where('studentId', '==', 's1')), false, `${actor} par fiche`);
      assert.equal(await list(actor, 'assessments', where('groupId', '==', 'g1')), false, `${actor} par groupe`);
      assert.equal(await allowed(() => getDoc(doc(dbOf(env, actor), `${C}/assessments/as-g1`))), false, `${actor} get`);
    }
    assert.equal(await list('teacherA', 'assessments', where('groupId', '==', 'g1')), true);
    assert.equal(await list('teacherA', 'assessments', ...where2(['groupId', 'g1'], ['studentId', 's1'])), true);
    assert.equal(await list('teacherA', 'assessments', where('studentId', '==', 's1')), false);
    assert.equal(await list('teacherB', 'assessments', where('groupId', '==', 'g1')), false);
    assert.equal(await list('director', 'assessments'), true);
  });
});

describe('acquittements : clubs/{c}/acknowledgements/{id}, « Vu » partagé par club avec uid', () => {
  test('création : `createdBy` est l\'uid du compte, pas celui d\'un collègue', async () => {
    const create = (actor, data, id = 'k1') => allowed(() => setDoc(doc(dbOf(env, actor), `${C}/acknowledgements/${id}`), data, merge));
    assert.equal(await create('teacherA', acknowledgementDoc()), true, 'son uid');
    assert.equal(await create('teacherA', acknowledgementDoc({ createdBy: 'u-dir' }), 'k2'), false, 'au nom du directeur');
    const { createdBy, ...bare } = acknowledgementDoc();
    assert.equal(await create('teacherA', bare, 'k3'), false, 'sans uid');
    assert.equal(await create('director', acknowledgementDoc({ createdBy: 'u-dir' }), 'k4'), true, 'directeur');
    assert.equal(await create('teacherB', acknowledgementDoc({ createdBy: 'u-teacher-b' }), 'k5'), false, 'autre groupe');
    assert.equal(await create('guardian', acknowledgementDoc({ createdBy: 'u-guardian' }), 'k6'), false, 'famille');
  });

  test('l\'uid ne se réécrit pas : un remplacement garde celui du premier « Vu »', async () => {
    await setDoc(doc(dbOf(env, 'teacherA'), `${C}/acknowledgements/k1`), acknowledgementDoc());
    const { createdBy, ...replacement } = acknowledgementDoc({ lastAttemptId: 'a2' });
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'director'), `${C}/acknowledgements/k1`), replacement, merge)), true, 'remplacement sans uid');
    assert.equal(await allowed(() => setDoc(doc(dbOf(env, 'director'), `${C}/acknowledgements/k1`), { createdBy: 'u-dir' }, merge)), false, 'uid réécrit');
    assert.equal((await getDoc(doc(dbOf(env, 'teacherA'), `${C}/acknowledgements/k1`))).data().createdBy, 'u-teacher-a');
  });

  test('partagé par club : le directeur et l\'enseignant du groupe le lisent ; la famille jamais', async () => {
    await setDoc(doc(dbOf(env, 'teacherA'), `${C}/acknowledgements/k1`), acknowledgementDoc());
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'director'), `${C}/acknowledgements/k1`))), true);
    assert.equal(await list('teacherA', 'acknowledgements', where('groupId', '==', 'g1')), true);
    assert.equal(await list('teacherA', 'acknowledgements', ...where2(['groupId', 'g1'], ['studentId', 's1'])), true);
    assert.equal(await list('teacherB', 'acknowledgements', where('groupId', '==', 'g1')), false);
    for (const actor of ['guardian', 'student']) {
      assert.equal(await list(actor, 'acknowledgements', where('studentId', '==', 's1')), false, actor);
      assert.equal(await allowed(() => getDoc(doc(dbOf(env, actor), `${C}/acknowledgements/k1`))), false, `${actor} get`);
    }
  });

  test('suppression : le directeur et l\'enseignant du groupe (eraseAll d\'un gestionnaire : liste puis suppression)', async () => {
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'guardian'), `${C}/acknowledgements/k-g1`))), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'teacherB'), `${C}/acknowledgements/k-g1`))), false);
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'teacherA'), `${C}/acknowledgements/k-g1`))), true);
    assert.equal(await list('director', 'acknowledgements'), true, 'le directeur liste le club');
    assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, 'director'), `${C}/acknowledgements/k-g2`))), true);
  });
});
