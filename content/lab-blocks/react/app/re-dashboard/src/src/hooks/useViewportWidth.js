import { useEffect, useState } from 'react';

/** The window's inner width in pixels, kept current while the window is resized. */
export function useViewportWidth() {
  const [width, setWidth] = useState(() => window.innerWidth);

  useEffect(() => {
    // mf:slot hooks.viewport.subscribe
    const onResize = () => setWidth(window.innerWidth);
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
    // mf:endslot
  }, []);

  return width;
}
