// Fumée du BUILD WEB COMPILÉ (dart2js, `scripts/build_web.sh`) contre l'ÉMULATEUR Auth
// (lot FB2, ADR 0024).
//
// Pourquoi : les tests Dart ne tournent jamais contre le vrai SDK `firebase_auth` (plugin
// natif absent sous `flutter test`) et les tests Node ne lancent pas l'application. Un
// blocage propre au build compilé (écran de démarrage qui ne finit jamais) passerait donc
// inaperçu. Ce test charge le build de production dans Chrome et vérifie, avec le vrai SDK :
//
// - le démarrage aboutit à l'écran de connexion (pas de blocage sur l'écran de démarrage) ;
// - un mauvais mot de passe et une adresse inconnue donnent le MÊME message générique ;
// - le lien d'une invitation (`/join/<code>`) ouvre l'inscription avec le code (FB3) ;
// - un compte vérifié se connecte ; Firestore n'étant PAS émulé ici, l'application, qui a bien
//   interrogé Firestore (requête refusée), n'ouvre que sur un club déjà retenu sur l'appareil :
//   avec un club retenu, la connexion aboutit à l'accueil (assertion de SUCCÈS) ; sans club
//   retenu, elle affiche « Service injoignable » (chemin d'échec, éprouvé à part) ; la session
//   survit à un rechargement et la déconnexion ramène à l'écran de connexion.
//
// Pourquoi Firestore n'est pas émulé : ses flux longs (WebChannel) ne passent pas par une
// interception de requêtes du navigateur, et le build de production refuse l'émulateur. Les
// règles et les opérations Firestore sont éprouvées par scripts/rules_test/ (SDK web, jetons
// réels de l'émulateur Auth) et les dépôts par les tests Dart. Le parcours « application + émulateurs
// Auth et Firestore + graine » a son propre garde-fou (scripts/emulator_e2e.sh) : le build de
// production, lui, refuse l'émulateur.
//
// Le build de production n'accepte jamais l'émulateur (`FirebaseEnvironment`) : le test ne
// le modifie pas. Il intercepte au niveau du navigateur les appels du SDK vers
// `identitytoolkit.googleapis.com` et `securetoken.googleapis.com` et les renvoie à
// l'émulateur local ; tout autre hôte que localhost est refusé et fait échouer le test
// (gstatic.com compris : le SDK web est servi par l'application, FB5a). Aucune requête n'atteint le projet réel.
//
// Prérequis (échec explicite, jamais de saut) : Google Chrome installé, `app/build/web`
// produit par `scripts/build_web.sh`, émulateur Auth lancé par `scripts/web_smoke.sh`.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, resolve } from 'node:path';
import { after, before, describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { deleteApp, initializeApp } from 'firebase/app';
import {
  applyActionCode,
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  sendEmailVerification,
  signOut,
} from 'firebase/auth';
import { chromium } from 'playwright-core';

const emulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT ?? '';
assert.ok(
  emulatorHost && /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(emulatorHost),
  'FIREBASE_AUTH_EMULATOR_HOST absent ou non local : lancer ce test par scripts/web_smoke.sh',
);
assert.match(projectId, /^demo-/, 'le projet du test doit commencer par « demo- »');

const emulator = `http://${emulatorHost}`;
const webRoot = resolve(
  fileURLToPath(new URL('.', import.meta.url)),
  '..',
  '..',
  'app',
  'build',
  'web',
);
const password = 'correct-horse-battery';
const email = `smoke-${process.pid}@example.org`;
const unknownEmail = `nobody-${process.pid}@example.org`;

// Hôtes dont les appels du SDK sont renvoyés à l'émulateur.
const proxied = new Set(['identitytoolkit.googleapis.com', 'securetoken.googleapis.com']);

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.yaml': 'text/yaml; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
};

