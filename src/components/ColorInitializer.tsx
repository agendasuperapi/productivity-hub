import { useEffect } from 'react';

const PRIMARY_STORAGE_KEY = 'primary-color';
const BACKGROUND_STORAGE_KEY = 'background-color';

export function ColorInitializer() {
  useEffect(() => {
    const root = document.documentElement;

    // Aplicar cor primária
    const savedPrimary = localStorage.getItem(PRIMARY_STORAGE_KEY);
    if (savedPrimary) {
      try {
        const color = JSON.parse(savedPrimary);
        root.style.setProperty('--primary', color.hsl);
        root.style.setProperty('--ring', color.hsl);
        root.style.setProperty('--sidebar-primary', color.hsl);
        root.style.setProperty('--sidebar-ring', color.hsl);
        
        const [h, s, l] = color.hsl.split(' ');
        const lighterL = Math.min(parseInt(l) + 5, 60);
        const accentHsl = `${h} ${s} ${lighterL}%`;
        root.style.setProperty('--accent', accentHsl);
      } catch {
        // Ignore parse errors
      }
    }

    // Aplicar cor de fundo
    const savedBackground = localStorage.getItem(BACKGROUND_STORAGE_KEY);
    if (savedBackground) {
      try {
        const bg = JSON.parse(savedBackground);
        root.style.setProperty('--background', bg.background);
        root.style.setProperty('--card', bg.card);
        root.style.setProperty('--popover', bg.card);
        
        const [h] = bg.background.split(' ');
        root.style.setProperty('--secondary', `${h} 20% 18%`);
        root.style.setProperty('--muted', `${h} 15% 18%`);
        root.style.setProperty('--border', `${h} 15% 22%`);
        root.style.setProperty('--input', `${h} 20% 15%`);
        root.style.setProperty('--sidebar-background', `${h} 30% 10%`);
        root.style.setProperty('--sidebar-accent', `${h} 20% 18%`);
        root.style.setProperty('--sidebar-border', `${h} 15% 20%`);
      } catch {
        // Ignore parse errors
      }
    }
  }, []);

  return null;
}
