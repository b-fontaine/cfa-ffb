// Règles Firestore : refus par défaut (lot FB1, ADR 0024 décision 12).
//
// Tant que les règles de la matrice des droits ne sont pas écrites (FB3),
// `firestore.rules` refuse TOUT : lecture et écriture, anonyme comme
// authentifié, quelle que soit la collection. Ces tests tournent contre
// l'émulateur Firestore (scripts/rules_test.sh) ; ils n'atteignent jamais la
// base de production (projet `demo-*`, hôte de l'émulateur obligatoire).
//
// Les cas de la matrice rôle x action (FB3) s'ajouteront dans ce dossier.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  setLogLevel,
  updateDoc,
} from 'firebase/firestore';

// Les refus attendus ne doivent pas noyer la sortie du garde-fou.
setLogLevel('silent');

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const host = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT ?? '';

// Garde de sécurité : jamais autre chose que l'émulateur local et un projet « demo- ».
assert.ok(
  host && /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host),
  'FIRESTORE_EMULATOR_HOST absent ou non local : lancer ces tests par scripts/rules_test.sh',
);
assert.match(projectId, /^demo-/, 'le projet des tests de règles doit commencer par « demo- »');

// Documents existants avant les tests : un refus vient donc des règles, pas d'un document absent.
const seeded = [
  'clubs/c1',
  'clubs/c1/members/u-director',
  'clubs/c1/students/s1',
  'clubs/c1/groups/g1/memberships/s1_2026-09-01',
  'admins/u-admin',
  'invitations/CODE1',
  'inconnue/d1',
];
// Chemins de documents touchés par les tentatives d'écriture (existants ou non).
const targets = [...seeded, 'clubs/c2', 'clubs/c1/students/nouveau', 'nouvelle_collection/x'];
// Collections lues en liste.
const collections = ['clubs', 'clubs/c1/students', 'clubs/c1/members', 'admins', 'invitations', 'inconnue'];

const actors = {
  anonyme: (env) => env.unauthenticatedContext(),
  authentifie: (env) => env.authenticatedContext('u-any', { email: 'a@example.org', email_verified: true }),
  'authentifie sans e-mail vérifié': (env) =>
    env.authenticatedContext('u-any2', { email: 'b@example.org', email_verified: false }),
  'administrateur déclaré dans la base': (env) =>
    env.authenticatedContext('u-admin', { email: 'admin@example.org', email_verified: true }),
  'directeur déclaré dans la base': (env) =>
    env.authenticatedContext('u-director', { email: 'dir@example.org', email_verified: true }),
};

let testEnv;

before(async () => {
  const [emulatorHost, port] = host.split(':');
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(resolve(root, 'firestore.rules'), 'utf8'),
      host: emulatorHost,
      port: Number(port),
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    for (const path of seeded) {
      await setDoc(doc(ctx.firestore(), path), { seed: true });
    }
  });
});

test('les documents de départ existent (un refus vient bien des règles)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    for (const path of seeded) {
      assert.equal((await getDoc(doc(ctx.firestore(), path))).exists(), true, path);
    }
  });
});

test('firestore.rules ne contient aucune autorisation inconditionnelle', () => {
  const rules = readFileSync(resolve(root, 'firestore.rules'), 'utf8')
    .split('\n')
    .map((line) => line.replace(/\/\/.*$/, '').trim())
    .join('\n');
  assert.doesNotMatch(rules, /if\s+true/);
  assert.doesNotMatch(rules, /request\.time\s*</);
  assert.match(rules, /allow\s+read\s*,\s*write\s*:\s*if\s+false/);
});

for (const [actorName, contextOf] of Object.entries(actors)) {
  describe(`refus par défaut : ${actorName}`, () => {
    for (const path of seeded) {
      test(`lecture du document ${path}`, async () => {
        await assertFails(getDoc(doc(contextOf(testEnv).firestore(), path)));
      });
    }

    for (const path of collections) {
      test(`liste de la collection ${path}`, async () => {
        await assertFails(getDocs(collection(contextOf(testEnv).firestore(), path)));
      });
    }

    for (const path of targets) {
      test(`création ou remplacement de ${path}`, async () => {
        await assertFails(setDoc(doc(contextOf(testEnv).firestore(), path), { x: 1 }));
      });
    }

    for (const path of seeded) {
      test(`mise à jour de ${path}`, async () => {
        await assertFails(updateDoc(doc(contextOf(testEnv).firestore(), path), { x: 1 }));
      });
      test(`suppression de ${path}`, async () => {
        await assertFails(deleteDoc(doc(contextOf(testEnv).firestore(), path)));
      });
    }
  });
}

test('preuve de sensibilité : sans règles, la même lecture réussit', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await assertSucceeds(getDoc(doc(ctx.firestore(), 'clubs/c1')));
  });
});
