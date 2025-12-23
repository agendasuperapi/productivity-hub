import { cn } from '@/lib/utils';
import { Monitor } from 'lucide-react';

export type LayoutType = 'single' | '2x1' | '1x2' | '2x2' | '3x1' | '1x3';

interface LayoutOption {
  value: LayoutType;
  label: string;
  cols: number;
  rows: number;
}

const layoutOptions: LayoutOption[] = [
  { value: '2x1', label: '2 × 1', cols: 2, rows: 1 },
  { value: '1x2', label: '1 × 2', cols: 1, rows: 2 },
  { value: '2x2', label: '2 × 2', cols: 2, rows: 2 },
  { value: '3x1', label: '3 × 1', cols: 3, rows: 1 },
  { value: '1x3', label: '1 × 3', cols: 1, rows: 3 },
];

interface LayoutSelectorProps {
  value: LayoutType;
  onChange: (value: LayoutType) => void;
  urlCount: number;
}

export function LayoutSelector({ value, onChange, urlCount }: LayoutSelectorProps) {
  // Filtrar layouts que fazem sentido para a quantidade de URLs
  const availableLayouts = layoutOptions.filter(
    layout => layout.cols * layout.rows >= urlCount
  );

  if (urlCount <= 1) {
    return null;
  }

  return (
    <div className="space-y-3">
      <div className="text-sm font-medium">Layout de Exibição</div>
      <p className="text-xs text-muted-foreground">{urlCount} páginas</p>
      
      <div className="flex flex-wrap gap-2">
        {availableLayouts.map((layout) => (
          <button
            key={layout.value}
            type="button"
            onClick={() => onChange(layout.value)}
            className={cn(
              "flex flex-col items-center gap-1 p-2 rounded-lg border-2 transition-all",
              value === layout.value
                ? "border-primary bg-primary/10"
                : "border-border hover:border-primary/50"
            )}
          >
            <div 
              className="grid gap-0.5"
              style={{
                gridTemplateColumns: `repeat(${layout.cols}, 1fr)`,
                gridTemplateRows: `repeat(${layout.rows}, 1fr)`,
              }}
            >
              {Array.from({ length: layout.cols * layout.rows }).map((_, i) => (
                <div
                  key={i}
                  className={cn(
                    "w-6 h-5 rounded-sm border",
                    i < urlCount
                      ? "bg-primary/30 border-primary/50"
                      : "bg-muted border-muted-foreground/20"
                  )}
                />
              ))}
            </div>
            <span className="text-xs font-medium">{layout.label}</span>
          </button>
        ))}
      </div>

      {/* Preview */}
      <div className="mt-4 p-3 rounded-lg border border-border bg-secondary/30">
        <div className="text-xs text-muted-foreground mb-2">
          Preview: {value === 'single' ? '1 coluna × 1 linha' : `${value.replace('x', ' colunas × ')} linhas`}
        </div>
        <div 
          className="grid gap-1"
          style={{
            gridTemplateColumns: `repeat(${value === 'single' ? 1 : parseInt(value.split('x')[0])}, 1fr)`,
            gridTemplateRows: `repeat(${value === 'single' ? 1 : parseInt(value.split('x')[1])}, 1fr)`,
          }}
        >
          {Array.from({ length: value === 'single' ? 1 : parseInt(value.split('x')[0]) * parseInt(value.split('x')[1]) }).map((_, i) => (
            <div
              key={i}
              className={cn(
                "h-12 rounded flex items-center justify-center text-xs",
                i < urlCount
                  ? "bg-primary/20 border border-primary/30"
                  : "bg-muted/50 border border-dashed border-muted-foreground/20"
              )}
            >
              {i < urlCount && (
                <div className="flex items-center gap-1">
                  <Monitor className="h-3 w-3" />
                  <span>{i + 1}</span>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
