import { useState, useEffect } from 'react';

export interface ColorOption {
  name: string;
  hsl: string; // formato: "177 100% 33%"
  hex: string; // para preview
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

const STORAGE_KEY = 'primary-color';

export function usePrimaryColor() {
  const [selectedColor, setSelectedColor] = useState<ColorOption>(() => {
    if (typeof window === 'undefined') return colorOptions[0];
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      try {
        return JSON.parse(saved);
      } catch {
        return colorOptions[0];
      }
    }
    return colorOptions[0];
  });

  useEffect(() => {
    // Aplicar a cor nas variáveis CSS
    const root = document.documentElement;
    
    // Primary color
    root.style.setProperty('--primary', selectedColor.hsl);
    root.style.setProperty('--ring', selectedColor.hsl);
    root.style.setProperty('--sidebar-primary', selectedColor.hsl);
    root.style.setProperty('--sidebar-ring', selectedColor.hsl);
    
    // Accent (ligeiramente mais claro)
    const [h, s, l] = selectedColor.hsl.split(' ');
    const lighterL = Math.min(parseInt(l) + 5, 60);
    const accentHsl = `${h} ${s} ${lighterL}%`;
    root.style.setProperty('--accent', accentHsl);
    
    // Salvar no localStorage
    localStorage.setItem(STORAGE_KEY, JSON.stringify(selectedColor));
  }, [selectedColor]);

  const setPrimaryColor = (color: ColorOption) => {
    setSelectedColor(color);
  };

  return {
    selectedColor,
    setPrimaryColor,
    colorOptions,
  };
}
