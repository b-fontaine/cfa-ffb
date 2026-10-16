// Enregistrement du service worker hors ligne et détection d'une nouvelle
// version. Fichier statique, non transformé par `flutter build`.
//
// Pont avec Dart (`app/platform/app_update_source_web.dart`) :
//   window.cfaOffline.updateAvailable      vrai si une version attend
//   window.cfaOffline.onUpdateChange(cb)   cb(bool) à chaque changement
//   window.cfaOffline.applyUpdate()        active la version en attente puis recharge
//
// Une nouvelle version n'est JAMAIS activée d'office : la page ouverte garde
// les fichiers avec lesquels elle a démarré, la saisie en cours n'est pas
// interrompue. L'activation est demandée par l'utilisateur (bannière) ou a
// lieu d'elle-même à la fermeture de tous les onglets.
(function () {
  'use strict';

  var listeners = [];
  var available = false;
  var registration = null;
  var reloading = false;
  var applying = false;
  // Une page qui démarre déjà contrôlée tourne avec les fichiers de l'ancienne
  // version : si le contrôleur change sous elle, elle est périmée.
  var hadController = false;

  function setAvailable(value) {
    if (available === value) return;
    available = value;
    listeners.slice().forEach(function (callback) {
      try {
        callback(value);
      } catch (_) {
        /* un abonné défaillant ne bloque pas les autres */
      }
    });
  }

  window.cfaOffline = {
    get updateAvailable() {
      return available;
    },
    onUpdateChange: function (callback) {
      listeners.push(callback);
    },
    applyUpdate: function () {
      var waiting = registration && registration.waiting;
      if (!waiting) {
        window.location.reload();
        return;
      }
      applying = true;
      waiting.postMessage({ type: 'SKIP_WAITING' });
    },
  };

  if (!('serviceWorker' in navigator)) return;

  hadController = !!navigator.serviceWorker.controller;
  navigator.serviceWorker.addEventListener('controllerchange', function () {
    if (applying) {
      if (reloading) return;
      reloading = true;
      window.location.reload();
    } else if (hadController) {
      // Un autre onglet a activé une nouvelle version : cette page garde ses
      // fichiers et sa saisie, mais propose de se recharger.
      setAvailable(true);
    }
  });

  // Évite que le navigateur efface la base locale (élèves, résultats) quand
  // l'espace manque ; sans effet là où l'API est absente ou refuse.
  try {
    if (navigator.storage && navigator.storage.persist) {
      navigator.storage.persist().catch(function () {});
    }
  } catch (_) {}

  function watch(worker) {
    function installed() {
      if (worker.state === 'installed' && navigator.serviceWorker.controller) {
        setAvailable(true);
      }
    }
    worker.addEventListener('statechange', installed);
    installed();
  }

  function track(reg) {
    registration = reg;
    // Une version est déjà installée et attend : on est dans le cas « mise à jour »
    // seulement si une version contrôle déjà la page (sinon c'est la première visite).
    if (reg.waiting && navigator.serviceWorker.controller) setAvailable(true);
    // Une installation peut être déjà en cours : `updatefound` a eu lieu.
    if (reg.installing) watch(reg.installing);
    reg.addEventListener('updatefound', function () {
      if (reg.installing) watch(reg.installing);
    });
  }

  function check() {
    if (registration) registration.update().catch(function () {});
  }

  window.addEventListener('load', function () {
    navigator.serviceWorker
      .register('offline_sw.js', { updateViaCache: 'none' })
      .then(track)
      .catch(function (error) {
        console.warn('Service worker hors ligne indisponible :', error);
      });
    // Une session longue (PWA laissée ouverte) vérifie à chaque retour au
    // premier plan, puis toutes les heures.
    document.addEventListener('visibilitychange', function () {
      if (document.visibilityState === 'visible') check();
    });
    window.setInterval(check, 60 * 60 * 1000);
  });
})();
