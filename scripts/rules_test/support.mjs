// Socle commun des tests des règles Firestore (lot FB3, ADR 0024) : environnement
// d'émulateur, acteurs, jeu de données de départ.
//
// Tout tourne contre l'ÉMULATEUR (scripts/rules_test.sh), projet « demo-… » : aucune requête
// n'atteint le projet Firebase réel. Les fichiers de test sont exécutés l'un après l'autre
// (`--test-concurrency=1`) : ils partagent la même base d'émulateur.
//
// `RULES_FILE` (variable d'environnement) remplace `firestore.rules` : c'est ce qui permet les
// mutations à la main sur une COPIE des règles (docs/engineering/testing.md), jamais sur le
// fichier versionné.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, doc, setDoc, setLogLevel } from 'firebase/firestore';

// Les refus attendus ne doivent pas noyer la sortie du garde-fou.
setLogLevel('silent');

export const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
export const rulesPath = process.env.RULES_FILE
  ? resolve(process.env.RULES_FILE)
  : resolve(root, 'firestore.rules');

const host = process.env.FIRESTORE_EMULATOR_HOST;
export const projectId = process.env.GCLOUD_PROJECT ?? '';

// Garde de sécurité : jamais autre chose que l'émulateur local et un projet « demo- ».
assert.ok(
  host && /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host),
  'FIRESTORE_EMULATOR_HOST absent ou non local : lancer ces tests par scripts/rules_test.sh',
);
assert.match(projectId, /^demo-/, 'le projet des tests de règles doit commencer par « demo- »');

export const readRules = () => readFileSync(rulesPath, 'utf8');

export const createEnv = async () => {
  const [emulatorHost, port] = host.split(':');
  return initializeTestEnvironment({
    projectId,
    firestore: { rules: readRules(), host: emulatorHost, port: Number(port) },
  });
};

// ───────────────────────── Acteurs ─────────────────────────
//
// Club `c1` : u-dir (directeur), u-teacher-a (groupe g1), u-teacher-b (groupe g2), u-student
// (élève s1, groupe g1), u-guardian (parent de s1), u-guardian2 (parent de s2, groupe g2).
// Club `c2` : u-dir2 (directeur), u-teacher-c2 (enseignant, groupe aussi nommé g1 : l'identifiant
// d'un groupe ne vaut que dans son club). u-admin : document `admins/u-admin`, aucun member.
// u-invited : compte vérifié sans member. u-dir avec une adresse non vérifiée : « unverified ».
export const actors = {
  anonymous: (env) => env.unauthenticatedContext(),
  unverified: (env) => env.authenticatedContext('u-dir', { email: 'dir@example.org', email_verified: false }),
  invited: (env) => verifiedContext(env, 'u-invited'),
  student: (env) => verifiedContext(env, 'u-student'),
  guardian: (env) => verifiedContext(env, 'u-guardian'),
  guardian2: (env) => verifiedContext(env, 'u-guardian2'),
  teacherA: (env) => verifiedContext(env, 'u-teacher-a'),
  teacherB: (env) => verifiedContext(env, 'u-teacher-b'),
  teacherC2: (env) => verifiedContext(env, 'u-teacher-c2'),
  director: (env) => verifiedContext(env, 'u-dir'),
  directorOther: (env) => verifiedContext(env, 'u-dir2'),
  admin: (env) => verifiedContext(env, 'u-admin'),
};

export const actorNames = Object.keys(actors);

/** L'uid de chaque acteur (les acquittements enregistrent `createdBy` = uid du compte, B5). */
export const uids = {
  student: 'u-student',
  guardian: 'u-guardian',
  guardian2: 'u-guardian2',
  teacherA: 'u-teacher-a',
  teacherB: 'u-teacher-b',
  teacherC2: 'u-teacher-c2',
  director: 'u-dir',
  directorOther: 'u-dir2',
  admin: 'u-admin',
  invited: 'u-invited',
  unverified: 'u-dir',
};

function verifiedContext(env, uid) {
  return env.authenticatedContext(uid, { email: `${uid}@example.org`, email_verified: true });
}

export const dbOf = (env, actor) => actors[actor](env).firestore();

// ───────────────────────── Jeu de données ─────────────────────────

export const now = () => Date.now();
export const ts = (millis) => Timestamp.fromMillis(millis);
export const hours = (n) => n * 3600 * 1000;
export const days = (n) => n * 24 * hours(1);

const createdAt = () => ts(now() - days(30));

export const member = (uid, role, extra = {}) => ({
  uid,
  role,
  groupIds: [],
  studentIds: [],
  displayName: uid,
  createdAt: createdAt(),
  ...extra,
});

export const student = (groupIds, extra = {}) => ({ firstName: 'Léa', groupIds, ...extra });
export const owned = (groupId, studentId, extra = {}) => ({
  groupId,
  seasonId: 'se1',
  ...(studentId ? { studentId } : {}),
  ...extra,
});

/**
 * Complète un document de donnée d'élève avec les champs que les codecs de l'application lisent
 * et que les règles exigent à la CRÉATION (un document minimal rendrait la lecture de toute la
 * liste impossible). Les champs fournis l'emportent ; une autre collection est rendue telle quelle.
 */
