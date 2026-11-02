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

## Étape 2 — pipeline

`runPipeline` enchaîne trois fonctions. Les options de segmentation et de maillage sont des paramètres ; les erreurs ne sont calculées que lorsque le code est exécuté.

1. `readVolumeHU` lit un fantôme déjà en HU, ou une série DICOM. Pour le DICOM : `HU = valeur stockée × RescaleSlope + RescaleIntercept`. L'espacement est `[sy sx sz]` en millimètres. S'il manque, la fonction s'arrête au lieu de supposer 1 mm. Les attributs identifiants (nom, identifiant, date de naissance) ne sont pas recopiés.
2. `segmentBone` lisse avec `imgaussfilt3` (écart-type en millimètres, converti en voxels anisotropes), seuille par Otsu (`multithresh`) ou par un seuil fixe (réglage par défaut 300 HU), puis `imopen`, `imclose`, `imfill`, `bwareaopen` et la plus grande composante connexe. Les rayons morphologiques par défaut sont nuls, parce qu'une ouverture enlève une coquille et biaise le volume.
3. `meshAndMeasure` calcule le volume voxel `N × sy × sx × sz`, un maillage `isosurface`, l'aire par somme des triangles, le volume du maillage par le théorème de la divergence, et les demi-axes par ACP des centres de voxels en millimètres (`demi-axe = sqrt(5 × valeur propre)`, correction de Sheppard `s²/12`). `regionprops3` fournit aussi la solidité et des longueurs en voxels : ces longueurs supposent des voxels isotropes, elles ne sont pas converties avec un seul espacement. La sphéricité est `π^(1/3) (6V)^(2/3) / A`.

L'aire de référence d'un ellipsoïde est la forme close (sphère, sphéroïde) ou les intégrales elliptiques incomplètes, avec une quadrature paramétrique de contrôle.

Le test de cette étape est `tests/PipelineTest.m`. Il recalcule les formules. Il n'a pas été lancé ici. Un cas sans bruit et sans morphologie demande que le volume voxel reste à moins de 3 % du volume analytique, et que l'ordre des demi-axes estimés suive les demi-axes vrais. Ce seuil est une tolérance de test, pas une erreur mesurée.

Pièges couverts dans le code : voxel anisotrope, `RescaleIntercept` oublié, table du scanner laissée comme seconde composante, confusion `meshgrid` / `ndgrid` (le maillage est construit en ordre image : ligne = y, colonne = x).

## Ce qui n'est pas encore dans ce dépôt

L'export (`results.json`, coupes, STL, vidéo, `validation.csv`) et le dashboard viennent ensuite. Aucun fichier de résultats n'a été généré.
