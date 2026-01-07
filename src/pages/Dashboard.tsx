import { useEffect, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { FolderOpen, Keyboard, Columns, Globe, Plus, ArrowRight, Mail, User, LayoutDashboard } from 'lucide-react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { useBrowserSafe } from '@/contexts/BrowserContext';
interface Stats {
  tabGroups: number;
  tabs: number;
  shortcuts: number;
  layouts: number;
}

interface ProfileData {
  full_name: string | null;
  avatar_url: string | null;
}

export default function Dashboard() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const browserContext = useBrowserSafe();
  const [stats, setStats] = useState<Stats>({
    tabGroups: 0,
    tabs: 0,
    shortcuts: 0,
    layouts: 0
  });
  const [profile, setProfile] = useState<ProfileData | null>(null);
  const [loading, setLoading] = useState(true);

  // REMOVIDO: auto-abrir aba virtual Dashboard ao acessar esta página
  // Agora a Dashboard funciona igual às outras abas virtuais - só abre pelo menu

  // Handler para abrir aba virtual
  const handleVirtualTabClick = (href: string, title: string, iconName: string) => {
    navigate('/browser', {
      state: {
        virtualTab: { route: href, name: title, icon: iconName },
      },
    });
  };

  useEffect(() => {
    async function fetchData() {
      if (!user) return;

      const [groupsRes, tabsRes, shortcutsRes, layoutsRes, profileRes] = await Promise.all([
        supabase.from('tab_groups').select('id', { count: 'exact', head: true }),
        supabase.from('tabs').select('id', { count: 'exact', head: true }),
        supabase.from('text_shortcuts').select('id', { count: 'exact', head: true }),
        supabase.from('split_layouts').select('id', { count: 'exact', head: true }),
        supabase.from('profiles').select('full_name, avatar_url').eq('user_id', user.id).maybeSingle()
      ]);

      setStats({
        tabGroups: groupsRes.count || 0,
        tabs: tabsRes.count || 0,
        shortcuts: shortcutsRes.count || 0,
        layouts: layoutsRes.count || 0
      });

      if (profileRes.data) {
        setProfile(profileRes.data);
      }

      setLoading(false);
    }
    fetchData();
  }, [user]);

  const getInitials = (name: string | null) => {
    if (!name) return user?.email?.charAt(0).toUpperCase() || 'U';
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
  };

  const statCards = [{
    title: 'Grupos de Abas',
    value: stats.tabGroups,
    description: 'Grupos configurados',
    icon: FolderOpen,
    href: '/tab-groups',
    iconName: 'FolderOpen',
    color: 'text-primary',
    bgColor: 'bg-primary/10'
  }, {
    title: 'Abas',
    value: stats.tabs,
    description: 'Páginas salvas',
    icon: Globe,
    href: '/tab-groups',
    iconName: 'FolderOpen',
    color: 'text-accent',
    bgColor: 'bg-accent/10'
  }, {
    title: 'Atalhos de Texto',
    value: stats.shortcuts,
    description: 'Comandos rápidos',
    icon: Keyboard,
    href: '/shortcuts',
    iconName: 'Keyboard',
    color: 'text-green-500',
    bgColor: 'bg-green-500/10'
  }, {
    title: 'Layouts',
    value: stats.layouts,
    description: 'Telas divididas',
    icon: Columns,
    href: '/layouts',
    iconName: 'Columns',
    color: 'text-orange-500',
    bgColor: 'bg-orange-500/10'
  }];

  const quickActions = [{
    title: 'Novo Grupo de Abas',
    description: 'Organize suas páginas em grupos',
    href: '/tab-groups',
    iconName: 'FolderOpen',
    icon: FolderOpen
  }, {
    title: 'Novo Atalho de Texto',
    description: 'Crie comandos /rápidos',
    href: '/shortcuts',
    iconName: 'Keyboard',
    icon: Keyboard
  }, {
    title: 'Novo Layout Split View',
    description: 'Configure telas divididas',
    href: '/layouts',
    iconName: 'Columns',
    icon: Columns
  }];

  return (
    <div className="space-y-8 px-0 py-0 mx-[10px]">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
          <p className="text-muted-foreground mt-1">Visão geral das suas configurações do navegador.</p>
        </div>
      </div>

      {/* User Profile Card */}
      <Card className="overflow-hidden">
        <div className="bg-background p-6">
          <div className="flex items-center gap-4">
            <Avatar className="h-16 w-16 border-2 border-border shadow-lg">
              <AvatarImage src={profile?.avatar_url || undefined} alt={profile?.full_name || 'Avatar'} />
              <AvatarFallback className="text-lg bg-primary text-primary-foreground">
                {getInitials(profile?.full_name)}
              </AvatarFallback>
            </Avatar>
            <div className="flex-1 min-w-0">
              <h2 className="text-xl font-semibold truncate">
                {profile?.full_name || 'Usuário'}
              </h2>
              <div className="flex items-center gap-2 text-muted-foreground mt-1">
                <Mail className="h-4 w-4 flex-shrink-0" />
                <span className="text-sm truncate">{user?.email}</span>
              </div>
            </div>
          </div>
        </div>
      </Card>

      {/* Stats Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {statCards.map(stat => (
          <div 
            key={stat.title} 
            onClick={() => handleVirtualTabClick(stat.href, stat.title, stat.iconName)}
            className="cursor-pointer"
          >
            <Card className="hover:border-primary/50 transition-colors cursor-pointer">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  {stat.title}
                </CardTitle>
                <div className={`p-2 rounded-lg ${stat.bgColor}`}>
                  <stat.icon className={`h-4 w-4 ${stat.color}`} />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">
                  {loading ? '...' : stat.value}
                </div>
                <p className="text-xs text-muted-foreground mt-1">
                  {stat.description}
                </p>
              </CardContent>
            </Card>
          </div>
        ))}
      </div>

      {/* Quick Actions */}
      <div>
        <h2 className="text-xl font-semibold mb-4">Ações Rápidas</h2>
        <div className="grid gap-4 md:grid-cols-3">
          {quickActions.map(action => (
            <div 
              key={action.title} 
              onClick={() => handleVirtualTabClick(action.href, action.title, action.iconName)}
              className="cursor-pointer"
            >
              <Card className="hover:border-primary/50 transition-all hover:shadow-lg hover:shadow-primary/5 cursor-pointer group">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <div className="p-2 rounded-lg bg-primary/10">
                      <action.icon className="h-5 w-5 text-primary" />
                    </div>
                    <ArrowRight className="h-4 w-4 text-muted-foreground group-hover:text-primary transition-colors" />
                  </div>
                  <CardTitle className="text-lg mt-4">{action.title}</CardTitle>
                  <CardDescription>{action.description}</CardDescription>
                </CardHeader>
              </Card>
            </div>
          ))}
        </div>
      </div>

      {/* Empty State */}
      {!loading && stats.tabGroups === 0 && stats.shortcuts === 0 && (
        <Card className="border-dashed">
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 rounded-full bg-primary/10 mb-4">
              <Plus className="h-8 w-8 text-primary" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Comece a configurar</h3>
            <p className="text-muted-foreground text-center max-w-md mb-6">
              Ainda não há configurações. Comece criando um grupo de abas ou um atalho de texto.
            </p>
            <div className="flex gap-3">
              <Button asChild>
                <Link to="/tab-groups">
                  <FolderOpen className="mr-2 h-4 w-4" />
                  Criar Grupo
                </Link>
              </Button>
              <Button variant="outline" asChild>
                <Link to="/shortcuts">
                  <Keyboard className="mr-2 h-4 w-4" />
                  Criar Atalho
                </Link>
              </Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}