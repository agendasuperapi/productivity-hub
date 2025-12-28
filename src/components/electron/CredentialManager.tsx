import { useState, useCallback, useEffect, useRef } from 'react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Key, Loader2, Check } from 'lucide-react';
import { useCredentials } from '@/hooks/useCredentials';
import { extractDomain } from '@/lib/crypto';
import { toast } from 'sonner';

interface CredentialData {
  url: string;
  username: string;
  password: string;
  siteName?: string;
}

interface SaveCredentialDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  credential: CredentialData | null;
}

export function SaveCredentialDialog({ open, onOpenChange, credential }: SaveCredentialDialogProps) {
  const { saveCredential } = useCredentials();
  const [saving, setSaving] = useState(false);
  const [siteName, setSiteName] = useState('');

  useEffect(() => {
    if (credential) {
      setSiteName(extractDomain(credential.url));
    }
  }, [credential]);

  const handleSave = async () => {
    if (!credential) return;

    setSaving(true);
    try {
      const success = await saveCredential(
        credential.url,
        credential.username,
        credential.password,
        siteName
      );
      if (success) {
        onOpenChange(false);
      }
    } finally {
      setSaving(false);
    }
  };

  if (!credential) return null;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Key className="h-5 w-5 text-primary" />
            Salvar Credencial?
          </DialogTitle>
          <DialogDescription>
            Deseja salvar as credenciais para este site?
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4 py-4">
          <div className="space-y-2">
            <Label>Domínio</Label>
            <Input value={extractDomain(credential.url)} disabled />
          </div>
          <div className="space-y-2">
            <Label>Nome do Site</Label>
            <Input 
              value={siteName} 
              onChange={(e) => setSiteName(e.target.value)}
              placeholder="Nome para identificação"
            />
          </div>
          <div className="space-y-2">
            <Label>Usuário/Email</Label>
            <Input value={credential.username} disabled />
          </div>
          <div className="space-y-2">
            <Label>Senha</Label>
            <Input value="••••••••" disabled type="password" />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Não Salvar
          </Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <Check className="h-4 w-4 mr-2" />
            )}
            Salvar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// Hook to handle credential detection and auto-fill in webviews
export function useWebviewCredentials() {
  const { saveCredential, getAllCredentialsForDomain } = useCredentials();
  const [saveDialogOpen, setSaveDialogOpen] = useState(false);
  const [pendingCredential, setPendingCredential] = useState<CredentialData | null>(null);
  const processedFormsRef = useRef<Set<string>>(new Set());

  // Handle credential capture from webview
  const handleCredentialCapture = useCallback((data: CredentialData) => {
    // Create a unique key for this credential
    const key = `${data.url}:${data.username}`;
    
    // Don't prompt for the same credential twice in a session
    if (processedFormsRef.current.has(key)) {
      return;
    }
    
    processedFormsRef.current.add(key);
    setPendingCredential(data);
    setSaveDialogOpen(true);
  }, []);

  // Auto-fill credentials for a domain
  const autoFillCredentials = useCallback(async (webview: any, url: string) => {
    const credentials = await getAllCredentialsForDomain(url);
    
    if (credentials.length === 0) {
      return false;
    }

    // Use the first credential (most common case)
    const cred = credentials[0];
    
    try {
      await webview.executeJavaScript(`
        (function() {
          // Find password field
          const passwordFields = document.querySelectorAll('input[type="password"]');
          if (passwordFields.length === 0) return false;
          
          const passwordField = passwordFields[0];
          const form = passwordField.closest('form') || document;
          
          // Find username/email field (usually before password field)
          const usernameField = form.querySelector('input[type="email"]') 
            || form.querySelector('input[type="text"][name*="user"]')
            || form.querySelector('input[type="text"][name*="email"]')
            || form.querySelector('input[type="text"][name*="login"]')
            || form.querySelector('input[type="text"][autocomplete*="username"]')
            || form.querySelector('input[type="text"]');
          
          if (usernameField) {
            usernameField.value = ${JSON.stringify(cred.username)};
            usernameField.dispatchEvent(new Event('input', { bubbles: true }));
            usernameField.dispatchEvent(new Event('change', { bubbles: true }));
          }
          
          passwordField.value = ${JSON.stringify(cred.password)};
          passwordField.dispatchEvent(new Event('input', { bubbles: true }));
          passwordField.dispatchEvent(new Event('change', { bubbles: true }));
          
          console.log('[GerenciaZap] Credenciais preenchidas automaticamente');
          return true;
        })();
      `);
      
      toast.success('Credenciais preenchidas automaticamente');
      return true;
    } catch (error) {
      console.error('[GerenciaZap] Erro ao preencher credenciais:', error);
      return false;
    }
  }, [getAllCredentialsForDomain]);

  // Generate the script to inject into webview for credential detection
  const getCredentialDetectionScript = useCallback(() => {
    return `
      (function() {
        if (window.__gerenciazapCredentialInjected) return;
        window.__gerenciazapCredentialInjected = true;
        
        console.log('[GerenciaZap] Iniciando detecção de formulários de login...');
        
        // Track form submissions
        document.addEventListener('submit', function(e) {
          const form = e.target;
          if (!(form instanceof HTMLFormElement)) return;
          
          const passwordField = form.querySelector('input[type="password"]');
          if (!passwordField || !passwordField.value) return;
          
          // Find username/email field
          const usernameField = form.querySelector('input[type="email"]') 
            || form.querySelector('input[type="text"][name*="user"]')
            || form.querySelector('input[type="text"][name*="email"]')
            || form.querySelector('input[type="text"][name*="login"]')
            || form.querySelector('input[type="text"]');
          
          if (usernameField && usernameField.value) {
            console.log('__GERENCIAZAP_CREDENTIAL__:' + JSON.stringify({
              url: window.location.href,
              username: usernameField.value,
              password: passwordField.value,
              siteName: document.title
            }));
          }
        }, true);
        
        // Also detect button clicks that might submit login forms
        document.addEventListener('click', function(e) {
          const button = e.target.closest('button, input[type="submit"], [role="button"]');
          if (!button) return;
          
          // Check if button is likely a login/submit button
          const text = (button.textContent || button.value || '').toLowerCase();
          const isLoginButton = ['login', 'entrar', 'sign in', 'log in', 'submit', 'enviar', 'acessar'].some(
            t => text.includes(t)
          );
          
          if (!isLoginButton) return;
          
          // Find nearest form or look for password field
          const form = button.closest('form') || document;
          const passwordField = form.querySelector('input[type="password"]');
          
          if (!passwordField || !passwordField.value) return;
          
          const usernameField = form.querySelector('input[type="email"]') 
            || form.querySelector('input[type="text"][name*="user"]')
            || form.querySelector('input[type="text"][name*="email"]')
            || form.querySelector('input[type="text"][name*="login"]')
            || form.querySelector('input[type="text"]');
          
          if (usernameField && usernameField.value) {
            console.log('__GERENCIAZAP_CREDENTIAL__:' + JSON.stringify({
              url: window.location.href,
              username: usernameField.value,
              password: passwordField.value,
              siteName: document.title
            }));
          }
        }, true);
        
        console.log('[GerenciaZap] Detecção de login configurada');
      })();
    `;
  }, []);

  return {
    saveDialogOpen,
    setSaveDialogOpen,
    pendingCredential,
    handleCredentialCapture,
    autoFillCredentials,
    getCredentialDetectionScript,
    SaveCredentialDialog: () => (
      <SaveCredentialDialog
        open={saveDialogOpen}
        onOpenChange={setSaveDialogOpen}
        credential={pendingCredential}
      />
    )
  };
}
