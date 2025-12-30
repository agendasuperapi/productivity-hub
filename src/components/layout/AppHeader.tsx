import { LayoutDashboard, FolderOpen, Keyboard, Settings, LogOut, Chrome, Globe, Sun, Moon, Menu, Shield, RefreshCw, Save } from 'lucide-react';
import { NavLink, useLocation, useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { useAuth } from '@/hooks/useAuth';
import { useTheme } from '@/hooks/useTheme';
import { useAdmin } from '@/hooks/useAdmin';
import { cn } from '@/lib/utils';
import { GroupSelector } from '@/components/browser/GroupSelector';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { WindowControls } from '@/components/electron/WindowControls';
import { useElectron } from '@/hooks/useElectron';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { useBrowser } from '@/contexts/BrowserContext';
import { useState } from 'react';
import { toast } from 'sonner';

const menuItems = [{
  title: 'Dashboard',
  url: '/',
  icon: LayoutDashboard
}, {
  title: 'Navegador',
  url: '/browser',
  icon: Globe
}, {
  title: 'Grupos de Abas',
  url: '/tab-groups',
  icon: FolderOpen
}, {
  title: 'Atalhos de Texto',
  url: '/shortcuts',
  icon: Keyboard
}, {
  title: 'Configurações',
  url: '/settings',
  icon: Settings
}];

function RefreshButton() {
  const { refreshData } = useBrowser();
  const [isRefreshing, setIsRefreshing] = useState(false);

  const handleRefresh = async () => {
    setIsRefreshing(true);
    await refreshData();
    setTimeout(() => setIsRefreshing(false), 500);
  };

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button variant="ghost" size="icon" onClick={handleRefresh} disabled={isRefreshing}>
          <RefreshCw className={cn("h-4 w-4", isRefreshing && "animate-spin")} />
        </Button>
      </TooltipTrigger>
      <TooltipContent>Atualizar dados</TooltipContent>
    </Tooltip>
  );
}

function SavePositionButton() {
  const { saveMainWindowPosition } = useElectron();
  const [isSaving, setIsSaving] = useState(false);

  const handleSavePosition = async () => {
    setIsSaving(true);
    const result = await saveMainWindowPosition();
    if (result.success) {
      toast.success('Posição da janela salva');
    } else {
      toast.error('Erro ao salvar posição');
    }
    setTimeout(() => setIsSaving(false), 300);
  };

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button variant="ghost" size="icon" onClick={handleSavePosition} disabled={isSaving}>
          <Save className={cn("h-4 w-4", isSaving && "opacity-50")} />
        </Button>
      </TooltipTrigger>
      <TooltipContent>Salvar posição da janela</TooltipContent>
    </Tooltip>
  );
}

export function AppHeader() {
  const location = useLocation();
  const navigate = useNavigate();
  const { signOut, user } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const { isAdmin } = useAdmin();
  const { isElectron } = useElectron();

  return (
    <header 
      className="h-14 border-b border-border bg-background flex items-center px-4 shrink-0 select-none"
      style={isElectron ? { WebkitAppRegion: 'drag' } as React.CSSProperties : undefined}
    >
      {/* Logo */}
      <div className="flex items-center gap-2 mr-4" style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
        <div className="p-1.5 rounded-lg bg-primary">
          <Chrome className="h-4 w-4 text-primary-foreground" />
        </div>
        <span className="font-semibold text-sm hidden sm:block">Gerencia Zap</span>
      </div>

      {/* Group Selector - Left side */}
      <div className="mr-4" style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
        <GroupSelector />
      </div>

      {/* Spacer */}
      <div className="flex-1" />

      {/* Desktop Navigation - Icons only */}
      <nav 
        className="hidden md:flex items-center gap-1 mr-4"
        style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
      >
        {menuItems.map(item => {
          const isActive = location.pathname === item.url;
          return (
            <NavLink 
              key={item.title} 
              to={item.url} 
              title={item.title} 
              className={cn(
                "flex items-center justify-center p-2 rounded-md transition-colors",
                "hover:bg-accent hover:text-accent-foreground",
                isActive && "bg-accent text-accent-foreground"
              )}
            >
              <item.icon className="h-4 w-4" />
            </NavLink>
          );
        })}
      </nav>

      {/* Mobile Navigation */}
      <div className="md:hidden" style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon">
              <Menu className="h-5 w-5" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            {menuItems.map(item => {
              const isActive = location.pathname === item.url;
              return (
                <DropdownMenuItem key={item.title} asChild>
                  <NavLink 
                    to={item.url} 
                    className={cn("flex items-center gap-2 w-full", isActive && "bg-accent")}
                  >
                    <item.icon className="h-4 w-4" />
                    <span>{item.title}</span>
                  </NavLink>
                </DropdownMenuItem>
              );
            })}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-2" style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
        {/* Save Position button - Only in Electron */}
        {isElectron && (
          <SavePositionButton />
        )}

        {/* Refresh button - Only in Electron */}
        {isElectron && (
          <RefreshButton />
        )}

        {isAdmin && (
          <Tooltip>
            <TooltipTrigger asChild>
              <Button variant="ghost" size="icon" onClick={() => navigate('/admin')}>
                <Shield className="h-4 w-4" />
              </Button>
            </TooltipTrigger>
            <TooltipContent>Painel Admin</TooltipContent>
          </Tooltip>
        )}

        <Button variant="ghost" size="icon" onClick={toggleTheme}>
          {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
        </Button>

        {user && (
          <span className="text-xs text-muted-foreground hidden lg:block max-w-32 truncate">
            {user.email}
          </span>
        )}

        <Button variant="ghost" size="icon" onClick={signOut} className="hover:text-destructive">
          <LogOut className="h-4 w-4" />
        </Button>
      </div>

      {/* Window Controls - Only in Electron */}
      <WindowControls />
    </header>
  );
}