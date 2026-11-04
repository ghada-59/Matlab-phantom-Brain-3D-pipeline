# Projets Python et MATLAB : plans de 2 heures

> Planning de 2 heures pour le **noyau** du projet. Le détail technique (architecture, validation, dashboard) est dans `docs/PLAN.md`, qui l'emporte en cas d'écart. Prompt mis à jour : Codex comme agent, conversion en HU.


Pour les stages Stryker, ZEISS et Dräger. Ordre conseillé : C++ (déjà prêt), puis Python, puis MATLAB.

## Projet MATLAB : morphométrie osseuse 3D à partir d'un scan CT

### Objectif

Lire un volume CT au format DICOM, segmenter l'os, construire un maillage 3D, puis calculer volume, surface et axes principaux, avec des statistiques sur plusieurs échantillons. C'est le cœur de l'offre Stryker 3D Bone Analysis. Valide la méthode sur des formes synthétiques dont le volume est connu, puis applique-la à un scan public si tu en trouves un.

### Données et prérequis

Génère des fantômes 3D (ellipsoïdes avec bruit) dont le volume exact est 4/3 x pi x a x b x c. Ça te donne une vérité terrain. Pour un vrai CT, utilise un jeu public dont tu vérifies la licence. Il faut l'Image Processing Toolbox (licence étudiante de ton université). Si `matlab` est dans le PATH, l'agent peut lancer `matlab -batch "runtests('tests')"` lui-même ; sinon tu exécutes et tu colles les erreurs.

### Plan minute par minute

| Temps       | Étape                                                                                            | Résultat attendu         |
|-------------|--------------------------------------------------------------------------------------------------|--------------------------|
| 0:00 à 0:15 | Structure du projet, génération des fantômes avec bruit                                          | Volumes synthétiques     |
| 0:15 à 0:35 | Lecture DICOM (ou lecture du fantôme), espacement des voxels                                     | Volume en millimètres    |
| 0:35 à 1:00 | Seuillage d'Otsu, ouverture morphologique, remplissage des trous, plus grande composante connexe | Masque binaire propre    |
| 1:00 à 1:20 | Maillage par isosurface, volume, surface, axes principaux par analyse en composantes principales | Mesures par échantillon  |
| 1:20 à 1:40 | Tests unitaires : le volume mesuré doit rester proche du volume exact                            | Erreur relative affichée |
| 1:40 à 2:00 | Statistiques entre échantillons, figures, README                                                 | Repo publiable           |

### Le prompt de départ pour Codex

```text
You are helping me build a MATLAB project for 3D bone morphometry from CT volumes. It is an educational project, not a clinical tool, and the README must say so. I will run the MATLAB code myself and paste errors back to you, so write code that is easy to run and debug.

Work in small steps, one script or function at a time, with a short test for each. Use only the Image Processing Toolbox and core MATLAB.

Step 1. Create a folder structure: src/, tests/, data/, results/, README.md. Write a function that generates a synthetic 3D phantom (ellipsoid with random semi-axes, Gaussian noise, known voxel spacing) and returns the volume and the exact analytic volume.

Step 2. Write a function that reads a DICOM series (dicomreadVolume) and returns the volume in HU (RescaleSlope, RescaleIntercept) and the voxel spacing. It must also accept the phantom so the pipeline works without real data.

Step 3. Segmentation: Otsu threshold (multithresh), morphological opening, hole filling, keep the largest connected component. Return a binary mask.

Step 4. Mesh and measurements: isosurface to get a triangle mesh, then volume (from voxels and spacing), surface area (from the mesh) and principal axes (PCA of voxel coordinates).

Step 5. Tests with matlab.unittest: on phantoms, recompute the relative volume error and check that the principal axes use the millimetre frame. Do not encode a universal 3 percent acceptance threshold. Show the actual errors only after MATLAB has run.

Step 6. Run the pipeline on 10 or more phantoms or samples, save a table of measurements, draw a boxplot and one 3D mesh figure, and update the README with method, results and limitations (synthetic data, no clinical validation).

Rules: comment the math briefly, no code I cannot explain, keep functions small, and list what was tested and what was not at the end.
```

Les tests de ce dépôt recalculent l'erreur relative. Ils n'imposent pas un seuil de 3 %. Tant que MATLAB n'a pas tourné, cette erreur n'a pas de valeur.

### Vérifications avant de publier

- Lance les tests toi-même et regarde l'erreur de volume réelle

- Affiche le maillage 3D et vérifie qu'il ressemble à la forme attendue

- Écris dans le README que les données sont synthétiques, sauf si tu ajoutes un vrai CT

- Ne promets aucune précision clinique

### Questions d'entretien probables

- Pourquoi le seuillage d'Otsu, et quand échoue-t-il sur un CT ?

- Comment l'espacement des voxels influence-t-il le volume ?

- Comment calcules-tu les axes principaux d'un os ?

- Comment comparer la morphologie de plusieurs échantillons ?

## Après les trois projets

- Mets chaque projet dans son propre repo, avec un README court et honnête

- Ajoute les trois liens dans le README de ton profil GitHub, avec la mention projet académique

- Dans chaque candidature, cite le projet qui correspond à l'offre : C++ pour la navigation, Python pour l'IA médicale, MATLAB pour l'os 3D
