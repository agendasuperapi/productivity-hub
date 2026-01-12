import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';
import { supabaseWithDevice as supabase } from '@/lib/supabaseClient';
import { usePrimaryColor, colorOptions, backgroundOptions, generateColorShades, generateBackgroundShades } from '@/hooks/usePrimaryColor';
import { useUserSettings } from '@/hooks/useUserSettings';
import { FileDown, FileUp, Loader2, Palette, Check, Moon, RotateCcw, User, Globe, Keyboard, Bell, Monitor, Plug, Clipboard, Database, Search, ChevronRight, Menu } from 'lucide-react';
import { useState, useMemo, useEffect, useRef } from 'react';
import { cn } from '@/lib/utils';
import { ClipboardDomainsConfig } from '@/components/settings/ClipboardDomainsConfig';
import { ProfileSettings } from '@/components/settings/ProfileSettings';
import { BrowserSettings } from '@/components/settings/BrowserSettings';
import { ShortcutSettings } from '@/components/settings/ShortcutSettings';
import { NotificationSettings } from '@/components/settings/NotificationSettings';
import { InterfaceSettings } from '@/components/settings/InterfaceSettings';
import { IntegrationSettings } from '@/components/settings/IntegrationSettings';
import { useIsMobileOrTablet } from '@/hooks/use-mobile';
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from '@/components/ui/drawer';

