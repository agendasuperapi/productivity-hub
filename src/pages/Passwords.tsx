import { useState } from 'react';
import { AppLayout } from '@/components/layout/AppLayout';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { 
  Key, 
  Eye, 
  EyeOff, 
  Trash2, 
  Search,
  Globe,
  User,
  Shield,
  Loader2,
  Plus
} from 'lucide-react';
import { useCredentials, SavedCredential } from '@/hooks/useCredentials';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { toast } from 'sonner';

function CredentialRow({ credential, onDelete, onDecrypt }: { 
  credential: SavedCredential; 
  onDelete: (id: string) => void;
  onDecrypt: (credential: SavedCredential) => Promise<string>;
}) {
  const [showPassword, setShowPassword] = useState(false);
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleShowPassword = async () => {
    if (showPassword) {
      setShowPassword(false);
      setPassword('');
      return;
    }

    setLoading(true);
    try {
      const decrypted = await onDecrypt(credential);
      setPassword(decrypted);
      setShowPassword(true);
    } catch {
      toast.error('Erro ao descriptografar senha');
    } finally {
      setLoading(false);
    }
  };

  const handleCopyPassword = async () => {
    try {
      const decrypted = showPassword ? password : await onDecrypt(credential);
      await navigator.clipboard.writeText(decrypted);
      toast.success('Senha copiada');
    } catch {
      toast.error('Erro ao copiar senha');
    }
  };

  return (
    <div className="flex items-center justify-between p-4 rounded-lg border bg-card hover:bg-accent/50 transition-colors">
      <div className="flex items-center gap-4 flex-1 min-w-0">
        <div className="p-2 rounded-lg bg-primary/10 shrink-0">
          <Globe className="h-5 w-5 text-primary" />
        </div>
        <div className="flex-1 min-w-0">
          <p className="font-medium truncate">{credential.site_name || credential.domain}</p>
          <p className="text-sm text-muted-foreground truncate">{credential.domain}</p>
        </div>
        <div className="flex items-center gap-2 text-sm text-muted-foreground shrink-0">
          <User className="h-4 w-4" />
          <span className="max-w-[200px] truncate">{credential.username}</span>
        </div>
        <div className="flex items-center gap-2 shrink-0 min-w-[180px]">
          <div className="flex-1 font-mono text-sm">
            {showPassword ? (
              <span className="text-foreground">{password}</span>
            ) : (
              <span className="text-muted-foreground">••••••••</span>
            )}
          </div>
          <Button
            variant="ghost"
            size="icon"
            onClick={handleShowPassword}
            disabled={loading}
          >
            {loading ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : showPassword ? (
              <EyeOff className="h-4 w-4" />
            ) : (
              <Eye className="h-4 w-4" />
            )}
          </Button>
        </div>
      </div>
      <div className="flex items-center gap-2 ml-4 shrink-0">
        <Button
          variant="outline"
          size="sm"
          onClick={handleCopyPassword}
        >
          Copiar
        </Button>
        <AlertDialog>
          <AlertDialogTrigger asChild>
            <Button variant="ghost" size="icon" className="text-destructive hover:text-destructive">
              <Trash2 className="h-4 w-4" />
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Remover credencial?</AlertDialogTitle>
              <AlertDialogDescription>
                Esta ação não pode ser desfeita. A credencial para "{credential.domain}" será removida permanentemente.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancelar</AlertDialogCancel>
              <AlertDialogAction
                onClick={() => onDelete(credential.id)}
                className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              >
                Remover
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </div>
    </div>
  );
}

function AddCredentialDialog({ onSave }: { onSave: (domain: string, username: string, password: string, siteName?: string) => Promise<boolean> }) {
  const [open, setOpen] = useState(false);
  const [domain, setDomain] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [siteName, setSiteName] = useState('');
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    if (!domain || !username || !password) {
      toast.error('Preencha todos os campos obrigatórios');
      return;
    }

    setSaving(true);
    try {
      // Normalize domain to URL if needed
      const url = domain.includes('://') ? domain : `https://${domain}`;
      const success = await onSave(url, username, password, siteName || undefined);
      if (success) {
        setOpen(false);
        setDomain('');
        setUsername('');
        setPassword('');
        setSiteName('');
      }
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>
          <Plus className="h-4 w-4 mr-2" />
          Adicionar
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Adicionar Credencial</DialogTitle>
          <DialogDescription>
            Adicione manualmente uma credencial para um site.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4 py-4">
          <div className="space-y-2">
            <Label htmlFor="domain">Domínio *</Label>
            <Input
              id="domain"
              placeholder="exemplo.com"
              value={domain}
              onChange={(e) => setDomain(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="siteName">Nome do Site</Label>
            <Input
              id="siteName"
              placeholder="Nome para identificação (opcional)"
              value={siteName}
              onChange={(e) => setSiteName(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="username">Usuário/Email *</Label>
            <Input
              id="username"
              placeholder="usuario@email.com"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password">Senha *</Label>
            <Input
              id="password"
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)}>
            Cancelar
          </Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
            Salvar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export default function Passwords() {
  const { credentials, loading, deleteCredential, decryptCredential, saveCredential } = useCredentials();
  const [search, setSearch] = useState('');

  const filteredCredentials = credentials.filter(cred => 
    cred.domain.toLowerCase().includes(search.toLowerCase()) ||
    cred.site_name?.toLowerCase().includes(search.toLowerCase()) ||
    cred.username.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <AppLayout>
      <div className="p-6 space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Senhas Salvas</h1>
            <p className="text-muted-foreground">
              Gerencie suas credenciais de login para sites externos
            </p>
          </div>
          <AddCredentialDialog onSave={saveCredential} />
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Shield className="h-5 w-5 text-primary" />
              Credenciais
            </CardTitle>
            <CardDescription>
              {credentials.length} {credentials.length === 1 ? 'credencial salva' : 'credenciais salvas'}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Buscar por domínio, nome ou usuário..."
                className="pl-10"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>

            {loading ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
              </div>
            ) : filteredCredentials.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12 text-center">
                <Key className="h-12 w-12 text-muted-foreground/50 mb-4" />
                <h3 className="font-medium text-lg mb-1">
                  {search ? 'Nenhuma credencial encontrada' : 'Nenhuma credencial salva'}
                </h3>
                <p className="text-sm text-muted-foreground max-w-md">
                  {search 
                    ? 'Tente ajustar sua busca'
                    : 'Quando você fizer login em um site no navegador embutido, será oferecida a opção de salvar as credenciais.'
                  }
                </p>
              </div>
            ) : (
              <div className="space-y-2">
                {filteredCredentials.map((credential) => (
                  <CredentialRow
                    key={credential.id}
                    credential={credential}
                    onDelete={deleteCredential}
                    onDecrypt={decryptCredential}
                  />
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </AppLayout>
  );
}
