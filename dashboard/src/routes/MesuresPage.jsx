import { useAppState } from '../app/store.js';
import Panel from '../components/Panel.jsx';
import { formatMeasurement, UNMEASURED } from '../utils/format.js';

export default function MesuresPage() {
  const { state } = useAppState();
  const spacing = state.results?.spacingMM;
  return (
    <>
      <header className="page-head">
        <p className="kicker">Mesures</p>
        <h1>Volume, aire, axes</h1>
        <p>La colonne de droite reprend le fichier results.json. Sans ce fichier, chaque valeur est un tiret.</p>
      </header>
      <div className="page-body">
        <Panel title="Espacement des voxels">
          <p className="num">
            {Array.isArray(spacing)
              ? `${spacing.map((value) => value.toLocaleString('fr-FR')).join(' × ')} mm`
              : UNMEASURED}
          </p>
          <p className="unit">Ordre ligne, colonne, coupe. Un espacement manquant n'est pas remplacé par 1 mm.</p>
          <p className="unit">
            Épaisseur de coupe DICOM : {formatMeasurement(state.results?.sliceThicknessMM, { digits: 2, unit: 'mm' })}.
            Origine de l'espacement : {state.results?.sliceSpacingSource || UNMEASURED}.
          </p>
        </Panel>
        <Panel title="Source">
          <p>{state.results?.source || UNMEASURED}</p>
          <p className="unit">
            HU confirmés : {state.results ? (state.results.huConfirmed ? 'oui' : 'non') : UNMEASURED}
          </p>
        </Panel>
      </div>
    </>
  );
}
