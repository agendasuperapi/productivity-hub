import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { User } from '@supabase/supabase-js';

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
  // Cores principais - paleta expandida
  { name: 'Teal', hsl: '177 100% 33%', hex: '#00a6a6' },
  { name: 'Ciano', hsl: '190 90% 45%', hex: '#17a2b8' },
  { name: 'Azul Claro', hsl: '195 100% 50%', hex: '#00bfff' },
  { name: 'Azul', hsl: '210 100% 50%', hex: '#0080ff' },
  { name: 'Azul Royal', hsl: '225 85% 55%', hex: '#4169e1' },
  { name: 'Índigo', hsl: '245 75% 55%', hex: '#5c4cd9' },
  { name: 'Roxo', hsl: '270 70% 50%', hex: '#8033cc' },
  { name: 'Violeta', hsl: '285 75% 55%', hex: '#a855f7' },
  { name: 'Magenta', hsl: '300 80% 50%', hex: '#e600e6' },
  { name: 'Rosa', hsl: '330 80% 55%', hex: '#e91e8c' },
  { name: 'Rosa Claro', hsl: '350 90% 65%', hex: '#f472b6' },
  { name: 'Vermelho', hsl: '0 75% 55%', hex: '#d94040' },
  { name: 'Coral', hsl: '15 90% 60%', hex: '#f97316' },
  { name: 'Laranja', hsl: '25 95% 53%', hex: '#f39c12' },
  { name: 'Âmbar', hsl: '40 95% 50%', hex: '#f59e0b' },
  { name: 'Amarelo', hsl: '50 95% 50%', hex: '#eab308' },
  { name: 'Lima', hsl: '75 80% 45%', hex: '#84cc16' },
  { name: 'Verde Claro', hsl: '120 60% 50%', hex: '#22c55e' },
  { name: 'Verde', hsl: '142 70% 40%', hex: '#27ae60' },
  { name: 'Esmeralda', hsl: '160 70% 40%', hex: '#10b981' },
];

// Gerar variações de uma cor (gradiente) - sempre inclui tons claros e escuros
export function generateColorShades(baseHsl: string): ColorShade[] {
  const [h, s] = baseHsl.split(' ');
  const hue = parseInt(h);
  const saturation = parseInt(s);
  
  // Gerar 14 variações de 10% a 95% de luminosidade para maior range
  const shades: ColorShade[] = [];
  const lightnessValues = [10, 18, 25, 32, 40, 48, 55, 62, 70, 78, 85, 90, 95];
  
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
  // Escuros - paleta expandida
  { name: 'Teal', background: '180 50% 10%', card: '180 45% 14%', hex: '#0d2626' },
  { name: 'Preto', background: '0 0% 6%', card: '0 0% 10%', hex: '#0f0f0f' },
  { name: 'Cinza', background: '240 10% 12%', card: '240 10% 16%', hex: '#1c1c22' },
  { name: 'Slate', background: '215 25% 14%', card: '215 22% 18%', hex: '#1e293b' },
  { name: 'Azul', background: '230 50% 12%', card: '230 45% 16%', hex: '#101830' },
  { name: 'Índigo', background: '245 45% 14%', card: '245 40% 18%', hex: '#1e1b4b' },
  { name: 'Roxo', background: '280 40% 12%', card: '280 35% 16%', hex: '#1f1229' },
  { name: 'Rosa Escuro', background: '330 35% 12%', card: '330 30% 16%', hex: '#2d1f29' },
  { name: 'Verde', background: '140 40% 10%', card: '140 35% 14%', hex: '#0f261a' },
  { name: 'Esmeralda', background: '160 40% 10%', card: '160 35% 14%', hex: '#0d2620' },
  { name: 'Vermelho', background: '0 40% 12%', card: '0 35% 16%', hex: '#2b1212' },
  { name: 'Marrom', background: '30 40% 12%', card: '30 35% 16%', hex: '#2b1f12' },
  // Claros - paleta expandida
  { name: 'Branco', background: '0 0% 98%', card: '0 0% 100%', hex: '#fafafa', isLight: true },
  { name: 'Cinza Claro', background: '220 20% 94%', card: '220 20% 98%', hex: '#ebeef5', isLight: true },
  { name: 'Slate Claro', background: '215 25% 95%', card: '215 25% 98%', hex: '#f1f5f9', isLight: true },
  { name: 'Creme', background: '45 50% 94%', card: '45 50% 98%', hex: '#f7f3e8', isLight: true },
  { name: 'Azul Claro', background: '210 60% 94%', card: '210 60% 98%', hex: '#e5f0fc', isLight: true },
  { name: 'Ciano Claro', background: '185 50% 94%', card: '185 50% 98%', hex: '#e5f7f7', isLight: true },
  { name: 'Verde Claro', background: '140 50% 94%', card: '140 50% 98%', hex: '#e5f7ed', isLight: true },
  { name: 'Lima Claro', background: '80 50% 94%', card: '80 50% 98%', hex: '#f0f7e5', isLight: true },
  { name: 'Amarelo Claro', background: '50 60% 94%', card: '50 60% 98%', hex: '#fef9e5', isLight: true },
  { name: 'Rosa Claro', background: '330 50% 95%', card: '330 50% 98%', hex: '#f7e5ef', isLight: true },
  { name: 'Lavanda', background: '260 40% 95%', card: '260 40% 98%', hex: '#efe8f7', isLight: true },
  { name: 'Pêssego', background: '20 60% 94%', card: '20 60% 98%', hex: '#fceee5', isLight: true },
];

