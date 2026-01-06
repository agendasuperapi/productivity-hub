import { LayoutDashboard, FolderOpen, Keyboard, Settings, LogOut, Chrome, Globe, Sun, Moon, Menu, Shield, RefreshCw, Save, Camera, Loader2 } from 'lucide-react';
import { APP_VERSION } from '@/config/version';
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
import { useState, useEffect, useRef } from 'react';
import { toast } from 'sonner';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { supabase } from '@/integrations/supabase/client';
import { ImageCropDialog } from '@/components/ui/image-crop-dialog';

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

interface ProfileData {
  full_name: string | null;
  avatar_url: string | null;
}

function UserAvatarMenu() {
  const { user, signOut } = useAuth();
  const [profile, setProfile] = useState<ProfileData | null>(null);
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [cropDialogOpen, setCropDialogOpen] = useState(false);
  const [tempImageSrc, setTempImageSrc] = useState<string>('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!user) return;
    
    const fetchProfile = async () => {
      const { data } = await supabase
        .from('profiles')
        .select('full_name, avatar_url')
        .eq('user_id', user.id)
        .maybeSingle();
      
      if (data) {
        setProfile(data);
        setAvatarUrl(data.avatar_url);
      }
    };

    fetchProfile();
  }, [user]);

  const getInitials = (name: string | null) => {
    if (!name) return user?.email?.charAt(0).toUpperCase() || 'U';
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
  };

  const handleAvatarClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !user) return;

    e.target.value = '';

    if (!file.type.startsWith('image/')) {
      toast.error('Por favor, selecione uma imagem');
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      toast.error('A imagem deve ter no máximo 5MB');
      return;
    }

    const reader = new FileReader();
    reader.onloadend = () => {
      const base64 = reader.result as string;
      setTempImageSrc(base64);
      setCropDialogOpen(true);
    };
    reader.onerror = () => {
      toast.error('Erro ao ler arquivo');
    };
    reader.readAsDataURL(file);
  };

  const handleCropComplete = async (croppedImage: string) => {
    if (!user) return;

    setUploading(true);
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ avatar_url: croppedImage })
        .eq('user_id', user.id);

      if (error) throw error;

      setAvatarUrl(croppedImage);
      setProfile(prev => prev ? { ...prev, avatar_url: croppedImage } : null);
      setTempImageSrc('');
      toast.success('Foto atualizada com sucesso!');
    } catch (error) {
      console.error('Error updating avatar:', error);
      toast.error('Erro ao atualizar foto');
    } finally {
      setUploading(false);
    }
  };

  return (
    <>
      <Popover>
        <PopoverTrigger asChild>
          <button className="focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-full">
            <Avatar className="h-8 w-8 cursor-pointer hover:ring-2 hover:ring-primary/50 transition-all">
              <AvatarImage src={avatarUrl || undefined} alt={profile?.full_name || 'Avatar'} />
              <AvatarFallback className="text-xs bg-primary text-primary-foreground">
                {getInitials(profile?.full_name)}
              </AvatarFallback>
            </Avatar>
          </button>
        </PopoverTrigger>
        <PopoverContent align="end" className="w-72 p-0">
          <div className="p-4 space-y-4">
            {/* Profile Header */}
            <div className="flex items-center gap-3">
              <div className="relative">
                <Avatar className="h-16 w-16">
                  <AvatarImage src={avatarUrl || undefined} alt={profile?.full_name || 'Avatar'} />
                  <AvatarFallback className="text-lg bg-primary text-primary-foreground">
                    {getInitials(profile?.full_name)}
                  </AvatarFallback>
                </Avatar>
                <button
                  onClick={handleAvatarClick}
                  className="absolute bottom-0 right-0 p-1.5 rounded-full bg-primary text-primary-foreground hover:bg-primary/90 transition-colors"
                  disabled={uploading}
                >
                  {uploading ? (
                    <Loader2 className="h-3 w-3 animate-spin" />
                  ) : (
                    <Camera className="h-3 w-3" />
                  )}
                </button>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={handleFileChange}
                />
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-medium truncate">
                  {profile?.full_name || 'Usuário'}
                </p>
                <p className="text-sm text-muted-foreground truncate">
                  {user?.email}
                </p>
              </div>
            </div>

            {/* Divider */}
            <div className="border-t border-border" />

            {/* Actions */}
            <div className="space-y-1">
              <Button 
                variant="ghost" 
                className="w-full justify-start gap-2 h-9" 
                onClick={() => window.location.href = '/settings'}
              >
                <Settings className="h-4 w-4" />
                Configurações
              </Button>
              <Button 
                variant="ghost" 
                className="w-full justify-start gap-2 h-9 text-destructive hover:text-destructive hover:bg-destructive/10" 
                onClick={signOut}
              >
                <LogOut className="h-4 w-4" />
                Sair
              </Button>
            </div>
          </div>
        </PopoverContent>
      </Popover>

      {/* Image Crop Dialog */}
      <ImageCropDialog
        open={cropDialogOpen}
        onOpenChange={setCropDialogOpen}
        imageSrc={tempImageSrc}
        onCropComplete={handleCropComplete}
        aspectRatio={1}
        circularCrop={true}
      />
    </>
  );
}

export function AppHeader() {
  const location = useLocation();
  const navigate = useNavigate();
  const { theme, toggleTheme } = useTheme();
  const { isAdmin } = useAdmin();
  const { isElectron } = useElectron();

  return (
    <header 
      className="h-14 border-b border-border bg-background flex items-center px-4 shrink-0 select-none"
      style={isElectron ? { WebkitAppRegion: 'drag' } as React.CSSProperties : undefined}
    >
      {/* Logo */}
      <div 
        className="flex items-center gap-2 mr-4 cursor-pointer hover:opacity-80 transition-opacity" 
        style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
        onClick={() => navigate('/')}
      >
        <div className="p-1.5 rounded-lg bg-primary">
          <Chrome className="h-4 w-4 text-primary-foreground" />
        </div>
        <span className="font-semibold text-sm hidden sm:block">Gerencia Zap</span>
        <span className="text-xs text-muted-foreground hidden sm:block">v{APP_VERSION}</span>
      </div>

      {/* Group Selector - Left side */}
      <div className="mr-4" style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
        <GroupSelector />
      </div>

      {/* Spacer */}
      <div className="flex-1" />

      {/* Navigation Menu */}
      <div className="mr-2" style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
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

        {/* User Avatar Menu */}
        <UserAvatarMenu />
      </div>

      {/* Window Controls - Only in Electron */}
      <WindowControls />
    </header>
  );
}
