import { useState, useEffect, createContext, useContext, ReactNode, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { User } from '@supabase/supabase-js';
import { backgroundOptions, BackgroundOption } from '@/hooks/usePrimaryColor';

type Theme = 'dark' | 'light';

interface ThemeContextType {
  theme: Theme;
  toggleTheme: () => void;
  setTheme: (theme: Theme) => void;
  isLoading: boolean;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

const BACKGROUND_STORAGE_KEY = 'background-color';

// Encontrar background equivalente no outro modo
function findEquivalentBackground(current: BackgroundOption, targetIsLight: boolean): BackgroundOption {
  const currentIndex = backgroundOptions.findIndex(bg => bg.name === current.name);
  
  // Se já está no modo correto, retornar atual
  if (current.isLight === targetIsLight) return current;
  
  // Encontrar equivalente baseado no nome ou posição
  const darkBgs = backgroundOptions.filter(bg => !bg.isLight);
  const lightBgs = backgroundOptions.filter(bg => bg.isLight);
  
  if (targetIsLight) {
    // Indo para claro: encontrar equivalente ou primeiro claro
    const darkIndex = darkBgs.findIndex(bg => bg.name === current.name);
    return lightBgs[darkIndex] || lightBgs[0];
  } else {
    // Indo para escuro: encontrar equivalente ou primeiro escuro
    const lightIndex = lightBgs.findIndex(bg => bg.name === current.name);
    return darkBgs[lightIndex] || darkBgs[0];
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

  // Salvar tema no banco e alternar background
  const saveThemeAndBackground = useCallback(async (newTheme: Theme) => {
    // Alternar background para corresponder ao tema
    const bgSaved = localStorage.getItem(BACKGROUND_STORAGE_KEY);
    if (bgSaved) {
      try {
        const currentBg = JSON.parse(bgSaved) as BackgroundOption;
        const newBg = findEquivalentBackground(currentBg, newTheme === 'light');
        localStorage.setItem(BACKGROUND_STORAGE_KEY, JSON.stringify(newBg));
        
        // Disparar evento para usePrimaryColor reagir
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
