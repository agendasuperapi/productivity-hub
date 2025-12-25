import { useEffect } from 'react';

const STORAGE_KEY = 'primary-color';

export function ColorInitializer() {
  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      try {
        const color = JSON.parse(saved);
        const root = document.documentElement;
        
        // Primary color
        root.style.setProperty('--primary', color.hsl);
        root.style.setProperty('--ring', color.hsl);
        root.style.setProperty('--sidebar-primary', color.hsl);
        root.style.setProperty('--sidebar-ring', color.hsl);
        
        // Accent (ligeiramente mais claro)
        const [h, s, l] = color.hsl.split(' ');
        const lighterL = Math.min(parseInt(l) + 5, 60);
        const accentHsl = `${h} ${s} ${lighterL}%`;
        root.style.setProperty('--accent', accentHsl);
      } catch {
        // Ignore parse errors
      }
    }
  }, []);

  return null;
}