const REQUIRED_AT_CREATION = {
  attempts: () => ({
    sessionId: 'x1', blockId: 'puissance', exerciseNumber: 1, date: '2026-10-03T00:00:00.000',
    potted: 4, total: 5, recordedAt: Timestamp.fromMillis(Date.now()),
  }),
  acquisitions: () => ({ blockId: 'puissance', date: '2026-09-15T00:00:00.000', source: 'placement' }),
  assessments: () => ({ date: '2026-10-05T00:00:00.000', concentration: 3, endurance: 2, frustration: 4 }),
  acknowledgements: () => ({
    blockId: 'puissance', exerciseNumber: 1, lastAttemptId: 'a1', date: '2026-10-05T00:00:00.000',
  }),
};
export const complete = (name, data) => ({ ...(REQUIRED_AT_CREATION[name]?.() ?? {}), ...data });

export const invitation = (extra = {}) => ({
  clubId: 'c1',
  role: 'teacher',
  groupIds: [],
  studentIds: [],
  createdBy: 'u-dir',
  createdAt: createdAt(),
  expiresAt: ts(now() + days(1)),
  used: false,
  ...extra,
});

/** Documents de départ : [chemin, données]. */
export const seedDocs = () => [
  ['admins/u-admin', {}],
  ['admins/u-admin2', {}],
  ['clubs/c1', { name: 'Club un', createdAt: createdAt() }],
  ['clubs/c2', { name: 'Club deux', createdAt: createdAt() }],
  ['clubs/c1/members/u-dir', member('u-dir', 'director', { displayName: 'Directrice' })],
  ['clubs/c1/members/u-teacher-a', member('u-teacher-a', 'teacher', { groupIds: ['g1'] })],
  ['clubs/c1/members/u-teacher-b', member('u-teacher-b', 'teacher', { groupIds: ['g2'] })],
  ['clubs/c1/members/u-student', member('u-student', 'student', { groupIds: ['g1'], studentIds: ['s1'] })],
  ['clubs/c1/members/u-guardian', member('u-guardian', 'guardian', { groupIds: ['g1'], studentIds: ['s1'] })],
  ['clubs/c1/members/u-guardian2', member('u-guardian2', 'guardian', { groupIds: ['g2'], studentIds: ['s2'] })],
  ['clubs/c2/members/u-dir2', member('u-dir2', 'director')],
  ['clubs/c2/members/u-teacher-c2', member('u-teacher-c2', 'teacher', { groupIds: ['g1'] })],
  ['clubs/c1/settings/main', { passesRequired: 5, alertThreshold: 3, recallStaleSessions: 4, groupFailureSharePercent: 50 }],
  ['clubs/c1/seasons/se1', { label: '2026-2027' }],
  ['clubs/c1/groups/g1', { seasonId: 'se1', name: 'Mardi', audience: 'children', teacherUids: ['u-teacher-a'] }],
  ['clubs/c1/groups/g2', { seasonId: 'se1', name: 'Jeudi', audience: 'adults', teacherUids: ['u-teacher-b'] }],
  ['clubs/c1/memberships/s1_2026-09-01', owned('g1', 's1', { from: '2026-09-01T00:00:00.000' })],
  ['clubs/c1/memberships/s2_2026-09-01', owned('g2', 's2', { from: '2026-09-01T00:00:00.000' })],
  ['clubs/c1/students/s1', student(['g1'])],
  ['clubs/c1/students/s2', student(['g2'], { firstName: 'Tom' })],
  ['clubs/c1/sessions/ss-g1', owned('g1')],
  ['clubs/c1/sessions/ss-g2', owned('g2')],
  ['clubs/c1/records/r-g1', owned('g1')],
  ['clubs/c1/records/r-g2', owned('g2')],
  ['clubs/c1/attempts/a-g1', owned('g1', 's1')],
  ['clubs/c1/attempts/a-g2', owned('g2', 's2')],
  ['clubs/c1/acquisitions/q-g1', owned('g1', 's1')],
  ['clubs/c1/acquisitions/q-g2', owned('g2', 's2')],
  ['clubs/c1/assessments/as-g1', owned('g1', 's1', { comment: 'ok' })],
  ['clubs/c1/assessments/as-g2', owned('g2', 's2')],
  ['clubs/c1/acknowledgements/k-g1', owned('g1', 's1')],
  ['clubs/c1/acknowledgements/k-g2', owned('g2', 's2')],
  ['clubs/c1/archives/ar1', { seasonId: 'se1', public: 'children' }],
  ['clubs/c2/students/s-c2', student(['g1'], { firstName: 'Zoé' })],
  ['clubs/c2/attempts/a-c2', owned('g1', 's-c2')],
  ['invitations/AAAAAAAAAA', invitation({ role: 'teacher', groupIds: ['g1'] })],
];

export const seed = async (env) => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [path, data] of seedDocs()) {
      await setDoc(doc(ctx.firestore(), path), data);
    }
  });
};

/** Écrit (sans règles) un document de départ, par exemple pour remettre une cible à zéro. */
export const put = async (env, path, data) =>
  env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));

export const remove = async (env, path) =>
  env.withSecurityRulesDisabled((ctx) => ctx.firestore().doc(path).delete());

/**
 * Exécute une opération Firestore : `true` si elle est acceptée, `false` si les règles la
 * refusent (`permission-denied`). Toute autre erreur est une erreur du test lui-même et
 * remonte : un refus ne doit jamais venir d'une requête mal formée.
 */
export const allowed = async (operation) => {
  try {
    await operation();
    return true;
  } catch (error) {
    if (error?.code === 'permission-denied') return false;
    throw error;
  }
};
