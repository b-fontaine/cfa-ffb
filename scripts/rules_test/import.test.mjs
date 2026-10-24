// Import d'une sauvegarde dans un club (FB7, partie A, ADR 0024 décision 19 et C2) : les
// ÉCRITURES DU PLAN, jouées contre l'émulateur Firestore et les VRAIES règles, avec les vrais
// rôles. Les écritures viennent de l'application elle-même : `app/tool/import_plan_fixture.dart`
// (appelé par scripts/rules_test.sh, dossier IMPORT_PLAN_DIR) applique le planificateur de
// l'application à des sauvegardes FICTIVES et écrit, lot par lot, les mêmes documents que
// l'application enverrait (mêmes codecs, mêmes champs), marqueur d'import non compris : le
// marqueur est construit ici, avec la forme que `ClubImportRunner` lui donne.
//
// Ce que ce fichier prouve, règles réelles à l'appui :
//   1. un directeur et un administrateur importent un fichier de plus de 1500 écritures, lot par
//      lot (jamais plus de 400 écritures marqueur compris), et la relecture complète des
//      collections est identique au plan ; les passages se relisent dans l'ordre du fichier ;
//   2. un enseignant importe dans SON groupe seulement ; il n'écrit ni saison ni groupe, ni dans
//      le groupe d'un autre, ni la fiche d'un élève dont l'appartenance n'est pas la sienne ;
//   3. le MIROIR du plan : ce que le plan dit permis à un enseignant est accepté, ce qu'il dit
//      refusé est refusé (et accepté du directeur : l'écriture est bien formée) ;
//   4. la CONVERGENCE : un lot rejoué, sauté ou réécrit est refusé en bloc par le marqueur ; la
//      reprise après N lots donne le même club qu'un import sans coupure.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  Timestamp,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  where,
  writeBatch,
} from 'firebase/firestore';

import { allowed, createEnv, dbOf, member, put } from './support.mjs';

const planDir = process.env.IMPORT_PLAN_DIR;
assert.ok(planDir, 'IMPORT_PLAN_DIR absent : lancer ces tests par scripts/rules_test.sh');
const load = (name) => JSON.parse(readFileSync(resolve(planDir, name), 'utf8'));
const director = load('director.json');
const teacher = load('teacher.json');
const teacherLarge = load('teacher-large.json');
const scope = load('teacher-scope.json');

let env;
before(async () => {
  env = await createEnv();
});
after(async () => {
  await env?.cleanup();
});

const ACTOR_UID = { director: 'u-dir', admin: 'u-admin', teacherA: 'u-teacher-a', teacherB: 'u-teacher-b' };
const ROLE = { director: 'director', admin: 'admin', teacherA: 'teacher', teacherB: 'teacher' };

/** Un club `c1` sans donnée : un directeur, deux enseignants (g1 et g2), un administrateur. */
const seedClub = async ({ groups = false } = {}) => {
  await env.clearFirestore();
  const docs = [
    ['admins/u-admin', {}],
    ['clubs/c1', { name: 'Club un', createdAt: Timestamp.fromMillis(Date.now() - 86400000) }],
    ['clubs/c1/members/u-dir', member('u-dir', 'director')],
    ['clubs/c1/members/u-teacher-a', member('u-teacher-a', 'teacher', { groupIds: ['g1'] })],
    ['clubs/c1/members/u-teacher-b', member('u-teacher-b', 'teacher', { groupIds: ['g2'] })],
  ];
  if (groups) {
    docs.push(
      ['clubs/c1/seasons/se1', { label: '2026-2027' }],
      ['clubs/c1/groups/g1', { seasonId: 'se1', name: 'Mardi', audience: 'children', teacherUids: ['u-teacher-a'] }],
      ['clubs/c1/groups/g2', { seasonId: 'se1', name: 'Jeudi', audience: 'adults', teacherUids: ['u-teacher-b'] }],
    );
  }
  for (const [path, data] of docs) await put(env, path, data);
};

// ───────────────────────── Lecture du plan ─────────────────────────

/** `AAAA-MM-JJThh:mm:ss.ffffffZ` en horodatage, microsecondes conservées. */
const toTimestamp = (iso) => {
  const [head, fraction = ''] = iso.replace('Z', '').split('.');
  const seconds = Math.floor(Date.parse(`${head}Z`) / 1000);
  return new Timestamp(seconds, Number(fraction.padEnd(9, '0').slice(0, 9)));
};

/** Valeurs du plan en valeurs du SDK ; `importer` devient l'uid de l'acteur. */
const decode = (value, uid) => {
  if (Array.isArray(value)) return value.map((v) => decode(v, uid));
  if (value && typeof value === 'object') {
    if (value.$serverTimestamp) return serverTimestamp();
    if (value.$arrayUnion) return arrayUnion(...value.$arrayUnion.map((v) => decode(v, uid)));
    if (value.$date) return toTimestamp(value.$date);
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, decode(v, uid)]));
  }
  return value === 'u-importer' ? uid : value;
};

const queue = (batch, db, op, uid) => {
  const ref = doc(db, op.path);
  const fields = op.fields ? decode(op.fields, uid) : undefined;
  if (op.kind === 'set') batch.set(ref, fields);
  else if (op.kind === 'merge') batch.set(ref, fields, { merge: true });
  else if (op.kind === 'update') batch.update(ref, fields);
  else if (op.kind === 'delete') batch.delete(ref);
  else throw new Error(`opération inconnue ${op.kind}`);
};

/** Le marqueur d'un lot, tel que `FirestoreClubImportStore.commit` l'écrit. */
const markerPath = (plan, uid) => `clubs/c1/imports/${plan.fileId}_${uid}`;

