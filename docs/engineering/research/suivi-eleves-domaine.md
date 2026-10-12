# Recherche — Modélisation domaine pur (Dart, sans Flutter) du suivi des élèves Blackball niveau 1 : entités, invariants, règles, métriques, 12 scénarios BDD

> Produit par un agent de recherche le 2026-10-11 (sources citées). **Les versions sont à revalider par `flutter pub get` avant usage.** Les faits de confiance `medium` ou `low` ne sont pas vérifiés dans le dépôt.

## Recommandation

LÉGENDE : [S] issu des sources fédérales ; [U] décision de l'animateur ; [Prop] proposé, à valider. Tout le domaine est du Dart pur (dépendances autorisées : meta, équatable ou freezed en annotations seulement ; aucun import flutter/firebase). Les règles sont des fonctions pures (entrées -> sorties) prenant une Clock/DateTime en paramètre, donc 100 % testables en TDD.

1. VALUE OBJECTS
- StudentId, GroupId, SeasonId, SessionId, AttemptId, AssessmentId : wrapper de String (UUID v4 généré hors domaine).
- Audience : enum {enfants, adultes}. Getter sessionDurationMinutes : enfants=90, adultes=120 [U].
- SuccessRate : {required:int, attempts:int}. Invariant 1 <= required <= attempts <= 16 [S : axe 0..16].
- ExerciseRef : {blockId:String, number:int}, number >= 1.
- Range : {min:int, max:int}, min <= max.
- Cycle : enum {A, B, C, D} [Prop, progression-par-cycles.md].
- Bridge : enum {cadre, surface} (nullable) [S].
- ValidationPolicy [Prop] : {passagesRequired:int = 1, ratioWhenTotalDiffers: bool = true}.
- RulesConfig [Prop] : {alertThreshold:int = 3, recallStaleSessions:int = 4, trendWindow:int = 5, maxPassesPerExerciseInSession:int = 2 [S], minDistinctExercises:int = 2 [S]}.

2. CATALOGUE (immuable, chargé du YAML, version 1)
- ExerciseSpec : {ref:ExerciseRef, rate:SuccessRate, bridge:Bridge?, bronze:bool, note:String?}.
- TrainingBlock : {id:String, title:String, recommendedSessions:Range, technicalSheets:List<int>, exercises:List<ExerciseSpec> (numéros 1..n contigus, rate défini), cycle:Cycle [Prop], teachingOrder:int [Prop, voir conflit rejet/rebond], duplicateInSource:bool}.
- ExerciseCatalogue : {version:int, level:int, blocks:List<TrainingBlock>}. Méthodes : blockById, exercise(ref), nextExercise(ref) (suivant dans le bloc, sinon premier du bloc suivant par teachingOrder), blocksInTeachingOrder. Invariants : ids de blocs uniques ; teachingOrder unique et strictement croissant ; le 2e rejet-naturel est conservé comme variante (duplicateInSource) mais exclu de la séquence principale [Prop].

3. ENTITÉS ET AGRÉGATS
Student (racine) : {id:StudentId, firstName:String, currentAudience:Audience, audienceHistory:List<AudienceChange>, active:bool, notes:String?}. AudienceChange : {audience, effectiveFrom:Date, reason:String?}. Pas de date de naissance obligatoire (aucune tranche d'âge) ; birthYear?:int optionnel [Prop] pour un simple avertissement < 16 ans lors du passage adultes. L'élève est indépendant de la saison : sa progression est cumulée d'une saison à l'autre [Prop] (même élèves toute la saison [U]).
 Invariants : audienceHistory non vide, triée par effectiveFrom, dernier élément == currentAudience ; changeAudience() ajoute une entrée, ne supprime ni ne modifie jamais ni les entrées passées ni les résultats [U] ; une même date ne peut porter deux changements contradictoires.

Season : {id, label (ex. « 2026-2027 »), startDate, endDate}. Invariants : endDate > startDate ; deux saisons ne se chevauchent pas [Prop].

Group : {id, seasonId, name, audience:Audience, memberships:List<Membership>}. Membership : {studentId, from:Date, to:Date?}. Invariants : un élève a au plus une appartenance ouverte par saison ; from <= to ; audience de l'élève à la date from == audience du groupe [Prop] (passer un jeune en cours adultes = clore l'appartenance enfants et en ouvrir une dans un groupe adultes).

