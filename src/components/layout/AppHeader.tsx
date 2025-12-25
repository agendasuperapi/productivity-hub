import { 
  LayoutDashboard, 
  FolderOpen, 
  Keyboard, 
  Columns, 
  Settings, 
  LogOut,
  Chrome,
  Globe,
  Sun,
  Moon,
  Menu
} from 'lucide-react';
import { NavLink, useLocation } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { useAuth } from '@/hooks/useAuth';
import { useTheme } from '@/hooks/useTheme';
import { cn } from '@/lib/utils';
import { GroupSelector } from '@/components/browser/GroupSelector';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

const menuItems = [
  { title: 'Dashboard', url: '/', icon: LayoutDashboard },
  { title: 'Navegador', url: '/browser', icon: Globe },
  { title: 'Grupos de Abas', url: '/tab-groups', icon: FolderOpen },
  { title: 'Atalhos de Texto', url: '/shortcuts', icon: Keyboard },
  { title: 'Layouts Split View', url: '/layouts', icon: Columns },
  { title: 'Configurações', url: '/settings', icon: Settings },
];

export function AppHeader() {
  const location = useLocation();
  const { signOut, user } = useAuth();
  const { theme, toggleTheme } = useTheme();

  return (
    <header className="h-14 border-b border-border bg-background flex items-center px-4 shrink-0">
      {/* Logo */}
      <div className="flex items-center gap-2 mr-4">
        <div className="p-1.5 rounded-lg bg-primary">
          <Chrome className="h-4 w-4 text-primary-foreground" />
        </div>
        <span className="font-semibold text-sm hidden sm:block">Navegador Pro</span>
      </div>

      {/* Group Selector - Left side */}
      <div className="mr-4">
        <GroupSelector />
      </div>

      {/* Spacer */}
      <div className="flex-1" />

      {/* Desktop Navigation - Icons only */}
      <nav className="hidden md:flex items-center gap-1 mr-4">
        {menuItems.map((item) => {
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
      <div className="md:hidden">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon">
              <Menu className="h-5 w-5" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            {menuItems.map((item) => {
              const isActive = location.pathname === item.url;
              return (
                <DropdownMenuItem key={item.title} asChild>
                  <NavLink
                    to={item.url}
                    className={cn(
                      "flex items-center gap-2 w-full",
                      isActive && "bg-accent"
                    )}
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
      <div className="flex items-center gap-2">
        <Button 
          variant="ghost" 
          size="icon"
          onClick={toggleTheme}
        >
          {theme === 'dark' ? (
            <Sun className="h-4 w-4" />
          ) : (
            <Moon className="h-4 w-4" />
          )}
        </Button>

        {user && (
          <span className="text-xs text-muted-foreground hidden lg:block max-w-32 truncate">
            {user.email}
          </span>
        )}

        <Button 
          variant="ghost" 
          size="icon"
          onClick={signOut}
          className="hover:text-destructive"
        >
          <LogOut className="h-4 w-4" />
        </Button>
      </div>
    </header>
  );
}