const markerOps = (plan, index, role, uid) => {
  const path = markerPath(plan, uid);
  const done = index + 1;
  const state = done === plan.lotCount ? 'done' : 'running';
  return index === 0
    ? {
        kind: 'set',
        path,
        fields: {
          fileId: plan.fileId, planId: plan.planId, lots: plan.lotCount, done, writes: plan.writes,
          restored: 0, role, createdBy: uid, state, startedAt: { $serverTimestamp: true }, updatedAt: { $serverTimestamp: true },
        },
      }
    : { kind: 'update', path, fields: { done, state, updatedAt: { $serverTimestamp: true } } };
};

/**
 * Applique le lot [index] du plan [plan] (écritures et marqueur dans UN lot atomique).
 * [markerIndex] fausse l'avancement du marqueur (un lot sauté) : par défaut, le bon.
 * [limit] ne garde que les premières écritures : l'émulateur met un temps considérable à
 * REFUSER un lot de 400 créations (il détaille l'évaluation de chacune) ; un refus se prouve
 * sur un extrait, pas sur le lot entier (le rejeu d'un lot existant, lui, est instantané).
 */
const applyLot = async (plan, index, actor, markerIndex = index, limit = Infinity) => {
  const uid = ACTOR_UID[actor];
  const db = dbOf(env, actor);
  const lot = plan.lots[index];
  assert.ok(lot.ops.length + 1 <= 400, `lot ${index} : ${lot.ops.length + 1} écritures, au plus 400`);
  return allowed(async () => {
    const batch = writeBatch(db);
    for (const op of lot.ops.slice(0, limit)) queue(batch, db, op, uid);
    queue(batch, db, markerOps(plan, markerIndex, ROLE[actor], uid), uid);
    await batch.commit();
  });
};

const applyRange = async (plan, from, to, actor) => {
  for (let i = from; i < to; i += 1) {
    assert.equal(await applyLot(plan, i, actor), true, `lot ${i} accepté pour ${actor}`);
  }
};

/** Applique des écritures isolées (sans marqueur) ; `true` si le lot est accepté. */
const applyOps = async (ops, actor) => {
  const db = dbOf(env, actor);
  return allowed(async () => {
    const batch = writeBatch(db);
    for (const op of ops) queue(batch, db, op, ACTOR_UID[actor]);
    await batch.commit();
  });
};

/** En cas de refus d'un lot qui devait passer : les écritures qui le sont une à une (diagnostic). */
const refusedOps = async (ops, actor) => {
  const refused = [];
  for (const op of ops) if (!(await applyOps([op], actor))) refused.push(op.path);
  return refused;
};

// ───────────────────────── Relecture ─────────────────────────

const COLLECTIONS = ['seasons', 'groups', 'students', 'memberships', 'archives', 'sessions', 'records',
  'attempts', 'acquisitions', 'assessments', 'acknowledgements'];

const millis = (t) => `${t.seconds}.${String(t.nanoseconds).padStart(9, '0')}`;

/** Champs comparables : les horodatages du plan en nombres, ceux du serveur en « serveur ». */
const normalizeExpected = (value, uid) => {
  if (Array.isArray(value)) return value.map((v) => normalizeExpected(v, uid));
  if (value && typeof value === 'object') {
    if (value.$serverTimestamp) return '<serveur>';
    if (value.$date) return millis(toTimestamp(value.$date));
    if (value.$arrayUnion) return value.$arrayUnion.map((v) => normalizeExpected(v, uid));
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, normalizeExpected(v, uid)]));
  }
  return value === 'u-importer' ? uid : value;
};
/** `createdBy` d'un acquittement : le compte qui a écrit CE lot (une reprise change d'auteur). */
const anyAuthor = (data) => ('createdBy' in data ? { ...data, createdBy: '<auteur>' } : data);
const normalizeActual = (value, expected) => {
  if (Array.isArray(value)) return value.map((v, i) => normalizeActual(v, expected?.[i]));
  if (value instanceof Timestamp) return expected === '<serveur>' ? '<serveur>' : millis(value);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, normalizeActual(v, expected?.[k])]));
  }
  return value;
};

/** Ce que le plan a écrit : chemin → champs attendus (création, `groupIds` d'une fusion comprise). */
const expectedDocs = (plan, uid) => {
  const expected = new Map();
  for (const lot of plan.lots) {
    for (const op of lot.ops) {
      if (op.kind !== 'set') continue;
      expected.set(op.path, normalizeExpected(op.fields, uid));
    }
  }
  return expected;
};

const readClub = async (actor) => {
  const db = dbOf(env, actor);
  const found = new Map();
  for (const name of COLLECTIONS) {
    for (const snapshot of (await getDocs(collection(db, `clubs/c1/${name}`))).docs) {
      found.set(snapshot.ref.path, snapshot.data());
    }
  }
  return found;
};

const assertSameAsPlan = async (plan, actor, { anyUid = false } = {}) => {
  const uid = ACTOR_UID[actor];
  const expected = expectedDocs(plan, uid);
  const found = await readClub('director');
  assert.deepEqual([...found.keys()].sort(), [...expected.keys()].sort(), 'mêmes documents que le plan');
  for (const [path, fields] of expected) {
    const wanted = anyUid ? anyAuthor(fields) : fields;
    const actual = anyUid ? anyAuthor(found.get(path)) : found.get(path);
    assert.deepEqual(normalizeActual(actual, wanted), wanted, path);
  }
  return found;
};

