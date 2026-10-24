// Parcours de bout en bout : APPLICATION (navigateur) + émulateurs Auth et Firestore + graine
// (lot FB3, ADR 0024). Ce que ni les tests Dart (doubles en mémoire), ni les tests de règles
// (SDK web seul), ni la fumée du build de production (Firestore refusé) ne prouvent : une
// directrice se connecte avec un vrai jeton de l'émulateur, l'application lit ses appartenances
// dans Firestore SOUS LES RÈGLES, et « Mon club » affiche l'équipe semée ; un parent ne voit que
// ses enfants ; un enseignant supprime son compte, avec l'invitation qu'il a créée ailleurs ; la
// dernière directrice ne le peut pas ; la directrice purge les marqueurs abandonnés (FB8 partie B).
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
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { after, before, describe, test } from 'node:test';

import { chromium } from 'playwright-core';

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';

import { deleteApp, initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import {
  collection,
  connectFirestoreEmulator,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  where,
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
const uids = new Map();
const uidOf = async (email) => uids.get(email);
const otherDevice = async (email) => {
  const app = initializeApp({ apiKey: 'e2e', projectId: process.env.GCLOUD_PROJECT }, `other-${otherApps.length}-${Date.now()}`);
  otherApps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${authHost}`, { disableWarnings: true });
  await signInWithEmailAndPassword(auth, email, demoPassword);
  uids.set(email, auth.currentUser.uid);
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

// Trace de la page (console, sélecteur de fichier), jointe au message d'un échec de `see`.
const trace = [];
const traceStart = Date.now();
let tracingFirestore = false;
let channelRequests = 0;
const note = (line) => {
  trace.push(`${Date.now() - traceStart} ${line}`);
  if (trace.length > 300) trace.shift();
};

const enableSemantics = () =>
  page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());

// Chaque parcours repart d'un navigateur vierge : aucune session ni club retenu d'un parcours à l'autre.
const open = async () => {
  await context?.close();
  context = await browser.newContext({ serviceWorkers: 'block', locale: 'fr-FR' });
  await context.route('**/*', route);
  page = await context.newPage();
  trace.length = 0;
  tracingFirestore = false;
  channelRequests = 0;
  page.on('pageerror', (error) => {
    pageErrors.push(error.message);
    note(`pageerror ${error.message.slice(0, 300)}`);
  });
  page.on('console', (message) => {
    // Le sélecteur de fichier et les erreurs de l'application seulement : le reste de la console
    // (polices refusées, ressources externes bloquées) ferait déborder le tampon pendant les 30 s
    // d'attente d'un `see`.
    const text = message.text();
    if (text.includes('[pick]') || text.includes('[imp]')) note(`page ${text}`);
    else if (message.type() === 'error' && !text.includes('Failed to load resource')) {
      note(`console.error ${text.slice(0, 300)}`);
    }
  });
  // Un rechargement ou une navigation de la page remettrait l'écran d'import à son étape initiale.
  page.on('load', () => note('page load'));
  page.on('framenavigated', (frame) => {
    if (frame === page.mainFrame()) note(`navigated ${frame.url()}`);
  });
  page.on('crash', () => note('page crash'));
  page.on('requestfailed', (request) => {
    const url = new URL(request.url());
    if (url.hostname === '127.0.0.1' || url.hostname === 'localhost') {
      note(`requestfailed ${request.method()} ${url.port}${url.pathname.slice(0, 80)}`);
    }
  });
  page.on('request', (request) => {
    if (!tracingFirestore) return;
    const url = new URL(request.url());
    if (url.port !== String(firestorePort)) return;
    // Les canaux d'écoute et d'écriture sont du long-polling permanent : on les compte, on ne
    // les note pas, sinon ils noient le reste de la trace.
    if (/\/(Listen|Write)\/channel$/.test(url.pathname)) channelRequests += 1;
    else note(`firestore ${request.method()} ${url.pathname.slice(-70)}`);
  });
  // Sans effet sur le comportement : note, dans la page, ce que fait le sélecteur de fichier
  // (clic sur l'input, focus, change, cancel, nombre de fichiers) pour qu'un échec en CI dise
  // si la sélection a été avalée par l'heuristique « le focus de la fenêtre vaut annulation ».
  await page.addInitScript(() => {
    const log = (message) => console.log(`[pick] ${Math.round(performance.now())} ${message}`);
    window.addEventListener('focus', () => log('window focus'), true);
    window.addEventListener('blur', () => log('window blur'), true);
    document.addEventListener('change', (event) => log(`change files=${event.target.files?.length}`), true);
    document.addEventListener('cancel', () => log('cancel'), true);
    const click = HTMLInputElement.prototype.click;
    HTMLInputElement.prototype.click = function (...args) {
      if (this.type === 'file') log('input.click');
      return click.apply(this, args);
    };
    // Ce que le sélecteur fait du fichier choisi : retrait de l'input du DOM, lecture des octets
    // (FileReader), URL d'objet, lecture par fetch d'une URL blob:.
    const removeChild = Node.prototype.removeChild;
    Node.prototype.removeChild = function (child, ...rest) {
      if (child?.tagName === 'INPUT' && child.type === 'file') log(`input retiré files=${child.files?.length}`);
      return removeChild.call(this, child, ...rest);
    };
    const readAsArrayBuffer = FileReader.prototype.readAsArrayBuffer;
    FileReader.prototype.readAsArrayBuffer = function (blob) {
      log(`FileReader.readAsArrayBuffer size=${blob?.size}`);
      this.addEventListener('loadend', () => log(`FileReader.loadend error=${this.error?.name ?? 'non'}`));
      return readAsArrayBuffer.call(this, blob);
    };
    const createObjectURL = URL.createObjectURL;
    URL.createObjectURL = function (object) {
      log(`URL.createObjectURL size=${object?.size}`);
      return createObjectURL.call(this, object);
    };
    const nativeFetch = window.fetch;
    window.fetch = function (input, ...rest) {
      const url = String(input?.url ?? input);
      if (url.startsWith('blob:')) log('fetch blob:');
      return nativeFetch.call(this, input, ...rest);
    };
  });
  page.on('request', (request) => {
    const match = /^https?:\/\/(?:127\.0\.0\.1|localhost):\d+\/(?:.*\/)?firebasejs\/[0-9.]+\/([\w.-]+\.js)$/.exec(request.url());
    if (match) sdkFiles.add(match[1]);
  });
  // Mise au point : E2E_CPU_THROTTLE=6 ralentit la page de 6 fois (processeur de Chrome seulement,
  // pas la machine ni les émulateurs) pour retrouver la lenteur d'un exécuteur de CI.
  if (process.env.E2E_CPU_THROTTLE) {
    const session = await context.newCDPSession(page);
    await session.send('Emulation.setCPUThrottlingRate', { rate: Number(process.env.E2E_CPU_THROTTLE) });
  }
  await page.goto(baseUrl);
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 180_000 });
  await enableSemantics();
};

const see = async (name, options = {}, timeout = 30_000) => {
  try {
    await page.getByText(name, options).first().waitFor({ state: 'visible', timeout });
  } catch (error) {
    const shown = await page.evaluate(() => document.body.innerText).catch(() => '(illisible)');
    const history = trace.slice(-70);
    throw new Error(
      `« ${name} » absent de ${page.url()} ; affiché : ${shown}\n  trace de la page (requêtes de canal Firestore depuis le choix du fichier : ${channelRequests}) :\n    ${history.join('\n    ') || '(rien)'}`,
      { cause: error },
    );
  }
};

// Les étapes de l'écran d'import recalculent le plan à chaque choix (relectures du club sur le
// serveur) : mesuré à ~17 s chacune dans cette version de débogage, sur une machine rapide. 30 s ne
// laissent aucune marge à un exécuteur de CI plus lent.
const importWait = 120_000;
const seeSlow = (name, options = {}) => see(name, options, importWait);

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
    // (FB6 : l'application est lancée avec le défaut Firestore, serve_and_test.sh ; voir les parcours suivants).
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

  // --- FB8, partie A : effacement d'un élève, côté serveur, par l'écran du directeur -------------
  // Le directeur efface Tom par l'écran (lots reprenables, marqueur d'opération, vraies règles) ;
  // le parent perd l'accès à cette fiche seulement ; une relecture par un autre appareil ne trouve
  // plus AUCUN document qui s'y rapporte (fiche, passages, appartenances, présences, lien du
  // compte, marqueur d'opération).
  test('le directeur efface Tom par l’écran : plus aucun document lié, et le parent perd cette seule fiche', async () => {
    const reader = await otherDevice(accounts.director.email);
    const guardian = await otherDevice(accounts.parent.email);
    const base = `clubs/${demoClubId}`;
    const linked = async (collectionName) =>
      (await getDocs(query(collection(reader, `${base}/${collectionName}`), where('studentId', '==', 's-tom')))).docs.map((d) => d.id);

    // Avant : Tom a des passages et le parent lit sa fiche.
    assert.ok((await linked('attempts')).length >= 1, 'la graine donne des passages à Tom');
    assert.ok((await getDoc(doc(guardian, `${base}/students/s-tom`))).exists(), 'le parent lit la fiche de Tom');

    await signInAs(accounts.director.email);
    await see(/^Élèves/);
    await goTo('Élèves');
    // Chaque ligne de la liste est un bouton « Ouvrir la fiche de {prénom} ».
    const openSheet = (name) => page.getByRole('button', { name: `Ouvrir la fiche de ${name}`, exact: true });
    await openSheet('Tom').waitFor({ state: 'visible', timeout: 30_000 });
    // La fiche de Tom s'ouvre par son adresse (le clic sur une ligne de liste d'un navigateur
    // sans souris réelle tombe sur la ligne voisine : on garde ce parcours pour l'import).
    await page.goto(`${baseUrl}#/students/s-tom`);
    await enableSemantics();
    await see('Effacer cet élève');
    assert.ok((await visible()).includes('Tom'), 'la fiche ouverte est celle de Tom');
    // La fiche est une liste défilante : les actions rares du bas ne sont construites qu'une fois
    // visibles. On fait défiler jusqu'à la carte d'effacement.
    const erase = page.getByRole('button', { name: /Effacer Tom/ });
    await page.mouse.move(400, 400);
    for (let attempt = 0; attempt < 30; attempt++) {
      if ((await erase.count()) > 0 && (await erase.first().isVisible())) break;
      await page.mouse.wheel(0, 1200);
      await page.waitForTimeout(300);
    }
    try {
      await erase.first().waitFor({ state: 'visible', timeout: 15_000 });
    } catch (error) {
      const dump = await page.evaluate(() =>
        [...document.querySelectorAll('flt-semantics')]
          .map((e) => `${e.getAttribute('role') ?? ''}|${e.getAttribute('aria-label') ?? ''}|${e.textContent.slice(0, 50)}|${Math.round(e.getBoundingClientRect().top)}`)
          .join('\n'),
      );
      throw new Error(`bouton « Effacer Tom » invisible : ${dump}`, { cause: error });
    }
    await see('limites', { exact: false });
    await erase.first().click();
    await see('Effacer Tom définitivement ?');
    await page.getByRole('button', { name: 'Confirmer', exact: true }).click();
    // L'effacement fini, l'écran revient à la liste des élèves, où Tom n'est plus.
    await page.waitForFunction(
      () => !document.body.innerText.includes('Effacer cet élève'),
      undefined,
      { timeout: 60_000 },
    );
    try {
      await openSheet('Léa').waitFor({ state: 'visible', timeout: 30_000 });
    } catch (error) {
      throw new Error(`liste des élèves absente de ${page.url()} ; affiché : ${await visible()}`, { cause: error });
    }
    await page.waitForTimeout(500);
    assert.equal(await openSheet('Tom').count(), 0, 'Tom n’est plus listé');

    // Relecture par un autre appareil, sous les vraies règles : plus aucun document lié.
    assert.equal((await getDoc(doc(reader, `${base}/students/s-tom`))).exists(), false, 'la fiche');
    for (const name of ['attempts', 'acquisitions', 'assessments', 'acknowledgements', 'memberships']) {
      assert.deepEqual(await linked(name), [], name);
    }
    const records = await getDocs(query(collection(reader, `${base}/records`), where('presentStudentIds', 'array-contains', 's-tom')));
    assert.equal(records.size, 0, 'présences');
    const members = await getDocs(collection(reader, `${base}/members`));
    for (const member of members.docs) {
      assert.ok(!(member.data().studentIds ?? []).includes('s-tom'), `lien de ${member.id}`);
    }
    const parent = members.docs.find((d) => d.data().displayName === accounts.parent.name);
    assert.deepEqual(parent.data().studentIds, ['s-lea'], 'le parent garde Léa seulement');
    const markers = await getDocs(query(collection(reader, `${base}/operations`), where('createdBy', '==', await uidOf(accounts.director.email))));
    assert.equal(markers.size, 0, 'aucun marqueur d’opération ne reste');
    // Le parent ne lit plus rien de Tom, ni sa fiche, ni ses passages.
    await assert.rejects(() => getDoc(doc(guardian, `${base}/students/s-tom`)), /permission|insufficient/i);
    await assert.rejects(
      () => getDocs(query(collection(guardian, `${base}/attempts`), where('studentId', '==', 's-tom'))),
      /permission|insufficient/i,
    );
  });

  test('le parent, ensuite, ne voit plus que Léa : plus de Tom ni de ses passages', async () => {
    await signInAs(accounts.parent.email);
    await see('Mes enfants');
    await see('Léa');
    await page.waitForTimeout(500);
    const shown = await visible();
    assert.ok(!shown.includes('Tom'), `« Tom » ne doit plus être visible : ${shown}`);
    assert.equal(await page.getByLabel('Tom', { exact: true }).count(), 0);
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

  // --- FB7, partie B : import d'un fichier de sauvegarde dans le club -------------------
  // Le fichier est une sauvegarde FICTIVE des tests (app/test/fixtures/backup, format 5). Le
  // directeur l'importe par l'écran, sous les vraies règles ; la relecture compare ce que le club
  // contient (autre appareil, Node) à ce que le fichier annonce. Puis un enseignant, qui ne peut
  // rien écrire hors de ses groupes, voit le serveur refuser son lot, sobrement.
  const backupPath = fileURLToPath(new URL('../../app/test/fixtures/backup/club-small-v5.json', import.meta.url));
  const backup = JSON.parse(readFileSync(backupPath, 'utf8')).data;

  // Le sélecteur de fichiers du navigateur : Playwright intercepte la boîte et donne le fichier.
  const chooseBackupFile = async () => {
    const [chooser] = await Promise.all([
      page.waitForEvent('filechooser'),
      page.getByRole('button', { name: 'Choisir un fichier de sauvegarde' }).click(),
    ]);
    note('playwright filechooser reçu');
    tracingFirestore = true;
    await chooser.setFiles(backupPath);
    note('playwright setFiles terminé');
  };

  // Un menu de choix (une question, ses options) : on l'ouvre par son nom accessible puis on prend l'option.
  const chooseOption = async (question, option) => {
    try {
      await page.getByRole('button', { name: question }).first().click({ timeout: 15_000 });
      await page.getByRole('menuitem', { name: option }).or(page.getByText(option, { exact: true })).first().click({ timeout: 15_000 });
    } catch (error) {
      const html = await page.evaluate(() =>
        [...document.querySelectorAll('flt-semantics')]
          .map((e) => `${e.getAttribute('role') ?? ''}|${e.getAttribute('aria-label') ?? ''}|${e.textContent.slice(0, 60)}`)
          .join('\n'),
      );
      throw new Error(`menu « ${question} » / « ${option} » : ${html}`, { cause: error });
    }
  };

  const clickButton = async (name) => {
    await page.getByRole('button', { name, exact: true }).click({ timeout: importWait });
  };

  const openImportScreen = async (email) => {
    await signInAs(email);
    await see(/^Plus/);
    await goTo('Plus');
    await see('Migrer mes données locales');
    await goTo('Migrer mes données locales');
    await see('Choisir le fichier');
  };

  test('le directeur importe la sauvegarde fictive par l’écran, et le club la contient ensuite', async () => {
    await openImportScreen(accounts.director.email);
    await seeSlow('Vous importez en tant que : Directeur.');
    await chooseBackupFile();

    await seeSlow('Rapport du fichier');
    await seeSlow('Des choix sont nécessaires');
    await clickButton('Continuer');
    await seeSlow('Correspondance des groupes');
    await chooseOption(/Que faire du groupe/, 'Créer dans le club');
    await clickButton('Continuer');
    await seeSlow('Récapitulatif avant écriture');
    await seeSlow('Rôle effectif : Directeur');
    await clickButton('Importer maintenant');
    await seeSlow('Import terminé', { exact: false });

    // Relecture comparée, par un autre appareil, sous les vraies règles.
    const reader = await otherDevice(accounts.director.email);
    const ids = async (collectionName) =>
      (await getDocs(collection(reader, `clubs/${demoClubId}/${collectionName}`))).docs.map((d) => d.id);
    const has = (all, wanted) => wanted.every((id) => all.includes(id));
    assert.ok(has(await ids('groups'), backup.groups.map((g) => g.id)), 'groupes');
    assert.ok(has(await ids('students'), backup.students.map((x) => x.id)), 'élèves');
    assert.ok(has(await ids('attempts'), backup.attempts.map((x) => x.id)), 'passages');
    assert.ok(has(await ids('records'), backup.sessionRecords.map((x) => x.id)), 'saisies');
    assert.ok(has(await ids('sessions'), backup.plannedSessions.map((x) => x.id)), 'séances planifiées');
    assert.ok(has(await ids('seasons'), backup.seasons.map((x) => x.id)), 'saisons');
    const marker = (await ids('imports')).length;
    assert.ok(marker >= 1, 'le marqueur d’import est posé');
    // Aucune donnée personnelle à l'écran de fin : ni prénom d'élève, ni identifiant de compte.
    const shown = await visible();
    for (const secret of [...backup.students.map((x) => x.firstName), 'directrice@demo.test']) {
      assert.ok(!shown.includes(secret), `« ${secret} » ne doit pas figurer à l'écran de fin`);
    }
  });

  test('le même fichier, rouvert par le même compte, est annoncé comme déjà importé', async () => {
    await openImportScreen(accounts.director.email);
    await chooseBackupFile();
    await seeSlow('Ce fichier est déjà importé');
    assert.equal(await page.getByRole('button', { name: 'Continuer', exact: true }).count(), 0);
  });

  test('un enseignant dont les groupes ne contiennent pas ces fiches est refusé sobrement par le serveur', async () => {
    await openImportScreen(accounts.teacherA.email);
    await seeSlow('Vous importez en tant que : Enseignant.');
    await chooseBackupFile();
    await clickButton('Continuer');
    await seeSlow('Correspondance des groupes');
    // Un enseignant ne crée pas de groupe : seule l'association à son propre groupe est proposée.
    await page.getByRole('button', { name: /Que faire du groupe/ }).first().click();
    assert.equal(await page.getByText('Créer dans le club', { exact: true }).count(), 0);
    // Le menu est ouvert : il ne propose que « À choisir » et l'association à son groupe.
    await page.getByRole('menuitem').first().waitFor({ state: 'attached', timeout: 15_000 });
    assert.equal(await page.getByRole('menuitem').count(), 2);
    await page.getByRole('menuitem', { name: 'Associer à : Enfants du mardi' }).click();
    await clickButton('Continuer');
    // Ses fiches sont créées sans qu'il puisse vérifier qu'elles n'existent pas déjà.
    await seeSlow('Confirmations');
    await page.getByRole('checkbox', { name: /Je confirme la création de/ }).click();
    await clickButton('Continuer');
    await seeSlow('Récapitulatif avant écriture');
    await seeSlow('Rôle effectif : Enseignant');
    await clickButton('Importer maintenant');
    // Les fiches existent déjà (le directeur les a importées dans un autre groupe) : les règles
    // refusent le lot en entier, l'écran le dit sans rouge ni détail technique.
    // Le message est une alerte annoncée par la seule région vive de l'écran ; son texte est aussi
    // affiché (les boutons « Réessayer » et « Terminer » restent hors de la région vive).
    await seeSlow('Le serveur a refusé l’écriture d’un lot');
    const shown = await visible();
    for (const secret of ['permission-denied', 'FirebaseError', ...backup.students.map((x) => x.firstName)]) {
      assert.ok(!shown.includes(secret), `« ${secret} » ne doit pas figurer à l'écran`);
    }
  });

  // --- FB8 partie B, tranche B2 : suppression de son propre compte -------------------------
  // Un enseignant (Julien, sans autre rôle dans ce parcours) supprime son compte par l'écran,
  // sous les VRAIES règles et le vrai Firebase Auth (émulateurs) : mot de passe vérifié, son
  // `member` supprimé par lui-même (règle `members` delete du titulaire), puis le compte Auth.
  // La relecture (autre appareil) prouve qu'il n'est plus membre et qu'il ne peut plus se connecter.
  test('un enseignant supprime son compte par l’écran : plus de member, plus de compte', async () => {
    const director = await otherDevice(accounts.director.email);
    const before = await getDocs(collection(director, `clubs/${demoClubId}/members`));
    const julien = before.docs.find((d) => d.data().displayName === accounts.teacherB.name);
    assert.ok(julien, 'le member de Julien est dans la graine');

    // Une invitation de parent que Julien a créée depuis UN AUTRE APPAREIL (client Node, vraies
    // règles) : le journal local du navigateur ne la connaît pas ; la suppression la retrouve par
    // la liste au serveur (`clubId ==`, `createdBy ==`) et la révoque avant de retirer le member.
    const julienElsewhere = await otherDevice(accounts.teacherB.email);
    const elsewhere = doc(julienElsewhere, 'invitations/JULIENOTHER2');
    await setDoc(elsewhere, {
      clubId: demoClubId,
      role: 'guardian',
      groupIds: ['g-adultes'],
      studentIds: ['s-marc'],
      createdBy: await uidOf(accounts.teacherB.email),
      createdAt: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 2 * 24 * 3600 * 1000),
      used: false,
    });
    assert.ok((await getDoc(doc(director, 'invitations/JULIENOTHER2'))).exists(), 'invitation créée ailleurs');

    await signInAs(accounts.teacherB.email);
    await see(/^Plus/);
    await goTo('Plus');
    await see('Supprimer mon compte');
    await page.getByRole('button', { name: 'Supprimer mon compte', exact: true }).click();
    await see('Les fiches des élèves, leurs résultats et les séances restent au club : ils appartiennent au club, pas à votre compte.');
    // Un mauvais mot de passe ne supprime rien.
    await typeInto('Votre mot de passe', 'pas-le-bon-mot-de-passe');
    await clickButton('Supprimer définitivement mon compte');
    await see('Mot de passe incorrect. Rien n’a été supprimé.');
    assert.ok((await getDoc(julien.ref)).exists(), 'le member reste après un mauvais mot de passe');

    await typeInto('Votre mot de passe', demoPassword);
    await clickButton('Supprimer définitivement mon compte');
    // Comme à la déconnexion, le cache local est vidé et la page web se recharge : l'arbre
    // d'accessibilité est à réactiver sur la nouvelle page.
    await page.waitForURL(/#\/sign-in/, { timeout: 60_000 });
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 180_000 });
    await enableSemantics();
    await see('Connexion à l’application');

    assert.equal((await getDoc(julien.ref)).exists(), false, 'le member de Julien est supprimé');
    assert.equal(
      (await getDoc(doc(director, 'invitations/JULIENOTHER2'))).exists(),
      false,
      'l’invitation créée depuis un autre appareil est révoquée',
    );
    const after = await getDocs(collection(director, `clubs/${demoClubId}/members`));
    assert.equal(after.size, before.size - 1, 'aucun autre member touché');
    const app = initializeApp({ apiKey: 'e2e', projectId: process.env.GCLOUD_PROJECT }, `deleted-${Date.now()}`);
    otherApps.push(app);
    const auth = getAuth(app);
    connectAuthEmulator(auth, `http://${authHost}`, { disableWarnings: true });
    await assert.rejects(
      () => signInWithEmailAndPassword(auth, accounts.teacherB.email, demoPassword),
      (error) => ['auth/user-not-found', 'auth/invalid-credential'].includes(error.code),
      'le compte Auth de Julien n’existe plus',
    );
  });

  // Décision D1 du 2026-10-24 : la garde est dans l'application (une règle ne compte pas les
  // membres). La directrice de la graine est la seule de son club : refus, rien n'est supprimé.
  test('la dernière directrice du club ne peut pas supprimer son compte : refus, rien n’est supprimé', async () => {
    const director = await otherDevice(accounts.director.email);
    const nadia = doc(director, `clubs/${demoClubId}/members/${await uidOf(accounts.director.email)}`);
    assert.ok((await getDoc(nadia)).exists(), 'le member de Nadia est dans la graine');

    await signInAs(accounts.director.email);
    await see(/^Plus/);
    await goTo('Plus');
    await see('Supprimer mon compte');
    await page.getByRole('button', { name: 'Supprimer mon compte', exact: true }).click();
    await typeInto('Votre mot de passe', demoPassword);
    await page.getByRole('button', { name: 'Supprimer définitivement mon compte', exact: true }).click();
    await see(
      'Vous êtes le dernier directeur du club Démo. Demandez à l’administrateur de nommer un autre directeur, puis réessayez. Rien n’a été supprimé.',
    );

    assert.ok((await getDoc(nadia)).exists(), 'le member de Nadia reste');
    const app = initializeApp({ apiKey: 'e2e', projectId: process.env.GCLOUD_PROJECT }, `kept-${Date.now()}`);
    otherApps.push(app);
    const auth = getAuth(app);
    connectAuthEmulator(auth, `http://${authHost}`, { disableWarnings: true });
    await signInWithEmailAndPassword(auth, accounts.director.email, demoPassword);
  });

  // Filet de 90 jours (B5, décision D4) : des marqueurs ANTIDATÉS (écrits règles désactivées, comme
  // seule la console le pourrait : les règles imposent `updatedAt == request.time`) d'un auteur
  // parti ; la directrice les purge depuis « Mon club » sous les vraies règles, par le SDK Dart.
  test('la directrice purge depuis « Mon club » les marqueurs abandonnés, jamais un récent', async () => {
    const [host, port] = [firestoreHost, Number(firestorePort)];
    const admin = await initializeTestEnvironment({ projectId: process.env.GCLOUD_PROJECT, firestore: { host, port } });
    const days = (n) => Timestamp.fromMillis(Date.now() - n * 24 * 3600 * 1000);
    const paths = {
      oldOperation: `clubs/${demoClubId}/operations/${'a1'.repeat(32)}_u-gone`,
      oldImport: `clubs/${demoClubId}/imports/${'b2'.repeat(32)}_u-gone`,
      recent: `clubs/${demoClubId}/operations/${'c3'.repeat(32)}_u-gone`,
    };
    const marker = (updatedAt) => ({ createdBy: 'u-gone', role: 'director', updatedAt, startedAt: updatedAt });
    const exists = async (path) => {
      let found;
      await admin.withSecurityRulesDisabled(async (ctx) => {
        found = (await getDoc(doc(ctx.firestore(), path))).exists();
      });
      return found;
    };
    try {
      await admin.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), paths.oldOperation), marker(days(120)));
        await setDoc(doc(ctx.firestore(), paths.oldImport), marker(days(95)));
        await setDoc(doc(ctx.firestore(), paths.recent), marker(days(30)));
      });

      await signInAs(accounts.director.email);
      await see(/^Plus/);
      await goTo('Plus');
      await see('Mon club');
      await goTo('Mon club');
      await see('Marqueurs abandonnés');
      await page.getByRole('button', { name: 'Supprimer les marqueurs abandonnés', exact: true }).click();
      await see('2 marqueurs abandonnés supprimés.');

      assert.equal(await exists(paths.oldOperation), false, 'marqueur d’opération de 120 jours supprimé');
      assert.equal(await exists(paths.oldImport), false, 'marqueur d’import de 95 jours supprimé');
      assert.equal(await exists(paths.recent), true, 'marqueur de 30 jours gardé');
    } finally {
      await admin.cleanup();
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
