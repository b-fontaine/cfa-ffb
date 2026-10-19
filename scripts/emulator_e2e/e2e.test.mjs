// Parcours de bout en bout : APPLICATION (navigateur) + émulateurs Auth et Firestore + graine
// (lot FB3, ADR 0024). Ce que ni les tests Dart (doubles en mémoire), ni les tests de règles
// (SDK web seul), ni la fumée du build de production (Firestore refusé) ne prouvent : une
// directrice se connecte avec un vrai jeton de l'émulateur, l'application lit ses appartenances
// dans Firestore SOUS LES RÈGLES, et « Mon club » affiche l'équipe semée ; un parent ne voit que
// ses enfants.
//
// L'application tourne en MODE DEBUG (`flutter run -d web-server`, DDC) et non en build compilé :
// le build `--profile` (seul autre mode qui accepte l'émulateur, la release le refuse) est
// inutilisable avec firebase_auth_web 6.x, qui y désabonne l'écoute de la session (clé de
// désabonnement partagée « no-op » ; voir docs/engineering/testing.md, « Piège »). Le build de
// production est éprouvé par scripts/web_smoke/ (Auth) ; ici, le chemin applicatif complet.
//
// Prérequis : scripts/emulator_e2e.sh (émulateurs, graine, application servie, variable E2E_URL).
// L'application et la graine visent le projet « demo-cfa-ffb » : aucune requête n'atteint un
// projet réel (la graine refuse tout autre projet, et seul localhost est joignable (le SDK web est servi en local)).
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { chromium } from 'playwright-core';