let server;
let origin;
let browser;
let context;
let page;
const blocked = new Set();
// Appels que le SDK Firestore a tentés : ce test n'émule PAS Firestore (les flux longs du SDK
// ne passent pas par une interception de requêtes) ; ils sont refusés explicitement, et les
// règles et les dépôts sont éprouvés par scripts/rules_test/ et par les tests Dart.
const firestoreRefused = new Set();
const pageErrors = [];
// Fichiers du SDK web demandés à l'application elle-même (et non à gstatic.com).
const sdkFiles = new Set();
let accountUid;

const startServer = () =>
  new Promise((done) => {
    server = createServer(async (request, response) => {
      const path = normalize(decodeURIComponent(new URL(request.url, 'http://x').pathname));
      const file = join(webRoot, path.endsWith('/') ? `${path}index.html` : path);
      if (!file.startsWith(webRoot)) {
        response.writeHead(403).end();
        return;
      }
      try {
        const body = await readFile(file);
        response.writeHead(200, {
          'content-type': mimeTypes[extname(file)] ?? 'application/octet-stream',
        });
        response.end(body);
      } catch {
        response.writeHead(404).end();
      }
    });
    server.listen(0, '127.0.0.1', () => {
      origin = `http://127.0.0.1:${server.address().port}`;
      done();
    });
  });

const route = async (r) => {
  const request = r.request();
  const url = new URL(request.url());
  if (url.hostname === '127.0.0.1' || url.hostname === 'localhost') return r.continue();
  // gstatic.com n'est PLUS joignable : le SDK web est servi en local (carte d'import de
  // index.html, ADR 0024 décision 30). Un appel vers gstatic tombe dans `blocked` et échoue.
  // Le SDK web de Firestore appelle aussi une image de sonde de connectivité de Google
  // (WebChannel) : même traitement, et c'est consigné au registre des traitements.
  if (
    url.hostname === 'firestore.googleapis.com' ||
    (url.hostname === 'www.google.com' && url.pathname === '/images/cleardot.gif')
  ) {
    firestoreRefused.add(`${url.hostname}${url.pathname}`);
    return r.abort('connectionrefused');
  }
  if (proxied.has(url.hostname)) {
    const upstream = await fetch(`${emulator}/${url.hostname}${url.pathname}${url.search}`, {
      method: request.method(),
      headers: { 'content-type': request.headers()['content-type'] ?? 'application/json' },
      body: ['GET', 'HEAD'].includes(request.method()) ? undefined : request.postDataBuffer(),
    });
    return r.fulfill({
      status: upstream.status,
      headers: {
        'content-type': upstream.headers.get('content-type') ?? 'application/json',
        'access-control-allow-origin': '*',
      },
      body: Buffer.from(await upstream.arrayBuffer()),
    });
  }
  blocked.add(`${url.hostname}${url.pathname}`);
  return r.abort();
};

