# Morphométrie osseuse 3D à partir de CT (MATLAB)

Projet académique, non clinique. Ce dépôt ne fournit pas d'outil de diagnostic et ne prétend à aucune exactitude clinique.

Les fantômes sont des ellipsoïdes synthétiques. Aucun examen de patient n'est inclus.

## Exécution

MATLAB n'est pas disponible dans l'environnement qui a préparé ce dépôt (`command -v matlab` ne retourne rien). **Aucun script n'a été exécuté.** Aucun volume, aucune aire et aucune erreur mesurée ne sont publiés. Tant qu'une métrique n'a pas été produite par une exécution locale, elle vaut « — ».

Les tests sont écrits pour MATLAB R2022b ou plus récent, avec l'Image Processing Toolbox. Depuis la racine du projet, sous Windows :

```bat
matlab -batch "runtests('tests')"
```

Vérification de la toolbox, dans MATLAB :

```matlab
license('test', 'Image_Toolbox')
ver
```

## Étape 1 — fantôme ellipsoïde

`src/generateEllipsoidPhantom.m` construit un volume 3D.

- Demi-axes `a`, `b`, `c` en millimètres, le long de `x` (colonnes), `y` (lignes) et `z` (coupes). Sans demi-axes fournis, ils sont tirés uniformément dans l'intervalle **[12, 36] mm**. Cet intervalle est un paramètre du générateur.
- Volume analytique : `V = 4/3·π·a·b·c`.
- Volume numérique : nombre de centres de voxels à l'intérieur de l'ellipsoïde, multiplié par le volume d'un voxel. C'est une référence de discrétisation, pas une mesure de segmentation.
- Espacement `[sy sx sz]` en millimètres (ligne, colonne, coupe). La valeur par défaut `[1 1 1]` est un paramètre.
- Intensités par défaut : fond **−1000 HU**, os **1000 HU**. Ce sont des réglages de simulation, pas des mesures.
- Bruit gaussien ajouté après la construction du masque. Le masque et les deux volumes restent géométriques.

Le test de cette étape est `tests/PhantomGenerationTest.m`. Il n'a pas été lancé ici.

## Ce qui n'est pas encore dans ce dépôt

Le pipeline (HU, segmentation, maillage, mesures), l'export et le dashboard viennent dans les étapes suivantes. Aucun fichier de résultats n'est généré.
