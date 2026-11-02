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

## Étape 3 — export et validation

Tout fichier de résultats est produit par une exécution. **Aucun n'a été généré ici**, et aucun n'est versionné (`results/` est ignoré par git).

`runProject` enchaîne, quand vous le lancez dans MATLAB :

- `validatePhantoms` : tailles de voxel **0,5 / 1 / 2 mm** (paramètres du plan), bruit **0 et 100 HU** (paramètres), rotation de 30 degrés sur des voxels cubiques. Pour chaque condition le code calcule l'erreur relative du volume voxel, du volume maillage, de l'aire et des demi-axes, plus l'écart entre Otsu et le seuil fixe, et l'écart de volume après rotation. La sortie est `results/validation.csv`.
- `runBatch` : 10 fantômes à demi-axes aléatoires, `results/batch.csv`.
- `exportResults` : `results.json` (version, unités, mesures), coupes PNG fenêtrées avec le préréglage d'affichage os 1800/400 HU, coupes JSON en HU bruts, `bone.stl`. `rotation.mp4` et les figures sont tentés ; sans affichage, le JSON indique `not_generated` et la raison, et un fichier vidéo partiel est supprimé.
- `compareDenoising` : gaussien, médian, bilatéral, moyennes non locales, Wiener. PSNR, SSIM si `ssim` existe, et surtout l'erreur de volume. `results/denoise.json`.

Les coupes PNG ne sont pas du WebP : `imwrite` de MATLAB R2022b n'écrit pas le WebP. Les HU bruts sont dans le JSON de coupe, l'unité est HU.

```matlab
runProject
```

Le test de cette étape est `tests/ExportTest.m`. Il recalcule les erreurs à partir des volumes qu'il vient d'obtenir. Il n'a pas été lancé ici.

## Étape 4 — dashboard statique

Le dashboard est dans `dashboard/`. Il lit uniquement `dashboard/public/data/`. Le fichier versionné `status.json` a `"executed": false`. Chaque mesure absente s'affiche « — ». Aucun chiffre de volume, d'aire, d'axe, de sphéricité, de PSNR ou d'erreur n'est codé en dur.

Pages : Coupes, 3D, Mesures, Validation, Débruitage, Vidéo, À propos. Pile : React 18, Vite, JSX, React Router en mode hash, Context et `useReducer`. Le maillage passe par three.js (`STLLoader`, `OrbitControls`). Pas de Bootstrap. Pas de colormap jet. Chaque colorbar indique son unité (HU). Les coupes restent en niveaux de gris.

Les préréglages de fenêtre 1800/400, 400/40 et 1600/−600 HU sont des réglages d'affichage, pas des mesures. Les tailles de voxel 0,5 / 1 / 2 mm citées sur la page Validation sont les conditions prévues par le code, pas des erreurs observées.

`npm install` n'a pas été lancé, et l'interface n'a pas été ouverte. Pour la lancer sur votre machine, après installation des paquets listés dans `dashboard/package.json` :

```bat
cd dashboard
npm install
npm run dev
```

Vite écoute sur `0.0.0.0` et le port `PORT`, sinon 5173. Ouvrir `index.html` en `file://` ne charge pas `status.json`.

`runProject` copie les exports vers `dashboard/public/data/` lorsque ce dossier existe. Il ne remplace pas `status.json`. Le dashboard n'utilise `results.json` que si `executed` est vrai et si `version` est celle de `status.json`.

Les coupes ne sont pas en WebP : MATLAB R2022b n'écrit pas ce format avec `imwrite`. Le dépôt fournit un PNG fenêtré et un JSON des HU bruts. Radix UI, Recharts et react-three-fiber ne sont pas des dépendances : rien n'a été installé pour les ajouter, et les contrôles natifs plus three.js couvrent les vues. Le débruitage par ondelettes (`wdenoise2`) n'est pas inclus : il demande la Wavelet Toolbox, qui n'est pas supposée.

Le test de cette étape est `tests/DashboardContractTest.m`. Il vérifie le tiret cadratin, l'absence de mesures dans `status.json`, l'unité des colorbars et l'absence de jet. Il n'a pas été lancé ici.

## Ce qui reste « — »

Aucun fichier de `results/` n'a été produit. Restent non mesurés, donc affichés « — » : volumes voxel et maillage, aires, demi-axes, sphéricité, solidité, erreurs relatives, PSNR, SSIM, seuil issu d'une exécution, étendue du STL, coupes, vidéo, `validation.csv`, `batch.csv`, `denoise.json` et les figures.
