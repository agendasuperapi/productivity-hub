import { useState, useEffect, createContext, useContext, ReactNode, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';

type Theme = 'dark' | 'light';

interface ThemeContextType {
  theme: Theme;
  toggleTheme: () => void;
  setTheme: (theme: Theme) => void;
  isLoading: boolean;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [theme, setThemeState] = useState<Theme>(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('app-theme') as Theme;
      return saved || 'dark';
    }
    return 'dark';
  });
  const [isLoading, setIsLoading] = useState(false);

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
          .select('theme_preference')
          .eq('user_id', user.id)
          .maybeSingle();

        if (!error && data?.theme_preference) {
          const dbTheme = data.theme_preference as Theme;
          setThemeState(dbTheme);
          applyTheme(dbTheme);
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

  // Salvar tema no banco
  const saveThemeToDB = useCallback(async (newTheme: Theme) => {
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
    saveThemeToDB(newTheme);
  }, [theme, saveThemeToDB]);

  const setTheme = useCallback((newTheme: Theme) => {
    setThemeState(newTheme);
    saveThemeToDB(newTheme);
  }, [saveThemeToDB]);

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
