import { useEffect, useRef } from 'react';
import { ExternalLink, Copy, Maximize2 } from 'lucide-react';

interface WebviewContextMenuProps {
  x: number;
  y: number;
  url: string;
  onOpenFloating: () => void;
  onOpenBrowser: () => void;
  onCopyLink: () => void;
  onClose: () => void;
}

export function WebviewContextMenu({
  x,
  y,
  url,
  onOpenFloating,
  onOpenBrowser,
  onCopyLink,
  onClose
}: WebviewContextMenuProps) {
  const menuRef = useRef<HTMLDivElement>(null);

  // Ajustar posição para não sair da tela
  useEffect(() => {
    if (!menuRef.current) return;
    
    const menu = menuRef.current;
    const rect = menu.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    
    let adjustedX = x;
    let adjustedY = y;
    
    if (x + rect.width > viewportWidth - 10) {
      adjustedX = viewportWidth - rect.width - 10;
    }
    
    if (y + rect.height > viewportHeight - 10) {
      adjustedY = viewportHeight - rect.height - 10;
    }
    
    menu.style.left = `${adjustedX}px`;
    menu.style.top = `${adjustedY}px`;
  }, [x, y]);

  // Fechar ao clicar fora, pressionar Escape ou clicar com botão do meio
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        onClose();
      }
    };
    
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    
    const handleAuxClick = (e: MouseEvent) => {
      // Botão do meio do mouse (button === 1)
      if (e.button === 1) {
        onClose();
      }
    };
    
    // Adicionar com delay para evitar fechar imediatamente
    setTimeout(() => {
      window.addEventListener('click', handleClickOutside);
      window.addEventListener('keydown', handleEscape);
      window.addEventListener('auxclick', handleAuxClick);
    }, 50);
    
    return () => {
      window.removeEventListener('click', handleClickOutside);
      window.removeEventListener('keydown', handleEscape);
      window.removeEventListener('auxclick', handleAuxClick);
    };
  }, [onClose]);

  const menuItemClass = `
    flex items-center gap-3 px-4 py-2.5 text-sm cursor-pointer
    transition-colors hover:bg-accent/20 text-foreground
  `;

  return (
    <div
      ref={menuRef}
      className="fixed z-[99999] bg-popover border border-border rounded-lg shadow-lg overflow-hidden min-w-[200px]"
      style={{ left: x, top: y }}
      onClick={(e) => e.stopPropagation()}
    >
      <div className="py-1">
        <div
          className={menuItemClass}
          onClick={() => {
            onOpenFloating();
            onClose();
          }}
        >
          <Maximize2 className="h-4 w-4 text-muted-foreground" />
          <span>Abrir em janela flutuante</span>
        </div>
        
        <div
          className={menuItemClass}
          onClick={() => {
            onOpenBrowser();
            onClose();
          }}
        >
          <ExternalLink className="h-4 w-4 text-muted-foreground" />
          <span>Abrir no navegador</span>
        </div>
        
        <div className="h-px bg-border my-1" />
        
        <div
          className={menuItemClass}
          onClick={() => {
            onCopyLink();
            onClose();
          }}
        >
          <Copy className="h-4 w-4 text-muted-foreground" />
          <span>Copiar link</span>
        </div>
      </div>
    </div>
  );
}
