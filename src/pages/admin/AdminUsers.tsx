import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { AdminLayout } from './AdminLayout';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Loader2, Search, Users, FolderOpen, Keyboard, Globe } from 'lucide-react';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { useNavigate } from 'react-router-dom';

interface UserData {
  id: string;
  email: string;
  full_name: string | null;
  created_at: string;
  tab_groups_count: number;
  tabs_count: number;
  shortcuts_count: number;
  role?: string;
}

export default function AdminUsers() {
  const navigate = useNavigate();
  const [users, setUsers] = useState<UserData[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      // Buscar profiles
      const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('user_id, full_name, created_at');

      if (profilesError) throw profilesError;

      // Buscar roles
      const { data: roles, error: rolesError } = await supabase
        .from('user_roles')
        .select('user_id, role');

      if (rolesError) throw rolesError;

      // Buscar contagens
      const { data: tabGroups } = await supabase
        .from('tab_groups')
        .select('user_id');

      const { data: tabs } = await supabase
        .from('tabs')
        .select('user_id');

      const { data: shortcuts } = await supabase
        .from('text_shortcuts')
        .select('user_id');

      // Mapear dados
      const usersMap = new Map<string, UserData>();

      profiles?.forEach(profile => {
        usersMap.set(profile.user_id, {
          id: profile.user_id,
          email: '', // Será preenchido via auth se disponível
          full_name: profile.full_name,
          created_at: profile.created_at,
          tab_groups_count: 0,
          tabs_count: 0,
          shortcuts_count: 0,
        });
      });

      // Adicionar roles
      roles?.forEach(role => {
        const user = usersMap.get(role.user_id);
        if (user) {
          user.role = role.role;
        }
      });

      // Contar tab_groups
      tabGroups?.forEach(tg => {
        const user = usersMap.get(tg.user_id);
        if (user) user.tab_groups_count++;
      });

      // Contar tabs
      tabs?.forEach(t => {
        const user = usersMap.get(t.user_id);
        if (user) user.tabs_count++;
      });

      // Contar shortcuts
      shortcuts?.forEach(s => {
        const user = usersMap.get(s.user_id);
        if (user) user.shortcuts_count++;
      });

      setUsers(Array.from(usersMap.values()));
    } catch (err) {
      console.error('Error fetching users:', err);
    } finally {
      setLoading(false);
    }
  };

  const filteredUsers = users.filter(user => 
    user.full_name?.toLowerCase().includes(search.toLowerCase()) ||
    user.id.toLowerCase().includes(search.toLowerCase())
  );

  const getRoleBadge = (role?: string) => {
    switch (role) {
      case 'super_admin':
        return <Badge variant="default" className="bg-primary">Super Admin</Badge>;
      case 'admin':
        return <Badge variant="secondary">Admin</Badge>;
      default:
        return <Badge variant="outline">Usuário</Badge>;
    }
  };

  return (
    <AdminLayout>
      <div className="container mx-auto px-4 py-6 space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Usuários</h1>
            <p className="text-muted-foreground">Gerencie os usuários do sistema</p>
          </div>
          <Button variant="outline" onClick={() => navigate('/admin')}>
            Voltar
          </Button>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center gap-4">
                <div className="p-3 rounded-lg bg-primary/10">
                  <Users className="h-6 w-6 text-primary" />
                </div>
                <div>
                  <p className="text-2xl font-bold">{users.length}</p>
                  <p className="text-sm text-muted-foreground">Total de Usuários</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center gap-4">
                <div className="p-3 rounded-lg bg-blue-500/10">
                  <FolderOpen className="h-6 w-6 text-blue-500" />
                </div>
                <div>
                  <p className="text-2xl font-bold">{users.reduce((acc, u) => acc + u.tab_groups_count, 0)}</p>
                  <p className="text-sm text-muted-foreground">Grupos de Abas</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center gap-4">
                <div className="p-3 rounded-lg bg-green-500/10">
                  <Globe className="h-6 w-6 text-green-500" />
                </div>
                <div>
                  <p className="text-2xl font-bold">{users.reduce((acc, u) => acc + u.tabs_count, 0)}</p>
                  <p className="text-sm text-muted-foreground">Total de Abas</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center gap-4">
                <div className="p-3 rounded-lg bg-purple-500/10">
                  <Keyboard className="h-6 w-6 text-purple-500" />
                </div>
                <div>
                  <p className="text-2xl font-bold">{users.reduce((acc, u) => acc + u.shortcuts_count, 0)}</p>
                  <p className="text-sm text-muted-foreground">Atalhos de Texto</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Users Table */}
        <Card>
          <CardHeader>
            <CardTitle>Lista de Usuários</CardTitle>
            <CardDescription>
              <div className="flex items-center gap-2 mt-2">
                <Search className="h-4 w-4 text-muted-foreground" />
                <Input 
                  placeholder="Buscar por nome ou ID..." 
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="max-w-sm"
                />
              </div>
            </CardDescription>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="flex items-center justify-center py-8">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Usuário</TableHead>
                    <TableHead>Role</TableHead>
                    <TableHead className="text-center">Grupos</TableHead>
                    <TableHead className="text-center">Abas</TableHead>
                    <TableHead className="text-center">Atalhos</TableHead>
                    <TableHead>Criado em</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredUsers.map(user => (
                    <TableRow key={user.id}>
                      <TableCell>
                        <div>
                          <p className="font-medium">{user.full_name || 'Sem nome'}</p>
                          <p className="text-xs text-muted-foreground truncate max-w-[200px]">{user.id}</p>
                        </div>
                      </TableCell>
                      <TableCell>{getRoleBadge(user.role)}</TableCell>
                      <TableCell className="text-center">{user.tab_groups_count}</TableCell>
                      <TableCell className="text-center">{user.tabs_count}</TableCell>
                      <TableCell className="text-center">{user.shortcuts_count}</TableCell>
                      <TableCell>
                        {format(new Date(user.created_at), "dd/MM/yyyy", { locale: ptBR })}
                      </TableCell>
                    </TableRow>
                  ))}
                  {filteredUsers.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={6} className="text-center text-muted-foreground py-8">
                        Nenhum usuário encontrado
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </div>
    </AdminLayout>
  );
}
