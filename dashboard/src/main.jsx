import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { AppStateProvider } from './app/store.js';
import App from './App.jsx';
import './styles/base.css';

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <AppStateProvider>
      <App />
    </AppStateProvider>
  </StrictMode>,
);
