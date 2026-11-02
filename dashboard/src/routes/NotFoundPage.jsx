import { Link } from 'react-router-dom';

export default function NotFoundPage() {
  return (
    <div className="page-body">
      <h1>Page introuvable</h1>
      <p><Link to="/coupes">Retour aux coupes</Link></p>
    </div>
  );
}
