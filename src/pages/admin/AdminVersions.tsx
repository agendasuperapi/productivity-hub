import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { AdminLayout } from './AdminLayout';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Checkbox } from '@/components/ui/checkbox';
import { Loader2, Plus, X, Rocket, ExternalLink, CheckCircle2, Clock, AlertCircle, RefreshCw, Trash2, Apple, Monitor, Smartphone } from 'lucide-react';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { APP_VERSION } from '@/config/version';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';

interface AppVersion {
  id: string;
  version: string;
  description: string;
  changes: string[];
  status: string;
  created_by: string;
  created_at: string;
  deploy_started_at: string | null;
  deploy_completed_at: string | null;
  workflow_run_id: string | null;
}

export default function AdminVersions() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [versions, setVersions] = useState<AppVersion[]>([]);
  const [loading, setLoading] = useState(true);
  const [deploying, setDeploying] = useState(false);
  const [search, setSearch] = useState('');
  
  // Form state
  const [description, setDescription] = useState('');
  const [changes, setChanges] = useState<string[]>([]);
  const [newChange, setNewChange] = useState('');
  
  // Platform selection
  const [platforms, setPlatforms] = useState({
    macos: true,
    windows: true,
    apk: false,
  });
  
  // Dialog state
  const [deleteDialog, setDeleteDialog] = useState<{ open: boolean; version: AppVersion | null }>({ open: false, version: null });
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    fetchVersions();
    
    // Subscribe to realtime updates
    const channel = supabase
      .channel('app_versions_changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'app_versions' },
        () => {
          fetchVersions();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const fetchVersions = async () => {
    try {
      const { data, error } = await supabase
        .from('app_versions')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      
      // Parse changes from JSON
      const parsed = (data || []).map(v => ({
        ...v,
        changes: Array.isArray(v.changes) ? (v.changes as string[]) : []
      })) as AppVersion[];
      
      setVersions(parsed);
    } catch (err) {
      console.error('Error fetching versions:', err);
    } finally {
      setLoading(false);
    }
  };

  const addChange = () => {
    if (newChange.trim()) {
      setChanges([...changes, newChange.trim()]);
      setNewChange('');
    }
  };

  const removeChange = (index: number) => {
    setChanges(changes.filter((_, i) => i !== index));
  };

  const handleDeploy = async () => {
    if (!description.trim()) {
      toast.error('Preencha a descrição da versão');
      return;
    }

    if (changes.length === 0) {
      toast.error('Adicione pelo menos uma mudança');
      return;
    }

    // Check if at least one platform is selected
    if (!platforms.macos && !platforms.windows && !platforms.apk) {
      toast.error('Selecione pelo menos uma plataforma');
      return;
    }

    setDeploying(true);

    try {
      // Check if version already exists
      const existingVersion = versions.find(v => v.version === APP_VERSION);
      if (existingVersion) {
        toast.error(`Versão ${APP_VERSION} já existe. Atualize o arquivo version.ts`);
        setDeploying(false);
        return;
      }

      // Create version record
      const { data: versionData, error: insertError } = await supabase
        .from('app_versions')
        .insert({
          version: APP_VERSION,
          description: description.trim(),
          changes: changes,
          status: 'deploying',
          created_by: user?.id,
          deploy_started_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (insertError) throw insertError;

      // Trigger deploy via edge function
      const { data, error } = await supabase.functions.invoke('trigger-deploy', {
        body: {
          version: APP_VERSION,
          description: description.trim(),
          changes: changes,
          version_id: versionData.id,
          platforms: platforms,
        },
      });

      if (error) throw error;

      if (data?.success) {
        toast.success('Deploy iniciado com sucesso!');
        setDescription('');
        setChanges([]);
      } else {
        throw new Error(data?.error || 'Erro ao iniciar deploy');
      }
    } catch (err: any) {
      console.error('Deploy error:', err);
      toast.error(err.message || 'Erro ao iniciar deploy');
    } finally {
      setDeploying(false);
    }
  };

  const handleDelete = async () => {
    if (!deleteDialog.version) return;
    
    setDeleting(true);
    try {
      const { error } = await supabase
        .from('app_versions')
        .delete()
        .eq('id', deleteDialog.version.id);

      if (error) throw error;
      
      toast.success('Versão excluída com sucesso');
      setDeleteDialog({ open: false, version: null });
    } catch (err: any) {
      toast.error(err.message || 'Erro ao excluir versão');
    } finally {
      setDeleting(false);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'completed':
        return <Badge className="bg-green-500 hover:bg-green-600"><CheckCircle2 className="h-3 w-3 mr-1" /> Concluído</Badge>;
      case 'deploying':
        return <Badge className="bg-yellow-500 hover:bg-yellow-600"><Loader2 className="h-3 w-3 mr-1 animate-spin" /> Em andamento</Badge>;
      case 'failed':
        return <Badge variant="destructive"><AlertCircle className="h-3 w-3 mr-1" /> Falhou</Badge>;
      default:
        return <Badge variant="secondary"><Clock className="h-3 w-3 mr-1" /> Pendente</Badge>;
    }
  };

  const latestVersion = versions[0];
  const isUpToDate = latestVersion?.version === APP_VERSION && latestVersion?.status === 'completed';
  const hasPendingDeploy = latestVersion?.version === APP_VERSION && latestVersion?.status !== 'completed';

  const filteredVersions = versions.filter(v => 
    v.version.toLowerCase().includes(search.toLowerCase()) ||
    v.description.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <AdminLayout>
      <div className="container mx-auto px-4 py-6 space-y-6 overflow-y-auto max-h-[calc(100vh-4rem)]">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Versionamento</h1>
            <p className="text-muted-foreground">Gerencie as versões e deploys do sistema</p>
          </div>
          <Button variant="outline" onClick={() => navigate('/admin')}>
            Voltar
          </Button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Status Card */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <RefreshCw className="h-5 w-5" />
                Status da Versão
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center justify-between p-4 rounded-lg bg-muted/50">
                <div>
                  <p className="text-sm text-muted-foreground">Versão do Código</p>
                  <p className="text-2xl font-bold">v{APP_VERSION}</p>
                </div>
                <div className="text-right">
                  <p className="text-sm text-muted-foreground">Última Versão Deployada</p>
                  <p className="text-2xl font-bold">{latestVersion?.status === 'completed' ? `v${latestVersion.version}` : '-'}</p>
                </div>
              </div>
              
              {isUpToDate ? (
                <Alert className="border-green-500 bg-green-500/10">
                  <CheckCircle2 className="h-4 w-4 text-green-500" />
                  <AlertDescription className="text-green-700 dark:text-green-400">
                    Sistema atualizado! A versão em produção está sincronizada com o código.
                  </AlertDescription>
                </Alert>
              ) : hasPendingDeploy ? (
                <Alert className="border-yellow-500 bg-yellow-500/10">
                  <Loader2 className="h-4 w-4 text-yellow-500 animate-spin" />
                  <AlertDescription className="text-yellow-700 dark:text-yellow-400">
                    Deploy em andamento para v{APP_VERSION}...
                  </AlertDescription>
                </Alert>
              ) : (
                <Alert className="border-orange-500 bg-orange-500/10">
                  <AlertCircle className="h-4 w-4 text-orange-500" />
                  <AlertDescription className="text-orange-700 dark:text-orange-400">
                    Nova versão disponível! Preencha os dados e faça o deploy para v{APP_VERSION}.
                  </AlertDescription>
                </Alert>
              )}
            </CardContent>
          </Card>

          {/* Deploy Card */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Rocket className="h-5 w-5" />
                Nova Versão e Deploy
              </CardTitle>
              <CardDescription>
                Preencha os dados e faça o deploy para produção
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>Número da Versão</Label>
                <Input value={`v${APP_VERSION}`} disabled className="bg-muted" />
                <p className="text-xs text-muted-foreground">
                  Versão definida em src/config/version.ts
                </p>
              </div>

              <div className="space-y-2">
                <Label htmlFor="description">Descrição *</Label>
                <Textarea 
                  id="description"
                  placeholder="Descreva as principais mudanças desta versão..."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  rows={3}
                />
              </div>

              <div className="space-y-2">
                <Label>Lista de Mudanças *</Label>
                <div className="flex gap-2">
                  <Input 
                    placeholder="Digite uma mudança..."
                    value={newChange}
                    onChange={(e) => setNewChange(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), addChange())}
                  />
                  <Button type="button" onClick={addChange} size="icon">
                    <Plus className="h-4 w-4" />
                  </Button>
                </div>
                {changes.length > 0 && (
                  <ul className="space-y-1 mt-2">
                    {changes.map((change, index) => (
                      <li key={index} className="flex items-center gap-2 text-sm bg-muted/50 px-3 py-2 rounded-md">
                        <span className="flex-1">{change}</span>
                        <Button 
                          type="button" 
                          variant="ghost" 
                          size="icon" 
                          className="h-6 w-6"
                          onClick={() => removeChange(index)}
                        >
                          <X className="h-3 w-3" />
                        </Button>
                      </li>
                    ))}
                  </ul>
                )}
              </div>

              {/* Platform Selection */}
              <div className="space-y-3">
                <Label>Plataformas de Deploy</Label>
                <div className="grid grid-cols-3 gap-3">
                  <label className="flex items-center gap-2 p-3 rounded-lg border bg-card hover:bg-accent/50 cursor-pointer transition-colors">
                    <Checkbox
                      checked={platforms.macos}
                      onCheckedChange={(checked) => 
                        setPlatforms(prev => ({ ...prev, macos: checked as boolean }))
                      }
                    />
                    <Apple className="h-4 w-4" />
                    <span className="text-sm font-medium">macOS</span>
                  </label>
                  <label className="flex items-center gap-2 p-3 rounded-lg border bg-card hover:bg-accent/50 cursor-pointer transition-colors">
                    <Checkbox
                      checked={platforms.windows}
                      onCheckedChange={(checked) => 
                        setPlatforms(prev => ({ ...prev, windows: checked as boolean }))
                      }
                    />
                    <Monitor className="h-4 w-4" />
                    <span className="text-sm font-medium">Windows</span>
                  </label>
                  <label className="flex items-center gap-2 p-3 rounded-lg border bg-card hover:bg-accent/50 cursor-pointer transition-colors">
                    <Checkbox
                      checked={platforms.apk}
                      onCheckedChange={(checked) => 
                        setPlatforms(prev => ({ ...prev, apk: checked as boolean }))
                      }
                    />
                    <Smartphone className="h-4 w-4" />
                    <span className="text-sm font-medium">APK</span>
                  </label>
                </div>
              </div>

              <Alert>
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>
                  Certifique-se de fazer <strong>Publish/Update</strong> no Lovable antes de fazer o deploy.
                </AlertDescription>
              </Alert>

              <div className="flex gap-2">
                <Button 
                  variant="outline" 
                  className="flex-1"
                  onClick={() => window.open('https://github.com/agendasuperapi/productivity-hub/actions', '_blank')}
                >
                  <ExternalLink className="h-4 w-4 mr-2" />
                  Ver Actions
                </Button>
                <Button 
                  className="flex-1"
                  onClick={handleDeploy}
                  disabled={deploying || hasPendingDeploy}
                >
                  {deploying ? (
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  ) : (
                    <Rocket className="h-4 w-4 mr-2" />
                  )}
                  Deploy para Produção
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* History Card */}
        <Card>
          <CardHeader>
            <CardTitle>Histórico de Versões</CardTitle>
            <CardDescription>
              <div className="flex items-center gap-2 mt-2">
                <Input 
                  placeholder="Buscar por versão ou descrição..." 
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="max-w-sm"
                />
              </div>
            </CardDescription>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="flex items-center justify-center py-8">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Versão</TableHead>
                    <TableHead>Descrição</TableHead>
                    <TableHead>Mudanças</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Data</TableHead>
                    <TableHead className="text-right">Ações</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredVersions.map(version => (
                    <TableRow key={version.id}>
                      <TableCell className="font-mono font-bold">v{version.version}</TableCell>
                      <TableCell className="max-w-[200px] truncate">{version.description}</TableCell>
                      <TableCell>
                        <ul className="text-xs space-y-0.5 max-w-[200px]">
                          {version.changes.slice(0, 2).map((c, i) => (
                            <li key={i} className="truncate">• {c}</li>
                          ))}
                          {version.changes.length > 2 && (
                            <li className="text-muted-foreground">+{version.changes.length - 2} mais</li>
                          )}
                        </ul>
                      </TableCell>
                      <TableCell>{getStatusBadge(version.status)}</TableCell>
                      <TableCell>
                        <div className="text-sm">
                          <p>{format(new Date(version.created_at), "dd/MM/yyyy HH:mm", { locale: ptBR })}</p>
                          {version.deploy_completed_at && (
                            <p className="text-xs text-muted-foreground">
                              Deploy: {format(new Date(version.deploy_completed_at), "dd/MM HH:mm", { locale: ptBR })}
                            </p>
                          )}
                        </div>
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex items-center justify-end gap-1">
                          {version.workflow_run_id && (
                            <Button 
                              variant="ghost" 
                              size="icon"
                              onClick={() => window.open(`https://github.com/agendasuperapi/productivity-hub/actions/runs/${version.workflow_run_id}`, '_blank')}
                            >
                              <ExternalLink className="h-4 w-4" />
                            </Button>
                          )}
                          <Button 
                            variant="ghost" 
                            size="icon"
                            className="text-destructive hover:text-destructive"
                            onClick={() => setDeleteDialog({ open: true, version })}
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                  {filteredVersions.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={6} className="text-center text-muted-foreground py-8">
                        Nenhuma versão encontrada
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Delete Dialog */}
      <Dialog open={deleteDialog.open} onOpenChange={(open) => setDeleteDialog({ open, version: null })}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Excluir Versão</DialogTitle>
            <DialogDescription>
              Tem certeza que deseja excluir a versão <strong>v{deleteDialog.version?.version}</strong>? Esta ação não pode ser desfeita.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialog({ open: false, version: null })}>
              Cancelar
            </Button>
            <Button variant="destructive" onClick={handleDelete} disabled={deleting}>
              {deleting ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Excluir'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </AdminLayout>
  );
}
