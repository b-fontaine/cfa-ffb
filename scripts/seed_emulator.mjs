#!/usr/bin/env node
// Graine des ÉMULATEURS Firebase (lot FB3, ADR 0024 décision 14 et C6) : un jeu de comptes et
// de données pour essayer les rôles à la main ou dans la fumée du build web.
//
//   scripts/seed_emulator.mjs                 (émulateurs lancés : `task emulators`)
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
//     GCLOUD_PROJECT=demo-cfa-ffb node scripts/seed_emulator.mjs
//
// DEV UNIQUEMENT. Le script REFUSE de s'exécuter si :
//   - l'hôte Firestore ou Auth n'est pas local (127.0.0.1, localhost, [::1]) ;
//   - le projet ne commence pas par « demo- » (jamais le projet réel `animation-billard`).
// Il n'utilise aucun identifiant de service et n'ouvre aucune connexion vers Google : tout passe
// par les hôtes d'émulateur. Mots de passe : un seul mot de passe de démonstration public, valable
// UNIQUEMENT dans l'émulateur.
//
// Contenu : un administrateur, un directeur, deux enseignants, un parent de deux enfants, un
// élève de 15 ans avec son propre compte, le club « Démo » avec deux groupes, ses fiches
// d'élèves et un code d'invitation d'enseignant valable.
import { pathToFileURL } from 'node:url';

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteApp, initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  signInWithEmailAndPassword,
} from 'firebase/auth';
import { Timestamp, doc, setDoc } from 'firebase/firestore';

/** Mot de passe de tous les comptes de démonstration (public, émulateur seulement). */
export const demoPassword = 'demo-password-2026';

/** Code d'invitation d'enseignant laissé valable (club « Démo »). */
export const demoInvitationCode = 'DEMOCODE2222';

export const demoClubId = 'demo';

/** Comptes de la graine : e-mail, rôle, identité dans le club. */
export const accounts = {
  admin: { email: 'admin@demo.test', role: 'admin' },
  director: { email: 'directrice@demo.test', role: 'director', name: 'Nadia' },
  teacherA: { email: 'prof.enfants@demo.test', role: 'teacher', name: 'Sophie', groups: ['g-enfants'] },
  teacherB: { email: 'prof.adultes@demo.test', role: 'teacher', name: 'Julien', groups: ['g-adultes'] },
  parent: {
    email: 'parent@demo.test',
    role: 'guardian',
    name: 'Anne',
    groups: ['g-enfants'],
    students: ['s-lea', 's-tom'],
  },
  teen: { email: 'ado@demo.test', role: 'student', name: 'Camille', groups: ['g-enfants'], students: ['s-camille'] },
};

const localHost = /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/;

/**
 * Refuse tout ce qui n'est pas un émulateur local et un projet de démonstration. Lève une erreur
 * dont le message dit pourquoi.
 */
export const assertLocalEmulators = ({ firestoreHost, authHost, projectId }) => {
  if (!firestoreHost || !localHost.test(firestoreHost)) {
    throw new Error(`hôte Firestore refusé (« ${firestoreHost ?? ''} ») : un émulateur local est exigé`);
  }
  if (!authHost || !localHost.test(authHost)) {
    throw new Error(`hôte Auth refusé (« ${authHost ?? ''} ») : un émulateur local est exigé`);
  }
  if (!/^demo-/.test(projectId ?? '')) {
    throw new Error(`projet refusé (« ${projectId ?? ''} ») : seul un projet « demo-… » est accepté`);
  }
};

/** Lit l'environnement ; les hôtes par défaut sont ceux de firebase.json. */
export const environmentFrom = (env = process.env) => ({
  firestoreHost: env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080',
  authHost: env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099',
  projectId: env.GCLOUD_PROJECT ?? env.FIREBASE_PROJECT_ID ?? '',
});