const seedVerifiedAccount = async () => {
  const app = initializeApp({ apiKey: 'smoke', projectId }, `seed-${process.pid}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, emulator, { disableWarnings: true });
  const { user } = await createUserWithEmailAndPassword(auth, email, password);
  await sendEmailVerification(user);
  const { oobCodes } = await (
    await fetch(`${emulator}/emulator/v1/projects/${projectId}/oobCodes`)
  ).json();
  const verification = oobCodes.find((c) => c.email === email && c.requestType === 'VERIFY_EMAIL');
  assert.ok(verification, 'un courriel de vérification doit avoir été émis par l’émulateur');
  await applyActionCode(auth, verification.oobCode);
  await signOut(auth);
  await deleteApp(app);
  return user.uid;
};

// Le club retenu par compte sur l'appareil (KeyValueActiveClubMemory, `shared_preferences` web :
// `localStorage`, valeur encodée en JSON) : de quoi ouvrir hors ligne dans un club.
const rememberClub = (uid) =>
  page.evaluate(
    ([key, club]) => localStorage.setItem(key, JSON.stringify(JSON.stringify(club))),
    [
      `active_club.${uid}`,
      { club: 'demo', name: 'Démo', role: 'director', groups: [], students: [] },
    ],
  );

// Flutter web n'expose l'arbre sémantique qu'après un clic sur le marqueur d'accessibilité.
const enableSemantics = () =>
  page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());

const open = async () => {
  await page.goto(`${origin}/`);
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30_000 });
  await enableSemantics();
};

const text = (name) => page.getByText(name);
// Noms des bases IndexedDB de la page : le cache hors ligne de Firestore s'y appelle « firestore/… ».
const indexedDbNames = () =>
  page.evaluate(async () => (await indexedDB.databases()).map((database) => database.name ?? ''));
// Échec lisible : on dit ce que la page affichait au lieu d'un simple délai dépassé.
const see = async (name) => {
  try {
    await text(name).first().waitFor({ state: 'visible', timeout: 20_000 });
  } catch (error) {
    const shown = await page.evaluate(() => document.body.innerText).catch(() => '(illisible)');
    throw new Error(`« ${name} » absent de ${page.url()} ; affiché : ${shown}`, { cause: error });
  }
};

// La page peut se recharger À TOUT MOMENT (autre onglet) : l'arbre sémantique se perd alors ;
// on le réactive à chaque essai jusqu'à voir le texte.
const seeAfterReload = async (name) => {
  const deadline = Date.now() + 40_000;
  while (Date.now() < deadline) {
    await enableSemantics().catch(() => {});
    if ((await text(name).count().catch(() => 0)) > 0) return;
    await page.waitForTimeout(500);
  }
  const shown = await page.evaluate(() => document.body.innerText).catch(() => '(illisible)');
  throw new Error(`« ${name} » absent de ${page.url()} ; affiché : ${shown}`);
};

// Flutter crée (et parfois recrée) l'élément de saisie quand le champ prend le focus, de
// façon asynchrone : des touches frappées trop tôt sont perdues. On attend l'élément, on
// laisse l'image se stabiliser, on frappe, puis on contrôle ce que le champ contient ; au
// besoin on efface et on recommence.
const typeInto = async (label, value) => {
  const field = page.getByLabel(label, { exact: true });
  let typed = '';
  for (let attempt = 0; attempt < 4 && typed !== value; attempt++) {
    await field.click();
    await page.waitForFunction(() =>
      ['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName),
    );
    await page.waitForTimeout(300);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.type(value, { delay: 15 });
    typed = await page.evaluate(() => document.activeElement.value);
  }
  assert.equal(typed, value, `saisie incomplète dans « ${label} »`);
};

const signInWith = async (address, secret) => {
  await typeInto('Adresse e-mail', address);
  await typeInto('Mot de passe', secret);
  await page.getByRole('button', { name: 'Se connecter', exact: true }).click();
};

before(async () => {
  await startServer();
  browser = await chromium.launch({ channel: 'chrome', headless: true });
  context = await browser.newContext({ serviceWorkers: 'block', locale: 'fr-FR' });
  await context.route('**/*', route);
  page = await context.newPage();
  page.on('pageerror', (error) => pageErrors.push(error.message));
  page.on('request', (request) => {
    const match = /^https?:\/\/(?:127\.0\.0\.1|localhost):\d+\/(?:.*\/)?firebasejs\/[0-9.]+\/([\w.-]+\.js)$/.exec(request.url());
    if (match) sdkFiles.add(match[1]);
  });
  await fetch(`${emulator}/emulator/v1/projects/${projectId}/accounts`, { method: 'DELETE' });
  accountUid = await seedVerifiedAccount();
});

after(async () => {
  await browser?.close();
  await new Promise((done) => (server ? server.close(done) : done()));
});

describe('build web compilé contre l’émulateur Auth', () => {
  test('le démarrage aboutit à l’écran de connexion', async () => {
    await open();

    await see('Connexion à l’application');
    assert.match(page.url(), /#\/sign-in/);
  });

  test('un mauvais mot de passe et une adresse inconnue donnent le même message', async () => {
    await open();
    await see('Connexion à l’application');

    await signInWith(email, 'not-the-password');
    await see('Adresse e-mail ou mot de passe incorrect.');
    // Le nombre de nœuds sémantiques qui portent le message varie (région vivante et libellé,
    // selon l'instant de la capture) : on compare le texte, pas le compte.
    // Les espaces de fin varient aussi avec l'instant de la capture (observé sur macOS en CI) : on
    // compare le message, espaces normalisées.
    const messageShown = async () =>
      (await page.getByText('Adresse e-mail ou mot de passe incorrect.').first().textContent())
        .replace(/\s+/g, ' ')
        .trim();
    const wrongPassword = await messageShown();

    await page.reload();
    await enableSemantics();
    await see('Connexion à l’application');
    await signInWith(unknownEmail, password);
    await see('Adresse e-mail ou mot de passe incorrect.');
    const unknownAddress = await messageShown();

    assert.equal(unknownAddress, wrongPassword);
  });

  test('le lien d’une invitation ouvre l’inscription avec le code (adresse /join/<code>)', async () => {
    await page.goto(`${origin}/#/join/ABCDEFGHJKMN`);
    await page.reload();
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30_000 });
    await enableSemantics();

    await see('Inscription sur invitation');
    assert.match(page.url(), /#\/register\?code=ABCDEFGHJKMN/);
  });

  test('sans club retenu et Firestore injoignable : « Service injoignable » (chemin d’échec)', async () => {
    await open();
    await see('Connexion à l’application');

    await signInWith(email, password);
    // L'application a bien tenté de lire les clubs du compte (adaptateur Firestore du build
    // compilé) ; sans club retenu sur l'appareil, elle ne peut que signaler l'indisponibilité.
    await see('Service injoignable');
    assert.ok(firestoreRefused.size > 0, 'le build compilé doit avoir interrogé Firestore');

    // Persistance hors ligne ACTIVÉE (FB5a, C4) : le SDK a ouvert son cache IndexedDB.
    assert.ok(
      (await indexedDbNames()).some((name) => name.startsWith('firestore/')),
      'la persistance hors ligne de Firestore doit être active (aucune base IndexedDB « firestore/ »)',
    );

    // La déconnexion vide le cache (terminate + clearPersistence du vrai SDK), puis la page se
    // recharge : le SDK ne rouvre pas une instance terminée.
    const reloaded = page.waitForEvent('load', { timeout: 60_000 });
    await page.getByRole('button', { name: 'Se déconnecter', exact: true }).click();
    await reloaded;
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30_000 });
    await enableSemantics();
    await see('Connexion à l’application');
    assert.deepEqual(
      (await indexedDbNames()).filter((name) => name.startsWith('firestore/')),
      [],
      'le cache de Firestore doit être vidé à la déconnexion',
    );
  });

  test('deux onglets : la déconnexion de l’un vide la base partagée, l’autre se recharge et se reconnecte', async () => {
    const tabA = page;
    // Un onglet en arrière-plan ne peint plus (Flutter attend les images d'animation) : chaque
    // changement d'onglet le ramène au premier plan.
    let tabB;
    try {
      await open();
      await see('Connexion à l’application');
      await rememberClub(accountUid);
      await signInWith(email, password);
      await see('Aujourd\'hui');

      // Le second onglet reprend la session persistée et ouvre le MÊME cache (multi-onglets).
      tabB = await context.newPage();
      tabB.on('pageerror', (error) => pageErrors.push(error.message));
      page = tabB;
      await open();
      await see('Aujourd\'hui');
      assert.ok(
        (await indexedDbNames()).some((name) => name.startsWith('firestore/')),
        'le cache Firestore doit être partagé par les deux onglets',
      );

      // Repère posé dans B : il disparaît quand B se recharge.
      await page.evaluate(() => { window.__tabBBeforeReload = true; });

      // Déconnexion dans A : la suppression de la base ne doit pas rester bloquée par B.
      page = tabA;
      await page.bringToFront();
      await page.getByText(/^Plus/).first().click();
      const reloaded = page.waitForEvent('load', { timeout: 60_000 });
      await page.getByRole('button', { name: 'Se déconnecter', exact: true }).click();
      await reloaded;
      await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30_000 });
      await enableSemantics();
      await see('Connexion à l’application');
      assert.deepEqual(
        (await indexedDbNames()).filter((name) => name.startsWith('firestore/')),
        [],
        'la base du cache doit être absente après la déconnexion dans l’autre onglet',
      );

      // B a perdu sa session et son instance Firestore est terminée : il se recharge seul.
      page = tabB;
      await page.bringToFront();
      // L'écran de connexion s'affiche AVANT le rechargement : on attend le rechargement lui-même
      // (le repère disparaît), sans quoi la saisie serait effacée par lui.
      await page.waitForFunction(() => !window.__tabBBeforeReload, undefined, { timeout: 40_000 });
      await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30_000 });
      await seeAfterReload('Connexion à l’application');

      // La reconnexion dans B aboutit à l'accueil (pas d'instance terminée, pas d'« injoignable »).
      await rememberClub(accountUid);
      await signInWith(email, password);
      await see('Aujourd\'hui');
      assert.equal(await text('Service injoignable').count(), 0);
      assert.ok(
        (await indexedDbNames()).some((name) => name.startsWith('firestore/')),
        'la reconnexion doit rouvrir le cache',
      );

      await page.getByText(/^Plus/).first().click();
      const closed = page.waitForEvent('load', { timeout: 60_000 });
      await page.getByRole('button', { name: 'Se déconnecter', exact: true }).click();
      try {
        await closed;
      } catch (error) {
        const shown = await page.evaluate(() => document.body.innerText).catch(() => '(illisible)');
        throw new Error(`pas de rechargement après la déconnexion de B ; affiché : ${shown}`, { cause: error });
      }

      // A (reconnecté par la session partagée de B) suit la déconnexion de B : on l'attend,
      // pour que le test suivant parte d'une session fermée.
      page = tabA;
      await page.bringToFront();
      await seeAfterReload('Connexion à l’application');
    } finally {
      page = tabA;
      await tabB?.close();
      await page.bringToFront();
    }
  });

  test('un compte vérifié se connecte et ouvre son club retenu ; la session survit au rechargement, la déconnexion la ferme', async () => {
    await open();
    await see('Connexion à l’application');
    await rememberClub(accountUid);
    // Remise à zéro : seules les requêtes Firestore refusées PENDANT cette connexion comptent.
    firestoreRefused.clear();

    await signInWith(email, password);
    // SUCCÈS : l'accueil du club retenu (directeur : onglets de l'animateur), pas une erreur.
    await see('Aujourd\'hui');
    await see('Plus');
    assert.equal(await text('Service injoignable').count(), 0);
    assert.equal(await text('Aucun club').count(), 0);
    assert.doesNotMatch(page.url(), /#\/(sign-in|splash|unavailable|select-club)/);
    assert.ok(firestoreRefused.size > 0, 'le build compilé doit avoir interrogé Firestore (refusé) pendant la connexion');

    await page.reload();
    await enableSemantics();
    await see('Aujourd\'hui');
    assert.equal(await text('Service injoignable').count(), 0);

    await page.getByText(/^Plus/).first().click();
    const reloaded = page.waitForEvent('load', { timeout: 60_000 });
    await page.getByRole('button', { name: 'Se déconnecter', exact: true }).click();
    // La déconnexion recharge la page (cache de Firestore vidé).
    await reloaded;
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30_000 });
    await enableSemantics();
    await see('Connexion à l’application');
    assert.match(page.url(), /#\/sign-in/);
  });

  test('le SDK web est servi par l’application, aucun appel vers un autre hôte que localhost, Firestore (refusé) et le SDK d’authentification', () => {
    assert.deepEqual(
      [...sdkFiles].sort(),
      ['firebase-app.js', 'firebase-auth.js', 'firebase-firestore-pipelines.js'],
    );
    assert.deepEqual([...blocked], []);
    assert.deepEqual(pageErrors, []);
  });
});
