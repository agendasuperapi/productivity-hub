import { ReactNode, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAdmin } from '@/hooks/useAdmin';
import { useAuth } from '@/hooks/useAuth';
import { Loader2, Shield } from 'lucide-react';

interface AdminLayoutProps {
  children: ReactNode;
  requireSuperAdmin?: boolean;
}

export function AdminLayout({ children, requireSuperAdmin = false }: AdminLayoutProps) {
  const navigate = useNavigate();
  const { user, loading: authLoading } = useAuth();
  const { isAdmin, isSuperAdmin, loading: adminLoading } = useAdmin();

  useEffect(() => {
    if (authLoading || adminLoading) return;

    if (!user) {
      navigate('/auth');
      return;
    }

    if (requireSuperAdmin && !isSuperAdmin) {
      navigate('/');
      return;
    }

    if (!isAdmin) {
      navigate('/');
    }
  }, [user, isAdmin, isSuperAdmin, authLoading, adminLoading, requireSuperAdmin, navigate]);

  if (authLoading || adminLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (!isAdmin || (requireSuperAdmin && !isSuperAdmin)) {
    return null;
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="border-b border-border bg-card">
        <div className="container mx-auto px-4 py-3 flex items-center gap-2">
          <Shield className="h-5 w-5 text-primary" />
          <span className="font-semibold">Painel Administrativo</span>
          {isSuperAdmin && (
            <span className="text-xs bg-primary text-primary-foreground px-2 py-0.5 rounded-full ml-2">
              Super Admin
            </span>
          )}
        </div>
      </div>
      {children}
    </div>
  );
}
