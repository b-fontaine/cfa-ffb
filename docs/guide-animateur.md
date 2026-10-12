# Guide de l'animateur : suivre une saison

Ce guide explique, en cinq étapes, comment utiliser l'application pour suivre
vos élèves de Blackball (niveau 1) pendant une saison. Il suit les décisions de
l'animateur : discipline Blackball uniquement, public enfants (séance de 90 min)
ou adultes (120 min), passage d'un public à l'autre toujours manuel.

L'application fonctionne sur smartphone, tablette et navigateur. La navigation
est en bas de l'écran sur smartphone, à gauche sur grand écran : **Accueil**,
**Élèves**, **Résultats**, **Séance**, **Sauvegarde**.

## 1. Constituer le groupe

1. Ouvrez **Élèves**, puis **Ajouter un élève**.
2. Saisissez le **prénom** et choisissez le **public** (enfants ou adultes).
   Rien d'autre n'est demandé : les élèves sont souvent mineurs, l'application
   ne garde que le strict minimum.
3. L'élève rejoint automatiquement le groupe de son public pour la saison en
   cours ; la saison et le groupe sont créés au besoin.

La liste affiche chaque élève avec un badge **Enfants** ou **Adultes** et, le
cas échéant, une alerte (par exemple après trois échecs consécutifs sur un
exercice). Le prénom peut être corrigé depuis la fiche de l'élève.

## 2. Préparer la séance

1. Ouvrez **Séance**, choisissez le groupe et cochez les élèves attendus.
2. L'application propose une séance de **90 min** (enfants) ou **120 min**
   (adultes) : déroulé minuté, exercices à travailler, rappel d'une notion si
   un élève en a besoin, jeu final.
3. Chaque exercice renvoie vers sa **fiche source** (fiche fédérale) pour
   l'expliquer aux élèves.

L'ordre d'enseignement suit le catalogue : par exemple le rebond sur bande est
enseigné avant le rejet naturel.

## 3. Saisir les résultats

1. Ouvrez **Résultats** (ou le bouton depuis la séance suggérée), choisissez le
   groupe, la date et les élèves **présents**, puis ouvrez la séance.
2. Choisissez l'exercice, puis, pour chaque élève, indiquez les **billes
   empochées** sur le **nombre de tentatives** de chaque passage.
3. L'application applique les règles :
   - **deux passages au maximum** par exercice et par séance ;
   - un passage est **réussi** quand le taux demandé par la fiche est atteint ;
   - un exercice est **validé** après plusieurs passages réussis (**5** par
     défaut, réglable) ;
   - une **alerte** apparaît après trois échecs consécutifs.

Si une saisie est refusée (par exemple un troisième passage), un message
explique pourquoi et rien n'est enregistré.

## 4. Lire la fiche d'un élève

Depuis **Élèves**, touchez un élève :

- la **progression par bloc** (pourcentage validé, exercice suivant
  recommandé) ;
- la **notion à rappeler** quand le dernier passage a été manqué ;
- la **courbe de performance** de chaque exercice : les essais en abscisse, les
  billes empochées en ordonnée, comme sur la fiche résultats fédérale. Un essai
  réussi est un disque plein, un essai manqué un anneau creux ; la liste des
  essais est aussi donnée en texte.

Chaque fiche a une adresse propre : vous pouvez l'ajouter aux favoris du
navigateur.

## 5. Le bilan de maturité et le passage en cours adultes

Dès 16 ou 17 ans, un jeune peut rejoindre le cours adultes si vous le jugez
suffisamment mature.

1. Sur la fiche de l'élève, ouvrez **Bilan de maturité**.
2. Notez de 1 à 4 la **concentration**, l'**endurance** et la **gestion de la
   frustration**, et ajoutez un commentaire si vous le souhaitez.
3. L'application affiche une **aide à la décision**. Ce n'est qu'une aide :
   elle ne modifie jamais le public.
4. Si vous décidez le passage, utilisez l'action explicite **Passer au public
   Adultes** et confirmez. L'**historique** des publics et tous les résultats
   sont conservés.

## Sauvegarder vos données

Ouvrez **Sauvegarde**.

- **Exporter** produit un fichier JSON (téléchargement dans le navigateur,
  partage de fichier sur mobile). Faites-le régulièrement, en fin de séance ou
  de mois.
- **Importer** lit un fichier et affiche d'abord une **prévisualisation**
  (nombre d'élèves, de séances, de passages) ; rien n'est écrit tant que vous
  n'avez pas confirmé. Un fichier invalide est refusé en entier.
- Si l'application vous avertit que les données ne sont conservées **qu'en
  mémoire** (navigateur sans stockage durable), exportez une sauvegarde avant
  de fermer l'onglet : sinon elles seraient perdues.

## Effacer un élève

Les élèves sont souvent mineurs : l'application ne garde que le **prénom** et
le **public**, sur votre appareil, et ne les envoie nulle part.

- Sur la fiche de l'élève, **Effacer** supprime définitivement l'élève, ses
  résultats, ses bilans et ses appartenances à un groupe. Une confirmation est
  demandée ; l'action ne peut pas être annulée.
- Effacez les élèves **à la fin de la saison**, ou à la demande de l'élève ou de
  ses parents. Exportez d'abord une sauvegarde si vous voulez garder une copie.
- Les sauvegardes déjà exportées ne sont pas modifiées : supprimez-les vous-même
  quand vous n'en avez plus besoin.

## Une saison en bref

| Quand | Action |
|-------|--------|
| Rentrée | Ajouter les élèves et leur public |
| Avant chaque séance | Consulter la séance suggérée du groupe |
| Après chaque séance | Saisir les passages de chaque élève |
| Régulièrement | Lire les fiches, rappeler les notions signalées |
| Vers 16-17 ans | Faire un bilan de maturité, décider du passage à la main |
| Fin de mois / de saison | Exporter une sauvegarde |
| Fin de saison | Effacer les élèves qui ne reviennent pas |
