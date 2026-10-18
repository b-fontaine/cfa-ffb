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
// projet réel (la graine refuse tout autre projet, et seuls localhost et gstatic sont joignables).
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { chromium } from 'playwright-core';

import { accounts, demoPassword } from '../seed_emulator.mjs';

const baseUrl = process.env.E2E_URL;
assert.ok(baseUrl && /^http:\/\/(127\.0\.0\.1|localhost):\d+\/?$/.test(baseUrl), 'E2E_URL absent ou non local : lancer ce test par scripts/emulator_e2e.sh');
assert.match(process.env.GCLOUD_PROJECT ?? '', /^demo-/, 'le projet doit commencer par « demo- »');

let browser;
let context;
let page;
const blocked = new Set();
const pageErrors = [];

const route = (r) => {
  const url = new URL(r.request().url());
  const local = url.hostname === '127.0.0.1' || url.hostname === 'localhost';
  const gstatic = url.hostname === 'gstatic.com' || url.hostname.endsWith('.gstatic.com');
  if (local || gstatic) return r.continue();
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

// Les onglets du bas portent « Onglet n sur m » après leur libellé : on cherche le début du texte.
const goTo = async (name) => {
  await page.getByText(new RegExp(`^${name}`)).first().click();
};

before(async () => {
  browser = await chromium.launch({ channel: 'chrome', headless: true });
});

after(async () => {
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

    // Rôle lu dans Firestore (guardian) : l'accueil est celui d'un parent. La liste des enfants
    // vient encore du stock local (les listes serveur d'élèves sont le lot FB4) : elle est vide
    // ici, ce que ce parcours ne prétend pas prouver.
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

  test('aucun appel vers un hôte autre que localhost et gstatic, aucune erreur de page', () => {
    assert.deepEqual([...blocked], []);
    assert.deepEqual(pageErrors, []);
  });
});
