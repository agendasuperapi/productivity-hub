import { useEffect, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { FolderOpen, Keyboard, Columns, Globe, Plus, ArrowRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
interface Stats {
  tabGroups: number;
  tabs: number;
  shortcuts: number;
  layouts: number;
}
export default function Dashboard() {
  const {
    user
  } = useAuth();
  const [stats, setStats] = useState<Stats>({
    tabGroups: 0,
    tabs: 0,
    shortcuts: 0,
    layouts: 0
  });
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    async function fetchStats() {
      if (!user) return;
      const [groupsRes, tabsRes, shortcutsRes, layoutsRes] = await Promise.all([supabase.from('tab_groups').select('id', {
        count: 'exact',
        head: true
      }), supabase.from('tabs').select('id', {
        count: 'exact',
        head: true
      }), supabase.from('text_shortcuts').select('id', {
        count: 'exact',
        head: true
      }), supabase.from('split_layouts').select('id', {
        count: 'exact',
        head: true
      })]);
      setStats({
        tabGroups: groupsRes.count || 0,
        tabs: tabsRes.count || 0,
        shortcuts: shortcutsRes.count || 0,
        layouts: layoutsRes.count || 0
      });
      setLoading(false);
    }
    fetchStats();
  }, [user]);
  const statCards = [{
    title: 'Grupos de Abas',
    value: stats.tabGroups,
    description: 'Grupos configurados',
    icon: FolderOpen,
    href: '/tab-groups',
    color: 'text-primary',
    bgColor: 'bg-primary/10'
  }, {
    title: 'Abas',
    value: stats.tabs,
    description: 'Páginas salvas',
    icon: Globe,
    href: '/tab-groups',
    color: 'text-accent',
    bgColor: 'bg-accent/10'
  }, {
    title: 'Atalhos de Texto',
    value: stats.shortcuts,
    description: 'Comandos rápidos',
    icon: Keyboard,
    href: '/shortcuts',
    color: 'text-green-500',
    bgColor: 'bg-green-500/10'
  }, {
    title: 'Layouts',
    value: stats.layouts,
    description: 'Telas divididas',
    icon: Columns,
    href: '/layouts',
    color: 'text-orange-500',
    bgColor: 'bg-orange-500/10'
  }];
  const quickActions = [{
    title: 'Novo Grupo de Abas',
    description: 'Organize suas páginas em grupos',
    href: '/tab-groups',
    icon: FolderOpen
  }, {
    title: 'Novo Atalho de Texto',
    description: 'Crie comandos /rápidos',
    href: '/shortcuts',
    icon: Keyboard
  }, {
    title: 'Novo Layout Split View',
    description: 'Configure telas divididas',
    href: '/layouts',
    icon: Columns
  }];
  return <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
        <p className="text-muted-foreground mt-1">Visão geral das suas configurações do navegador</p>
      </div>

      {/* Stats Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {statCards.map(stat => <Link key={stat.title} to={stat.href}>
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
          </Link>)}
      </div>

      {/* Quick Actions */}
      <div>
        <h2 className="text-xl font-semibold mb-4">Ações Rápidas</h2>
        <div className="grid gap-4 md:grid-cols-3">
          {quickActions.map(action => <Link key={action.title} to={action.href}>
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
            </Link>)}
        </div>
      </div>

      {/* Empty State */}
      {!loading && stats.tabGroups === 0 && stats.shortcuts === 0 && <Card className="border-dashed">
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
        </Card>}
    </div>;
}