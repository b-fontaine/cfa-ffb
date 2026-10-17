// Refus par défaut (ADR 0024 décisions 12 et 21), conservé après l'écriture des règles complètes
// (lot FB3) :
//
// - un chemin qui n'est pas dans le modèle est refusé à TOUS, administrateur et directeur
//   compris : lecture, liste, création, mise à jour, suppression ;
// - l'anonyme et tout compte dont l'adresse n'est pas vérifiée ne lisent ni n'écrivent RIEN du
//   modèle, quel que soit leur rôle déclaré dans la base (administrateur, directeur,
//   enseignant, parent) ;
// - une preuve de sensibilité : sans règles, la même lecture réussit.
//
// Ces tests tournent contre l'émulateur Firestore (scripts/rules_test.sh) ; ils n'atteignent
// jamais la base de production (projet `demo-*`, hôte de l'émulateur obligatoire).
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc } from 'firebase/firestore';

import { actorNames, allowed, createEnv, dbOf, seed, seedDocs } from './support.mjs';

let env;
before(async () => {
  env = await createEnv();
  // Une seule mise en place : toutes les opérations de ce fichier doivent être REFUSÉES, donc
  // ne rien changer (si une règle s'affaiblit, c'est l'assertion qui échoue).
  await seed(env);
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const path of unknown) await setDoc(doc(ctx.firestore(), path), { seed: true });
  });
});
after(async () => {
  await env?.cleanup();
});

// Documents hors modèle, existants : un refus vient donc des règles, pas d'un document absent.
const unknown = [
  'inconnue/d1',
  'nouvelle_collection/x',
  'users/u-admin',
  'clubs/c1/inconnue/x',
  'clubs/c1/members/u-dir/extra/y',
  'clubs/c1/students/s1/historique/h1',
  'admins/u-admin/sub/z',
  'invitations/AAAAAAAAAA/sub/q',
  'clubs/c1/settings/autre',
];
const unknownCollections = ['inconnue', 'users', 'clubs/c1/inconnue', 'clubs/c1/students/s1/historique'];

test('les documents hors modèle existent (un refus vient bien des règles)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const path of unknown) {
      assert.equal((await getDoc(doc(ctx.firestore(), path))).exists(), true, path);
    }
  });
});

for (const actor of actorNames) {
  describe(`hors modèle : ${actor}`, () => {
    for (const path of unknown) {
      test(`lecture, mise à jour, suppression de ${path}`, async () => {
        const db = dbOf(env, actor);
        assert.equal(await allowed(() => getDoc(doc(db, path))), false, 'lecture');
        assert.equal(await allowed(() => updateDoc(doc(db, path), { x: 1 })), false, 'mise à jour');
        assert.equal(await allowed(() => deleteDoc(doc(db, path))), false, 'suppression');
      });
    }
    test('création et liste de collections hors modèle', async () => {
      const db = dbOf(env, actor);
      for (const path of unknown) {
        assert.equal(await allowed(() => setDoc(doc(db, `${path}-nouveau`), { x: 1 })), false, path);
      }
      for (const path of unknownCollections) {
        assert.equal(await allowed(() => getDocs(collection(db, path))), false, `liste de ${path}`);
      }
    });
  });
}

// Adresse non vérifiée : même un administrateur ou un directeur déclarés dans la base n'ont rien.
const unverifiedActors = {
  anonyme: (e) => e.unauthenticatedContext(),
  'administrateur sans adresse vérifiée': (e) => e.authenticatedContext('u-admin', { email: 'a@example.org', email_verified: false }),
  'directeur sans adresse vérifiée': (e) => e.authenticatedContext('u-dir', { email: 'd@example.org', email_verified: false }),
  'enseignant sans adresse vérifiée': (e) => e.authenticatedContext('u-teacher-a', { email: 't@example.org', email_verified: false }),
  'parent sans adresse vérifiée': (e) => e.authenticatedContext('u-guardian', { email: 'p@example.org', email_verified: false }),
  'jeton sans revendication email_verified': (e) => e.authenticatedContext('u-dir', { email: 'd@example.org' }),
};

for (const [name, contextOf] of Object.entries(unverifiedActors)) {
  describe(`modèle entier refusé : ${name}`, () => {
    test('lecture, mise à jour et suppression de chaque document du modèle', async () => {
      const db = contextOf(env).firestore();
      for (const [path] of seedDocs()) {
        assert.equal(await allowed(() => getDoc(doc(db, path))), false, `lecture de ${path}`);
        assert.equal(await allowed(() => updateDoc(doc(db, path), { x: 1 })), false, `mise à jour de ${path}`);
        assert.equal(await allowed(() => deleteDoc(doc(db, path))), false, `suppression de ${path}`);
      }
    });
    test('liste des collections du modèle et création', async () => {
      const db = contextOf(env).firestore();
      for (const path of ['clubs', 'admins', 'invitations', 'clubs/c1/members', 'clubs/c1/students', 'clubs/c1/attempts']) {
        assert.equal(await allowed(() => getDocs(collection(db, path))), false, `liste de ${path}`);
      }
      for (const [path, data] of seedDocs()) {
        assert.equal(await allowed(() => setDoc(doc(db, `${path}-nouveau`), data)), false, `création près de ${path}`);
      }
    });
  });
}

test('preuve de sensibilité : sans règles, la même lecture réussit', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    assert.equal(await allowed(() => getDoc(doc(ctx.firestore(), 'clubs/c1'))), true);
    assert.equal(await allowed(() => getDoc(doc(ctx.firestore(), 'inconnue/d1'))), true);
  });
});