/** Les passages dans l'ordre que l'application leur donne : date serveur, recordedAt, identifiant. */
const attemptOrder = (found) =>
  [...found.entries()]
    .filter(([path]) => path.includes('/attempts/'))
    .map(([path, data]) => ({ id: path.split('/').pop(), createdAt: millis(data.createdAt), recordedAt: millis(data.recordedAt) }))
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt) || a.recordedAt.localeCompare(b.recordedAt) || a.id.localeCompare(b.id))
    .map((a) => a.id);

const planAttemptOrder = (plan) =>
  plan.lots.flatMap((lot) => lot.ops).filter((op) => op.path.includes('/attempts/')).map((op) => op.path.split('/').pop());

/** Le marqueur de [owner] (par défaut l'acteur qui le lit : on ne lit que le sien). */
const readMarker = async (plan, actor = 'director', owner = actor) =>
  (await getDoc(doc(dbOf(env, actor), markerPath(plan, ACTOR_UID[owner])))).data();

// ───────────────────────── Le plan lui-même ─────────────────────────

describe('le plan jeu de données', () => {
  test('le fichier du directeur compte plus de 1500 écritures, en lots de 400 marqueur compris au plus', () => {
    assert.ok(director.writes >= 1500, `${director.writes} écritures`);
    assert.ok(director.lotCount >= 4);
    assert.equal(director.lots.reduce((n, lot) => n + lot.ops.length, 0), director.writes);
    for (const lot of director.lots) assert.ok(lot.ops.length + 1 <= 400);
    assert.equal(director.status, 'ready');
  });
});

// ───────────────────────── Directeur et administrateur ─────────────────────────

describe('un gestionnaire importe un club entier', () => {
  for (const actor of ['director', 'admin']) {
    test(`${actor} : tous les lots sont acceptés, la relecture est celle du plan, l'ordre des passages est celui du fichier`, async () => {
      await seedClub();
      await applyRange(director, 0, director.lotCount, actor);
      const found = await assertSameAsPlan(director, actor);
      assert.deepEqual(attemptOrder(found), planAttemptOrder(director));
      const marker = await readMarker(director, actor);
      assert.equal(marker.done, director.lotCount);
      assert.equal(marker.state, 'done');
      assert.equal(marker.role, ROLE[actor]);
      assert.deepEqual(Object.keys(marker).sort(), [
        'createdBy', 'done', 'fileId', 'lots', 'planId', 'restored', 'role', 'startedAt', 'state', 'updatedAt',
        'writes',
      ]);
      assert.equal(marker.createdBy, ACTOR_UID[actor]);
    });
  }

  test('un acquittement porte l\'uid de celui qui importe', async () => {
    await seedClub();
    await applyRange(director, 0, director.lotCount, 'admin');
    const found = await readClub('director');
    const acknowledgements = [...found.entries()].filter(([path]) => path.includes('/acknowledgements/'));
    assert.ok(acknowledgements.length > 0);
    for (const [, data] of acknowledgements) assert.equal(data.createdBy, 'u-admin');
  });

  test('createdAt est la date du serveur du lot : identique dans un lot, croissante d\'un lot à l\'autre', async () => {
    await seedClub();
    await applyRange(director, 0, director.lotCount, 'director');
    const found = await readClub('director');
    const dates = new Map();
    director.lots.forEach((lot, index) => {
      for (const op of lot.ops) {
        if (op.path.includes('/attempts/')) dates.set(index, new Set([...(dates.get(index) ?? []), millis(found.get(op.path).createdAt)]));
      }
    });
    const perLot = [...dates.entries()].sort((a, b) => a[0] - b[0]);
    assert.ok(perLot.length >= 2);
    for (const [, set] of perLot) assert.equal(set.size, 1, 'une seule date serveur par lot');
    for (let i = 1; i < perLot.length; i += 1) {
      assert.ok([...perLot[i][1]][0] > [...perLot[i - 1][1]][0], 'la date du lot suivant est postérieure');
    }
  });
});

// ───────────────────────── Convergence : le marqueur ─────────────────────────

