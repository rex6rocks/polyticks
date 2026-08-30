import React from 'react';
import ReactDOM from 'react-dom/client';
import { App } from './App';
import './index.css';
import { handleDeepLinkOnLoad } from './deepLinks';

// T5.2: /post/:id deep links must expose og:image for social previews.
handleDeepLinkOnLoad();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
