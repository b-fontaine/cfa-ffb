// Budget d'accès des règles (ADR 0024 décision 25, lot FB3) : Firestore limite à 10 le nombre de
// documents lus (`get`, `exists`, `getAfter`, `existsAfter`) par évaluation de règle. Ce fichier
// MESURE les deux hypothèses sur lesquelles repose le budget de firestore.rules, avec de petites
// règles à part (jamais celles du dépôt) :
//
//   1. la limite est exactement de 10 documents DISTINCTS (10 passent, 11 sont refusés) ;
//   2. lire plusieurs fois le MÊME document ne compte qu'une fois (c'est ce qui permet à
//      `me(clubId)` d'être appelé partout sans consommer le budget).
//
// Si une version de l'émulateur change l'une de ces règles, ce test échoue et le budget
// documenté dans docs/engineering/clubs-roles-plan.md est à refaire.
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

import { allowed, projectId } from './support.mjs';

const host = process.env.FIRESTORE_EMULATOR_HOST;
const [emulatorHost, port] = host.split(':');

const distinct = (n) =>
  Array.from({ length: n }, (_, i) => `exists(/databases/$(database)/documents/d/doc${i + 1})`).join(' && ');
const same = (n) =>
  Array.from({ length: n }, () => 'get(/databases/$(database)/documents/d/doc1).data.ok == true').join(' && ');

const rules = `rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /dix/{x} { allow get: if ${distinct(10)}; }
    match /onze/{x} { allow get: if ${distinct(11)}; }
    match /meme/{x} { allow get: if ${same(15)}; }
  }
}`;

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules, host: emulatorHost, port: Number(port) },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (let i = 1; i <= 12; i += 1) await setDoc(doc(db, `d/doc${i}`), { ok: true });
    for (const name of ['dix', 'onze', 'meme']) await setDoc(doc(db, `${name}/x`), {});
  });
});

after(async () => {
  await env?.cleanup();
});

const read = (path) => allowed(() => getDoc(doc(env.unauthenticatedContext().firestore(), path)));

test('dix documents distincts passent, le onzième est refusé', async () => {
  assert.equal(await read('dix/x'), true);
  assert.equal(await read('onze/x'), false);
});

test('un même document lu quinze fois ne compte qu\'une fois', async () => {
  assert.equal(await read('meme/x'), true);
});
