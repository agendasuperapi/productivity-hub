import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { usePrimaryColor, colorOptions, backgroundOptions, generateColorShades, generateBackgroundShades } from '@/hooks/usePrimaryColor';
import { 
  User, 
  FileDown, 
  FileUp,
  Loader2,
  Palette,
  Check,
  Moon,
  RotateCcw
} from 'lucide-react';
import { useState, useMemo } from 'react';
import { cn } from '@/lib/utils';
import { ClipboardDomainsConfig } from '@/components/settings/ClipboardDomainsConfig';

export default function Settings() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [exporting, setExporting] = useState(false);
  const [importing, setImporting] = useState(false);
  const [showGradient, setShowGradient] = useState(false);
  const [showBgGradient, setShowBgGradient] = useState(false);
  const { selectedColor, setPrimaryColor, selectedBackground, setBackgroundColor, resetToDefaults } = usePrimaryColor();

  // Gerar gradientes
  const colorShades = useMemo(() => generateColorShades(selectedColor.hsl), [selectedColor.hsl]);
  const bgShades = useMemo(() => generateBackgroundShades(selectedBackground), [selectedBackground]);

  async function exportAllData() {
    if (!user) return;
    setExporting(true);

    try {
      const [groups, tabs, shortcuts, layouts] = await Promise.all([
        supabase.from('tab_groups').select('*'),
        supabase.from('tabs').select('*'),
        supabase.from('text_shortcuts').select('*'),
        supabase.from('split_layouts').select('*'),
      ]);

      const data = {
        exportDate: new Date().toISOString(),
        tabGroups: groups.data || [],
        tabs: tabs.data || [],
        shortcuts: shortcuts.data || [],
        layouts: layouts.data || [],
      };

      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `navegador-backup-${new Date().toISOString().split('T')[0]}.json`;
      a.click();
      URL.revokeObjectURL(url);

      toast({ title: 'Dados exportados!' });
    } catch {
      toast({ title: 'Erro ao exportar', variant: 'destructive' });
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

      // Import groups first
      if (data.tabGroups?.length > 0) {
        for (const group of data.tabGroups) {
          await supabase.from('tab_groups').upsert({
            ...group,
            user_id: user.id
          }, { onConflict: 'id' });
        }
      }

      // Import tabs
      if (data.tabs?.length > 0) {
        for (const tab of data.tabs) {
          await supabase.from('tabs').upsert({
            ...tab,
            user_id: user.id
          }, { onConflict: 'id' });
        }
      }

      // Import shortcuts
      if (data.shortcuts?.length > 0) {
        for (const shortcut of data.shortcuts) {
          await supabase.from('text_shortcuts').upsert({
            ...shortcut,
            user_id: user.id
          }, { onConflict: 'user_id,command' });
        }
      }

      // Import layouts
      if (data.layouts?.length > 0) {
        for (const layout of data.layouts) {
          await supabase.from('split_layouts').upsert({
            ...layout,
            user_id: user.id
          }, { onConflict: 'id' });
        }
      }

      toast({ title: 'Dados importados com sucesso!' });
    } catch {
      toast({ title: 'Erro ao importar', description: 'Arquivo inválido', variant: 'destructive' });
    }
    setImporting(false);
    event.target.value = '';
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Configurações</h1>
        <p className="text-muted-foreground mt-1">
          Gerencie sua conta e preferências
        </p>
      </div>

      {/* Profile */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <User className="h-5 w-5" />
            Perfil
          </CardTitle>
          <CardDescription>
            Informações da sua conta
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            <p className="text-sm text-muted-foreground">Email</p>
            <p className="font-medium">{user?.email}</p>
          </div>
        </CardContent>
      </Card>

      {/* Theme Color */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Palette className="h-5 w-5" />
            Cor do Tema
          </CardTitle>
          <CardDescription>
            Escolha a cor primária do aplicativo
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Cores principais */}
          <div className="grid grid-cols-4 sm:grid-cols-8 gap-3">
            {colorOptions.map((color) => (
              <button
                key={color.name}
                onClick={() => {
                  setPrimaryColor(color);
                  setShowGradient(true);
                }}
                className={cn(
                  "relative w-12 h-12 rounded-xl transition-all duration-200 hover:scale-110 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-background",
                  selectedColor.name === color.name && "ring-2 ring-offset-2 ring-offset-background scale-110"
                )}
                style={{ 
                  backgroundColor: color.hex,
                  boxShadow: selectedColor.name === color.name 
                    ? `0 4px 14px ${color.hex}66` 
                    : undefined
                }}
                title={color.name}
              >
                {selectedColor.name === color.name && (
                  <Check className="absolute inset-0 m-auto h-5 w-5 text-white drop-shadow-md" />
                )}
              </button>
            ))}
          </div>

          {/* Gradiente de tons */}
          {showGradient && (
            <div className="animate-fade-in">
              <p className="text-xs text-muted-foreground mb-2">
                Ajuste fino: escolha um tom de {selectedColor.name}
              </p>
              <div className="flex rounded-xl overflow-hidden border border-border">
                {colorShades.map((shade, index) => {
                  const isSelected = selectedColor.hsl === shade.hsl;
                  return (
                    <button
                      key={index}
                      onClick={() => {
                        setPrimaryColor({
                          name: `${selectedColor.name} ${shade.lightness}%`,
                          hsl: shade.hsl,
                          hex: shade.hex
                        });
                      }}
                      className={cn(
                        "relative flex-1 h-10 transition-all duration-200 hover:scale-y-125 focus:outline-none",
                        isSelected && "scale-y-125 z-10"
                      )}
                      style={{ backgroundColor: shade.hex }}
                      title={`${shade.lightness}%`}
                    >
                      {isSelected && (
                        <span className="absolute inset-0 flex items-center justify-center text-xs font-bold drop-shadow-md"
                          style={{ color: shade.lightness > 50 ? '#000' : '#fff' }}
                        >
                          S
                        </span>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          <p className="text-xs text-muted-foreground">
            Cor selecionada: <span className="font-medium">{selectedColor.name}</span>
          </p>
        </CardContent>
      </Card>

      {/* Background Color */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Moon className="h-5 w-5" />
            Cor de Fundo
          </CardTitle>
          <CardDescription>
            Escolha a cor de fundo do aplicativo
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Separador Escuros */}
          <div>
            <p className="text-xs text-muted-foreground mb-2 font-medium">Escuros</p>
            <div className="grid grid-cols-4 sm:grid-cols-8 gap-2">
              {backgroundOptions.filter(bg => !bg.isLight).map((bg) => (
                <button
                  key={bg.name}
                  onClick={() => {
                    setBackgroundColor(bg);
                    setShowBgGradient(true);
                  }}
                  className={cn(
                    "relative w-10 h-10 rounded-lg transition-all duration-200 hover:scale-110 focus:outline-none border border-border/50",
                    selectedBackground.name === bg.name && "ring-2 ring-offset-1 ring-offset-background ring-primary scale-110"
                  )}
                  style={{ backgroundColor: bg.hex }}
                  title={bg.name}
                >
                  {selectedBackground.name === bg.name && (
                    <Check className="absolute inset-0 m-auto h-4 w-4 text-primary drop-shadow-md" />
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Separador Claros */}
          <div>
            <p className="text-xs text-muted-foreground mb-2 font-medium">Claros</p>
            <div className="grid grid-cols-4 sm:grid-cols-8 gap-2">
              {backgroundOptions.filter(bg => bg.isLight).map((bg) => (
                <button
                  key={bg.name}
                  onClick={() => {
                    setBackgroundColor(bg);
                    setShowBgGradient(true);
                  }}
                  className={cn(
                    "relative w-10 h-10 rounded-lg transition-all duration-200 hover:scale-110 focus:outline-none border border-border",
                    selectedBackground.name === bg.name && "ring-2 ring-offset-1 ring-offset-background ring-primary scale-110"
                  )}
                  style={{ backgroundColor: bg.hex }}
                  title={bg.name}
                >
                  {selectedBackground.name === bg.name && (
                    <Check className="absolute inset-0 m-auto h-4 w-4 text-primary drop-shadow-md" />
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Gradiente de fundo */}
          {showBgGradient && (
            <div className="animate-fade-in">
              <p className="text-xs text-muted-foreground mb-2">
                Ajuste fino: escolha a intensidade
              </p>
              <div className="flex rounded-xl overflow-hidden border border-border">
                {bgShades.map((shade, index) => {
                  const isSelected = selectedBackground.background === shade.background;
                  return (
                    <button
                      key={index}
                      onClick={() => setBackgroundColor(shade)}
                      className={cn(
                        "relative flex-1 h-10 transition-all duration-200 hover:scale-y-125 focus:outline-none",
                        isSelected && "scale-y-125 z-10"
                      )}
                      style={{ backgroundColor: shade.hex }}
                      title={shade.name}
                    >
                      {isSelected && (
                        <span className="absolute inset-0 flex items-center justify-center text-xs font-bold drop-shadow-md"
                          style={{ color: shade.isLight ? '#000' : '#fff' }}
                        >
                          S
                        </span>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          <div className="flex items-center justify-between">
            <p className="text-xs text-muted-foreground">
              Fundo selecionado: <span className="font-medium">{selectedBackground.name}</span>
            </p>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                resetToDefaults();
                setShowGradient(false);
                setShowBgGradient(false);
                toast({ title: 'Cores restauradas para o padrão' });
              }}
              className="text-xs text-muted-foreground hover:text-foreground"
            >
              <RotateCcw className="mr-1 h-3 w-3" />
              Resetar cores
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Clipboard Domains */}
      <ClipboardDomainsConfig />

      {/* Data Management */}
      <Card>
        <CardHeader>
          <CardTitle>Gerenciamento de Dados</CardTitle>
          <CardDescription>
            Exporte ou importe suas configurações
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex flex-col sm:flex-row gap-4">
            <Button 
              variant="outline" 
              onClick={exportAllData}
              disabled={exporting}
            >
              {exporting ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <FileDown className="mr-2 h-4 w-4" />
              )}
              Exportar Tudo
            </Button>
            <label>
              <Button 
                variant="outline" 
                asChild
                disabled={importing}
              >
                <span>
                  {importing ? (
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  ) : (
                    <FileUp className="mr-2 h-4 w-4" />
                  )}
                  Importar Backup
                </span>
              </Button>
              <input 
                type="file" 
                accept=".json" 
                className="hidden" 
                onChange={importAllData}
                disabled={importing}
              />
            </label>
          </div>
          <p className="text-xs text-muted-foreground">
            O backup inclui todos os grupos de abas, abas, atalhos de texto e layouts.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
