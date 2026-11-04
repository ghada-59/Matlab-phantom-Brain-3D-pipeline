# Projet 3 : morphométrie osseuse 3D à partir de CT (MATLAB)
Référence : docs/PLAN.md, section 4 et sections 9 à 15.

Planning minute par minute du noyau : docs/PLAN_2H.md (PLAN.md l'emporte en cas d'écart).

## Règles
- Travaille uniquement dans ce dossier.
- Ordre : fantômes synthétiques et validation → pipeline → export → dashboard.
- N'invente aucun chiffre. Tout résultat vient d'une exécution.
- Demande avant d'installer quoi que ce soit. Données sur D:.
- Un commit par étape, puis un court résumé.
- Exécution : si `matlab` est dans le PATH, lance les scripts et les tests avec `matlab -batch "runtests('tests')"` et montre la sortie. Sinon, donne-moi la commande à lancer et attends que je colle le résultat.
- Projet académique, non clinique. Anonymise tout.

## Spécifications
- MATLAB R2022b ou plus, Image Processing Toolbox. Vérifier avec license('test','Image_Toolbox') et la commande ver.
- Données principales : fantômes d'ellipsoïdes (V = 4/3·π·a·b·c), voxels 0,5 / 1 / 2 mm, bruit en HU. Volume CT réel optionnel : vérifie la licence et la taille avant.
- Pipeline : dicomreadVolume → HU (RescaleSlope, RescaleIntercept), une seule fois → espacement [sy sx sz] (PixelSpacing, puis distance des centres par ImagePositionPatient ; SliceThickness est enregistrée et ne sert pas d'espacement) → imgaussfilt3 → seuil d'Otsu comparé à un seuil fixe → imopen, imclose, bwareaopen, plus grande composante → isosurface → volume N×sy×sx×sz, aire des triangles, volume du maillage par la divergence, demi-axes par eig en mm. regionprops3 fournit la solidité et PrincipalAxisLength en voxels, sans conversion par un seul espacement. Sphéricité = π^(1/3) (6V)^(2/3) / A.
- Aire du maillage par somme des triangles. Volume du maillage par le théorème de la divergence.
- Validation : erreur relative du volume et de l'aire, erreur des axes, par taille de voxel et par bruit. Test d'invariance par rotation.
- Tests avec matlab.unittest (runtests). Ils recalculent les erreurs. Ils n'imposent pas un seuil de 3 %.
- Export : results.json, coupes PNG fenêtrées et JSON des HU bruts (imwrite n'écrit pas le WebP), bone.stl (stlwrite), rotation.mp4 (VideoWriter), validation.csv.
- Pièges : voxel anisotrope, RescaleIntercept oublié, table du scanner incluse, effet d'escalier sur la surface.
- Jamais de colormap jet. Toute colorbar porte son unité.
- Option : onglet Débruitage (imgaussfilt3, medfilt3, imbilatfilt, imnlmfilt, wiener2), avec l'effet sur l'erreur de volume.

## Dashboard (dossier dashboard/, statique)
- React + Vite, JSX, Context + useReducer, React Router, three.js (STLLoader) pour l'os.
- Pas de Bootstrap.
- Palette : fond #FAF6EF, surface #FFFFFF, texte #2B2420, accent #B8502F, pétrole #2F6F73. Os en ivoire #E8DCC8. Polices Source Serif 4 et Public Sans.
- Pages : Coupes, 3D, Mesures, Validation, Débruitage, Vidéo, À propos.
