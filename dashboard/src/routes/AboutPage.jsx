export default function AboutPage() {
  return (
    <>
      <header className="page-head">
        <p className="kicker">À propos</p>
        <h1>Morphométrie osseuse, version académique</h1>
        <p>Projet d'exercice. Ce n'est pas un dispositif médical et aucune exactitude clinique n'est revendiquée.</p>
      </header>
      <div className="page-body about-grid">
        <section>
          <h2>Pipeline</h2>
          <ol className="pipeline">
            <li>Fantôme ellipsoïde, ou DICOM converti en HU avec la pente et l'intercept.</li>
            <li>Espacement des voxels. S'il manque, le calcul s'arrête.</li>
            <li>Lissage, seuil d'Otsu comparé à un seuil fixe, morphologie, plus grande composante.</li>
            <li>Isosurface, aire des triangles, volume par le théorème de la divergence.</li>
            <li>Demi-axes par ACP en millimètres. La sphéricité compare volume et aire.</li>
            <li>Validation sur plusieurs tailles de voxel, niveaux de bruit et une rotation.</li>
          </ol>
        </section>
        <section>
          <h2>Limites</h2>
          <ul>
            <li>Données synthétiques seulement dans ce dépôt. Pas de scanner réel.</li>
            <li>MATLAB n'a pas été exécuté ici. Les métriques affichent un tiret.</li>
            <li>L'ouverture morphologique enlève une coquille et biaise le volume.</li>
            <li>L'aire du maillage en escalier est souvent plus haute que l'aire lisse.</li>
            <li>regionprops3 donne des longueurs en voxels isotropes. L'ACP en millimètres est la mesure physique.</li>
            <li>Otsu échoue si l'histogramme n'est pas bimodal, par exemple os fin ou table du scanner fusionnée à l'os.</li>
          </ul>
          <h2>Technologies</h2>
          <ul>
            <li>MATLAB R2022b ou plus récent, Image Processing Toolbox.</li>
            <li>React, Vite, React Router en mode hash, Context et useReducer.</li>
            <li>three.js, STLLoader, pour le maillage.</li>
          </ul>
        </section>
      </div>
    </>
  );
}
