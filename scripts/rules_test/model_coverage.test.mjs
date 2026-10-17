// Couverture du modèle : `firestore.rules` couvre chaque collection de l'ADR 0024, et rien
// d'autre (lot FB3). La liste des collections est `model.json` ; ce test la compare
//   1. aux blocs `match` du fichier de règles (ni oubli, ni collection non documentée) ;
//   2. à l'ADR 0024 (chaque ligne du tableau « document × rôle » citée) ;
//   3. aux tests : chaque collection a sa grille dans matrix.test.mjs.
// Il vérifie aussi que le fichier de règles ne contient aucune autorisation inconditionnelle,
// aucune date d'expiration, et se termine par le refus par défaut.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { readRules, root } from './support.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const model = JSON.parse(readFileSync(resolve(here, 'model.json'), 'utf8'));

const stripComments = (text) => text.replace(/\/\/[^\n]*/g, (m) => ' '.repeat(m.length));

/** Chemins complets (variables normalisées en `{}`) des blocs `match` du fichier de règles. */
export const matchedPaths = (rules) => {
  const text = stripComments(rules);
  // Les variables de chemin (`{clubId}`, `{path=**}`) sont masquées, à longueur égale, pour que
  // le comptage des accolades ne voie que la structure.
  const masked = text.replace(/\{[A-Za-z_][A-Za-z0-9_]*(?:=\*\*)?\}/g, (m) => '_'.repeat(m.length));
  const stack = [];
  const found = [];
  for (const m of masked.matchAll(/match\s+(\/\S+)\s*\{/g)) {
    const start = m.index;
    const open = start + m[0].length - 1;
    let depth = 0;
    let end = open;
    for (let i = open; i < masked.length; i += 1) {
      if (masked[i] === '{') depth += 1;
      if (masked[i] === '}') {
        depth -= 1;
        if (depth === 0) {
          end = i;
          break;
        }
      }
    }
    while (stack.length && stack.at(-1).end < start) stack.pop();
    const rawPath = text.slice(m.index + m[0].indexOf('/'), m.index + m[0].indexOf('/') + m[1].length);
    const local = rawPath
      .replace(/\{[^}]*=\*\*\}/g, '\u0000')
      .replace(/\{[^}]*\}/g, '{}')
      .replace(/\u0000/g, '{**}');
    const full = [...stack.map((s) => s.local), local].join('');
    stack.push({ end, local });
    found.push(full.replace(/^\/+/, '').replace(/\/+/g, '/'));
  }
  // Le bloc racine `/databases/{database}/documents` n'est pas une collection.
  const racine = 'databases/{}/documents';
  return found.filter((p) => p !== racine).map((p) => p.slice(racine.length + 1));
};

test('firestore.rules couvre exactement les collections de model.json', () => {
  const wanted = [...model.collections, ...model.speciaux].map((c) => c.path).sort();
  const actual = matchedPaths(readRules()).sort();
  assert.deepEqual(actual, wanted);
});

test('chaque collection du modèle est citée par le tableau de l\'ADR 0024', () => {
  const adr = readFileSync(resolve(root, model.adr), 'utf8');
  for (const collection of model.collections) {
    assert.ok(adr.includes(collection.adr), `ADR 0024 : ${collection.adr} (${collection.name})`);
  }
});

test('chaque collection du modèle a sa grille de droits dans matrix.test.mjs', () => {
  const matrix = readFileSync(resolve(here, 'matrix.test.mjs'), 'utf8');
  for (const collection of model.collections) {
    if (collection.name === 'invitations') continue; // grille de lecture ici, le reste dans invitations.test.mjs
    assert.match(matrix, new RegExp(`(suite|groupOwnedSuite)\\('${collection.name}'`), collection.name);
  }
  assert.match(matrix, /suite\('invitations'/);
  const invitations = readFileSync(resolve(here, 'invitations.test.mjs'), 'utf8');
  assert.match(invitations, /describe\('consommation/);
  assert.match(invitations, /describe\('révocation/);
});

test('le fichier de règles ne contient aucune autorisation inconditionnelle ni date d\'expiration', () => {
  const rules = stripComments(readRules());
  assert.doesNotMatch(rules, /:\s*if\s+true/);
  assert.doesNotMatch(rules, /request\.time\s*<\s*timestamp/);
  assert.doesNotMatch(rules, /allow[^;]*:\s*if\s*;/);
});

test('le dernier bloc refuse tout par défaut', () => {
  const rules = stripComments(readRules());
  const last = rules.lastIndexOf('match /{document=**}');
  assert.ok(last > 0, 'bloc par défaut');
  assert.match(rules.slice(last), /allow\s+read\s*,\s*write\s*:\s*if\s+false/);
  assert.equal(matchedPaths(readRules()).at(-1), '{**}', 'le refus par défaut est le dernier bloc');
});

test('l\'administrateur est détecté par l\'existence du document, jamais par un champ', () => {
  const rules = stripComments(readRules());
  assert.match(rules, /exists\(\/databases\/\$\(database\)\/documents\/admins\/\$\(request\.auth\.uid\)\)/);
  assert.doesNotMatch(rules, /admins\/[^)]*\)\.data/);
  assert.doesNotMatch(rules, /get\(\/databases\/\$\(database\)\/documents\/admins/);
});

test('l\'e-mail vérifié est exigé et le rôle se lit par un get() sur members', () => {
  const rules = stripComments(readRules());
  assert.match(rules, /request\.auth\.token\.email_verified == true/);
  assert.match(rules, /get\(\/databases\/\$\(database\)\/documents\/clubs\/\$\(c\)\/members\/\$\(request\.auth\.uid\)\)\.data/);
});