import { deleteApp, initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import {
  collection,
  connectFirestoreEmulator,
  deleteDoc,
  doc,
  getDocs,
  getFirestore,
  serverTimestamp,
  setDoc,
} from 'firebase/firestore';

import { accounts, demoClubId, demoPassword, passingAttempt } from '../seed_emulator.mjs';

const baseUrl = process.env.E2E_URL;
assert.ok(baseUrl && /^http:\/\/(127\.0\.0\.1|localhost):\d+\/?$/.test(baseUrl), 'E2E_URL absent ou non local : lancer ce test par scripts/emulator_e2e.sh');
assert.match(process.env.GCLOUD_PROJECT ?? '', /^demo-/, 'le projet doit commencer par « demo- »');

let browser;
let context;
let page;
const blocked = new Set();
const pageErrors = [];
// Fichiers du SDK web demandés à l'application elle-même (et non à gstatic.com, FB5a).
const sdkFiles = new Set();

// Un autre appareil : un client Node qui se connecte à l'émulateur Auth avec un vrai jeton et écrit
// sous les VRAIES règles (l'animateur qui saisit, le directeur qui retire un accès).
const [firestoreHost, firestorePort] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
const otherApps = [];
const otherDevice = async (email) => {
  const app = initializeApp({ apiKey: 'e2e', projectId: process.env.GCLOUD_PROJECT }, `other-${otherApps.length}-${Date.now()}`);
  otherApps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${authHost}`, { disableWarnings: true });
  await signInWithEmailAndPassword(auth, email, demoPassword);
  const db = getFirestore(app);
  connectFirestoreEmulator(db, firestoreHost, Number(firestorePort));
  return db;
};

const route = (r) => {
  const url = new URL(r.request().url());
  const local = url.hostname === '127.0.0.1' || url.hostname === 'localhost';
  // Pas de gstatic.com : le SDK web est servi en local (carte d'import de index.html) et le moteur
  // aussi (`flutter run --no-web-resources-cdn`, serve_and_test.sh).
  if (local) return r.continue();
  // Seule exception, refusée sans faire échouer le test : la police de repli que le moteur de
  // Flutter demande à `fonts.gstatic.com` en mode debug quand un glyphe manque (absente du build de
  // production, la fumée le prouve). Rien n'est joignable : l'écran reste lisible avec Exo 2.
  if (url.hostname === 'fonts.gstatic.com') return r.abort();
  blocked.add(url.hostname);
  return r.abort();
};

const enableSemantics = () =>
  page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());

// Chaque parcours repart d'un navigateur vierge : aucune session ni club retenu d'un parcours à l'autre.
const open = async () => {
  await context?.close();
  context = await browser.newContext({ serviceWorkers: 'block', locale: 'fr-FR' });
  await context.route('**/*', route);
  page = await context.newPage();
  page.on('pageerror', (error) => pageErrors.push(error.message));
  page.on('request', (request) => {
    const match = /^https?:\/\/(?:127\.0\.0\.1|localhost):\d+\/(?:.*\/)?firebasejs\/[0-9.]+\/([\w.-]+\.js)$/.exec(request.url());
    if (match) sdkFiles.add(match[1]);
  });
  await page.goto(baseUrl);
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 180_000 });
  await enableSemantics();
};

const see = async (name, options = {}) => {
  try {
    await page.getByText(name, options).first().waitFor({ state: 'visible', timeout: 30_000 });
  } catch (error) {
    const shown = await page.evaluate(() => document.body.innerText).catch(() => '(illisible)');
    throw new Error(`« ${name} » absent de ${page.url()} ; affiché : ${shown}`, { cause: error });
  }
};

// Une ligne de membre avec son bouton « Retirer l'accès » est un groupe sémantique dont le nom
// (« Sophie\nEnseignant ») est l'étiquette ; sans bouton, c'est un simple texte.
const seeMember = async (name) => {
  const row = page.locator(`flt-semantics[aria-label^="${name}"]`).or(page.getByText(name));
  try {
    await row.first().waitFor({ state: 'visible', timeout: 30_000 });
  } catch (error) {
    const shown = await page.evaluate(() => document.body.innerText).catch(() => '(illisible)');
    throw new Error(`membre « ${name} » absent de ${page.url()} ; affiché : ${shown}`, { cause: error });
  }
};

const typeInto = async (label, value) => {
  const field = page.getByLabel(label, { exact: true });
  let typed = '';
  for (let attempt = 0; attempt < 4 && typed !== value; attempt++) {
    await field.click();
    await page.waitForFunction(() => ['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName));
    await page.waitForTimeout(300);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.type(value, { delay: 15 });
    typed = await page.evaluate(() => document.activeElement.value);
  }
  assert.equal(typed, value, `saisie incomplète dans « ${label} »`);
};

const signInAs = async (email) => {
  await open();
  await see('Connexion à l’application');
  await typeInto('Adresse e-mail', email);
  await typeInto('Mot de passe', demoPassword);
  await page.getByRole('button', { name: 'Se connecter', exact: true }).click();
};

// Ce que l'écran donne à lire : le texte ET les étiquettes d'accessibilité (une puce de choix ou
// un bouton n'a que son étiquette, pas de texte).
const visible = () =>
  page.evaluate(() =>
    [
      document.body.innerText,
      ...[...document.querySelectorAll('[aria-label]')].map((e) => e.getAttribute('aria-label')),
    ].join('\n'),
  );

// Une puce de choix d'enfant (étiquette = prénom).
const childChip = (name) => page.getByLabel(name, { exact: true }).first();
const seeChild = async (name) => {
  try {
    await childChip(name).waitFor({ state: 'visible', timeout: 30_000 });
  } catch (error) {
    throw new Error(`puce « ${name} » absente de ${page.url()} ; affiché : ${await visible()}`, { cause: error });
  }
};

// Les onglets du bas portent « Onglet n sur m » après leur libellé : on cherche le début du texte.
const goTo = async (name) => {
  await page.getByText(new RegExp(`^${name}`)).first().click();
};

before(async () => {
  browser = await chromium.launch({ channel: 'chrome', headless: true });
});

after(async () => {
  await Promise.all(otherApps.map((app) => deleteApp(app)));
  await context?.close();
  await browser?.close();
});

describe('application + émulateurs Auth et Firestore + graine', () => {
  test('la directrice se connecte et voit l’équipe de son club dans « Mon club »', async () => {
    await signInAs(accounts.director.email);

    // Ni « Aucun club » ni « Service injoignable » : l'application a lu ses appartenances.
    await see(/^Plus/);
    await goTo('Plus');
    await see('Mon club');
    await goTo('Mon club');
    await see('Équipe et familles');
    for (const name of ['Nadia', 'Sophie', 'Julien', 'Anne', 'Camille']) {
      await seeMember(name);
    }
    // Quatre membres à retirer (ni soi-même) : l'équipe et les familles viennent bien de Firestore.
    assert.equal(await page.getByText('Retirer l’accès').count(), 4);
    assert.equal(await page.getByText('Aucun club', { exact: true }).count(), 0);
    assert.equal(await page.getByText('Service injoignable', { exact: true }).count(), 0);
  });

  test('le parent atterrit sur « Mes enfants » : ni l’animateur, ni « Mon club »', async () => {
    await signInAs(accounts.parent.email);

    // Rôle lu dans Firestore (guardian) : l'accueil est celui d'un parent, ses données aussi
    // (FB6 : l'application est lancée avec DATA_BACKEND=firestore explicite, serve_and_test.sh ; voir les parcours suivants).
    await see('Mes enfants');
    assert.equal(await page.getByText(/^Aujourd/).count(), 0, 'pas d’onglet animateur');
    await goTo('Plus');
    // « Mon club » est l'entrée de l'animateur dans « Plus » : absente pour un parent.
    assert.equal(await page.getByText('Mon club', { exact: true }).count(), 0);
    // Une adresse tapée à la main ne contourne pas le garde de rôle : /club ramène à /my-children
    // et l'écran « Équipe et familles » (propre à /club) ne s'affiche pas.
    await page.goto(`${baseUrl}#/club`);
    await page.waitForURL(/#\/my-children$/, { timeout: 30_000 });
    await enableSemantics();
    await see('Mes enfants');
    assert.equal(await page.getByText('Équipe et familles').count(), 0);
  });

  test('le parent de deux enfants voit ses deux enfants et seulement eux, sans aucune action d’animateur', async () => {
    await signInAs(accounts.parent.email);

    // Espace du parent : le sélecteur d'enfant (Léa puis Tom, dans l'ordre du lien).
    await see('Mes enfants');
    await seeChild('Léa');
    await seeChild('Tom');
    await see('Parcours à commencer');
    // Les séances de SON groupe seulement.
    await see('Prochaines séances');
    await see('Rebond au centre');
    const shown = await visible();
    for (const other of ['Marc', 'Camille', 'Séance des adultes']) {
      assert.ok(!shown.includes(other), `« ${other} » ne doit pas être visible : ${shown}`);
    }
    // Aucune action d'animateur : ni onglet, ni bouton d'écriture.
    for (const action of [/^Aujourd/, /^Élèves/, /^Résultats/, /^Séances/, 'Noter', 'Planifier', 'Inviter', 'Saisir', 'Terminé']) {
      assert.equal(await page.getByText(action).count(), 0, `action « ${action} » visible`);
    }
    // Une adresse tapée à la main n'ouvre aucun écran d'animateur.
    for (const hash of ['#/students', '#/record', '#/planner', '#/club', '#/settings']) {
      await page.goto(`${baseUrl}${hash}`);
      await page.waitForURL(/#\/my-children$/, { timeout: 30_000 });
      await enableSemantics();
      await see('Mes enfants');
    }
    // Plus : ni « Mon club » ni réglages.
    await goTo('Plus');
    assert.equal(await page.getByText('Mon club', { exact: true }).count(), 0);
  });

  test('le parent voit la saisie d’un animateur apparaître sans recharger, et ne mélange jamais ses deux enfants', async () => {
    await signInAs(accounts.parent.email);
    await see('Parcours à commencer');
    const origin = await page.evaluate(() => performance.timeOrigin);

    // L'animateur (autre appareil, vraies règles) saisit deux exercices réussis pour Léa.
    const coach = await otherDevice(accounts.teacherA.email);
    for (const [exercise, count] of [[1, 5], [2, 5]]) {
      for (let n = 1; n <= count; n++) {
        const id = `lea-${exercise}-${n}-${Date.now()}`;
        await setDoc(
          doc(coach, `clubs/${demoClubId}/attempts/${id}`),
          passingAttempt('s-lea', 'g-enfants', id, serverTimestamp(), exercise),
        );
      }
    }

    // Sans recharger : la page est la même, l'écran de Léa a changé.
    await see('2 exercices validés');
    assert.equal(await page.getByText('Parcours à commencer').count(), 0);
    assert.equal(await page.evaluate(() => performance.timeOrigin), origin, 'la page a été rechargée');

    // Tom a son propre parcours (un exercice), jamais celui de Léa.
    await childChip('Tom').click();
    await see('1 exercice validé');
    assert.equal(await page.getByText('2 exercices validés').count(), 0, 'les deux enfants se mélangent');
    await childChip('Léa').click();
    await see('2 exercices validés');
    assert.equal(await page.getByText('1 exercice validé', { exact: true }).count(), 0);
  });

  test('l’élève de 15 ans arrive sur sa progression : la sienne et rien d’un autre élève', async () => {
    await signInAs(accounts.teen.email);

    await see('Ma progression');
    await see('Camille');
    await see('Prochaines séances');
    await see('Rebond au centre');
    const shown = await visible();
    for (const other of ['Léa', 'Tom', 'Marc', 'Séance des adultes']) {
      assert.ok(!shown.includes(other), `« ${other} » ne doit pas être visible : ${shown}`);
    }
    assert.equal(await page.getByText(/^Élèves/).count(), 0);
  });

  test('le directeur retire l’accès du parent : son écran passe à « Accès retiré » sans recharger', async () => {
    await signInAs(accounts.parent.email);
    await see('Léa');
    const origin = await page.evaluate(() => performance.timeOrigin);

    // Le directeur (autre appareil) retire le lien du parent.
    const director = await otherDevice(accounts.director.email);
    const members = await getDocs(collection(director, `clubs/${demoClubId}/members`));
    const parent = members.docs.find((d) => d.data().displayName === accounts.parent.name);
    assert.ok(parent, 'le member du parent est dans la graine');
    await deleteDoc(parent.ref);

    await see('Accès retiré');
    assert.equal(await page.evaluate(() => performance.timeOrigin), origin, 'la page a été rechargée');
    const shown = await visible();
    for (const gone of ['Rebond au centre', '1 exercice validé', 'Parcours à commencer']) {
      assert.ok(!shown.includes(gone), `« ${gone} » doit avoir disparu : ${shown}`);
    }
  });

  test('le SDK web est servi par l’application, aucun appel vers un hôte autre que localhost, aucune erreur de page', () => {
    assert.deepEqual(
      [...sdkFiles].sort(),
      ['firebase-app.js', 'firebase-auth.js', 'firebase-firestore-pipelines.js'],
    );
    assert.deepEqual([...blocked], []);
    assert.deepEqual(pageErrors, []);
  });
});
