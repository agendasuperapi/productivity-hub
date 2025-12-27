import { Minus, Square, X, Copy } from 'lucide-react';
import { useElectron } from '@/hooks/useElectron';
import { useEffect, useState } from 'react';
import { cn } from '@/lib/utils';

export function WindowControls() {
  const { isElectron, minimizeWindow, maximizeWindow, closeMainWindow, isMaximized, onMaximizeChange } = useElectron();
  const [maximized, setMaximized] = useState(false);

  useEffect(() => {
    if (!isElectron) return;
    
    // Check initial state
    isMaximized().then(setMaximized);
    
    // Listen for changes
    onMaximizeChange(setMaximized);
  }, [isElectron, isMaximized, onMaximizeChange]);

  if (!isElectron) return null;

  return (
    <div className="flex items-center ml-2" style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
      <button
        onClick={minimizeWindow}
        className={cn(
          "flex items-center justify-center w-11 h-8",
          "hover:bg-accent transition-colors"
        )}
        title="Minimizar"
      >
        <Minus className="h-4 w-4" />
      </button>
      <button
        onClick={async () => {
          const result = await maximizeWindow();
          setMaximized(result.isMaximized);
        }}
        className={cn(
          "flex items-center justify-center w-11 h-8",
          "hover:bg-accent transition-colors"
        )}
        title={maximized ? "Restaurar" : "Maximizar"}
      >
        {maximized ? (
          <Copy className="h-3 w-3" />
        ) : (
          <Square className="h-3 w-3" />
        )}
      </button>
      <button
        onClick={closeMainWindow}
        className={cn(
          "flex items-center justify-center w-11 h-8",
          "hover:bg-destructive hover:text-destructive-foreground transition-colors"
        )}
        title="Fechar"
      >
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}
