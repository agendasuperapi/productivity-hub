import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { applyKeywords } from '@/lib/shortcuts';

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface Keyword {
  key: string;
  value: string;
}

interface ShortcutPreviewDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  messages: ShortcutMessage[];
  keywords: Keyword[];
  title?: string;
}

export function ShortcutPreviewDialog({
  open,
  onOpenChange,
  messages,
  keywords,
  title,
}: ShortcutPreviewDialogProps) {
  const validMessages = messages.filter((m) => m.text.trim());

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[600px] max-h-[80vh]">
        <DialogHeader>
          <DialogTitle>
            {title ? `Pré-visualização: ${title}` : 'Pré-visualização da Mensagem'}
          </DialogTitle>
          <DialogDescription>
            Mensagem completa com variáveis substituídas
          </DialogDescription>
        </DialogHeader>
        <div className="py-4 max-h-[50vh] overflow-y-auto">
          {validMessages.map((msg, index, arr) => (
            <div key={index} className="mb-4">
              {arr.length > 1 && (
                <div className="flex items-center gap-2 mb-2">
                  <span className="text-xs font-medium text-muted-foreground bg-muted px-2 py-1 rounded">
                    Mensagem {index + 1}
                  </span>
                  {msg.auto_send && (
                    <span className="text-xs text-primary bg-primary/10 px-2 py-1 rounded">
                      Envio automático
                    </span>
                  )}
                </div>
              )}
              <div className="p-4 bg-muted/50 rounded-lg border">
                <p className="whitespace-pre-wrap text-sm">
                  {applyKeywords(msg.text, keywords)}
                </p>
              </div>
              {index < arr.length - 1 && (
                <div className="border-b border-dashed border-border my-4" />
              )}
            </div>
          ))}
        </div>
        <DialogFooter>
          <Button onClick={() => onOpenChange(false)}>Fechar</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
