import { useState, useEffect, createContext, useContext, ReactNode, useCallback } from 'react';
import { supabaseWithDevice as supabase } from '@/lib/supabaseClient';
import { User } from '@supabase/supabase-js';

type Theme = 'dark' | 'light';

interface ThemeContextType {
  theme: Theme;
  toggleTheme: () => void;
  setTheme: (theme: Theme) => void;
  isLoading: boolean;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

const BACKGROUND_STORAGE_KEY = 'background-color';

// Interface local para evitar dependência circular
interface BackgroundOption {
  name: string;
  background: string;
  card: string;
  hex: string;
  isLight?: boolean;
}

// Opções de fundo locais para mapeamento de tema
const darkBackgrounds: BackgroundOption[] = [
  { name: 'Teal', background: '180 50% 10%', card: '180 45% 14%', hex: '#0d2626' },
  { name: 'Preto', background: '0 0% 6%', card: '0 0% 10%', hex: '#0f0f0f' },
  { name: 'Cinza', background: '240 10% 12%', card: '240 10% 16%', hex: '#1c1c22' },
  { name: 'Azul', background: '230 50% 12%', card: '230 45% 16%', hex: '#101830' },
  { name: 'Roxo', background: '280 40% 12%', card: '280 35% 16%', hex: '#1f1229' },
  { name: 'Verde', background: '140 40% 10%', card: '140 35% 14%', hex: '#0f261a' },
  { name: 'Vermelho', background: '0 40% 12%', card: '0 35% 16%', hex: '#2b1212' },
  { name: 'Marrom', background: '30 40% 12%', card: '30 35% 16%', hex: '#2b1f12' },
];

const lightBackgrounds: BackgroundOption[] = [
  { name: 'Branco', background: '0 0% 98%', card: '0 0% 100%', hex: '#fafafa', isLight: true },
  { name: 'Cinza Claro', background: '220 20% 94%', card: '220 20% 98%', hex: '#ebeef5', isLight: true },
  { name: 'Creme', background: '45 50% 94%', card: '45 50% 98%', hex: '#f7f3e8', isLight: true },
  { name: 'Azul Claro', background: '210 60% 94%', card: '210 60% 98%', hex: '#e5f0fc', isLight: true },
  { name: 'Verde Claro', background: '140 50% 94%', card: '140 50% 98%', hex: '#e5f7ed', isLight: true },
  { name: 'Rosa Claro', background: '330 50% 95%', card: '330 50% 98%', hex: '#f7e5ef', isLight: true },
  { name: 'Lavanda', background: '260 40% 95%', card: '260 40% 98%', hex: '#efe8f7', isLight: true },
  { name: 'Pêssego', background: '20 60% 94%', card: '20 60% 98%', hex: '#fceee5', isLight: true },
];

// Encontrar background equivalente no outro modo
function findEquivalentBackground(current: BackgroundOption, targetIsLight: boolean): BackgroundOption {
  if (current.isLight === targetIsLight) return current;
  
  if (targetIsLight) {
    const darkIndex = darkBackgrounds.findIndex(bg => bg.name === current.name);
    return lightBackgrounds[darkIndex >= 0 ? darkIndex : 0] || lightBackgrounds[0];
  } else {
    const lightIndex = lightBackgrounds.findIndex(bg => bg.name === current.name);
    return darkBackgrounds[lightIndex >= 0 ? lightIndex : 0] || darkBackgrounds[0];
  }
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [theme, setThemeState] = useState<Theme>(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('app-theme') as Theme;
      if (saved) return saved;
      // Detectar baseado no background salvo
      const bgSaved = localStorage.getItem(BACKGROUND_STORAGE_KEY);
      if (bgSaved) {
        try {
          const bg = JSON.parse(bgSaved) as BackgroundOption;
          return bg.isLight ? 'light' : 'dark';
        } catch { /* ignore */ }
      }
      return 'dark';
    }
    return 'dark';
  });
  const [isLoading, setIsLoading] = useState(false);

  // Obter usuário
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

  // Aplicar tema no DOM
  const applyTheme = useCallback((newTheme: Theme) => {
    const root = document.documentElement;
    root.classList.remove('light', 'dark');
    root.classList.add(newTheme);
    localStorage.setItem('app-theme', newTheme);
  }, []);

  // Carregar tema do banco quando usuário logar
  useEffect(() => {
    if (!user) return;

    const loadThemeFromDB = async () => {
      setIsLoading(true);
      try {
        const { data, error } = await supabase
          .from('profiles')
          .select('theme_preference, background_color')
          .eq('user_id', user.id)
          .maybeSingle();

        if (!error && data) {
          if (data.theme_preference) {
            const dbTheme = data.theme_preference as Theme;
            setThemeState(dbTheme);
            applyTheme(dbTheme);
          } else if (data.background_color) {
            // Inferir tema do background
            const bg = data.background_color as unknown as BackgroundOption;
            const inferredTheme = bg.isLight ? 'light' : 'dark';
            setThemeState(inferredTheme);
            applyTheme(inferredTheme);
          }
        }
      } catch (err) {
        console.error('Erro ao carregar tema:', err);
      } finally {
        setIsLoading(false);
      }
    };

    loadThemeFromDB();
  }, [user, applyTheme]);

  // Aplicar tema no DOM quando mudar
  useEffect(() => {
    applyTheme(theme);
  }, [theme, applyTheme]);

  // Aplicar variáveis CSS de background diretamente
  const applyBackgroundCSS = useCallback((bg: BackgroundOption) => {
    const root = document.documentElement;
    
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
  }, []);

  // Salvar tema no banco e alternar background
  const saveThemeAndBackground = useCallback(async (newTheme: Theme) => {
    // Alternar background para corresponder ao tema
    const bgSaved = localStorage.getItem(BACKGROUND_STORAGE_KEY);
    if (bgSaved) {
      try {
        const currentBg = JSON.parse(bgSaved) as BackgroundOption;
        const newBg = findEquivalentBackground(currentBg, newTheme === 'light');
        localStorage.setItem(BACKGROUND_STORAGE_KEY, JSON.stringify(newBg));
        
        // Aplicar variáveis CSS imediatamente
        applyBackgroundCSS(newBg);
        
        // Disparar evento para usePrimaryColor sincronizar estado
        window.dispatchEvent(new CustomEvent('theme-changed', { detail: { background: newBg } }));
      } catch { /* ignore */ }
    }

    if (!user) return;

    try {
      const { error } = await supabase
        .from('profiles')
        .update({ theme_preference: newTheme })
        .eq('user_id', user.id);

      if (error) {
        console.error('Erro ao salvar tema:', error);
      }
    } catch (err) {
      console.error('Erro ao salvar tema:', err);
    }
  }, [user]);

  const toggleTheme = useCallback(() => {
    const newTheme = theme === 'dark' ? 'light' : 'dark';
    setThemeState(newTheme);
    saveThemeAndBackground(newTheme);
  }, [theme, saveThemeAndBackground]);

  const setTheme = useCallback((newTheme: Theme) => {
    setThemeState(newTheme);
    saveThemeAndBackground(newTheme);
  }, [saveThemeAndBackground]);

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme, setTheme, isLoading }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
}