const verifiedUser = async (auth, authHost, projectId, email) => {
  let credential;
  try {
    credential = await createUserWithEmailAndPassword(auth, email, demoPassword);
  } catch (error) {
    if (error.code !== 'auth/email-already-in-use') throw error;
    credential = await signInWithEmailAndPassword(auth, email, demoPassword);
  }
  // Compte d'émulateur : l'adresse est marquée vérifiée par l'API d'administration locale.
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:update`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: 'Bearer owner' },
      body: JSON.stringify({ localId: credential.user.uid, emailVerified: true }),
    },
  );
  if (!response.ok) throw new Error(`vérification de ${email} impossible : ${response.status}`);
  return credential.user.uid;
};

/**
 * Crée les comptes (adresses vérifiées) et écrit les documents (règles désactivées, comme une
 * mise en place par la console). Idempotent. Renvoie les identifiants des comptes.
 */
export const seedEmulators = async (environment = environmentFrom()) => {
  assertLocalEmulators(environment);
  const { firestoreHost, authHost, projectId } = environment;
  const [host, port] = firestoreHost.split(':');

  const app = initializeApp({ apiKey: 'seed', projectId }, `seed-${process.pid}-${Date.now()}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${authHost}`, { disableWarnings: true });
  const uids = {};
  try {
    for (const [key, account] of Object.entries(accounts)) {
      uids[key] = await verifiedUser(auth, authHost, projectId, account.email);
    }
  } finally {
    await deleteApp(app);
  }

  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { host, port: Number(port) },
  });
  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const now = Timestamp.now();
      const put = (path, data) => setDoc(doc(db, path), data);

      await put(`admins/${uids.admin}`, {});
      await put(`clubs/${demoClubId}`, { name: 'Démo', createdAt: now });
      await put(`clubs/${demoClubId}/settings/main`, {
        passesRequired: 5,
        alertThreshold: 3,
        recallStaleSessions: 4,
        groupFailureSharePercent: 50,
      });
      await put(`clubs/${demoClubId}/seasons/saison`, {
        label: '2026-2027',
        startDate: Timestamp.fromDate(new Date('2026-09-01')),
        endDate: Timestamp.fromDate(new Date('2027-08-31')),
      });
      await put(`clubs/${demoClubId}/groups/g-enfants`, {
        seasonId: 'saison',
        name: 'Enfants du mardi',
        audience: 'children',
        teacherUids: [uids.teacherA],
      });
      await put(`clubs/${demoClubId}/groups/g-adultes`, {
        seasonId: 'saison',
        name: 'Adultes du jeudi',
        audience: 'adults',
        teacherUids: [uids.teacherB],
      });
      const students = {
        's-lea': { firstName: 'Léa', audience: 'children', groupIds: ['g-enfants'] },
        's-tom': { firstName: 'Tom', audience: 'children', groupIds: ['g-enfants'] },
        's-camille': { firstName: 'Camille', audience: 'children', groupIds: ['g-enfants'] },
        's-marc': { firstName: 'Marc', audience: 'adults', groupIds: ['g-adultes'] },
      };
      for (const [id, student] of Object.entries(students)) {
        await put(`clubs/${demoClubId}/students/${id}`, { ...student, createdAt: now });
      }
      for (const [key, account] of Object.entries(accounts)) {
        if (account.role === 'admin') continue;
        await put(`clubs/${demoClubId}/members/${uids[key]}`, {
          uid: uids[key],
          role: account.role,
          displayName: account.name,
          groupIds: account.groups ?? [],
          studentIds: account.students ?? [],
          createdAt: now,
        });
      }
      await put(`invitations/${demoInvitationCode}`, {
        clubId: demoClubId,
        role: 'teacher',
        groupIds: ['g-enfants'],
        studentIds: [],
        createdBy: uids.director,
        createdAt: now,
        expiresAt: Timestamp.fromMillis(Date.now() + 24 * 3600 * 1000),
        used: false,
      });
    });
  } finally {
    await testEnv.cleanup();
  }
  return uids;
};

// Lancement direct : `node scripts/seed_emulator.mjs`.
if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  const environment = environmentFrom();
  try {
    assertLocalEmulators(environment);
  } catch (error) {
    console.error(`✘ ${error.message}`);
    process.exit(1);
  }
  const uids = await seedEmulators(environment);
  console.log(`✔ Graine posée dans ${environment.projectId} (${Object.keys(uids).length} comptes).`);
  console.log(`  Mot de passe commun : ${demoPassword}`);
  for (const account of Object.values(accounts)) console.log(`  ${account.role.padEnd(9)} ${account.email}`);
  console.log(`  Code d'invitation (enseignant, club Démo) : ${demoInvitationCode}`);
  process.exit(0);
}
