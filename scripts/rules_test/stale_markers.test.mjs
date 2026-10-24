// Filet des marqueurs abandonnés (FB8 partie B, tranche B5 ; décision D4 du 2026-10-24 ; ADR 0024
// décision 19) : un GESTIONNAIRE du club (directeur, administrateur : `manages` des règles) supprime
// un marqueur d'import (`imports/{empreinte}_{uid}`) ou d'opération (`operations/{empreinte}_{uid}`)
// d'un AUTRE auteur dont `updatedAt` a plus de 90 jours (`staleMarkerAge()` des règles, même valeur
// que `staleMarkerAge` du domaine), et liste les marqueurs d'opération ANCIENS du club par une
// requête de plage sur `updatedAt`. Joué contre l'émulateur Firestore et les VRAIES règles, avec les
// vrais rôles ; les écritures sont celles de `FirestoreStaleMarkerStore` (mêmes chemins, même
// requête).
//
// Ce que ce fichier prouve :
//   1. juste après 90 jours (horodatage du marqueur à 90 j + 5 min de l'heure de l'émulateur), le
//      directeur et l'administrateur suppriment le marqueur d'un auteur parti ; juste avant (90 j
//      − 5 min), personne ;
//   2. ATTAQUES : enseignant, parent, élève, invité, compte non vérifié, anonyme, directeur d'un
//      autre club ; marqueur d'un autre club ; marqueur sans `updatedAt` (illisible : refus) ;
//      `updatedAt` antidaté par l'auteur ou par un tiers (refusé : toujours `request.time`) ;
//   3. LISTE : la requête `updatedAt < (maintenant − 91 j)` passe pour un gestionnaire, une borne
//      plus récente que 90 jours est refusée, comme toute liste d'un enseignant ou d'un autre club ;
//   4. un lot de 400 suppressions de marqueurs anciens passe les limites d'accès des règles.
// Mutation (docs/engineering/testing.md) : retirer `staleMarker()` d'une règle fait échouer 1 et 3 ;
// remplacer `<` par `<=` ou 90 par 0 fait échouer « juste avant ».
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

import { actorNames, allowed, createEnv, dbOf, days, now, put, remove, seed, ts, uids } from './support.mjs';

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

const MGR = ['director', 'admin'];
const GONE = 'u-gone'; // un auteur dont le compte est supprimé : aucun member
const KEY = 'c'.repeat(64);
const minutes = (n) => n * 60 * 1000;
const justAfter = () => ts(now() - days(90) - minutes(5));
const justBefore = () => ts(now() - days(90) + minutes(5));

const importPath = (club, uid, key = KEY) => `clubs/${club}/imports/${key}_${uid}`;
const operationPath = (club, uid, key = KEY) => `clubs/${club}/operations/${key}_${uid}`;

const importMarker = (uid, updatedAt, key = KEY) => ({
  fileId: key, planId: 'd'.repeat(64), lots: 3, done: 3, writes: 12, restored: 0, role: 'teacher',
  createdBy: uid, state: 'done', startedAt: updatedAt, updatedAt,
});
const operationMarker = (uid, updatedAt, key = KEY) => ({
  operationId: key, kind: 'closure', done: 2, stage: 1, role: 'director', createdBy: uid,
  startedAt: updatedAt, updatedAt, seasonId: 'se1', closedOn: '2026-06-30T00:00:00.000',
  prepareNext: true, dropPlanned: false,
});

const KINDS = [
  { name: 'import', path: importPath, marker: importMarker, collection: (c) => `clubs/${c}/imports` },
  { name: 'opération', path: operationPath, marker: operationMarker, collection: (c) => `clubs/${c}/operations` },
];

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