describe('la convergence : un lot ne s\'applique jamais deux fois', () => {
  beforeEach(() => seedClub());

  test('un lot rejoué est refusé en bloc, le marqueur ne bouge pas', async () => {
    await applyRange(director, 0, 2, 'director');
    assert.equal(await applyLot(director, 0, 'director'), false, 'rejeu du lot 0 (création du marqueur)');
    assert.equal(await applyLot(director, 1, 'director'), false, 'rejeu du lot 1 (avancement)');
    assert.equal((await readMarker(director)).done, 2);
  });

  test('un lot sauté est refusé : le marqueur n\'avance que d\'un, et rien du lot n\'est écrit', async () => {
    await applyRange(director, 0, 2, 'director');
    const probe = director.lots[2].ops.find((op) => op.path.includes('/attempts/'));
    // Les écritures du lot 2 avec l'avancement du lot 3 : refusées en bloc.
    assert.equal(await applyLot(director, 2, 'director', 3, 20), false);
    assert.equal(await applyLot(director, 2, 'director', 4, 20), false);
    assert.equal((await readMarker(director)).done, 2);
    assert.equal((await getDoc(doc(dbOf(env, 'director'), probe.path))).exists(), false);
    // Le bon lot passe ensuite.
    assert.equal(await applyLot(director, 2, 'director'), true);
    assert.equal((await readMarker(director)).done, 3);
  });

  test('un autre appareil (ou la file du SDK) qui rejoue un lot déjà appliqué n\'écrit rien de plus', async () => {
    await applyRange(director, 0, 3, 'director');
    const before = await readClub('director');
    assert.equal(await applyLot(director, 2, 'director'), false);
    assert.equal(await applyLot(director, 1, 'director'), false);
    assert.deepEqual(await readClub('director'), before);
  });

  test('un second auteur ne peut rien écraser : son marqueur est le sien, les documents déjà importés sont refusés', async () => {
    await applyRange(director, 0, 3, 'director');
    const before = await readClub('director');
    // L'administrateur rejoue le lot 0 avec SON marqueur (créé) : les documents existent, lot refusé en bloc.
    assert.equal(await applyLot(director, 0, 'admin', 0, 20), false);
    assert.deepEqual(await readClub('director'), before);
    assert.equal(await readMarker(director, 'admin'), undefined, 'aucun marqueur du second auteur');
    assert.equal((await readMarker(director)).done, 3, 'celui du premier n\'a pas bougé');
  });

  test('la reprise après N lots donne le même club qu\'un import sans coupure', async () => {
    await applyRange(director, 0, 3, 'director'); // coupure ici
    // Reprise depuis la valeur relue du marqueur (le même compte, autre appareil).
    const done = (await readMarker(director, 'director')).done;
    assert.equal(done, 3);
    await applyRange(director, done, director.lotCount, 'director');
    await assertSameAsPlan(director, 'director', { anyUid: true });
    assert.equal((await readMarker(director)).state, 'done');
  });

  test('un import terminé n\'avance plus, et le même fichier ne peut pas être recréé', async () => {
    await applyRange(director, 0, director.lotCount, 'director');
    assert.equal(await applyLot(director, director.lotCount - 1, 'director'), false);
    assert.equal(await applyLot(director, 0, 'director'), false);
  });

  test('un passage ne s\'écrase pas : réécrire un document existant est refusé par les règles', async () => {
    await applyRange(director, 0, director.lotCount, 'director');
    const attempt = director.lots.flatMap((lot) => lot.ops).find((op) => op.path.includes('/attempts/'));
    assert.equal(await applyOps([attempt], 'director'), false, 'createdAt est figé : un rejeu ne passe pas');
  });
});

// ───────────────────────── Jamais d'écrasement (ADR 0024, décision 19 et C2) ─────────────────────────

/** Les valeurs du plan en valeurs sans « serveur » : un document VIVANT, créé hors de l'import. */
const live = (value) => {
  if (Array.isArray(value)) return value.map(live);
  if (value && typeof value === 'object') {
    if (value.$serverTimestamp) return { $date: new Date(Date.now() - 3600000).toISOString() };
    if (value.$arrayUnion) return value.$arrayUnion.map(live);
    if (value.$date) return value;
    return Object.fromEntries(Object.entries(value).filter(([k]) => k !== 'importedAt').map(([k, v]) => [k, live(v)]));
  }
  return value;
};

const firstSet = (plan, collection) =>
  plan.lots.flatMap((lot) => lot.ops).find((op) => op.kind === 'set' && op.path.split('/')[2] === collection);