interface ProfileData {
  full_name: string | null;
  avatar_url: string | null;
}
type SettingsSection = 'profile' | 'browser' | 'shortcuts' | 'notifications' | 'interface' | 'integrations' | 'theme' | 'background' | 'clipboard' | 'data';
const menuItems: {
  id: SettingsSection;
  label: string;
  icon: React.ElementType;
  description: string;
}[] = [{
  id: 'profile',
  label: 'Perfil',
  icon: User,
  description: 'Informações pessoais'
}, {
  id: 'browser',
  label: 'Navegador',
  icon: Globe,
  description: 'Janelas e links'
}, {
  id: 'shortcuts',
  label: 'Atalhos de Texto',
  icon: Keyboard,
  description: 'Prefixo e comandos'
}, {
  id: 'notifications',
  label: 'Notificações',
  icon: Bell,
  description: 'Alertas e sons'
}, {
  id: 'interface',
  label: 'Interface',
  icon: Monitor,
  description: 'Aparência e layout'
}, {
  id: 'integrations',
  label: 'Integrações',
  icon: Plug,
  description: 'Webhooks externos'
}, {
  id: 'theme',
  label: 'Cor do Tema',
  icon: Palette,
  description: 'Cor primária'
}, {
  id: 'background',
  label: 'Cor de Fundo',
  icon: Moon,
  description: 'Fundo do app'
}, {
  id: 'clipboard',
  label: 'Modo Clipboard',
  icon: Clipboard,
  description: 'Domínios especiais'
}, {
  id: 'data',
  label: 'Dados',
  icon: Database,
  description: 'Exportar e importar'
}];
export default function Settings() {
  const {
    user
  } = useAuth();
  const {
    toast
  } = useToast();
  const [exporting, setExporting] = useState(false);
  const [importing, setImporting] = useState(false);
  const [showGradient, setShowGradient] = useState(false);
  const [showBgGradient, setShowBgGradient] = useState(false);
  const [profile, setProfile] = useState<ProfileData | null>(null);
  const [activeSection, setActiveSection] = useState<SettingsSection>('profile');
  const [searchQuery, setSearchQuery] = useState('');
  const [drawerOpen, setDrawerOpen] = useState(false);
  const contentRef = useRef<HTMLDivElement>(null);
  const isMobileOrTablet = useIsMobileOrTablet();
  const {
    selectedColor,
    setPrimaryColor,
    selectedBackground,
    setBackgroundColor,
    resetToDefaults
  } = usePrimaryColor();
  const {
    settings,
    updateSettings,
    loading: settingsLoading
  } = useUserSettings();

  // Load profile data
  useEffect(() => {
    async function loadProfile() {
      if (!user) return;
      try {
        const {
          data,
          error
        } = await supabase.from('profiles').select('full_name, avatar_url').eq('user_id', user.id).single();
        if (error) throw error;
        setProfile(data);
      } catch (error) {
        console.error('Error loading profile:', error);
      }
    }
    loadProfile();
  }, [user]);

  // Gerar gradientes
  const colorShades = useMemo(() => generateColorShades(selectedColor.hsl), [selectedColor.hsl]);
  const bgShades = useMemo(() => generateBackgroundShades(selectedBackground), [selectedBackground]);

  // Filter menu items by search
  const filteredMenuItems = useMemo(() => {
    if (!searchQuery.trim()) return menuItems;
    const query = searchQuery.toLowerCase();
    return menuItems.filter(item => item.label.toLowerCase().includes(query) || item.description.toLowerCase().includes(query));
  }, [searchQuery]);
  async function exportAllData() {
    if (!user) return;
    setExporting(true);
    try {
      const [groups, tabs, shortcuts] = await Promise.all([supabase.from('tab_groups').select('*'), supabase.from('tabs').select('*'), supabase.from('text_shortcuts').select('*')]);
      const data = {
        exportDate: new Date().toISOString(),
        tabGroups: groups.data || [],
        tabs: tabs.data || [],
        shortcuts: shortcuts.data || []
      };
      const blob = new Blob([JSON.stringify(data, null, 2)], {
        type: 'application/json'
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `navegador-backup-${new Date().toISOString().split('T')[0]}.json`;
      a.click();
      URL.revokeObjectURL(url);
      toast({
        title: 'Dados exportados!'
      });
    } catch {
      toast({
        title: 'Erro ao exportar',
        variant: 'destructive'
      });
    }
    setExporting(false);
  }
  async function importAllData(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file || !user) return;
    setImporting(true);
    try {
      const text = await file.text();
      const data = JSON.parse(text);
      if (data.tabGroups?.length > 0) {
        for (const group of data.tabGroups) {
          await supabase.from('tab_groups').upsert({
            ...group,
            user_id: user.id
          }, {
            onConflict: 'id'
          });
        }
      }
      if (data.tabs?.length > 0) {
        for (const tab of data.tabs) {
          await supabase.from('tabs').upsert({
            ...tab,
            user_id: user.id
          }, {
            onConflict: 'id'
          });
        }
      }
      if (data.shortcuts?.length > 0) {
        for (const shortcut of data.shortcuts) {
          await supabase.from('text_shortcuts').upsert({
            ...shortcut,
            user_id: user.id
          }, {
            onConflict: 'user_id,command'
          });
        }
      }
      toast({
        title: 'Dados importados com sucesso!'
      });
    } catch {
      toast({
        title: 'Erro ao importar',
        description: 'Arquivo inválido',
        variant: 'destructive'
      });
    }
    setImporting(false);
    event.target.value = '';
  }
  const handleMenuClick = (section: SettingsSection) => {
    setActiveSection(section);
    setDrawerOpen(false);
    // Scroll to top when changing section
    if (contentRef.current) {
      contentRef.current.scrollTop = 0;
    }
  };

  // Get current section info for mobile header
  const currentMenuItem = menuItems.find(item => item.id === activeSection);

  // Menu items list component (reused in sidebar and drawer)
  const MenuItemsList = () => (
    <div className="py-2">
      {filteredMenuItems.map(item => {
        const Icon = item.icon;
        const isActive = activeSection === item.id;
        return (
          <button
            key={item.id}
            onClick={() => handleMenuClick(item.id)}
            className={cn(
              "w-full flex items-center gap-3 px-4 py-2.5 text-left transition-all rounded-lg mx-2 border border-transparent",
              isActive
                ? "bg-primary text-primary-foreground shadow-md"
                : "hover:border-primary/30 hover:bg-primary/5"
            )}
          >
            <Icon className={cn("h-5 w-5 flex-shrink-0 transition-colors", isActive ? "text-primary-foreground" : "text-muted-foreground")} />
            <div className="flex-1 min-w-0">
              <p className={cn("text-sm font-medium truncate transition-colors", isActive ? "text-primary-foreground" : "text-muted-foreground")}>
                {item.label}
              </p>
            </div>
            <ChevronRight className={cn("h-4 w-4 flex-shrink-0 transition-colors", isActive ? "text-primary-foreground" : "text-muted-foreground/50")} />
          </button>
        );
      })}
    </div>
  );
  if (settingsLoading) {
    return <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>;
  }
  const renderContent = (hideHeader: boolean = false) => {
    const Header = ({ title, description }: { title: string; description: string }) => {
      if (hideHeader) return null;
      return (
        <div className="mb-6">
          <h2 className="text-xl font-semibold">{title}</h2>
          <p className="text-sm text-muted-foreground">{description}</p>
        </div>
      );
    };

    switch (activeSection) {
      case 'profile':
        return <div className="space-y-6">
            <Header title="Perfil" description="Gerencie suas informações pessoais" />
            <ProfileSettings profile={profile} onProfileUpdate={setProfile} />
          </div>;
      case 'browser':
        return <div className="space-y-6">
            <Header title="Navegador" description="Configure o comportamento das janelas e links" />
            <BrowserSettings settings={settings.browser} onUpdate={updates => updateSettings('browser', updates)} />
          </div>;
      case 'shortcuts':
        return <div className="space-y-6">
            <Header title="Atalhos de Texto" description="Configure como os atalhos são ativados" />
            <ShortcutSettings settings={settings.shortcuts} onUpdate={updates => updateSettings('shortcuts', updates)} />
          </div>;
      case 'notifications':
        return <div className="space-y-6">
            <Header title="Notificações" description="Configure alertas e sons do aplicativo" />
            <NotificationSettings settings={settings.notifications} onUpdate={updates => updateSettings('notifications', updates)} />
          </div>;
      case 'interface':
        return <div className="space-y-6">
            <Header title="Interface" description="Personalize a aparência e comportamento" />
            <InterfaceSettings settings={settings.interface} onUpdate={updates => updateSettings('interface', updates)} />
          </div>;
      case 'integrations':
        return <div className="space-y-6">
            <Header title="Integrações" description="Configure webhooks e conexões externas" />
            <IntegrationSettings settings={settings.integrations} onUpdate={updates => updateSettings('integrations', updates)} />
          </div>;
      case 'theme':
        return <div className="space-y-6">
            <Header title="Cor do Tema" description="Escolha a cor primária do aplicativo" />
            <Card>
              <CardContent className="pt-6 space-y-4">
                <div className="grid grid-cols-5 sm:grid-cols-10 gap-2">
                  {colorOptions.map(color => <button key={color.name} onClick={() => {
                  setPrimaryColor(color);
                  setShowGradient(true);
                }} className={cn("relative w-10 h-10 rounded-lg transition-all duration-200 hover:scale-110 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-background", selectedColor.name === color.name && "ring-2 ring-offset-2 ring-offset-background scale-110")} style={{
                  backgroundColor: color.hex,
                  boxShadow: selectedColor.name === color.name ? `0 4px 14px ${color.hex}66` : undefined
                }} title={color.name}>
                      {selectedColor.name === color.name && <Check className="absolute inset-0 m-auto h-4 w-4 text-white drop-shadow-md" />}
                    </button>)}
                </div>

                {showGradient && <div className="animate-fade-in">
                    <p className="text-xs text-muted-foreground mb-2">
                      Ajuste fino: escolha um tom de {selectedColor.name}
                    </p>
                    <div className="flex rounded-xl overflow-hidden border border-border">
                      {colorShades.map((shade, index) => {
                    const isSelected = selectedColor.hsl === shade.hsl;
                    return <button key={index} onClick={() => {
                      setPrimaryColor({
                        name: `${selectedColor.name} ${shade.lightness}%`,
                        hsl: shade.hsl,
                        hex: shade.hex
                      });
                    }} className={cn("relative flex-1 h-10 transition-all duration-200 hover:scale-y-125 focus:outline-none", isSelected && "scale-y-125 z-10")} style={{
                      backgroundColor: shade.hex
                    }} title={`${shade.lightness}%`}>
                            {isSelected && <span className="absolute inset-0 flex items-center justify-center text-xs font-bold drop-shadow-md" style={{
                        color: shade.lightness > 50 ? '#000' : '#fff'
                      }}>
                                S
                              </span>}
                          </button>;
                  })}
                    </div>
                  </div>}

                <p className="text-xs text-muted-foreground">
                  Cor selecionada: <span className="font-medium">{selectedColor.name}</span>
                </p>
              </CardContent>
            </Card>
          </div>;
      case 'background':
        return <div className="space-y-6">
            <Header title="Cor de Fundo" description="Escolha a cor de fundo do aplicativo" />
            <Card>
              <CardContent className="pt-6 space-y-4">
                <div>
                  <p className="text-xs text-muted-foreground mb-2 font-medium">Escuros</p>
                  <div className="grid grid-cols-6 sm:grid-cols-12 gap-2">
                    {backgroundOptions.filter(bg => !bg.isLight).map(bg => <button key={bg.name} onClick={() => {
                    setBackgroundColor(bg);
                    setShowBgGradient(true);
                  }} className={cn("relative w-8 h-8 rounded-md transition-all duration-200 hover:scale-110 focus:outline-none border border-border/50", selectedBackground.name === bg.name && "ring-2 ring-offset-1 ring-offset-background ring-primary scale-110")} style={{
                    backgroundColor: bg.hex
                  }} title={bg.name}>
                        {selectedBackground.name === bg.name && <Check className="absolute inset-0 m-auto h-3 w-3 text-primary drop-shadow-md" />}
                      </button>)}
                  </div>
                </div>

                <div>
                  <p className="text-xs text-muted-foreground mb-2 font-medium">Claros</p>
                  <div className="grid grid-cols-6 sm:grid-cols-12 gap-2">
                    {backgroundOptions.filter(bg => bg.isLight).map(bg => <button key={bg.name} onClick={() => {
                    setBackgroundColor(bg);
                    setShowBgGradient(true);
                  }} className={cn("relative w-8 h-8 rounded-md transition-all duration-200 hover:scale-110 focus:outline-none border border-border", selectedBackground.name === bg.name && "ring-2 ring-offset-1 ring-offset-background ring-primary scale-110")} style={{
                    backgroundColor: bg.hex
                  }} title={bg.name}>
                        {selectedBackground.name === bg.name && <Check className="absolute inset-0 m-auto h-3 w-3 text-primary drop-shadow-md" />}
                      </button>)}
                  </div>
                </div>

                {showBgGradient && <div className="animate-fade-in">
                    <p className="text-xs text-muted-foreground mb-2">
                      Ajuste fino: escolha a intensidade
                    </p>
                    <div className="flex rounded-xl overflow-hidden border border-border">
                      {bgShades.map((shade, index) => {
                    const isSelected = selectedBackground.background === shade.background;
                    return <button key={index} onClick={() => setBackgroundColor(shade)} className={cn("relative flex-1 h-10 transition-all duration-200 hover:scale-y-125 focus:outline-none", isSelected && "scale-y-125 z-10")} style={{
                      backgroundColor: shade.hex
                    }} title={shade.name}>
                            {isSelected && <span className="absolute inset-0 flex items-center justify-center text-xs font-bold drop-shadow-md" style={{
                        color: shade.isLight ? '#000' : '#fff'
                      }}>
                                S
                              </span>}
                          </button>;
                  })}
                    </div>
                  </div>}

                <div className="flex items-center justify-between">
                  <p className="text-xs text-muted-foreground">
                    Fundo selecionado: <span className="font-medium">{selectedBackground.name}</span>
                  </p>
                  <Button variant="ghost" size="sm" onClick={() => {
                  resetToDefaults();
                  setShowGradient(false);
                  setShowBgGradient(false);
                  toast({
                    title: 'Cores restauradas para o padrão'
                  });
                }} className="text-xs text-muted-foreground hover:text-foreground">
                    <RotateCcw className="mr-1 h-3 w-3" />
                    Resetar cores
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>;
      case 'clipboard':
        return <div className="space-y-6">
            <Header title="Modo Clipboard Manual" description="Configure domínios com comportamento especial" />
            <ClipboardDomainsConfig />
          </div>;
      case 'data':
        return <div className="space-y-6">
            <Header title="Gerenciamento de Dados" description="Exporte ou importe suas configurações" />
            <Card>
              <CardContent className="pt-6 space-y-4">
                <div className="flex flex-col sm:flex-row gap-4">
                  <Button variant="outline" onClick={exportAllData} disabled={exporting} className="w-full sm:w-auto">
                    {exporting ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <FileDown className="mr-2 h-4 w-4" />}
                    Exportar Tudo
                  </Button>
                  <Button variant="outline" asChild disabled={importing} className="w-full sm:w-auto">
                    <label className="cursor-pointer">
                      {importing ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <FileUp className="mr-2 h-4 w-4" />}
                      Importar Backup
                      <input type="file" accept=".json" className="hidden" onChange={importAllData} disabled={importing} />
                    </label>
                  </Button>
                </div>
                <p className="text-xs text-muted-foreground">
                  O backup inclui todos os grupos de abas, abas e atalhos de texto.
                </p>
              </CardContent>
            </Card>
          </div>;
      default:
        return null;
    }
  };

  // Mobile/Tablet layout with Drawer
  if (isMobileOrTablet) {
    return (
      <div className="flex flex-col h-full overflow-hidden">
        {/* Mobile Header with Menu Button */}
        <div className="flex items-center gap-3 p-4 border-b border-border bg-background/50">
          <Drawer open={drawerOpen} onOpenChange={setDrawerOpen} direction="left">
            <DrawerTrigger asChild>
              <Button variant="outline" size="icon" className="flex-shrink-0">
                <Menu className="h-5 w-5" />
              </Button>
            </DrawerTrigger>
            <DrawerContent className="h-full w-72 rounded-none rounded-r-lg fixed left-0 top-0 bottom-0">
              <div className="flex flex-col h-full">
                {/* Header */}
                <div className="p-4 border-b border-border">
                  <h1 className="text-lg font-semibold">Configurações</h1>
                </div>
                
                {/* Search */}
                <div className="p-3 border-b border-border">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input
                      value={searchQuery}
                      onChange={e => setSearchQuery(e.target.value)}
                      placeholder="Pesquisar configurações"
                      className="pl-9 h-9 bg-muted/50"
                    />
                  </div>
                </div>
                
                {/* Menu Items */}
                <ScrollArea className="flex-1">
                  <MenuItemsList />
                </ScrollArea>
              </div>
            </DrawerContent>
          </Drawer>
          <div className="flex-1 min-w-0">
            <h1 className="text-lg font-semibold truncate">{currentMenuItem?.label}</h1>
            <p className="text-xs text-muted-foreground truncate">{currentMenuItem?.description}</p>
          </div>
        </div>

        {/* Content Area */}
        <ScrollArea ref={contentRef} className="flex-1">
          <div className="p-4">
            {renderContent(true)}
          </div>
        </ScrollArea>
      </div>
    );
  }

  // Desktop layout with Sidebar
  return (
    <div className="flex h-full overflow-hidden">
      {/* Sidebar Menu */}
      <div className="w-64 border-r border-border flex-shrink-0 flex flex-col bg-background/50">
        {/* Header */}
        <div className="p-4 border-b border-border">
          <h1 className="text-lg font-semibold">Configurações</h1>
        </div>

        {/* Search */}
        <div className="p-3 border-b border-border">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input value={searchQuery} onChange={e => setSearchQuery(e.target.value)} placeholder="Pesquisar configurações" className="pl-9 h-9 bg-muted/50" />
          </div>
        </div>

        {/* Menu Items */}
        <ScrollArea className="flex-1">
          <MenuItemsList />
        </ScrollArea>
      </div>

      {/* Content Area */}
      <ScrollArea ref={contentRef} className="flex-1">
        <div className="p-6">
          {renderContent()}
        </div>
      </ScrollArea>
    </div>
  );
}