SessionRecord (racine) : {id, groupId, seasonId, date:Date, audience:Audience (instantané), plannedDurationMinutes:int, mainBlockId:String?, recallBlockId:String?, present:Set<StudentId>, attempts:List<ExerciseAttempt>, comment:String?}.
 Invariants : date dans la saison ; plannedDurationMinutes == audience.sessionDurationMinutes [U] ; present inclus dans les membres du groupe à la date ; chaque attempt.studentId in present ; une seule notion principale [S] ; pour (élève, exercice) au plus 2 passages dans la séance [S] ; avertissement (non bloquant) si un élève a moins de 2 exercices distincts [S].

ExerciseAttempt = un passage d'un élève sur un exercice = une colonne « essai » de la fiche [S] : {id:AttemptId, studentId, sessionId, exercise:ExerciseRef, passIndex:int (1 ou 2 dans la séance), potted:int (billes réussies), total:int (tentatives), recordedAt:DateTime}.
 Invariants : 0 <= potted <= total ; 1 <= total <= 16 [S : axe] ; total == catalogue.rate.attempts, sinon l'attempt est marqué customTotal=true et évalué au ratio [Prop] ; l'exercice doit exister au catalogue ; passIndex in {1,2} [S]. Un résultat enregistré n'est pas supprimé mais corrigeable par un événement de correction (audit) [Prop].
 Dérivé : ratio = potted/total ; passed = (potted >= rate.required) si total == rate.attempts, sinon ratio >= required/attempts.

ExerciseResult (vue dérivée par élève x exercice, jamais saisie) : {studentId, exercise, attempts:List<ExerciseAttempt> triée (date séance, passIndex), status:{notStarted, inProgress, validated}, validatedOn:Date?, consecutiveFailures:int, best:SuccessRatio, last:SuccessRatio}. Validé = au moins ValidationPolicy.passagesRequired passages réussis [Prop] ; la validation est monotone (un échec ultérieur ne la retire pas) [Prop].

MaturityAssessment : {id, studentId, date:Date, concentration:int, endurance:int, frustration:int (1..4 [Prop]), comment:String?, assessor:String?}. Invariants : valeurs dans 1..4 ; date non future ; plusieurs bilans par élève autorisés (historique). Critères [U] ; échelle [Prop]. Dérivé uniquement : readinessHint = tous critères >= 3 [Prop], affiché comme aide ; il ne déclenche JAMAIS changeAudience [U]. Pas de calcul fondé sur l'âge ou sur les taux de réussite seuls [U].

Ports (interfaces domaine) : CatalogueRepository, StudentRepository, GroupRepository, SeasonRepository, SessionRepository, AssessmentRepository ; Failure scellée {InvariantViolation(code,message), NotFound}. Itération 1 : persistance locale suffit ; Firebase seulement si synchronisation multi-appareils (question ouverte 3 de 08-lacunes) ; l'élève étant un mineur, prévoir minimisation des données (prénom seul).

