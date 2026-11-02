import { lazy, Suspense } from 'react';
import { createHashRouter, Navigate, RouterProvider } from 'react-router-dom';
import Layout from './components/Layout.jsx';
import CoupesPage from './routes/CoupesPage.jsx';
import MesuresPage from './routes/MesuresPage.jsx';
import ValidationPage from './routes/ValidationPage.jsx';
import DenoisePage from './routes/DenoisePage.jsx';
import VideoPage from './routes/VideoPage.jsx';
import AboutPage from './routes/AboutPage.jsx';
import NotFoundPage from './routes/NotFoundPage.jsx';

const MeshPage = lazy(() => import('./routes/MeshPage.jsx'));

const router = createHashRouter([
  {
    path: '/',
    element: <Layout />,
    children: [
      { index: true, element: <Navigate to="/coupes" replace /> },
      { path: 'coupes', element: <CoupesPage /> },
      {
        path: '3d',
        element: (
          <Suspense fallback={<p className="page-body">Chargement de la vue 3D…</p>}>
            <MeshPage />
          </Suspense>
        ),
      },
      { path: 'mesures', element: <MesuresPage /> },
      { path: 'validation', element: <ValidationPage /> },
      { path: 'debruitage', element: <DenoisePage /> },
      { path: 'video', element: <VideoPage /> },
      { path: 'a-propos', element: <AboutPage /> },
      { path: '*', element: <NotFoundPage /> },
    ],
  },
]);

export default function App() {
  return <RouterProvider router={router} />;
}
