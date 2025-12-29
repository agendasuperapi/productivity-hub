import { ReactNode, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { AppHeader } from './AppHeader';
import { useAuth } from '@/hooks/useAuth';
import { BrowserProvider } from '@/contexts/BrowserContext';
import { Loader2 } from 'lucide-react';
interface AppLayoutProps {
  children: ReactNode;
}
export function AppLayout({
  children
}: AppLayoutProps) {
  const {
    user,
    loading
  } = useAuth();
  const navigate = useNavigate();
  useEffect(() => {
    if (!loading && !user) {
      navigate('/auth');
    }
  }, [user, loading, navigate]);
  if (loading) {
    return <div className="min-h-screen flex items-center justify-center bg-background">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>;
  }
  if (!user) {
    return null;
  }
  return <BrowserProvider>
      <div className="h-screen flex flex-col overflow-hidden">
        <AppHeader />
        <main className="flex-1 overflow-hidden mx-[10px]">
          {children}
        </main>
      </div>
    </BrowserProvider>;
}