describe('un document créé entre l\'inventaire et le lot n\'est jamais écrasé', () => {
  beforeEach(() => seedClub());

  const COLLECTIONS_WRITTEN = ['seasons', 'groups', 'students', 'memberships', 'archives', 'sessions', 'records',
    'attempts', 'acquisitions', 'assessments', 'acknowledgements'];

  /** La fiche que la donnée suppose (un gestionnaire n'écrit une donnée que sur une fiche existante). */
  const seedStudentOf = async (op) => {
    const studentId = op.fields?.studentId;
    if (studentId) await put(env, `clubs/c1/students/${studentId}`, { firstName: 'Léa', groupIds: [op.fields.groupId] });
  };

  for (const collection of COLLECTIONS_WRITTEN) {
    test(`${collection} : le lot qui tombe sur un document vivant est refusé en bloc, le marqueur reste absent`, async () => {
      const op = firstSet(director, collection);
      assert.ok(op, `le plan écrit des ${collection}`);
      const marker = markerOps(director, 0, 'director', 'u-dir');
      const markerPath = marker.path;
      // Témoin : sans document vivant, la même écriture et son marqueur passent.
      if (collection !== 'students') await seedStudentOf(op);
      assert.equal(await applyOps([op, marker], 'director'), true, 'l\'écriture est bien formée');
      await env.clearFirestore();
      await seedClub();
      if (collection !== 'students') await seedStudentOf(op);
      await put(env, op.path, decode(live(op.fields), 'u-dir'));
      const before = (await getDoc(doc(dbOf(env, 'director'), op.path))).data();
      assert.equal(await applyOps([op, marker], 'director'), false, 'l\'écriture remplacerait un document vivant');
      assert.deepEqual((await getDoc(doc(dbOf(env, 'director'), op.path))).data(), before);
      assert.equal((await getDoc(doc(dbOf(env, 'director'), markerPath))).exists(), false);
    });
  }

  test('un document importé ne se réécrit pas non plus : un second import d\'un autre fichier est refusé', async () => {
    const op = firstSet(director, 'seasons');
    assert.equal(await applyOps([op, markerOps(director, 0, 'director', 'u-dir')], 'director'), true);
    const other = { ...director, fileId: 'f'.repeat(64) };
    assert.equal(await applyOps([op, markerOps(other, 0, 'director', 'u-dir')], 'director'), false);
  });

  test('l\'application garde la main sur un document importé : la fusion et la mise à jour restent permises', async () => {
    const op = firstSet(director, 'seasons');
    assert.equal(await applyOps([op, markerOps(director, 0, 'director', 'u-dir')], 'director'), true);
    const db = dbOf(env, 'director');
    const rename = allowed(async () => {
      const batch = writeBatch(db);
      batch.set(doc(db, op.path), { label: 'Renommée' }, { merge: true });
      await batch.commit();
    });
    assert.equal(await rename, true);
  });

  test('une mise à jour ne pose pas importedAt, pas même à null (document sans marque)', async () => {
    await seedClub({ groups: true }); // `se1` existe, créé hors import : pas de marque
    const db = dbOf(env, 'director');
    const se1 = doc(db, 'clubs/c1/seasons/se1');
    const attempt = (fields, merge) =>
      allowed(async () => {
        const batch = writeBatch(db);
        batch.set(se1, { label: '2026-2027', ...fields }, { merge });
        await batch.commit();
      });
    assert.equal(await attempt({}, true), true, 'témoin : une fusion ordinaire passe');
    assert.equal(await attempt({ importedAt: null }, true), false, 'null par fusion');
    assert.equal(await attempt({ importedAt: null }, false), false, 'null par remplacement');
    assert.equal(await attempt({ importedAt: Timestamp.fromMillis(1000) }, true), false, 'une date de son choix');
    assert.equal(await attempt({ importedAt: serverTimestamp() }, true), false, 'la date du serveur, sur un document existant');
  });

  test('une mise à jour garde, ou ôte, la marque d\'un document importé, sans jamais la changer', async () => {
    await applyLot(director, 0, 'director'); // crée les saisons du plan (importedAt posé)
    const op = firstSet(director, 'seasons');
    const db = dbOf(env, 'director');
    const ref = doc(db, op.path);
    assert.ok((await getDoc(ref)).data().importedAt, 'la saison importée porte sa marque');
    const attempt = (fields, merge) =>
      allowed(async () => {
        const batch = writeBatch(db);
        batch.set(ref, fields, { merge });
        await batch.commit();
      });
    assert.equal(await attempt({ label: 'modifié' }, true), true, 'fusion : la marque est gardée');
    assert.equal(await attempt({ label: 'remplacé' }, false), true, 'remplacement sans la marque : permis (elle est ôtée)');
  });

  test('personne ne pose un importedAt de son choix', async () => {
    const op = firstSet(director, 'seasons');
    const db = dbOf(env, 'director');
    const forged = allowed(async () => {
      const batch = writeBatch(db);
      batch.set(doc(db, op.path), { label: 'x', importedAt: Timestamp.fromMillis(1000) });
      await batch.commit();
    });
    assert.equal(await forged, false);
  });

  // Deux lots de deux auteurs (deux marqueurs distincts) qui créent les MÊMES documents, envoyés
  // ensemble : à la même milliseconde de serveur, le second ne doit jamais être lu comme une mise
  // à jour du premier (`importedAt == resource.importedAt`) et l'écraser. Avec l'ancienne règle,
  // plusieurs essais sur 30 donnaient deux lots acceptés.
  test('deux lots simultanés sur les mêmes documents : jamais deux acceptés (30 essais)', async () => {
    const op = firstSet(director, 'seasons');
    const trials = 30;
    let doubles = 0;
    let singles = 0;
    for (let i = 0; i < trials; i += 1) {
      const path = `clubs/c1/seasons/race-${i}`;
      const twin = { ...op, path, fields: { ...op.fields, label: `race-${i}` } };
      const planOf = (tag) => ({ ...director, fileId: String(i).padStart(2, '0').repeat(32).replace(/^(..)/, tag) });
      const [a, b] = await Promise.all([
        applyOps([twin, markerOps(planOf('aa'), 0, 'director', 'u-dir')], 'director'),
        applyOps([twin, markerOps(planOf('bb'), 0, 'admin', 'u-admin')], 'admin'),
      ]);
      if (a && b) doubles += 1;
      if (a !== b) singles += 1;
    }
    assert.equal(doubles, 0, 'aucun écrasement : un seul des deux lots est accepté');
    assert.equal(singles, trials, 'un des deux lots est accepté à chaque essai');
  });
});

// ───────────────────────── Le marqueur ne se falsifie pas ─────────────────────────

