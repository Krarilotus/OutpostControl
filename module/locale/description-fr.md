# Outpost Control

**Auteur** : Monsterfish
**Version** : 1.0.16

Offre davantage de contrôle sur les avant-postes européens et arabes placés dans l'éditeur de cartes. Chaque élément peut être désactivé dans les paramètres.

## Panneau de l'avant-poste

Sélectionnez un avant-poste dans l'éditeur de cartes. Le bouton en haut du panneau bascule désormais entre deux pages ; chaque curseur affiche sa valeur à droite.

- **Attaquants** — troupes envoyées par l'avant-poste, avec trois curseurs :
  - **Taille :** nombre exact de troupes par vague, de 0 (aucune vague) au maximum du jeu (ou 6 paliers aléatoires si l'option est désactivée). Sans le module, la carte conserve le palier le plus proche.
  - **Délai initial :** attente avant la première vague, en secondes à vitesse normale.
  - **Croissance :** augmentation par vague en pourcentage de la première vague (0 = fixe, 50 = moitié en plus, 100 = taille initiale ajoutée à chaque vague, plafond à 999 troupes). La cadence reste celle du jeu.
- **Défenseurs** — les mêmes huit boutons d'unités avec un nouveau rôle, et un curseur :
  - **Boutons d'unités :** gardes de l'avant-poste (plusieurs choix alternent). Avant-poste européen : archers, arbalétriers, lanciers, piquiers, massiers, épéistes, chevaliers, moines ; arabe : archers arabes, frondeurs, archers montés, épéistes arabes, esclaves, assassins, lanceurs de feu, arbalétriers. Sans sélection : archers.
  - **Quantité :** de 0 à 50 gardes. Les gardes tombés reviennent un par un plus vite selon le total (toutes les 30 s pour 8, toutes les 5 s pour 50).
  - **Postures :** fantassins de mêlée en défensive ; esclaves en agressive ; chevaliers en patrouille agressive attaquant troupes et bâtiments ennemis à moins de 10 cases ; archers montés en patrouille sur six points aléatoires entre 7 et 15 cases ; tireurs à pied en garde statique.
  - **Sur les murs :** les gardes à pied montent sur les murs, tours et portes en pierre du propriétaire dans un rayon de 16 cases (réglable).

## Rôles des attaquants

Chaque vague se divise par type d'unité à son départ :

| Unité | Premier rôle (par défaut) | Reste |
| --- | --- | --- |
| Esclaves | combler les douves (50 %) | incendier et détruire les bâtiments |
| Lanciers | combler les douves (50 %) | frapper murs et portes |
| Massiers | combler les douves (30 %) | détruire les bâtiments |
| Épéistes | frapper murs et portes (60 %) | détruire les bâtiments |
| Épéistes arabes | frapper murs et portes (50 %) | détruire les bâtiments |
| Chevaliers | chasser le seigneur (40 %) | chevaucher autour du château |
| Archers, archers arabes | combler les douves (30 %) | avancer et tirer sur les troupes |
| Frondeurs | contourner le château (30 %) | avancer et tirer sur les troupes |
| Archers montés | chevaucher autour du château (100 %) | avancer et tirer sur les troupes |
| Lanceurs de feu | incendier les bâtiments (60 %) | avancer et brûler les troupes |

Contourner le château signifie harceler ouvriers et troupes hors des murs. Les chevaliers ne chassent le seigneur que s'il est accessible. Chaque part est configurable.

## Engins de siège en chemin

Les catapultes (trébuchets/mangonneaux inclus) et balistes incendiaires s'arrêtent pour tirer dès qu'une cible ennemie est à portée (bâtiment le plus proche pour les catapultes ; troupes et ouvriers d'abord pour les balistes), selon leur portée réelle (Rebalancer inclus), sans jamais viser d'alliés.

## Adversaire suivant

Une fois le seigneur du joueur ciblé mort, la troupe choisit l'ennemi le plus proche dont le seigneur vit encore au lieu de rester inactive.

## Les avant-postes renforcent l'IA (désactivé par défaut)

Les vagues d'un avant-poste IA rejoignent son armée d'attaque (tireurs en renfort, autres dans l'armée principale) et combattent lors de son attaque suivante. Les engins de siège restent à l'avant-poste.

## Sauvegardes et cartes

Les réglages sont enregistrés dans la carte et les sauvegardes (via Map Extensions). Sans ce module, la carte reste jouable : le nombre de gardes est conservé (au moins un archer) et les vagues reprennent la taille d'origine sans croissance.
