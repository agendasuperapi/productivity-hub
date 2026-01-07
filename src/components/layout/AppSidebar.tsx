import { 
  LayoutDashboard, 
  FolderOpen, 
  Keyboard, 
  Settings, 
  LogOut,
  Chrome,
  Globe,
  Sun,
  Moon,
  Key,
  FileText
} from 'lucide-react';
import { NavLink, useLocation, useNavigate } from 'react-router-dom';
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarHeader,
  SidebarFooter,
  useSidebar,
} from '@/components/ui/sidebar';
import { Button } from '@/components/ui/button';
import { useAuth } from '@/hooks/useAuth';
import { useTheme } from '@/hooks/useTheme';
import { useBrowser } from '@/contexts/BrowserContext';
import { cn } from '@/lib/utils';

// Itens que sempre navegam normalmente (não são abas virtuais)
const normalNavItems = [
  { title: 'Dashboard', url: '/', icon: LayoutDashboard },
  { title: 'Navegador', url: '/browser', icon: Globe },
];

// Itens que abrem como abas virtuais dentro do navegador
const virtualTabItems = [
  { title: 'Grupos de Abas', url: '/tab-groups', icon: FolderOpen, iconName: 'FolderOpen' },
  { title: 'Atalhos de Texto', url: '/shortcuts', icon: Keyboard, iconName: 'Keyboard' },
  { title: 'Senhas', url: '/passwords', icon: Key, iconName: 'Key' },
  { title: 'Formulários', url: '/form-data', icon: FileText, iconName: 'FileText' },
  { title: 'Configurações', url: '/settings', icon: Settings, iconName: 'Settings' },
];

export function AppSidebar() {
  const { state } = useSidebar();
  const collapsed = state === 'collapsed';
  const location = useLocation();
  const navigate = useNavigate();
  const { signOut, user } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const browserContext = useBrowser();

  const handleVirtualTabClick = (item: typeof virtualTabItems[0]) => {
    // Se estiver no navegador, abrir como aba virtual
    if (location.pathname === '/browser' && browserContext?.openVirtualTab) {
      browserContext.openVirtualTab(item.url, item.title, item.iconName);
      return;
    }

    // Se não estiver no navegador, ir para o navegador e pedir para abrir a aba virtual lá
    navigate('/browser', {
      state: {
        virtualTab: { route: item.url, name: item.title, icon: item.iconName },
      },
    });
  };

  // Verificar se um item virtual está ativo
  const isVirtualTabActive = (url: string) => {
    return browserContext?.activeVirtualTab?.route === url;
  };

  return (
    <Sidebar collapsible="icon">
      <SidebarHeader className="p-4">
        <div className={cn(
          "flex items-center gap-3",
          collapsed && "justify-center"
        )}>
          <div className="p-2 rounded-xl bg-sidebar-primary shrink-0">
            <Chrome className="h-5 w-5 text-sidebar-primary-foreground" />
          </div>
          {!collapsed && (
            <div className="flex flex-col">
              <span className="font-semibold text-sm">Navegador Pro</span>
              <span className="text-xs text-sidebar-foreground/70">Painel de Controle</span>
            </div>
          )}
        </div>
      </SidebarHeader>

      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Menu Principal</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {/* Itens de navegação normal */}
              {normalNavItems.map((item) => {
                const isActive = location.pathname === item.url;
                return (
                  <SidebarMenuItem key={item.title}>
                    <SidebarMenuButton 
                      asChild
                      isActive={isActive}
                      tooltip={item.title}
                    >
                      <NavLink to={item.url}>
                        <item.icon className={cn(
                          "h-4 w-4",
                          isActive && "text-sidebar-primary"
                        )} />
                        <span>{item.title}</span>
                      </NavLink>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                );
              })}
              
              {/* Itens que abrem como abas virtuais */}
              {virtualTabItems.map((item) => {
                const isActive = isVirtualTabActive(item.url);
                return (
                  <SidebarMenuItem key={item.title}>
                    <SidebarMenuButton 
                      isActive={isActive}
                      tooltip={item.title}
                      onClick={() => handleVirtualTabClick(item)}
                      className="cursor-pointer"
                    >
                      <item.icon className={cn(
                        "h-4 w-4",
                        isActive && "text-sidebar-primary"
                      )} />
                      <span>{item.title}</span>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                );
              })}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>

      <SidebarFooter className="p-4 space-y-2">
        {/* Botão de alternar tema */}
        <Button 
          variant="ghost" 
          size={collapsed ? "icon" : "default"}
          onClick={toggleTheme}
          className={cn(
            "w-full justify-start text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
            collapsed && "justify-center"
          )}
        >
          {theme === 'dark' ? (
            <Sun className="h-4 w-4" />
          ) : (
            <Moon className="h-4 w-4" />
          )}
          {!collapsed && (
            <span className="ml-2">
              {theme === 'dark' ? 'Tema Claro' : 'Tema Escuro'}
            </span>
          )}
        </Button>

        {!collapsed && user && (
          <div className="px-2 py-1.5 text-xs text-sidebar-foreground/70 truncate">
            {user.email}
          </div>
        )}
        <Button 
          variant="ghost" 
          size={collapsed ? "icon" : "default"}
          onClick={signOut}
          className={cn(
            "w-full justify-start text-sidebar-foreground hover:text-destructive hover:bg-sidebar-accent",
            collapsed && "justify-center"
          )}
        >
          <LogOut className="h-4 w-4" />
          {!collapsed && <span className="ml-2">Sair</span>}
        </Button>
      </SidebarFooter>
    </Sidebar>
  );
}
