import { useState, useEffect } from 'react';

export interface ColorOption {
  name: string;
  hsl: string; // formato: "177 100% 33%"
  hex: string; // para preview
}

export interface BackgroundOption {
  name: string;
  background: string; // HSL
  card: string; // HSL
  hex: string; // para preview
  isLight?: boolean; // para ajustar foreground
}

export const colorOptions: ColorOption[] = [
  { name: 'Teal', hsl: '177 100% 33%', hex: '#00a6a6' },
  { name: 'Azul', hsl: '210 100% 50%', hex: '#0080ff' },
  { name: 'Roxo', hsl: '270 70% 50%', hex: '#8033cc' },
  { name: 'Verde', hsl: '142 70% 40%', hex: '#27ae60' },
  { name: 'Laranja', hsl: '25 95% 53%', hex: '#f39c12' },
  { name: 'Rosa', hsl: '330 80% 55%', hex: '#e91e8c' },
  { name: 'Vermelho', hsl: '0 75% 55%', hex: '#d94040' },
  { name: 'Ciano', hsl: '190 90% 45%', hex: '#17a2b8' },
];

export const backgroundOptions: BackgroundOption[] = [
  // Escuros
  { name: 'Escuro Teal', background: '180 30% 8%', card: '180 25% 12%', hex: '#0f1a1a' },
  { name: 'Preto Puro', background: '0 0% 4%', card: '0 0% 8%', hex: '#0a0a0a' },
  { name: 'Cinza Escuro', background: '220 15% 10%', card: '220 15% 14%', hex: '#161a1f' },
  { name: 'Azul Noite', background: '220 30% 8%', card: '220 30% 12%', hex: '#0e1320' },
  { name: 'Roxo Escuro', background: '270 30% 8%', card: '270 30% 12%', hex: '#150e1a' },
  { name: 'Verde Escuro', background: '150 30% 6%', card: '150 30% 10%', hex: '#0a1410' },
  // Claros
  { name: 'Branco', background: '0 0% 100%', card: '0 0% 97%', hex: '#ffffff', isLight: true },
  { name: 'Cinza Claro', background: '220 15% 96%', card: '220 15% 100%', hex: '#f4f5f7', isLight: true },
  { name: 'Bege', background: '40 30% 96%', card: '40 30% 100%', hex: '#faf8f5', isLight: true },
  { name: 'Azul Claro', background: '210 40% 96%', card: '210 40% 100%', hex: '#f0f5fa', isLight: true },
];

const PRIMARY_STORAGE_KEY = 'primary-color';
const BACKGROUND_STORAGE_KEY = 'background-color';

export function usePrimaryColor() {
  const [selectedColor, setSelectedColor] = useState<ColorOption>(() => {
    if (typeof window === 'undefined') return colorOptions[0];
    const saved = localStorage.getItem(PRIMARY_STORAGE_KEY);
    if (saved) {
      try {
        return JSON.parse(saved);
      } catch {
        return colorOptions[0];
      }
    }
    return colorOptions[0];
  });

  const [selectedBackground, setSelectedBackground] = useState<BackgroundOption>(() => {
    if (typeof window === 'undefined') return backgroundOptions[0];
    const saved = localStorage.getItem(BACKGROUND_STORAGE_KEY);
    if (saved) {
      try {
        return JSON.parse(saved);
      } catch {
        return backgroundOptions[0];
      }
    }
    return backgroundOptions[0];
  });

  useEffect(() => {
    // Aplicar a cor primária nas variáveis CSS
    const root = document.documentElement;
    
    root.style.setProperty('--primary', selectedColor.hsl);
    root.style.setProperty('--ring', selectedColor.hsl);
    root.style.setProperty('--sidebar-primary', selectedColor.hsl);
    root.style.setProperty('--sidebar-ring', selectedColor.hsl);
    
    // Accent (ligeiramente mais claro)
    const [h, s, l] = selectedColor.hsl.split(' ');
    const lighterL = Math.min(parseInt(l) + 5, 60);
    const accentHsl = `${h} ${s} ${lighterL}%`;
    root.style.setProperty('--accent', accentHsl);
    
    localStorage.setItem(PRIMARY_STORAGE_KEY, JSON.stringify(selectedColor));
  }, [selectedColor]);

  useEffect(() => {
    // Aplicar cor de fundo
    const root = document.documentElement;
    
    root.style.setProperty('--background', selectedBackground.background);
    root.style.setProperty('--card', selectedBackground.card);
    root.style.setProperty('--popover', selectedBackground.card);
    
    const [h] = selectedBackground.background.split(' ');
    
    if (selectedBackground.isLight) {
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
    
    localStorage.setItem(BACKGROUND_STORAGE_KEY, JSON.stringify(selectedBackground));
  }, [selectedBackground]);

  const setPrimaryColor = (color: ColorOption) => {
    setSelectedColor(color);
  };

  const setBackgroundColor = (bg: BackgroundOption) => {
    setSelectedBackground(bg);
  };

  return {
    selectedColor,
    setPrimaryColor,
    colorOptions,
    selectedBackground,
    setBackgroundColor,
    backgroundOptions,
  };
}