4. RÈGLES DÉTERMINISTES (fonctions pures)
R1 Validation d'un passage [S taux ; Prop pour total différent] : passed(attempt, spec) comme défini en 3.
R2 Exercice suivant d'un élève [S ordre et taux ; Prop pour la politique de validation] : nextExercise(student, catalogue, results) = premier exercice non validé en parcourant les blocs par teachingOrder puis les n croissants ; on ne saute pas un exercice non validé ; si tous validés -> « niveau 1 terminé ». Un bloc n'est « acquis » que si tous ses exercices sont validés [Prop] ; seuil d'avancement configurable (la doc projet dit « au moins pour les premiers exercices », donc non tranché).
R3 Nombre de séances par bloc [S valeurs, approximatif] : sessionsSpent(student, block) = séances où l'élève était présent et où le bloc est mainBlock ou recallBlock ou comporte un passage. Si sessionsSpent > max et bloc non acquis -> drapeau « durée dépassée » [Prop] ; ne jamais bloquer (valeur approximative [S]). Unité « séance » = séance du groupe (90 ou 120 min) [Prop, question ouverte].
R4 Alerte 3 échecs consécutifs [Prop, demandé] : pour un (élève, exercice), compter les passages non réussis les plus récents sans réussite intercalaire, triés par (date, passIndex) ; absence = neutre (ne casse pas la série) ; alerte active si compte >= RulesConfig.alertThreshold (3) ; se résout au premier passage réussi ou par acquittement explicite de l'animateur. Niveau d'alerte : 3 = attention, >= 5 = persistante [Prop].
R5 Notion à rappeler [Prop ; le principe du rappel autorisé est [S] via progression-par-cycles règle 3] : candidats = blocs déjà commencés (au moins un passage) et différents du mainBlock. Retenir un candidat si (a) une alerte R4 active sur un de ses exercices, ou (b) dernier passage échoué, ou (c) non pratiqué depuis >= recallStaleSessions séances (4). Tri : alerte active d'abord, puis plus petit (ratio dernier passage / ratio requis), puis plus ancien, puis plus petit teachingOrder. Au niveau groupe : bloc dont >= 50 % des présents ont un dernier passage échoué est prioritaire. Résultat : au plus 1 notion à rappeler, ou aucune. Un rappel peut remplacer un exercice d'entraînement [S/Prop, progression-par-cycles règle 3].
R6 Séance suggérée selon le public [S pour ordre, plafonds et notion unique ; U pour durées ; Prop pour minutage et sélection] : suggestSession(group, date, catalogue, results, config) -> SessionPlan {audience, durationMinutes (90|120), mainBlockId, recallBlockId?, exercises:List<ExerciseRef>, phases:List<Phase{name, minutes}>, gameNote}. Étapes : (1) mainBlock = bloc de l'exercice suivant le plus fréquent parmi les présents prévus (égalité -> plus petit teachingOrder) ; jamais un bloc dont les prérequis (bloc précédent) n'ont aucun passage [S : pas de notion non vue]. (2) exercices : enfants = 2 exercices distincts, adultes = 2 à 3 dont éventuellement 1 de rappel [S + Prop] ; premier = exercice suivant dominant, deuxième = suivant dominant +1 si pertinent, sinon exercice de rappel ; chacun planifié au plus 2 fois [S]. (3) phases : enfants 10/20/35/20/5 = 90 ; adultes 10/25/50/25/10 = 120 ; invariant somme == durée [S/U]. (4) ordre des phases : accueil, notion+initiation, entraînement, jeu, bilan [S]. (5) jeu : thème de la notion, ou partie à difficulté réduite après les quantités de billes [S].
R7 Passage enfants -> adultes [U] : changeAudience(student, adultes, date) toujours manuel ; avertissements non bloquants : aucun bilan de maturité enregistré, birthYear < 16 si renseigné ; l'historique est conservé.

