import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { Clipboard, Globe, Plus, Trash2, Loader2 } from 'lucide-react';

interface ClipboardDomain {
  id: string;
  domain: string;
}

export function ClipboardDomainsConfig() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [domains, setDomains] = useState<ClipboardDomain[]>([]);
  const [loading, setLoading] = useState(true);
  const [adding, setAdding] = useState(false);
  const [newDomain, setNewDomain] = useState('');

  // Carregar domínios do usuário
  useEffect(() => {
    if (!user) return;
    
    async function loadDomains() {
      const { data, error } = await supabase
        .from('clipboard_domains')
        .select('id, domain')
        .eq('user_id', user.id)
        .order('created_at', { ascending: true });
      
      if (error) {
        console.error('Erro ao carregar domínios:', error);
        toast({ title: 'Erro ao carregar domínios', variant: 'destructive' });
      } else {
        // Se não tem domínios, adicionar WhatsApp como padrão
        if (data && data.length === 0) {
          await addDefaultDomains();
        } else {
          setDomains(data || []);
        }
      }
      setLoading(false);
    }
    
    loadDomains();
  }, [user]);

  async function addDefaultDomains() {
    if (!user) return;
    
    const defaultDomains = ['whatsapp.com'];
    
    for (const domain of defaultDomains) {
      const { data, error } = await supabase
        .from('clipboard_domains')
        .insert({ user_id: user.id, domain })
        .select('id, domain')
        .single();
      
      if (!error && data) {
        setDomains(prev => [...prev, data]);
      }
    }
  }

  async function addDomain() {
    if (!user || !newDomain.trim()) return;
    
    // Limpar domínio (remover http://, https://, www., e trailing slashes)
    let cleanDomain = newDomain.trim()
      .replace(/^https?:\/\//, '')
      .replace(/^www\./, '')
      .replace(/\/.*$/, '')
      .toLowerCase();
    
    if (!cleanDomain) {
      toast({ title: 'Domínio inválido', variant: 'destructive' });
      return;
    }
    
    // Verificar se já existe
    if (domains.some(d => d.domain === cleanDomain)) {
      toast({ title: 'Domínio já adicionado', variant: 'destructive' });
      return;
    }
    
    setAdding(true);
    
    const { data, error } = await supabase
      .from('clipboard_domains')
      .insert({ user_id: user.id, domain: cleanDomain })
      .select('id, domain')
      .single();
    
    if (error) {
      console.error('Erro ao adicionar domínio:', error);
      toast({ title: 'Erro ao adicionar domínio', variant: 'destructive' });
    } else if (data) {
      setDomains(prev => [...prev, data]);
      setNewDomain('');
      toast({ title: 'Domínio adicionado!' });
    }
    
    setAdding(false);
  }

  async function removeDomain(id: string) {
    const { error } = await supabase
      .from('clipboard_domains')
      .delete()
      .eq('id', id);
    
    if (error) {
      console.error('Erro ao remover domínio:', error);
      toast({ title: 'Erro ao remover domínio', variant: 'destructive' });
    } else {
      setDomains(prev => prev.filter(d => d.id !== id));
      toast({ title: 'Domínio removido!' });
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addDomain();
    }
  };

  if (loading) {
    return (
      <Card>
        <CardContent className="flex items-center justify-center py-8">
          <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Clipboard className="h-5 w-5" />
          Modo Clipboard Manual
        </CardTitle>
        <CardDescription>
          Nesses sites, o atalho será copiado para o clipboard. Pressione Ctrl+V para colar.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Lista de domínios */}
        <div className="space-y-2">
          {domains.length === 0 ? (
            <p className="text-sm text-muted-foreground py-4 text-center">
              Nenhum domínio configurado. Adicione um abaixo.
            </p>
          ) : (
            domains.map((domain) => (
              <div 
                key={domain.id}
                className="flex items-center gap-3 p-3 rounded-lg bg-muted/50 border border-border/50"
              >
                <Globe className="h-4 w-4 text-muted-foreground shrink-0" />
                <span className="flex-1 font-mono text-sm">{domain.domain}</span>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8 text-muted-foreground hover:text-destructive"
                  onClick={() => removeDomain(domain.id)}
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            ))
          )}
        </div>

        {/* Adicionar novo domínio */}
        <div className="flex gap-2">
          <Input
            placeholder="Ex: telegram.org, messenger.com"
            value={newDomain}
            onChange={(e) => setNewDomain(e.target.value)}
            onKeyDown={handleKeyDown}
            className="flex-1"
          />
          <Button 
            onClick={addDomain} 
            disabled={adding || !newDomain.trim()}
          >
            {adding ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Plus className="h-4 w-4 mr-1" />
            )}
            Adicionar
          </Button>
        </div>

        <p className="text-xs text-muted-foreground">
          Útil para sites que bloqueiam substituição automática de texto (WhatsApp, Telegram, etc).
        </p>
      </CardContent>
    </Card>
  );
}
