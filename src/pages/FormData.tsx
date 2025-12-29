import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { useElectron, ElectronAPI } from '@/hooks/useElectron';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Badge } from '@/components/ui/badge';
import { 
  Loader2, 
  Trash2, 
  Globe, 
  ArrowLeft,
  FileText
} from 'lucide-react';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';

interface DomainData {
  domain: string;
  valueCount: number;
}

export default function FormData() {
  const navigate = useNavigate();
  const { user, loading: authLoading } = useAuth();
  const { isElectron } = useElectron();
  
  const [domains, setDomains] = useState<DomainData[]>([]);
  const [deleteDomain, setDeleteDomain] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!authLoading && !user) {
      navigate('/auth');
    }
  }, [user, authLoading, navigate]);

  useEffect(() => {
    if (isElectron) {
      loadData();
    } else {
      setIsLoading(false);
    }
  }, [user, isElectron]);

  const loadData = async () => {
    const api = window.electronAPI as ElectronAPI | undefined;
    if (!api?.getFormFieldDomains) {
      setIsLoading(false);
      return;
    }
    
    setIsLoading(true);
    try {
      const data = await api.getFormFieldDomains();
      setDomains(data);
    } catch (error) {
      console.error('Erro ao carregar domínios:', error);
    }
    setIsLoading(false);
  };

  const handleDelete = async () => {
    const api = window.electronAPI as ElectronAPI | undefined;
    if (!deleteDomain || !api?.clearFormFieldsForDomain) return;
    
    try {
      await api.clearFormFieldsForDomain(deleteDomain);
      await loadData();
    } catch (error) {
      console.error('Erro ao limpar dados:', error);
    }
    setDeleteDomain(null);
  };

  const totalValues = domains.reduce((acc, d) => acc + d.valueCount, 0);

  if (authLoading || isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-background">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  if (!isElectron) {
    return (
      <div className="min-h-screen bg-background">
        <div className="container mx-auto p-6 max-w-4xl">
          <div className="flex items-center gap-4 mb-6">
            <Button variant="ghost" size="icon" onClick={() => navigate(-1)}>
              <ArrowLeft className="h-5 w-5" />
            </Button>
            <div>
              <h1 className="text-2xl font-bold">Dados de Formulários</h1>
              <p className="text-muted-foreground">
                Disponível apenas no aplicativo desktop
              </p>
            </div>
          </div>
          <Card>
            <CardContent className="p-12 text-center">
              <FileText className="h-12 w-12 mx-auto text-muted-foreground/50 mb-4" />
              <h3 className="font-medium mb-2">Recurso exclusivo do desktop</h3>
              <p className="text-sm text-muted-foreground">
                Os dados de formulários são armazenados localmente no aplicativo Electron.
              </p>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="container mx-auto p-6 max-w-4xl">
        {/* Header */}
        <div className="flex items-center gap-4 mb-6">
          <Button variant="ghost" size="icon" onClick={() => navigate(-1)}>
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div>
            <h1 className="text-2xl font-bold">Dados de Formulários</h1>
            <p className="text-muted-foreground">
              Sugestões salvas localmente para auto-preenchimento
            </p>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/10">
                <Globe className="h-5 w-5 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-bold">{domains.length}</p>
                <p className="text-sm text-muted-foreground">Sites</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/10">
                <FileText className="h-5 w-5 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-bold">{totalValues}</p>
                <p className="text-sm text-muted-foreground">Valores salvos</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Content */}
        {domains.length === 0 ? (
          <Card>
            <CardContent className="p-12 text-center">
              <FileText className="h-12 w-12 mx-auto text-muted-foreground/50 mb-4" />
              <h3 className="font-medium mb-2">Nenhum dado salvo</h3>
              <p className="text-sm text-muted-foreground">
                Os valores dos formulários serão salvos automaticamente quando você preencher campos no navegador.
              </p>
            </CardContent>
          </Card>
        ) : (
          <ScrollArea className="h-[calc(100vh-350px)]">
            <div className="space-y-2">
              {domains.map((item) => (
                <Card key={item.domain}>
                  <CardContent className="p-4 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <Globe className="h-4 w-4 text-primary" />
                      <span className="font-medium">{item.domain}</span>
                    </div>
                    <div className="flex items-center gap-3">
                      <Badge variant="secondary">{item.valueCount} valores</Badge>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8 text-destructive hover:text-destructive"
                        onClick={() => setDeleteDomain(item.domain)}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </ScrollArea>
        )}
      </div>

      {/* Delete Dialog */}
      <AlertDialog open={!!deleteDomain} onOpenChange={() => setDeleteDomain(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Limpar dados do site</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja excluir todos os dados salvos para <strong>{deleteDomain}</strong>? Esta ação não pode ser desfeita.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={handleDelete} className="bg-destructive text-destructive-foreground">
              Limpar Dados
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