describe('le marqueur d\'import est lié à son auteur', () => {
  beforeEach(() => seedClub({ groups: true }));

  test('un enseignant ne fait pas avancer le marqueur d\'un directeur', async () => {
    await seedClub(); // sans groupe : le plan du directeur crée les siens
    assert.equal(await applyLot(director, 0, 'director'), true);
    assert.equal(await applyOps([markerOps(director, 1, 'director', 'u-dir')], 'teacherA'), false);
    assert.equal((await readMarker(director)).done, 1);
  });

  test('un enseignant ne fait pas avancer le marqueur d\'un autre enseignant', async () => {
    assert.equal(await applyLot(teacherLarge, 0, 'teacherA'), true);
    assert.equal(await applyOps([markerOps(teacherLarge, 1, 'teacher', 'u-teacher-a')], 'teacherB'), false);
    assert.equal((await readMarker(teacherLarge, 'teacherA')).done, 1);
  });

  test('l\'auteur reprend son import ; un gestionnaire ne reprend pas celui d\'un autre', async () => {
    await applyRange(teacherLarge, 0, 2, 'teacherA');
    assert.equal(await applyLot(teacherLarge, 2, 'teacherA'), true);
    assert.equal(await applyLot(teacherLarge, 3, 'director'), false);
    assert.equal(await applyOps([markerOps(teacherLarge, 3, 'teacher', 'u-teacher-a')], 'director'), false);
    assert.equal((await readMarker(teacherLarge, 'teacherA')).done, 3);
  });

  // Attaques T1, T2, T3 rejouées : un enseignant pose un marqueur « au nom du fichier » (planId
  // quelconque, un seul lot, état terminé) ; le directeur importe quand même.
  const forged = (uid, fileId) => ({
    kind: 'set',
    path: `clubs/c1/imports/${fileId}${uid ? `_${uid}` : ''}`,
    fields: {
      fileId, planId: 'd'.repeat(64), lots: 1, done: 1, writes: 0, restored: 0, role: 'teacher',
      createdBy: 'u-teacher-a', state: 'done', startedAt: { $serverTimestamp: true }, updatedAt: { $serverTimestamp: true },
    },
  });

  test('T1 : un enseignant crée un marqueur terminé au nom du fichier du directeur : refusé sous l\'empreinte seule et sous l\'uid du directeur', async () => {
    assert.equal(await applyOps([forged(null, director.fileId)], 'teacherA'), false);
    assert.equal(await applyOps([forged('u-dir', director.fileId)], 'teacherA'), false);
  });

  test('T2 : le marqueur qu\'un enseignant crée sous SON uid ne touche pas le directeur, qui importe le fichier en entier', async () => {
    await seedClub();
    assert.equal(await applyOps([forged('u-teacher-a', director.fileId)], 'teacherA'), true, 'le sien : permis');
    await applyRange(director, 0, director.lotCount, 'director');
    assert.equal((await readMarker(director)).state, 'done');
    await assertSameAsPlan(director, 'director', { anyUid: true });
  });

  test('T3 : un enseignant ne lit ni n\'avance le marqueur du directeur, et le directeur ne lit pas le sien', async () => {
    await seedClub();
    assert.equal(await applyLot(director, 0, 'director'), true);
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'teacherA'), markerPath(director, 'u-dir')))), false);
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'director'), markerPath(director, 'u-teacher-a')))), false);
    assert.equal(await applyOps([markerOps(director, 1, 'director', 'u-dir')], 'teacherA'), false);
    assert.equal((await readMarker(director)).done, 1);
  });

  test('le marqueur porte l\'uid de celui qui le crée, pas celui d\'un autre', async () => {
    const lot = teacher.lots[0];
    const db = dbOf(env, 'teacherA');
    const ok = await allowed(async () => {
      const batch = writeBatch(db);
      for (const op of lot.ops) queue(batch, db, op, 'u-teacher-a');
      queue(batch, db, markerOps(teacher, 0, 'teacher', 'u-teacher-b'), 'u-teacher-a');
      await batch.commit();
    });
    assert.equal(ok, false);
  });

  // L'identifiant du marqueur est comparé à l'uid comme une CHAÎNE : un uid fait de métacaractères
  // de regex (« .* », « .+ ») ne donne accès à aucun autre marqueur.
  for (const uid of ['.*', '.+', '[0-9a-f]+', 'u-teacher-a|.*']) {
    test(`un compte dont l'uid est « ${uid} » ne lit que son propre marqueur`, async () => {
      assert.equal(await applyLot(teacherLarge, 0, 'teacherA'), true);
      await put(env, `clubs/c1/members/${uid.replaceAll('/', '_')}`, member(uid, 'teacher', { groupIds: ['g1'] }));
      const db = env.authenticatedContext(uid, { email: 'x@example.org', email_verified: true }).firestore();
      assert.equal(await allowed(() => getDoc(doc(db, markerPath(teacherLarge, 'u-teacher-a')))), false, 'celui d\'un autre');
      assert.equal(await allowed(() => getDoc(doc(db, markerPath(teacherLarge, 'u-dir')))), false, 'celui du directeur');
      assert.equal(await allowed(() => getDoc(doc(db, markerPath(teacherLarge, uid)))), true, 'le sien (même absent)');
    });
  }

  /** Un marqueur déjà là (un lot), posé hors règles au nom de [uid]. */
  const storedMarker = (plan, uid) => ({
    fileId: plan.fileId, planId: 'd'.repeat(64), lots: 3, done: 1, writes: 10, restored: 0, role: 'director',
    createdBy: uid, state: 'running', startedAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });

  // FB8 partie B (B1) : l'auteur supprime SES marqueurs (suppression de son compte), jamais celui d'un autre.
  for (const uid of ['.*', '.+', '[0-9a-f]+', 'u-teacher-a|.*']) {
    test(`un compte dont l'uid est « ${uid} » ne supprime que son propre marqueur`, async () => {
      assert.equal(await applyLot(teacherLarge, 0, 'teacherA'), true);
      await put(env, `clubs/c1/members/${uid.replaceAll('/', '_')}`, member(uid, 'teacher', { groupIds: ['g1'] }));
      const db = env.authenticatedContext(uid, { email: 'x@example.org', email_verified: true }).firestore();
      assert.equal(await allowed(() => deleteDoc(doc(db, markerPath(teacherLarge, 'u-teacher-a')))), false, 'celui d\'un autre');
      assert.equal(await allowed(() => deleteDoc(doc(db, markerPath(teacherLarge, uid)))), true, 'le sien');
      assert.equal((await readMarker(teacherLarge, 'teacherA')).done, 1);
    });
  }

  test('un lot qui supprime SON marqueur et celui d\'un autre est refusé en bloc', async () => {
    assert.equal(await applyLot(teacherLarge, 0, 'teacherA'), true);
    await put(env, markerPath(teacherLarge, 'u-teacher-b'), { ...storedMarker(teacherLarge, 'u-teacher-b'), role: 'teacher' });
    const db = dbOf(env, 'teacherA');
    const ok = await allowed(async () => {
      const batch = writeBatch(db);
      batch.delete(doc(db, markerPath(teacherLarge, 'u-teacher-a')));
      batch.delete(doc(db, markerPath(teacherLarge, 'u-teacher-b')));
      await batch.commit();
    });
    assert.equal(ok, false);
    assert.equal((await readMarker(teacherLarge, 'teacherA')).done, 1);
    assert.equal((await readMarker(teacherLarge, 'teacherB')).done, 1);
  });

  test('l\'enseignant liste et supprime ses marqueurs ; ceux du directeur restent (idempotence entre auteurs intacte)', async () => {
    assert.equal(await applyLot(teacherLarge, 0, 'teacherA'), true);
    await put(env, markerPath(teacherLarge, 'u-dir'), storedMarker(teacherLarge, 'u-dir'));
    const db = dbOf(env, 'teacherA');
    const own = await getDocs(query(collection(db, 'clubs/c1/imports'), where('createdBy', '==', 'u-teacher-a')));
    assert.deepEqual(own.docs.map((d) => d.id), [`${teacherLarge.fileId}_u-teacher-a`]);
    for (const d of own.docs) await deleteDoc(d.ref);
    assert.equal(await readMarker(teacherLarge, 'teacherA'), undefined);
    assert.equal((await readMarker(teacherLarge, 'director')).done, 1);
  });

  test('l\'auteur du marqueur ne se change pas à l\'avancement', async () => {
    assert.equal(await applyLot(teacherLarge, 0, 'teacherA'), true);
    const db = dbOf(env, 'director');
    const ok = await allowed(async () => {
      const batch = writeBatch(db);
      batch.update(doc(db, markerPath(teacherLarge, 'u-teacher-a')), {
        done: 2, state: 'running', updatedAt: serverTimestamp(), createdBy: 'u-dir',
      });
      await batch.commit();
    });
    assert.equal(ok, false);
  });
});