5. MÉTRIQUES DE COURBE DE PROGRESSION (toutes dérivées)
- Point de courbe [S] : {index (ordre chronologique, 1..n), date, sessionId, potted, total, ratio, passed}. Axe y = potted 0..16 [S] ; l'app n'est pas limitée à 5/6 colonnes (pagination par fiche de 5 [Prop]).
- Par (élève, exercice) : meilleur, dernier, premier, delta(dernier - premier), moyenne mobile sur 3 [Prop], pente de régression linéaire du ratio sur les trendWindow (5) derniers passages [Prop], scoreRelatif = ratio / (required/attempts) (>= 1 = taux atteint) [Prop], passagesJusquàValidation, séancesJusquàValidation, stagnation = >= 5 passages, aucune validation, pente <= 0 [Prop].
- Par (élève, bloc) : % d'exercices validés, séances passées vs recommandées (R3), statut {nonCommencé, enCours, acquis, aRevoir}.
- Par élève : nb d'exercices validés / 64 (+ détail par cycle), alertes actives, dernier bilan de maturité, assiduité (présences / séances du groupe dans la saison).
- Par groupe / séance : répartition des élèves par exercice courant, taux de réussite moyen par exercice dans la séance, carte de chaleur élèves x blocs, part du groupe en échec au dernier passage (alimente R5/R6).

