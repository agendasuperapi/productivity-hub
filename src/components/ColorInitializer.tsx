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
        
        if (bg.isLight) {
          // Modo claro
          root.style.setProperty('--foreground', `${h} 30% 15%`);
          root.style.setProperty('--card-foreground', `${h} 30% 15%`);
          root.style.setProperty('--popover-foreground', `${h} 30% 15%`);
          root.style.setProperty('--secondary', `${h} 15% 90%`);
          root.style.setProperty('--secondary-foreground', `${h} 30% 20%`);
          root.style.setProperty('--muted', `${h} 10% 92%`);
          root.style.setProperty('--muted-foreground', `${h} 15% 45%`);
          root.style.setProperty('--border', `${h} 15% 85%`);
          root.style.setProperty('--input', `${h} 15% 90%`);
          root.style.setProperty('--sidebar-background', `${h} 20% 97%`);
          root.style.setProperty('--sidebar-foreground', `${h} 30% 15%`);
          root.style.setProperty('--sidebar-accent', `${h} 15% 92%`);
          root.style.setProperty('--sidebar-accent-foreground', `${h} 30% 15%`);
          root.style.setProperty('--sidebar-border', `${h} 15% 88%`);
        } else {
          // Modo escuro
          root.style.setProperty('--foreground', `${h} 20% 95%`);
          root.style.setProperty('--card-foreground', `${h} 20% 95%`);
          root.style.setProperty('--popover-foreground', `${h} 20% 95%`);
          root.style.setProperty('--secondary', `${h} 20% 18%`);
          root.style.setProperty('--secondary-foreground', `${h} 20% 90%`);
          root.style.setProperty('--muted', `${h} 15% 18%`);
          root.style.setProperty('--muted-foreground', `${h} 15% 60%`);
          root.style.setProperty('--border', `${h} 15% 22%`);
          root.style.setProperty('--input', `${h} 20% 15%`);
          root.style.setProperty('--sidebar-background', `${h} 30% 10%`);
          root.style.setProperty('--sidebar-foreground', `${h} 20% 95%`);
          root.style.setProperty('--sidebar-accent', `${h} 20% 18%`);
          root.style.setProperty('--sidebar-accent-foreground', `${h} 20% 95%`);
          root.style.setProperty('--sidebar-border', `${h} 15% 20%`);
        }
      } catch {
        // Ignore parse errors
      }
    }
  }, []);

  return null;
}
