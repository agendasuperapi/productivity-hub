import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { 
  Plus, 
  Columns, 
  Trash2, 
  Pencil, 
  Star,
  Loader2
} from 'lucide-react';
import { cn } from '@/lib/utils';

interface SplitLayout {
  id: string;
  name: string;
  layout_type: string;
  panels: unknown[];
  is_favorite: boolean;
}

const layoutTypes = [
  { value: '50-50', label: '50% / 50%', preview: ['1fr', '1fr'] },
  { value: '70-30', label: '70% / 30%', preview: ['7fr', '3fr'] },
  { value: '30-70', label: '30% / 70%', preview: ['3fr', '7fr'] },
  { value: '33-33-33', label: '33% / 33% / 33%', preview: ['1fr', '1fr', '1fr'] },
  { value: '50-25-25', label: '50% / 25% / 25%', preview: ['2fr', '1fr', '1fr'] },
  { value: '25-50-25', label: '25% / 50% / 25%', preview: ['1fr', '2fr', '1fr'] },
];

export default function Layouts() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [layouts, setLayouts] = useState<SplitLayout[]>([]);
  const [loading, setLoading] = useState(true);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingLayout, setEditingLayout] = useState<SplitLayout | null>(null);
  const [saving, setSaving] = useState(false);

  // Form state
  const [name, setName] = useState('');
  const [layoutType, setLayoutType] = useState('50-50');
  const [isFavorite, setIsFavorite] = useState(false);

  useEffect(() => {
    fetchLayouts();
  }, [user]);

  async function fetchLayouts() {
    if (!user) return;

    const { data, error } = await supabase
      .from('split_layouts')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      toast({
        title: 'Erro ao carregar layouts',
        description: error.message,
        variant: 'destructive'
      });
    } else {
      setLayouts((data || []).map(d => ({
        ...d,
        panels: Array.isArray(d.panels) ? d.panels : []
      })));
    }
    setLoading(false);
  }

  function resetForm() {
    setName('');
    setLayoutType('50-50');
    setIsFavorite(false);
    setEditingLayout(null);
  }

  function openEditDialog(layout: SplitLayout) {
    setEditingLayout(layout);
    setName(layout.name);
    setLayoutType(layout.layout_type);
    setIsFavorite(layout.is_favorite);
    setIsDialogOpen(true);
  }

  async function handleSave() {
    if (!user || !name.trim()) {
      toast({
        title: 'Nome obrigatório',
        description: 'Informe o nome do layout',
        variant: 'destructive'
      });
      return;
    }

    setSaving(true);

    const panelsCount = layoutType.split('-').length;
    const panels = Array(panelsCount).fill({});

    if (editingLayout) {
      const { error } = await supabase
        .from('split_layouts')
        .update({
          name: name.trim(),
          layout_type: layoutType,
          panels,
          is_favorite: isFavorite
        })
        .eq('id', editingLayout.id);

      if (error) {
        toast({ title: 'Erro ao atualizar', description: error.message, variant: 'destructive' });
      } else {
        toast({ title: 'Layout atualizado!' });
        setIsDialogOpen(false);
        resetForm();
        fetchLayouts();
      }
    } else {
      const { error } = await supabase
        .from('split_layouts')
        .insert({
          user_id: user.id,
          name: name.trim(),
          layout_type: layoutType,
          panels,
          is_favorite: isFavorite
        });

      if (error) {
        toast({ title: 'Erro ao criar', description: error.message, variant: 'destructive' });
      } else {
        toast({ title: 'Layout criado!' });
        setIsDialogOpen(false);
        resetForm();
        fetchLayouts();
      }
    }
    setSaving(false);
  }

  async function handleDelete(id: string) {
    const { error } = await supabase
      .from('split_layouts')
      .delete()
      .eq('id', id);

    if (error) {
      toast({ title: 'Erro ao excluir', description: error.message, variant: 'destructive' });
    } else {
      toast({ title: 'Layout excluído!' });
      fetchLayouts();
    }
  }

  async function toggleFavorite(layout: SplitLayout) {
    const { error } = await supabase
      .from('split_layouts')
      .update({ is_favorite: !layout.is_favorite })
      .eq('id', layout.id);

    if (!error) {
      fetchLayouts();
    }
  }

  function getLayoutPreview(type: string) {
    const layout = layoutTypes.find(l => l.value === type);
    return layout?.preview || ['1fr', '1fr'];
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Layouts Split View</h1>
          <p className="text-muted-foreground mt-1">
            Configure layouts de tela dividida para usar no navegador
          </p>
        </div>
        <Dialog open={isDialogOpen} onOpenChange={(open) => {
          setIsDialogOpen(open);
          if (!open) resetForm();
        }}>
          <DialogTrigger asChild>
            <Button className="gradient-primary">
              <Plus className="mr-2 h-4 w-4" />
              Novo Layout
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[500px]">
            <DialogHeader>
              <DialogTitle>
                {editingLayout ? 'Editar Layout' : 'Novo Layout Split View'}
              </DialogTitle>
              <DialogDescription>
                Configure como dividir a tela do navegador
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label htmlFor="layout-name">Nome do Layout *</Label>
                <Input
                  id="layout-name"
                  placeholder="Ex: WhatsApp + Gestor"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label>Tipo de Divisão</Label>
                <Select value={layoutType} onValueChange={setLayoutType}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {layoutTypes.map(type => (
                      <SelectItem key={type.value} value={type.value}>
                        {type.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {/* Preview */}
              <div className="space-y-2">
                <Label>Preview</Label>
                <div 
                  className="h-24 rounded-lg border border-border overflow-hidden flex gap-1 p-1 bg-secondary/30"
                  style={{ 
                    display: 'grid',
                    gridTemplateColumns: getLayoutPreview(layoutType).join(' ')
                  }}
                >
                  {getLayoutPreview(layoutType).map((_, i) => (
                    <div 
                      key={i} 
                      className="bg-primary/20 rounded flex items-center justify-center text-xs text-muted-foreground"
                    >
                      Painel {i + 1}
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex items-center justify-between">
                <div>
                  <Label htmlFor="favorite">Marcar como favorito</Label>
                  <p className="text-xs text-muted-foreground">
                    Layouts favoritos aparecem primeiro
                  </p>
                </div>
                <Switch
                  id="favorite"
                  checked={isFavorite}
                  onCheckedChange={setIsFavorite}
                />
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setIsDialogOpen(false)}>
                Cancelar
              </Button>
              <Button onClick={handleSave} disabled={saving}>
                {saving && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                {editingLayout ? 'Salvar' : 'Criar'}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      {/* Layouts Grid */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      ) : layouts.length === 0 ? (
        <Card className="border-dashed">
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 rounded-full bg-primary/10 mb-4">
              <Columns className="h-8 w-8 text-primary" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Nenhum layout criado</h3>
            <p className="text-muted-foreground text-center max-w-md">
              Crie seu primeiro layout de tela dividida
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {layouts.map((layout) => (
            <Card key={layout.id} className="group hover:border-primary/50 transition-colors">
              <CardHeader className="pb-3">
                <div className="flex items-start justify-between">
                  <CardTitle className="text-lg">{layout.name}</CardTitle>
                  <Button
                    variant="ghost"
                    size="icon"
                    className={cn(
                      "h-8 w-8",
                      layout.is_favorite && "text-yellow-500"
                    )}
                    onClick={() => toggleFavorite(layout)}
                  >
                    <Star className={cn("h-4 w-4", layout.is_favorite && "fill-current")} />
                  </Button>
                </div>
                <CardDescription>
                  {layoutTypes.find(l => l.value === layout.layout_type)?.label}
                </CardDescription>
              </CardHeader>
              <CardContent>
                {/* Mini Preview */}
                <div 
                  className="h-16 rounded-lg border border-border overflow-hidden flex gap-0.5 p-0.5 bg-secondary/30 mb-4"
                  style={{ 
                    display: 'grid',
                    gridTemplateColumns: getLayoutPreview(layout.layout_type).join(' ')
                  }}
                >
                  {getLayoutPreview(layout.layout_type).map((_, i) => (
                    <div 
                      key={i} 
                      className="bg-primary/20 rounded"
                    />
                  ))}
                </div>

                <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                  <Button 
                    variant="ghost" 
                    size="sm"
                    onClick={() => openEditDialog(layout)}
                  >
                    <Pencil className="h-4 w-4" />
                  </Button>
                  <Button 
                    variant="ghost" 
                    size="sm"
                    className="text-destructive hover:text-destructive"
                    onClick={() => handleDelete(layout.id)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
