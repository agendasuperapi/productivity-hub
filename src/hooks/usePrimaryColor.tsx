import { useState, useEffect } from 'react';

export interface ColorOption {
  name: string;
  hsl: string; // formato: "177 100% 33%"
  hex: string; // para preview
}

export interface ColorShade {
  hsl: string;
  hex: string;
  lightness: number;
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

// Gerar variações de uma cor (gradiente)
export function generateColorShades(baseHsl: string): ColorShade[] {
  const [h, s] = baseHsl.split(' ');
  const hue = parseInt(h);
  const saturation = parseInt(s);
  
  // Gerar 10 variações de 15% a 85% de luminosidade
  const shades: ColorShade[] = [];
  const lightnessValues = [15, 22, 30, 37, 45, 52, 60, 70, 80, 90];
  
  for (const l of lightnessValues) {
    const hsl = `${hue} ${saturation}% ${l}%`;
    const hex = hslToHex(hue, saturation, l);
    shades.push({ hsl, hex, lightness: l });
  }
  
  return shades;
}

// Converter HSL para HEX
function hslToHex(h: number, s: number, l: number): string {
  s /= 100;
  l /= 100;
  const a = s * Math.min(l, 1 - l);
  const f = (n: number) => {
    const k = (n + h / 30) % 12;
    const color = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
    return Math.round(255 * color).toString(16).padStart(2, '0');
  };
  return `#${f(0)}${f(8)}${f(4)}`;
}

export const backgroundOptions: BackgroundOption[] = [
  // Escuros - cores mais distintas e saturadas
  { name: 'Teal', background: '180 50% 10%', card: '180 45% 14%', hex: '#0d2626' },
  { name: 'Preto', background: '0 0% 6%', card: '0 0% 10%', hex: '#0f0f0f' },
  { name: 'Cinza', background: '240 10% 12%', card: '240 10% 16%', hex: '#1c1c22' },
  { name: 'Azul', background: '230 50% 12%', card: '230 45% 16%', hex: '#101830' },
  { name: 'Roxo', background: '280 40% 12%', card: '280 35% 16%', hex: '#1f1229' },
  { name: 'Verde', background: '140 40% 10%', card: '140 35% 14%', hex: '#0f261a' },
  { name: 'Vermelho', background: '0 40% 12%', card: '0 35% 16%', hex: '#2b1212' },
  { name: 'Marrom', background: '30 40% 12%', card: '30 35% 16%', hex: '#2b1f12' },
  // Claros - cores mais distintas
  { name: 'Branco', background: '0 0% 98%', card: '0 0% 100%', hex: '#fafafa', isLight: true },
  { name: 'Cinza Claro', background: '220 20% 94%', card: '220 20% 98%', hex: '#ebeef5', isLight: true },
  { name: 'Creme', background: '45 50% 94%', card: '45 50% 98%', hex: '#f7f3e8', isLight: true },
  { name: 'Azul Claro', background: '210 60% 94%', card: '210 60% 98%', hex: '#e5f0fc', isLight: true },
  { name: 'Verde Claro', background: '140 50% 94%', card: '140 50% 98%', hex: '#e5f7ed', isLight: true },
  { name: 'Rosa Claro', background: '330 50% 95%', card: '330 50% 98%', hex: '#f7e5ef', isLight: true },
  { name: 'Lavanda', background: '260 40% 95%', card: '260 40% 98%', hex: '#efe8f7', isLight: true },
  { name: 'Pêssego', background: '20 60% 94%', card: '20 60% 98%', hex: '#fceee5', isLight: true },
];

// Gerar variações de fundo (gradiente de luminosidade)
export function generateBackgroundShades(baseBg: BackgroundOption): BackgroundOption[] {
  const [h, s] = baseBg.background.split(' ');
  const hue = parseInt(h);
  const saturation = parseInt(s);
  const isLight = baseBg.isLight;
  
  const shades: BackgroundOption[] = [];
  
  if (isLight) {
    // Para modo claro: de 90% a 100%
    const lightnessValues = [90, 92, 94, 96, 97, 98, 99, 100];
    for (const l of lightnessValues) {
      const cardL = Math.min(l + 3, 100);
      shades.push({
        name: `${baseBg.name} ${l}%`,
        background: `${hue} ${saturation}% ${l}%`,
        card: `${hue} ${saturation}% ${cardL}%`,
        hex: hslToHex(hue, saturation, l),
        isLight: true
      });
    }
  } else {
    // Para modo escuro: de 4% a 18%
    const lightnessValues = [4, 6, 8, 10, 12, 14, 16, 18];
    for (const l of lightnessValues) {
      const cardL = l + 4;
      shades.push({
        name: `${baseBg.name} ${l}%`,
        background: `${hue} ${saturation}% ${l}%`,
        card: `${hue} ${saturation}% ${cardL}%`,
        hex: hslToHex(hue, saturation, l),
        isLight: false
      });
    }
  }
  
  return shades;
}

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