for (const kind of KINDS) {
  describe(`marqueur d'${kind.name} abandonné : filet de 90 jours après updatedAt`, () => {
    test('juste APRÈS 90 jours : le directeur et l\'administrateur du club le suppriment, personne d\'autre', async () => {
      const path = kind.path('c1', GONE);
      await check({
        expectAllowed: MGR,
        run: (db) => deleteDoc(doc(db, path)),
        reset: () => put(env, path, kind.marker(GONE, justAfter())),
      });
    });

    test('juste AVANT 90 jours : personne ne supprime le marqueur d\'un autre (une reprise reste possible)', async () => {
      const path = kind.path('c1', GONE);
      await put(env, path, kind.marker(GONE, justBefore()));
      await check({ expectAllowed: [], run: (db) => deleteDoc(doc(db, path)) });
    });

    test('ATTAQUE : le marqueur ancien d\'un AUTRE club ; seuls son directeur et l\'administrateur', async () => {
      const path = kind.path('c2', GONE);
      await check({
        expectAllowed: ['directorOther', 'admin'],
        run: (db) => deleteDoc(doc(db, path)),
        reset: () => put(env, path, kind.marker(GONE, justAfter())),
      });
    });

    test('ATTAQUE : un marqueur sans updatedAt (forme inattendue) n\'est jamais supprimé par un tiers', async () => {
      const path = kind.path('c1', GONE);
      const { updatedAt, ...withoutDate } = kind.marker(GONE, justAfter());
      assert.ok(updatedAt);
      await put(env, path, withoutDate);
      await check({ expectAllowed: [], run: (db) => deleteDoc(doc(db, path)) });
    });

    test('ATTAQUE : antidater updatedAt est refusé (la règle impose request.time)', async () => {
      // Un enseignant (imports) ou le directeur (opérations) antidate SON marqueur récent.
      const author = kind.name === 'import' ? 'teacherA' : 'director';
      const path = kind.path('c1', uids[author]);
      await put(env, path, { ...kind.marker(uids[author], ts(now() - 1000)), state: 'running', done: 1 });
      const db = dbOf(env, author);
      assert.equal(await allowed(() => updateDoc(doc(db, path), { done: 2, updatedAt: justAfter() })), false);
      assert.equal(
        await allowed(() => setDoc(doc(db, kind.path('c1', uids[author], 'e'.repeat(64))), {
          ...kind.marker(uids[author], justAfter(), 'e'.repeat(64)), done: 1, state: 'running',
        })),
        false,
      );
      // Un gestionnaire n'antidate pas davantage le marqueur récent d'un autre pour le rendre « ancien ».
      const other = kind.path('c1', GONE);
      await put(env, other, kind.marker(GONE, justBefore()));
      for (const actor of MGR) {
        assert.equal(await allowed(() => updateDoc(doc(dbOf(env, actor), other), { updatedAt: justAfter() })), false, actor);
        assert.equal(await allowed(() => deleteDoc(doc(dbOf(env, actor), other))), false, actor);
      }
      await remove(env, path);
    });

    test('LISTE bornée par ancienneté : `updatedAt < maintenant − 91 j` pour un gestionnaire du club', async () => {
      // L'application demande `maintenant − 91 j` (un jour de marge pour l'horloge de l'appareil) :
      // un marqueur de 120 jours sort, un marqueur de 90 jours − 5 min reste.
      await put(env, kind.path('c1', GONE), kind.marker(GONE, ts(now() - days(120))));
      await put(env, kind.path('c1', 'u-other', 'f'.repeat(64)), kind.marker('u-other', justBefore(), 'f'.repeat(64)));
      const stale = (db) => getDocs(query(collection(db, kind.collection('c1')), where('updatedAt', '<', ts(now() - days(91)))));
      await check({ expectAllowed: MGR, run: stale });
      // Une borne à 89 jours ne prouve pas l'ancienneté : refusée pour les marqueurs d'opération
      // (la liste des imports est déjà ouverte au gestionnaire, FB7).
      const tooRecent = (db) => getDocs(query(collection(db, kind.collection('c1')), where('updatedAt', '<', ts(now() - days(89)))));
      await check({ expectAllowed: kind.name === 'import' ? MGR : [], run: tooRecent });
      // Ce que la liste rend : seulement l'ancien, l'autre reste.
      const seen = await getDocs(query(collection(dbOf(env, 'director'), kind.collection('c1')), where('updatedAt', '<', ts(now() - days(91)))));
      assert.deepEqual(seen.docs.map((d) => d.id), [`${KEY}_${GONE}`]);
      // La liste d'un autre club : son directeur et l'administrateur.
      await put(env, kind.path('c2', GONE), kind.marker(GONE, ts(now() - days(120))));
      const elsewhere = (db) => getDocs(query(collection(db, kind.collection('c2')), where('updatedAt', '<', ts(now() - days(91)))));
      await check({ expectAllowed: ['directorOther', 'admin'], run: elsewhere });
    });
  });
}

describe('budget : un lot de 400 suppressions de marqueurs anciens', () => {
  test('passe les limites d\'accès des règles (directeur)', async () => {
    const key = (i) => i.toString(16).padStart(64, '0');
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (let start = 0; start < 400; start += 200) {
        const batch = writeBatch(db);
        for (let i = start; i < start + 200; i++) {
          const kind = i % 2 === 0 ? KINDS[0] : KINDS[1];
          batch.set(doc(db, kind.path('c1', GONE, key(i))), kind.marker(GONE, justAfter(), key(i)));
        }
        await batch.commit();
      }
    });
    const db = dbOf(env, 'director');
    const batch = writeBatch(db);
    for (let i = 0; i < 400; i++) {
      const kind = i % 2 === 0 ? KINDS[0] : KINDS[1];
      batch.delete(doc(db, kind.path('c1', GONE, key(i))));
    }
    assert.equal(await allowed(() => batch.commit()), true);
  });

  test('un seul marqueur récent dans le lot le fait refuser EN BLOC (rien n\'est supprimé)', async () => {
    await put(env, importPath('c1', GONE), importMarker(GONE, justAfter()));
    await put(env, operationPath('c1', GONE), operationMarker(GONE, justBefore()));
    const db = dbOf(env, 'director');
    const batch = writeBatch(db);
    batch.delete(doc(db, importPath('c1', GONE)));
    batch.delete(doc(db, operationPath('c1', GONE)));
    assert.equal(await allowed(() => batch.commit()), false);
    // Le marqueur ancien est toujours là : il part seul ensuite.
    assert.equal(await allowed(() => deleteDoc(doc(db, importPath('c1', GONE)))), true);
  });
});