// Gerar variações de fundo (gradiente de luminosidade) - expandido para mais opções
export function generateBackgroundShades(baseBg: BackgroundOption): BackgroundOption[] {
  const [h, s] = baseBg.background.split(' ');
  const hue = parseInt(h);
  const saturation = parseInt(s);
  const isLight = baseBg.isLight;
  
  const shades: BackgroundOption[] = [];
  
  if (isLight) {
    // Para modo claro: de 85% a 100% - mais opções
    const lightnessValues = [85, 88, 90, 92, 94, 96, 97, 98, 99, 100];
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
    // Para modo escuro: de 3% a 25% - inclui tons mais claros!
    const lightnessValues = [3, 5, 7, 9, 11, 14, 17, 20, 23, 26];
    for (const l of lightnessValues) {
      const cardL = l + 4;
      // Tons acima de 20% viram "claros" no modo escuro
      const becomesLight = l > 22;
      shades.push({
        name: `${baseBg.name} ${l}%`,
        background: `${hue} ${saturation}% ${l}%`,
        card: `${hue} ${saturation}% ${cardL}%`,
        hex: hslToHex(hue, saturation, l),
        isLight: becomesLight
      });
    }
  }
  
  return shades;
}

const PRIMARY_STORAGE_KEY = 'primary-color';
const BACKGROUND_STORAGE_KEY = 'background-color';

export function usePrimaryColor() {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
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

  // Obter usuário atual
  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_, session) => {
        setUser(session?.user ?? null);
      }
    );

    return () => subscription.unsubscribe();
  }, []);

  // Carregar preferências do banco de dados
  useEffect(() => {
    async function loadFromDatabase() {
      if (!user) {
        setIsLoading(false);
        return;
      }

      const { data } = await supabase
        .from('profiles')
        .select('primary_color, background_color')
        .eq('user_id', user.id)
        .maybeSingle();

      if (data) {
        if (data.primary_color) {
          const color = data.primary_color as unknown as ColorOption;
          setSelectedColor(color);
          localStorage.setItem(PRIMARY_STORAGE_KEY, JSON.stringify(color));
        }
        if (data.background_color) {
          const bg = data.background_color as unknown as BackgroundOption;
          setSelectedBackground(bg);
          localStorage.setItem(BACKGROUND_STORAGE_KEY, JSON.stringify(bg));
        }
      }
      setIsLoading(false);
    }

    loadFromDatabase();
  }, [user]);

  // Salvar no banco de dados
  const saveToDatabase = useCallback(async (primaryColor?: ColorOption, bgColor?: BackgroundOption) => {
    if (!user) return;

    const updates: Record<string, unknown> = {};
    if (primaryColor) updates.primary_color = primaryColor;
    if (bgColor) updates.background_color = bgColor;

    await supabase
      .from('profiles')
      .update(updates)
      .eq('user_id', user.id);
  }, [user]);

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

  // Escutar mudanças de tema
  useEffect(() => {
    const handleThemeChange = (event: CustomEvent<{ background: BackgroundOption }>) => {
      const newBg = event.detail.background;
      setSelectedBackground(newBg);
    };

    window.addEventListener('theme-changed', handleThemeChange as EventListener);
    return () => window.removeEventListener('theme-changed', handleThemeChange as EventListener);
  }, []);

  const setPrimaryColor = useCallback((color: ColorOption) => {
    setSelectedColor(color);
    saveToDatabase(color, undefined);
  }, [saveToDatabase]);

  const setBackgroundColor = useCallback((bg: BackgroundOption) => {
    setSelectedBackground(bg);
    saveToDatabase(undefined, bg);
  }, [saveToDatabase]);

  const resetToDefaults = useCallback(() => {
    const defaultColor = colorOptions[0];
    const defaultBackground = backgroundOptions[0];
    
    setSelectedColor(defaultColor);
    setSelectedBackground(defaultBackground);
    
    localStorage.setItem(PRIMARY_STORAGE_KEY, JSON.stringify(defaultColor));
    localStorage.setItem(BACKGROUND_STORAGE_KEY, JSON.stringify(defaultBackground));
    
    saveToDatabase(defaultColor, defaultBackground);
  }, [saveToDatabase]);

  return {
    selectedColor,
    setPrimaryColor,
    colorOptions,
    selectedBackground,
    setBackgroundColor,
    backgroundOptions,
    isLoading,
    resetToDefaults,
  };
}
