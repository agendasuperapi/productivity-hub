import { useCallback, useRef, useEffect } from 'react';
import { supabaseWithDevice as supabase } from '@/lib/supabaseClient';

// Armazena contadores locais pendentes de sincronização
const pendingCounts: Map<string, number> = new Map();
const SYNC_THRESHOLD = 10; // Sincronizar quando atingir 10 usos
const SYNC_INTERVAL = 30000; // Ou sincronizar a cada 30 segundos

export function useShortcutUsage() {
  const syncTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Sincroniza todos os contadores pendentes com o banco
  const syncToDatabase = useCallback(async () => {
    if (pendingCounts.size === 0) return;

    const updates = Array.from(pendingCounts.entries());
    pendingCounts.clear();

    // Atualiza em background sem bloquear a UI
    for (const [shortcutId, count] of updates) {
      try {
        // @ts-ignore - função RPC criada dinamicamente
        await supabase.rpc('increment_shortcut_use_count', {
          shortcut_id: shortcutId,
          increment_by: count
        });
      } catch (error) {
        // Se falhar, restaura o contador para tentar novamente depois
        const current = pendingCounts.get(shortcutId) || 0;
        pendingCounts.set(shortcutId, current + count);
        console.error('Erro ao sincronizar uso do atalho:', error);
      }
    }
  }, []);

  // Incrementa o uso de um atalho
  const incrementUsage = useCallback((shortcutId: string) => {
    const currentCount = (pendingCounts.get(shortcutId) || 0) + 1;
    pendingCounts.set(shortcutId, currentCount);

    // Se atingiu o threshold, sincroniza imediatamente
    if (currentCount >= SYNC_THRESHOLD) {
      syncToDatabase();
    }
  }, [syncToDatabase]);

  // Configura sincronização periódica
  useEffect(() => {
    syncTimeoutRef.current = setInterval(() => {
      syncToDatabase();
    }, SYNC_INTERVAL);

    // Sincroniza ao desmontar ou ao fechar a página
    const handleBeforeUnload = () => {
      if (pendingCounts.size > 0) {
        // Usa sendBeacon para garantir que os dados sejam enviados
        const updates = Array.from(pendingCounts.entries());
        pendingCounts.clear();
        
        // Tenta sincronizar de forma síncrona antes de fechar
        updates.forEach(([shortcutId, count]) => {
          navigator.sendBeacon(
            `${import.meta.env.VITE_SUPABASE_URL}/rest/v1/rpc/increment_shortcut_use_count`,
            JSON.stringify({
              shortcut_id: shortcutId,
              increment_by: count
            })
          );
        });
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);

    return () => {
      if (syncTimeoutRef.current) {
        clearInterval(syncTimeoutRef.current);
      }
      window.removeEventListener('beforeunload', handleBeforeUnload);
      // Sincroniza ao desmontar o componente
      syncToDatabase();
    };
  }, [syncToDatabase]);

  return { incrementUsage, syncToDatabase };
}
