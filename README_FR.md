# HealTide

**Un HUD de prédiction de soins compact pour World of Warcraft: Forever - une barre fine par carte.**

HealTide affiche les soins que tu donnes et reçois sous forme de barres compactes, même quand le client cache les chiffres.

Chaque carte est une seule barre :

- **Vie** — remplit la barre de gauche à droite, colorée vert → jaune → rouge.
- **Soins** — prolongent la barre depuis la position actuelle de la vie jusqu'au total prévu. Ton soin est plus lumineux, ceux des autres légèrement plus sombres.
- **Overheal** — la prolongation passe en orange quand le client signale de l'overheal. Elle continue au-delà de la barre ; sa longueur au-delà représente la quantité gaspillée. Les montants sont masqués et le dégradé de sévérité n'est pas disponible quand les valeurs sont secrètes.

La carte incoming est une barre minimale de soins reçus : pas de barre de vie, de nom ni de montant. Elle réagit à toute prédiction de soin sur toi, y compris d'un joueur hors de ton groupe ; un auto-soin seul la laisse vide et invisible.

La barre reprend volontairement l'allure de la barre de cast : une seule ligne, fond sombre, bordure fine, texte à l'intérieur.

Tes propres soins sur toi apparaissent sur la carte sortante **You** ; la barre incoming montre les soins des autres joueurs, même hors de ton groupe.

## Fonctionnalités

- Cartes compactes à une barre : une pour la cible soignée (et les membres du groupe pendant tes casts de soin), une barre incoming minimale pour les soins que tu reçois.
- Barre fine 220 × 16 par défaut, bordure noire de 1 px, petits textes et étincelles de barre de cast aux bords de la vie et des soins.
- Prédiction native de Forever via `UnitGetDetailedHealPrediction` / `UnitHealPredictionCalculator` ; pas de LibHealComm, pas de journal de combat.
- Compatible avec les valeurs secrètes : les valeurs de vie/soin vont directement dans les StatusBars ; les montants sont masqués et l'overheal est indiqué par une extension/cap orange.
- Cartes déplaçables, mode verrouillage.
- Mode démo pour tester l'affichage sans groupe.
- Aucune bibliothèque externe.

## Installation

1. Copier le dossier `HealTide` dans :
   `World of Warcraft\_forever_\Interface\AddOns\HealTide`
2. `/reload`.
3. Activer **HealTide** dans la liste des addons.
4. `/ht status` doit afficher :
   `Prediction: OK | clamps: MaximumHealth / MissingHealth | two calculators: yes`

## Commandes

| Commande | Description |
|---|---|
| `/ht test` | Cartes de démo 15 s : cible à 50 % avec 250 des autres + 350 de toi (100 d'overheal) ; toi à 70 % avec 300 reçus. |
| `/ht live` | Vraies valeurs pendant 10 s. |
| `/ht stop` | Masque les cartes de démo. |
| `/ht unlock` / `/ht lock` | Déplacer/verrouiller les cartes. |
| `/ht outgoing` / `/ht incoming` | Activer/désactiver chaque type. |
| `/ht healsonly` | Activer/désactiver le filtre « sorts de soin ». |
| `/ht width 220` | Largeur (120–500). |
| `/ht height 16` | Hauteur (10–40). |
| `/ht spacing 2` | Espacement entre les cartes (0–20). |
| `/ht reset` | Valeurs par défaut. |
| `/ht status` | API, clamp, réglages, diagnostics. |
| `/ht secrets` | Diagnostic des valeurs secrètes (vie, calculateur, soins reçus). |

## Compatibilité

- World of Warcraft: Forever 1.60.x, interface `16001`.
- Pas compatible avec Retail ou Classic sans portage séparé.
- Aucune dépendance.

## Limites connues

- **Soins directs uniquement.** La prédiction native de Forever n'inclut pas les HoTs. HealTide ne les devine pas ; les HoTs des autres joueurs ne sont pas exposés en combat.
- Le client marque les valeurs de vie et de prédiction comme secrètes, même hors combat. Les barres s'affichent nativement ; les montants sont masqués et l'overheal est indiqué par l'extension/cap orange.
- Soins de zone : des cartes de groupe supplémentaires apparaissent pendant tes casts de soin ; sinon la cible du cast est affichée.
- C'est un HUD flottant, pas un remplacement de VuhDo, HealBot, Grid2 ou HealForever.

## Développement

Tests hors-jeu (Lua 5.1) :

```sh
lua tests/test_healtide.lua
```

Construire le zip :

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

Le zip est écrit dans `dist/HealTide-<version>.zip` et contient `HealTide/HealTide.toc`, `HealTide/HealTide.lua`, `HealTide/README_FR.md` et `HealTide/LICENSE`.

Le workflow CI lance la vérification syntaxique et les tests hors-jeu sur les pushes vers `main` et sur les pull requests. Les tags sont gérés par le workflow `Release`, qui lance aussi les tests.

## Licence

MIT — voir `LICENSE`.