// ───────────────────────── Enseignant ─────────────────────────

describe('un enseignant importe dans son groupe seulement', () => {
  beforeEach(() => seedClub({ groups: true }));

  test('teacherA : tous les lots du plan de son groupe sont acceptés et relus comme le plan', async () => {
    await applyRange(teacher, 0, teacher.lotCount, 'teacherA');
    const found = await readClub('director');
    const expected = expectedDocs(teacher, 'u-teacher-a');
    for (const [path, fields] of expected) {
      assert.deepEqual(normalizeActual(found.get(path), fields), fields, path);
    }
    assert.equal((await readMarker(teacher, 'teacherA')).role, 'teacher');
    // L'enseignant n'a écrit ni saison, ni groupe, ni archive.
    const kinds = new Set([...expected.keys()].map((path) => path.split('/')[2]));
    for (const forbidden of ['seasons', 'groups', 'archives']) assert.equal(kinds.has(forbidden), false, forbidden);
  });

  test('teacherA : un grand groupe (30 fiches neuves) passe lot par lot malgré le budget de lectures des règles', async () => {
    const students = teacherLarge.lots.map((lot) => new Set(lot.ops.filter((op) => op.path.includes('/students/')).map((op) => op.path)).size);
    assert.ok(teacherLarge.lotCount >= 4, `${teacherLarge.lotCount} lots`);
    assert.ok(Math.max(...students) <= 17, `fiches par lot : ${students}`);
    await applyRange(teacherLarge, 0, teacherLarge.lotCount, 'teacherA');
    const found = await readClub('director');
    assert.equal([...found.keys()].filter((path) => path.includes('/students/')).length, 30);
    assert.equal([...found.keys()].filter((path) => path.includes('/memberships/')).length, 30);
  });

  test('la limite est réelle : 18 fiches neuves d\'un enseignant dans UN lot dépassent le budget de lectures des règles', async () => {
    const units = teacherLarge.lots
      .flatMap((lot) => lot.ops)
      .filter((op) => op.path.includes('/students/') || op.path.includes('/memberships/'));
    const first = units.filter((op) => op.path.includes('/students/')).slice(0, 18).map((op) => op.path.split('/').pop());
    const ofStudents = (ids) => units.filter((op) => ids.some((id) => op.path.endsWith(`/${id}`) || op.path.includes(`_${id}_`)));
    const ops = ofStudents(first);
    assert.equal(ops.length, 36);
    assert.equal(await applyOps(ops, 'teacherA'), false);
    // Les dix-sept premières passent : la limite du plan est exactement celle des règles.
    assert.equal(await applyOps(ofStudents(first.slice(0, 17)), 'teacherA'), true);
  });

  test('teacherB : le groupe d\'un autre est refusé dès le premier lot (fiches neuves de g1)', async () => {
    assert.equal(await applyLot(teacher, 0, 'teacherB'), false);
    assert.equal(await readMarker(teacher, 'teacherB'), undefined);
  });

  test('un enseignant ne peut pas importer le club entier d\'un directeur', async () => {
    assert.equal(await applyLot(director, 0, 'teacherA', 0, 20), false, 'saisons et groupes sont au directeur');
    assert.equal(await readMarker(director, 'teacherA'), undefined);
  });

  test('le marqueur d\'un enseignant porte son rôle : il ne peut pas se dire directeur', async () => {
    const lot = teacher.lots[0];
    const db = dbOf(env, 'teacherA');
    const ok = await allowed(async () => {
      const batch = writeBatch(db);
      for (const op of lot.ops) queue(batch, db, op, 'u-teacher-a');
      queue(batch, db, markerOps(teacher, 0, 'director', 'u-teacher-a'), 'u-teacher-a');
      await batch.commit();
    });
    assert.equal(ok, false);
  });
});

// ───────────────────────── Ce qu'un enseignant ne peut pas voir ─────────────────────────