6. DOUZE SCÉNARIOS BDD PRIORITAIRES (Gherkin, # language: fr, itération 1 ; mise en œuvre : mots-clés anglais, libellés français, voir `app/test/bdd/*.feature`. Scénarios 3, 4 et 6 réécrits avec 5 passages [U])
Fonctionnalité: Suivi des résultats d'entraînement

Scénario: 1 [S] Enregistrer un passage valide
  Soit un élève "Léa" présente à la séance du groupe enfants
  Quand j'enregistre pour "puissance 1" 7 billes réussies sur 9 tentatives
  Alors le passage est enregistré avec le ratio 7/9

Scénario: 2 [S] Refuser plus de réussites que de tentatives
  Soit un élève "Léa" présente à la séance
  Quand j'enregistre pour "puissance 1" 10 billes réussies sur 9 tentatives
  Alors l'enregistrement est refusé avec le message "réussites supérieures aux tentatives"

Scénario: 3 [S/U] Valider un exercice au cinquième passage réussi
  Soit "Léa" avec 4 passages réussis sur "puissance 1" lors de séances précédentes
  Quand j'enregistre pour "puissance 1" 7 sur 9
  Alors "puissance 1" est validé pour "Léa"
  Et l'exercice suivant recommandé est "puissance 2"

Scénario: 4 [S/U] Taux non atteint
  Soit "Léa" avec 4 passages réussis sur "puissance 1" lors de séances précédentes
  Quand j'enregistre pour "puissance 1" 6 sur 9
  Alors "puissance 1" reste en cours avec 4 passages réussis sur 5
  Et l'exercice suivant recommandé est "puissance 1"

Scénario: 5 [Prop] Alerte après trois échecs consécutifs
  Soit "Théo" avec deux passages échoués sur "bille-pleine 1" lors de séances précédentes
  Quand j'enregistre pour "bille-pleine 1" 4 sur 8
  Alors une alerte "3 échecs consécutifs" est active pour "Théo" sur "bille-pleine 1"

Scénario: 6 [Prop/U] Une réussite résout l'alerte et valide l'exercice
  Soit "Théo" avec 4 passages réussis puis 3 échecs sur "bille-pleine 1" (alerte active)
  Quand j'enregistre pour "bille-pleine 1" 6 sur 8
  Alors l'alerte n'est plus active
  Et l'exercice est validé (5e passage réussi)

Scénario: 7 [S] Deux passages maximum par exercice et par séance
  Soit "Léa" avec deux passages sur "puissance 2" dans la séance
  Quand j'enregistre un troisième passage sur "puissance 2"
  Alors l'enregistrement est refusé avec le message "2 passages maximum par séance"

Scénario: 8 [U] Passage en cours adultes avec historique conservé
  Soit "Hugo" du groupe enfants avec 5 passages enregistrés
  Quand je passe "Hugo" en public adultes au 2026-11-01
  Alors son public courant est "adultes"
  Et ses 5 passages restent visibles
  Et son historique de public contient "enfants" puis "adultes"

Scénario: 9 [U] Le bilan de maturité ne change pas le public
  Quand j'enregistre pour "Hugo" un bilan concentration 4, endurance 4, frustration 3
  Alors le bilan indique "prêt" à titre d'aide
  Et le public de "Hugo" reste "enfants"

Scénario: 10 [U/Prop] Séance suggérée enfants
  Soit un groupe enfants dont le plus grand nombre d'élèves travaille "demi-bille 2"
  Quand je demande la séance suggérée
  Alors la durée est de 90 minutes
  Et la somme des phases est de 90 minutes
  Et la notion principale est "demi-bille" avec 2 exercices distincts

Scénario: 11 [Prop] Séance adultes avec rappel
  Soit un groupe adultes travaillant "trois-quarts 1" dont "bille-pleine 3" est à 5/8 au dernier passage
  Quand je demande la séance suggérée
  Alors la durée est de 120 minutes
  Et la notion à rappeler est "bille-pleine"
  Et aucun exercice n'est prévu plus de 2 fois

Scénario: 12 [S] Courbe de progression d'un exercice
  Soit "Léa" avec sur "puissance 2" les passages 5/10, 7/10, 6/10, 8/10 dans cet ordre
  Quand j'ouvre sa courbe pour "puissance 2"
  Alors la courbe contient les points 5, 7, 6, 8
  Et le meilleur résultat est 8/10 et la pente est positive

Ordre d'implémentation conseillé : domaine (catalogue + invariants, TDD) -> scénarios 1-4, 7, 12 -> 5, 6 -> 8, 9 -> 10, 11. Une couche données chargeant le YAML du catalogue (asset) précède les écrans ; Widgetbook concerne seulement les écrans, hors de ce lot.

## Faits relevés

- **[high]** La fiche résultats est par élève ET par exercice d'entraînement : champs nom, séance, exercice, notion technique ; colonnes ESSAI 1 à 5 (PDF fourni) ou 6 (exemple du mémento) ; chaque colonne = « nb de billes empochées / total » ; axe vertical gradué 0 à 16 ; on pointe le score puis on relie les points pour obtenir une courbe de performance.
  - Source : /home/bfontaine/github/cfa-ffb/docs/sources/Fiches résultats CFA blackball.pdf (pdftotext) et docs/sources/Fiches techniques CFA BàP.pdf lignes 68-100 ; synthèse docs/knowledge/04-evaluation-et-suivi.md
- **[high]** Exemple du mémento : essai 1 = 5/10, essai 2 = 7/10, essai 3 = 6/10, essai 4 = 8/10 (essais 5 et 6 vides). Utilisable comme jeu de test de la courbe.
  - Source : docs/sources/Fiches techniques CFA BàP.pdf (extrait pdftotext) ; docs/knowledge/04-evaluation-et-suivi.md ligne 10
- **[high]** Chaque exercice du catalogue porte un taux « réussites requises / tentatives » pour passer à l'exercice suivant (ex. puissance E1 7/9, E2 5/10 ; coulé E3 8/12 ; trajectoires E6 10/15). Le dénominateur maximal du catalogue est 15, donc compatible avec l'axe 0..16 de la fiche. Total : 13 blocs distincts, 64 exercices (+4 pour le doublon rejet naturel).
  - Source : /home/bfontaine/github/cfa-ffb/docs/knowledge/03-exercices/catalogue-entrainement.yaml (calcul par comptage des entrées)
- **[high]** Règles de séance sourcées : plusieurs exercices différents par séance, chacun joué 2 fois au maximum, résultats d'entraînement seuls reportés sur les fiches résultats ; ordre notion+initiation en groupe, puis entraînement, puis jeu ; une seule notion principale ; nombre de séances par notion « approximatif ».
  - Source : docs/knowledge/01-methode-pedagogique.md ; docs/knowledge/05-seances/README.md ; docs/sources/Fiches techniques CFA BàP.pdf lignes 40-60
- **[high]** Durées 90 min (enfants) et 120 min (adultes) sont des contraintes projet [U], absentes des sources fédérales. Minutage interne proposé [Prop] : enfants 10/20/35/20/5 = 90 ; adultes 10/25/50/25/10 = 120 (accueil / notion+initiation / entraînement / jeu / bilan).
  - Source : docs/knowledge/05-seances/structure-type-seance.md ; docs/knowledge/05-seances/README.md
- **[high]** Décision utilisateur [U] : le public est un attribut modifiable avec historique des résultats conservé ; passage possible en cours adultes dès 16-17 ans selon maturité ; bilan de maturité sur 3 critères (concentration, endurance pour 2 h, gestion de la frustration) qui aide mais ne décide jamais ; ne pas déduire la maturité de l'âge seul ni des seuls taux de réussite ; pas de tranche d'âge enfants.
  - Source : docs/knowledge/05-seances/passage-enfants-adultes.md ; demande utilisateur relayée (points 2 et 3)
- **[high]** Conflit d'ordre entre catalogue YAML et enseignement : le YAML (ordre du PDF) place rejet-naturel avant rebond-bande, alors que la méthode et progression-par-cycles enseignent le rebond sur bande (n°9) avant le rejet naturel (n°10). Le bloc rejet naturel est en doublon dans la source (2e occurrence, 1 à 2 séances, schémas différents). Il faut donc un champ teachingOrder explicite distinct de l'ordre du fichier.
  - Source : catalogue-entrainement.yaml lignes 65-83 ; docs/knowledge/01-methode-pedagogique.md « Ordre d'enseignement » point 4 ; docs/knowledge/05-seances/progression-par-cycles.md
- **[medium]** La source ne précise pas si un seul passage au taux requis valide l'exercice, ni si le taux doit être confirmé sur 2 passages ; elle ne définit pas la durée d'une « séance » pour le nombre de séances conseillé. Ces points sont donc des paramètres de politique [Prop], pas des règles [S].
  - Source : docs/knowledge/03-exercices/catalogue-entrainement.yaml ligne 9 (sessions_unit_defined: false) ; docs/knowledge/04-evaluation-et-suivi.md ligne 14 ; docs/knowledge/08-lacunes-et-questions-ouvertes.md
- **[high]** Aucune recherche web ni consultation context7 n'a été nécessaire : le sujet est une modélisation métier à partir de fichiers locaux ; aucune version de paquet n'a été vérifiée dans ce lot.
  - Source : périmètre de la tâche (fichiers locaux en lecture seule)

## Risques

- Le catalogue YAML a un ordre de fichier différent de l'ordre pédagogique (rejet naturel avant rebond sur bande) et un bloc en doublon : sans teachingOrder explicite, R2 et R6 recommanderaient une mauvaise notion.
- La politique de validation (1 passage réussi suffit ?) et la notion de « séance » pour les nombres conseillés ne sont pas définies par la source : à faire trancher par l'animateur, sinon la règle R2/R3 reste [Prop].
- Les seuils 3 échecs, 4 séances de péremption, fenêtre de 5 passages, 50 % de groupe et le minutage des phases sont des propositions : les exposer en configuration plutôt qu'en constantes codées.
- Les taux requis du catalogue sont des seuils par exercice ; si total saisi != tentatives du catalogue, l'évaluation au ratio est une extrapolation non sourcée.
- Données sur des mineurs : stocker le minimum (prénom, public) ; birthYear optionnel ; vérifier le cadre RGPD avant toute synchronisation Firebase.
- La prise en charge du français (# language: fr) par bdd_widget_test 2.1.4 n'a pas été vérifiée dans ce lot ; à confirmer dans la documentation du paquet avant d'écrire les .feature (sinon utiliser les mots-clés anglais Given/When/Then avec libellés français).
- Le bilan de maturité ne doit jamais automatiser le changement de public ; un readinessHint affiché de façon trop affirmative contredirait la décision [U].
