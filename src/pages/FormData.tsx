import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { useFormFieldValues, FormFieldValue } from '@/hooks/useFormFieldValues';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Badge } from '@/components/ui/badge';
import { 
  Loader2, 
  Search, 
  Trash2, 
  Edit2, 
  Check, 
  X, 
  Globe, 
  ArrowLeft,
  FileText
} from 'lucide-react';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from '@/components/ui/collapsible';
import { ChevronDown, ChevronRight } from 'lucide-react';

export default function FormData() {
  const navigate = useNavigate();
  const { user, loading: authLoading } = useAuth();
  const { getAllGroupedByDomain, deleteFieldValue, updateFieldValue, loading } = useFormFieldValues();
  
  const [data, setData] = useState<Record<string, FormFieldValue[]>>({});
  const [searchTerm, setSearchTerm] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editValue, setEditValue] = useState('');
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [expandedDomains, setExpandedDomains] = useState<Set<string>>(new Set());
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!authLoading && !user) {
      navigate('/auth');
    }
  }, [user, authLoading, navigate]);

  useEffect(() => {
    loadData();
  }, [user]);

  const loadData = async () => {
    setIsLoading(true);
    const grouped = await getAllGroupedByDomain();
    setData(grouped);
    // Expandir primeiro domínio por padrão
    const domains = Object.keys(grouped);
    if (domains.length > 0) {
      setExpandedDomains(new Set([domains[0]]));
    }
    setIsLoading(false);
  };

  const handleDelete = async () => {
    if (!deleteId) return;
    const success = await deleteFieldValue(deleteId);
    if (success) {
      await loadData();
    }
    setDeleteId(null);
  };

  const handleEdit = (item: FormFieldValue) => {
    setEditingId(item.id);
    setEditValue(item.field_value);
  };

  const handleSaveEdit = async (id: string) => {
    const success = await updateFieldValue(id, editValue);
    if (success) {
      await loadData();
    }
    setEditingId(null);
  };

  const toggleDomain = (domain: string) => {
    const newExpanded = new Set(expandedDomains);
    if (newExpanded.has(domain)) {
      newExpanded.delete(domain);
    } else {
      newExpanded.add(domain);
    }
    setExpandedDomains(newExpanded);
  };

  // Filtrar domínios e valores
  const filteredData: Record<string, FormFieldValue[]> = {};
  Object.entries(data).forEach(([domain, values]) => {
    const filteredValues = values.filter(v => 
      v.field_value.toLowerCase().includes(searchTerm.toLowerCase()) ||
      v.field_identifier.toLowerCase().includes(searchTerm.toLowerCase()) ||
      domain.toLowerCase().includes(searchTerm.toLowerCase())
    );
    if (filteredValues.length > 0 || domain.toLowerCase().includes(searchTerm.toLowerCase())) {
      filteredData[domain] = searchTerm ? filteredValues : values;
    }
  });

  const totalValues = Object.values(data).reduce((acc, vals) => acc + vals.length, 0);
  const totalDomains = Object.keys(data).length;

  if (authLoading || isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-background">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="container mx-auto p-6 max-w-4xl">
        {/* Header */}
        <div className="flex items-center gap-4 mb-6">
          <Button variant="ghost" size="icon" onClick={() => navigate(-1)}>
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div>
            <h1 className="text-2xl font-bold">Dados de Formulários</h1>
            <p className="text-muted-foreground">
              Gerencie valores salvos para auto-preenchimento
            </p>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/10">
                <Globe className="h-5 w-5 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-bold">{totalDomains}</p>
                <p className="text-sm text-muted-foreground">Sites</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/10">
                <FileText className="h-5 w-5 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-bold">{totalValues}</p>
                <p className="text-sm text-muted-foreground">Valores salvos</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Search */}
        <div className="relative mb-6">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Buscar por domínio, campo ou valor..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>

        {/* Content */}
        {Object.keys(filteredData).length === 0 ? (
          <Card>
            <CardContent className="p-12 text-center">
              <FileText className="h-12 w-12 mx-auto text-muted-foreground/50 mb-4" />
              <h3 className="font-medium mb-2">Nenhum dado salvo</h3>
              <p className="text-sm text-muted-foreground">
                Os valores dos formulários serão salvos automaticamente quando você preencher campos no navegador.
              </p>
            </CardContent>
          </Card>
        ) : (
          <ScrollArea className="h-[calc(100vh-400px)]">
            <div className="space-y-3">
              {Object.entries(filteredData).map(([domain, values]) => (
                <Card key={domain}>
                  <Collapsible 
                    open={expandedDomains.has(domain)} 
                    onOpenChange={() => toggleDomain(domain)}
                  >
                    <CollapsibleTrigger className="w-full">
                      <CardHeader className="p-4 flex flex-row items-center justify-between hover:bg-muted/50 transition-colors">
                        <div className="flex items-center gap-3">
                          {expandedDomains.has(domain) ? (
                            <ChevronDown className="h-4 w-4 text-muted-foreground" />
                          ) : (
                            <ChevronRight className="h-4 w-4 text-muted-foreground" />
                          )}
                          <Globe className="h-4 w-4 text-primary" />
                          <CardTitle className="text-base">{domain}</CardTitle>
                        </div>
                        <Badge variant="secondary">{values.length} valores</Badge>
                      </CardHeader>
                    </CollapsibleTrigger>
                    <CollapsibleContent>
                      <CardContent className="p-4 pt-0">
                        <div className="space-y-2">
                          {values.map((item) => (
                            <div 
                              key={item.id} 
                              className="flex items-center gap-3 p-3 rounded-lg bg-muted/30 hover:bg-muted/50 transition-colors"
                            >
                              <div className="flex-1 min-w-0">
                                <p className="text-xs text-muted-foreground mb-1">
                                  {item.field_label || item.field_identifier}
                                </p>
                                {editingId === item.id ? (
                                  <Input
                                    value={editValue}
                                    onChange={(e) => setEditValue(e.target.value)}
                                    className="h-8"
                                    autoFocus
                                  />
                                ) : (
                                  <p className="font-medium truncate">{item.field_value}</p>
                                )}
                              </div>
                              <Badge variant="outline" className="shrink-0">
                                {item.use_count}x
                              </Badge>
                              {editingId === item.id ? (
                                <div className="flex gap-1">
                                  <Button
                                    variant="ghost"
                                    size="icon"
                                    className="h-8 w-8"
                                    onClick={() => handleSaveEdit(item.id)}
                                    disabled={loading}
                                  >
                                    <Check className="h-4 w-4 text-green-500" />
                                  </Button>
                                  <Button
                                    variant="ghost"
                                    size="icon"
                                    className="h-8 w-8"
                                    onClick={() => setEditingId(null)}
                                  >
                                    <X className="h-4 w-4" />
                                  </Button>
                                </div>
                              ) : (
                                <div className="flex gap-1">
                                  <Button
                                    variant="ghost"
                                    size="icon"
                                    className="h-8 w-8"
                                    onClick={() => handleEdit(item)}
                                  >
                                    <Edit2 className="h-4 w-4" />
                                  </Button>
                                  <Button
                                    variant="ghost"
                                    size="icon"
                                    className="h-8 w-8 text-destructive hover:text-destructive"
                                    onClick={() => setDeleteId(item.id)}
                                  >
                                    <Trash2 className="h-4 w-4" />
                                  </Button>
                                </div>
                              )}
                            </div>
                          ))}
                        </div>
                      </CardContent>
                    </CollapsibleContent>
                  </Collapsible>
                </Card>
              ))}
            </div>
          </ScrollArea>
        )}
      </div>

      {/* Delete Dialog */}
      <AlertDialog open={!!deleteId} onOpenChange={() => setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmar exclusão</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja excluir este valor? Esta ação não pode ser desfeita.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={handleDelete} className="bg-destructive text-destructive-foreground">
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