describe('une fiche du fichier qui existe hors des groupes de l\'enseignant lui est invisible', () => {
  beforeEach(() => seedClub({ groups: true }));
  const firstStudent = () =>
    teacher.lots.flatMap((lot) => lot.ops).find((op) => op.kind === 'set' && op.path.includes('/students/'));

  test('le plan le dit : ses fiches neuves sont à confirmer, il ne peut pas les vérifier', () => {
    assert.ok(teacher.unverifiable > 0, `fiches non vérifiables annoncées : ${teacher.unverifiable}`);
  });

  test('sa requête ne la voit pas ; le lot qui la crée est refusé en bloc par les règles, sans marqueur', async () => {
    const existing = firstStudent();
    // La fiche existe déjà dans le groupe d'un autre enseignant (g2) : g1 ne la voit pas.
    await put(env, existing.path, { firstName: 'Déjà là', audience: 'adults', groupIds: ['g2'] });
    const visible = await getDocs(
      query(collection(dbOf(env, 'teacherA'), 'clubs/c1/students'), where('groupIds', 'array-contains-any', ['g1'])),
    );
    assert.equal(visible.docs.some((d) => d.ref.path === existing.path), false, 'invisible à ses requêtes');
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'teacherA'), existing.path))), false, 'et à sa lecture');
    assert.equal(await applyLot(teacher, 0, 'teacherA'), false, 'lot refusé en bloc');
    assert.equal(await readMarker(teacher, 'teacherA'), undefined, 'aucun marqueur');
    const kept = (await getDoc(doc(dbOf(env, 'director'), existing.path))).data();
    assert.deepEqual(kept.groupIds, ['g2'], 'la fiche existante n\'a pas bougé');
  });

  test('une séance préexistante hors de sa visibilité n\'est pas écrasée : lot refusé en bloc, sans marqueur', async () => {
    const op = firstSet(teacher, 'sessions');
    assert.ok(op, 'le plan de l\'enseignant écrit des séances');
    const marker = markerOps(teacher, 0, 'teacher', 'u-teacher-a');
    // La séance du plan existe déjà, dans le groupe d'un autre enseignant (g2) : elle lui est invisible.
    await put(env, op.path, { ...decode(live(op.fields), 'u-teacher-a'), groupId: 'g2' });
    assert.equal(await allowed(() => getDoc(doc(dbOf(env, 'teacherA'), op.path))), false, 'invisible à sa lecture');
    assert.equal(await applyOps([op, marker], 'teacherA'), false, 'lot refusé en bloc');
    assert.equal(await readMarker(teacher, 'teacherA'), undefined, 'aucun marqueur');
    assert.equal((await getDoc(doc(dbOf(env, 'director'), op.path))).data().groupId, 'g2', 'la séance n\'a pas bougé');
  });

  test('un groupe préexistant d\'un autre enseignant n\'est ni écrasé ni réécrit par un import', async () => {
    const op = firstSet(director, 'groups');
    assert.ok(op, 'le plan du directeur écrit des groupes');
    const clash = { ...op, path: 'clubs/c1/groups/g2' };
    const before = (await getDoc(doc(dbOf(env, 'director'), clash.path))).data();
    assert.equal(await applyOps([clash], 'teacherA'), false, 'l\'enseignant n\'écrit aucun groupe');
    assert.equal(await applyOps([clash], 'director'), false, 'ni le directeur : le groupe existe');
    assert.deepEqual((await getDoc(doc(dbOf(env, 'director'), clash.path))).data(), before);
  });

  test('sans fiche préexistante, le même lot est accepté', async () => {
    assert.equal(await applyLot(teacher, 0, 'teacherA'), true);
  });
});

// ───────────────────────── Le miroir du plan ─────────────────────────

describe('les droits que le plan annonce sont ceux des règles', () => {
  beforeEach(() => seedClub({ groups: true }));

  test('le jeu contient des écritures permises et des refusées', () => {
    const [phase1, phase2] = scope.allowedBatches;
    assert.ok(phase1.length > 0 && phase2.length > 0);
    assert.ok(scope.deniedUnits.length >= 8, `${scope.deniedUnits.length} unités refusées`);
    const categories = new Set(scope.deniedUnits.map((u) => u.category));
    for (const expected of ['seasons', 'students', 'sessionRecords', 'attempts']) {
      assert.ok(categories.has(expected), `refus attendu pour ${expected}`);
    }
  });

  test('ce que le plan permet à l\'enseignant est accepté par les règles', async () => {
    for (const batch of scope.allowedBatches) {
      if (batch.length === 0) continue;
      const ok = await applyOps(batch, 'teacherA');
      assert.equal(ok, true, `lot refusé ; écritures refusées une à une : ${(await refusedOps(batch, 'teacherA')).join(', ')}`);
    }
  });

  test('ce que le plan refuse à l\'enseignant est refusé, unité par unité', async () => {
    for (const batch of scope.allowedBatches) {
      if (batch.length > 0) assert.equal(await applyOps(batch, 'teacherA'), true);
    }
    const wrong = [];
    for (const unit of scope.deniedUnits) {
      if (await applyOps(unit.ops, 'teacherA')) wrong.push(`${unit.category} ${unit.ops[0].path}`);
    }
    assert.deepEqual(wrong, [], 'écritures acceptées alors que le plan les annonce refusées');
  });

  test('et ces écritures refusées sont bien formées : le directeur les fait', async () => {
    for (const batch of scope.allowedBatches) {
      if (batch.length > 0) assert.equal(await applyOps(batch, 'teacherA'), true);
    }
    const refused = [];
    for (const unit of scope.deniedUnits) {
      if (!(await applyOps(unit.ops, 'director'))) refused.push(`${unit.category} ${unit.ops[0].path}`);
    }
    assert.deepEqual(refused, [], 'le refus doit venir du rôle, pas de la forme de l\'écriture');
  });
});
