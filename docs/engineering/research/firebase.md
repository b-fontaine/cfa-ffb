# Recherche — Firebase (FlutterFire) pour billard_cfa : faisabilité, coûts, RGPD, hors-ligne, opportunité

> Produit par un agent de recherche le 2026-10-11 (sources citées). **Les versions sont à revalider par `flutter pub get` avant usage.** Les faits de confiance `medium` ou `low` ne sont pas vérifiés dans le dépôt.

## Recommandation

Recommandation : PLUS TARD (pas maintenant, pas jamais). Pour un seul animateur avec le même groupe d'élèves toute la saison, démarrer en stockage local (SQLite via drift ou équivalent, ou fichiers) avec export/import JSON/CSV : zéro serveur, zéro coût, pas de transfert de données de mineurs vers un tiers, RGPD bien plus simple (données sur l'appareil de l'animateur, registre + information suffisent), fonctionne hors-ligne sur toutes les cibles y compris Linux, que FlutterFire ne supporte pas. Firebase se justifie si : plusieurs animateurs ou appareils doivent partager les mêmes fiches de suivi, synchronisation entre téléphone et ordinateur nécessaire, sauvegarde automatique voulue, ou accès parents/élèves. À ce moment-là, isoler la persistance derrière un repository (Clean Architecture déjà en place) pour pouvoir brancher cloud_firestore sans toucher au domaine ; et cibler Android/iOS/web en production (Windows dev uniquement, Linux non supporté, macOS beta). Si on y va, l'utilisateur devra créer côté Firebase : (1) un projet Firebase (plan Spark suffit) ; (2) une base Firestore en mode production dans une région européenne, de préférence europe-west9 (Paris) ou eur3, à choisir avec soin car irréversible ; (3) Firebase Authentication avec email/mot de passe (ou lien magique), compte animateur unique, MFA si possible ; (4) des règles de sécurité Firestore restrictives (accès uniquement à l'uid de l'animateur) ; (5) les apps Android/iOS/web enregistrées via flutterfire configure (CLI FlutterFire, à lancer avec le compte de l'utilisateur) ; (6) acceptation des Data Processing and Security Terms de Firebase ; et côté conformité : registre des traitements, mention d'information aux parents, durée de conservation définie (suppression/anonymisation en fin de saison). Pseudonymiser les élèves (prénom + initiale ou identifiant interne) limite fortement le risque.

## Faits relevés

- **[high]** firebase_core 4.15.0 ; plateformes listées sur pub.dev : Android, iOS, macOS, web, Windows (Linux absent). Publié il y a ~27 jours (date exacte non donnée).
  - Source : https://pub.dev/packages/firebase_core
- **[high]** cloud_firestore 6.10.0 ; plateformes listées : Android, iOS, macOS, web, Windows (pas Linux).
  - Source : https://pub.dev/packages/cloud_firestore
- **[high]** firebase_auth 6.7.0 ; plateformes listées : Android, iOS, macOS, web, Windows (pas Linux).
  - Source : https://pub.dev/packages/firebase_auth
- **[high]** La doc officielle de setup FlutterFire cite iOS, Android, web, autres plateformes Apple (macOS) et Windows ; Linux n'est pas mentionné. Avertissement : Firebase sur Windows 'n'est pas destiné à la production, seulement au développement local'. Beaucoup de plugins sont marqués beta.
  - Source : https://firebase.google.com/docs/flutter/setup
- **[medium]** README FlutterFire : pour firebase_core, cloud_firestore, firebase_auth, Windows = 'for development only. Production on Windows is not supported' ; macOS marqué beta ; aucune colonne Linux. Conclusion : Linux non supporté, Windows dev uniquement, macOS beta ; seules Android, iOS et web sont des cibles de production solides.
  - Source : https://github.com/firebase/flutterfire
- **[high]** Plan Spark (gratuit, sans moyen de paiement) Firestore Standard : 1 GiB stockés, 10 GiB/mois de sortie réseau, 20K écritures/jour, 50K lectures/jour, 20K suppressions/jour. Auth : 50K MAU (Identity Platform), Phone Auth non disponible sur Spark (Blaze, facturé au SMS). Cloud Storage et Cloud Functions non disponibles sur Spark. Largement suffisant pour un animateur et quelques dizaines d'élèves.
  - Source : https://firebase.google.com/pricing
- **[high]** Régions Firestore en Europe : multi-région eur3 (europe-west1 Belgique + europe-west4 Pays-Bas, témoin europe-north1) ; régionales dont europe-west9 (Paris), europe-west3 (Francfort), europe-west1, europe-west4, etc. La localisation ne peut PAS être changée après création de la base. Le quota gratuit par région n'est pas précisé sur cette page.
  - Source : https://firebase.google.com/docs/firestore/locations
- **[high]** Hors-ligne : persistance activée par défaut sur Android et Apple (iOS/macOS), désactivée par défaut sur web (à activer explicitement, Chrome/Safari/Firefox ; cache non effacé entre sessions, attention aux appareils non fiables). Desktop non listé comme supporté pour la persistance. Cache par défaut 100 Mo ; en cas de modifications hors-ligne concurrentes sur un même document, last-write-wins ; données fromCache possiblement périmées.
  - Source : https://firebase.google.com/docs/firestore/manage-data/enable-offline
- **[high]** Rôle RGPD : Google est généralement sous-traitant (processor), le client (club/animateur) est responsable de traitement et doit gérer les droits des personnes. Google est certifié DPF (transferts UE-US) et propose des SCC et des Data Processing and Security Terms. Firestore est certifié ISO 27001, SOC 1/2/3 et chiffre au repos.
  - Source : https://firebase.google.com/support/privacy
- **[high]** Firebase Authentication 'ne tourne que depuis des datacenters US' : les données d'auth (email, mot de passe, IP, user agent) sont traitées aux États-Unis quelle que soit la région Firestore ; les IP loguées sont conservées quelques semaines ; les comptes supprimés disparaissent des systèmes live et sauvegardes sous 180 jours. Point de friction pour un public UE/mineurs, à documenter (DPF/SCC).
  - Source : https://firebase.google.com/support/privacy
- **[high]** CNIL (licences sportives, 18 juin 2024) : minimisation (données adéquates, pertinentes, limitées au nécessaire) ; information des membres sur finalité et durée de conservation ; chaque finalité a sa base légale ; pour un mineur, identité et coordonnées des parents admises ; questionnaire de santé pour mineurs rempli avec les parents (certificat uniquement si une réponse le déclenche) ; mesures de sécurité adaptées (authentification multi-facteur recommandée pour les grosses bases) ; contrat de sous-traitance si le club traite pour le compte de la fédération ; analyse d'impact (AIPD) si les critères sont réunis ; tout réemploi à d'autres fins (newsletter, promotion) exige consentement/analyse de compatibilité.
  - Source : https://cnil.fr/fr/licences-sportives-les-principales-regles-respecter-pour-la-protection-des-donnees-personnelles
- **[medium]** CNIL (durées de conservation, sportifs/dirigeants) : pas de durée chiffrée unique ; la loi en fixe peu ; la durée dépend de la finalité ; trois phases (base active, archivage intermédiaire non automatique, puis suppression ou anonymisation). Aucune durée en années pour les résultats ou suivis de mineurs trouvée : à justifier et documenter soi-même (ex. fin de saison + durée courte, par principe de minimisation), ce choix relève du responsable de traitement et non d'une règle CNIL vérifiée.
  - Source : https://cnil.fr/fr/la-duree-de-conservation-des-donnees-personnelles-des-sportifs-dirigeants-et-autres-personnes-dans
- **[medium]** Obligations concrètes synthétisées pour un animateur de club : (a) tenir un registre des traitements ; (b) informer élèves/parents (mentions, finalité, durée, droits) ; (c) collecter le minimum (prénom + initiale, niveau, présence, résultats d'exercices ; pas de données de santé, pas de photos sans consentement parental) ; (d) consentement/information des représentants légaux pour les mineurs ; (e) droits d'accès/effacement/portabilité à pouvoir honorer ; (f) suppression ou anonymisation en fin de saison/d'adhésion ; (g) sécurité (règles Firestore strictes, auth forte, pas d'accès public) ; (h) signer/accepter les termes de traitement de données Google. L'âge de consentement numérique en France est 15 ans (non vérifié ici).
  - Source : https://cnil.fr/fr/licences-sportives-les-principales-regles-respecter-pour-la-protection-des-donnees-personnelles ; https://firebase.google.com/support/privacy

## Risques

- Linux non supporté par FlutterFire et Windows 'dev uniquement' : une application multi-plateforme à 6 cibles ne peut pas s'appuyer sur Firebase partout ; il faudrait un repository local en repli sur ces plateformes.
- Firebase Auth traite les données exclusivement aux États-Unis (DPF/SCC) même avec Firestore en région UE : point sensible pour des mineurs ; éviter si possible d'y mettre des identifiants révélant l'identité réelle des enfants.
- Région Firestore irréversible après création de la base.
- Persistance hors-ligne désactivée par défaut sur web ; et sur web le cache n'est pas effacé entre sessions, risque sur appareil partagé ; desktop non listé pour la persistance.
- Conflits en hors-ligne : last-write-wins par document.
- Durées de conservation chiffrées pour les suivis de mineurs non trouvées dans les sources CNIL : à justifier soi-même (responsable de traitement) ; une validation par la fédération ou un DPO est conseillée.
- Les versions (4.15.0 / 6.10.0 / 6.7.0) sont celles de pub.dev lues aujourd'hui ; compatibilité exacte avec Flutter 3.47.7 / Dart 3.13.5 non vérifiée (contraintes SDK non lues).
- Le quota gratuit par région Firestore (Paris vs eur3) n'est pas précisé sur la page des localisations ; à vérifier avant de choisir.
- Les pages de doc Firebase étaient tronquées/aplaties par l'outil de fetch (tableau de plateformes ambigu) ; le statut Linux repose sur son absence des sources, pas sur une déclaration explicite.

## Versions relevées

- firebase_core 4.15.0
- cloud_firestore 6.10.0
- firebase_auth 6.7.0
