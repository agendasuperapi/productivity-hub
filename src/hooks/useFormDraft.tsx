import { useState, useEffect, useCallback, useRef } from 'react';

const DRAFT_STORAGE_KEY = 'lovable_form_drafts';

interface DraftData {
  [key: string]: {
    data: { [key: string]: unknown };
    savedAt: number;
  };
}

/**
 * Hook para auto-save de formulários
 * Salva rascunhos no localStorage enquanto o usuário preenche
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function useFormDraft<T extends Record<string, any>>(
  formId: string,
  initialValues: T,
  debounceMs: number = 500
) {
  const [values, setValues] = useState<T>(initialValues);
  const [hasDraft, setHasDraft] = useState(false);
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);
  const isInitializedRef = useRef(false);

  // Carregar rascunho ao iniciar
  useEffect(() => {
    if (isInitializedRef.current) return;
    isInitializedRef.current = true;

    try {
      const stored = localStorage.getItem(DRAFT_STORAGE_KEY);
      if (stored) {
        const drafts: DraftData = JSON.parse(stored);
        const draft = drafts[formId];
        if (draft) {
          // Verificar se o rascunho não é muito antigo (24h)
          const maxAge = 24 * 60 * 60 * 1000;
          if (Date.now() - draft.savedAt < maxAge) {
            setValues(draft.data as T);
            setHasDraft(true);
          } else {
            // Limpar rascunho antigo
            delete drafts[formId];
            localStorage.setItem(DRAFT_STORAGE_KEY, JSON.stringify(drafts));
          }
        }
      }
    } catch (error) {
      console.error('[useFormDraft] Error loading draft:', error);
    }
  }, [formId]);

  // Salvar rascunho com debounce
  const saveDraft = useCallback((newValues: T) => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }

    timeoutRef.current = setTimeout(() => {
      try {
        const stored = localStorage.getItem(DRAFT_STORAGE_KEY);
        const drafts: DraftData = stored ? JSON.parse(stored) : {};
        
        drafts[formId] = {
          data: newValues,
          savedAt: Date.now(),
        };
        
        localStorage.setItem(DRAFT_STORAGE_KEY, JSON.stringify(drafts));
        setHasDraft(true);
        console.log(`[useFormDraft] Draft saved for ${formId}`);
      } catch (error) {
        console.error('[useFormDraft] Error saving draft:', error);
      }
    }, debounceMs);
  }, [formId, debounceMs]);

  // Atualizar valor e salvar rascunho
  const updateValue = useCallback(<K extends keyof T>(key: K, value: T[K]) => {
    setValues(prev => {
      const newValues = { ...prev, [key]: value };
      saveDraft(newValues);
      return newValues;
    });
  }, [saveDraft]);

  // Atualizar múltiplos valores de uma vez
  const updateValues = useCallback((updates: Partial<T>) => {
    setValues(prev => {
      const newValues = { ...prev, ...updates };
      saveDraft(newValues);
      return newValues;
    });
  }, [saveDraft]);

  // Limpar rascunho (após salvar com sucesso ou ao cancelar)
  const clearDraft = useCallback(() => {
    try {
      const stored = localStorage.getItem(DRAFT_STORAGE_KEY);
      if (stored) {
        const drafts: DraftData = JSON.parse(stored);
        delete drafts[formId];
        localStorage.setItem(DRAFT_STORAGE_KEY, JSON.stringify(drafts));
      }
      setHasDraft(false);
      console.log(`[useFormDraft] Draft cleared for ${formId}`);
    } catch (error) {
      console.error('[useFormDraft] Error clearing draft:', error);
    }

    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }
  }, [formId]);

  // Resetar para valores iniciais
  const resetToInitial = useCallback(() => {
    setValues(initialValues);
    clearDraft();
    isInitializedRef.current = true; // Evitar recarregar rascunho
  }, [initialValues, clearDraft]);

  // Carregar valores específicos (para edição)
  const loadValues = useCallback((newValues: T) => {
    setValues(newValues);
    // Não limpa o rascunho automaticamente - o rascunho será sobrescrito se o usuário editar
  }, []);

  // Cleanup ao desmontar
  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  return {
    values,
    setValues,
    updateValue,
    updateValues,
    hasDraft,
    clearDraft,
    resetToInitial,
    loadValues,
  };
}
