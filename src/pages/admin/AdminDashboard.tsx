import { AdminLayout } from './AdminLayout';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Users, Rocket, ArrowRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export default function AdminDashboard() {
  const navigate = useNavigate();

  return (
    <AdminLayout>
      <div className="container mx-auto px-4 py-6 space-y-6">
        <div>
          <h1 className="text-2xl font-bold">Painel Administrativo</h1>
          <p className="text-muted-foreground">Gerencie usuários e versões do sistema</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card className="hover:border-primary/50 transition-colors cursor-pointer" onClick={() => navigate('/admin/users')}>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="p-3 rounded-lg bg-primary/10">
                  <Users className="h-6 w-6 text-primary" />
                </div>
                <ArrowRight className="h-5 w-5 text-muted-foreground" />
              </div>
              <CardTitle className="mt-4">Usuários</CardTitle>
              <CardDescription>
                Visualize e gerencie os usuários do sistema, suas configurações e estatísticas de uso.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Button variant="outline" className="w-full">
                Ver Usuários
              </Button>
            </CardContent>
          </Card>

          <Card className="hover:border-primary/50 transition-colors cursor-pointer" onClick={() => navigate('/admin/versions')}>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="p-3 rounded-lg bg-primary/10">
                  <Rocket className="h-6 w-6 text-primary" />
                </div>
                <ArrowRight className="h-5 w-5 text-muted-foreground" />
              </div>
              <CardTitle className="mt-4">Versionamento</CardTitle>
              <CardDescription>
                Gerencie as versões do aplicativo, faça deploys e acompanhe o histórico de releases.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Button variant="outline" className="w-full">
                Ver Versões
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </AdminLayout>
  );
}
