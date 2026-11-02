export default function withLoading(Component) {
  function Wrapped({ loadState, error, children, ...rest }) {
    if (loadState === 'idle' || loadState === 'loading') {
      return <p>Chargement des fichiers exportés…</p>;
    }
    if (loadState === 'error') {
      return <p role="alert">{error || 'Lecture impossible.'}</p>;
    }
    return <Component {...rest}>{children}</Component>;
  }
  Wrapped.displayName = `withLoading(${Component.displayName || Component.name || 'Component'})`;
  return Wrapped;
}
