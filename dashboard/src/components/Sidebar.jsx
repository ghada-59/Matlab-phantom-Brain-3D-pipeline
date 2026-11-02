import { NavLink } from 'react-router-dom';

const LINKS = [
  ['/coupes', 'Coupes'],
  ['/3d', '3D'],
  ['/mesures', 'Mesures'],
  ['/validation', 'Validation'],
  ['/debruitage', 'Débruitage'],
  ['/video', 'Vidéo'],
  ['/a-propos', 'À propos'],
];

export default function Sidebar() {
  return (
    <aside className="sidebar">
      <p className="kicker">MATLAB</p>
      <nav aria-label="Pages">
        {LINKS.map(([to, label]) => (
          <NavLink key={to} to={to}>
            {label}
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}
