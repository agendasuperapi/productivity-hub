import { useState, useRef, useEffect, useCallback } from 'react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Send, RotateCcw, Keyboard, MessageSquare } from 'lucide-react';
import { applyKeywords } from '@/lib/shortcuts';
import { useUserSettings } from '@/hooks/useUserSettings';

interface ShortcutMessage {
  text: string;
  auto_send: boolean;
}

interface Shortcut {
  id: string;
  command: string;
  expanded_text: string;
  messages?: ShortcutMessage[];
}

interface Keyword {
  key: string;
  value: string;
}

interface ChatMessage {
  id: string;
  text: string;
  type: 'sent' | 'pending';
  shortcutUsed?: string;
}

interface ShortcutTestDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  shortcuts: Shortcut[];
  keywords: Keyword[];
}

// Parse WhatsApp formatting: *bold* _italic_ ~strikethrough~ `code`
function parseWhatsAppFormatting(text: string): React.ReactNode {
  const parts: React.ReactNode[] = [];
  let lastIndex = 0;
  
  // Regex to match WhatsApp formatting patterns
  // Order matters: we process from left to right
  const patterns = [
    { regex: /\*([^*]+)\*/g, render: (content: string, key: number) => <strong key={key}>{content}</strong> },
    { regex: /_([^_]+)_/g, render: (content: string, key: number) => <em key={key}>{content}</em> },
    { regex: /~([^~]+)~/g, render: (content: string, key: number) => <s key={key}>{content}</s> },
    { regex: /`([^`]+)`/g, render: (content: string, key: number) => <code key={key} className="bg-black/20 px-1 rounded text-xs font-mono">{content}</code> },
  ];

  // Combined regex to find all formatting
  const combinedRegex = /(\*[^*]+\*|_[^_]+_|~[^~]+~|`[^`]+`)/g;
  let match;
  let keyCounter = 0;

  while ((match = combinedRegex.exec(text)) !== null) {
    // Add text before the match
    if (match.index > lastIndex) {
      parts.push(text.slice(lastIndex, match.index));
    }

    const matchedText = match[0];
    const marker = matchedText[0];
    const content = matchedText.slice(1, -1);

    switch (marker) {
      case '*':
        parts.push(<strong key={keyCounter++}>{content}</strong>);
        break;
      case '_':
        parts.push(<em key={keyCounter++}>{content}</em>);
        break;
      case '~':
        parts.push(<s key={keyCounter++}>{content}</s>);
        break;
      case '`':
        parts.push(<code key={keyCounter++} className="bg-black/20 px-1 rounded text-xs font-mono">{content}</code>);
        break;
    }

    lastIndex = match.index + matchedText.length;
  }

  // Add remaining text
  if (lastIndex < text.length) {
    parts.push(text.slice(lastIndex));
  }

  return parts.length > 0 ? parts : text;
}

export function ShortcutTestDialog({ 
  open, 
  onOpenChange, 
  shortcuts, 
  keywords 
}: ShortcutTestDialogProps) {
  const [inputValue, setInputValue] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [lastExpandedShortcut, setLastExpandedShortcut] = useState<string | null>(null);
  const { settings } = useUserSettings();
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const prefix = settings.shortcuts.prefix || '/';

  // Scroll to bottom when messages change
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Focus input when dialog opens
  useEffect(() => {
    if (open) {
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  }, [open]);

  // Find shortcut by command
  const findShortcut = useCallback((command: string): Shortcut | undefined => {
    return shortcuts.find(s => s.command.toLowerCase() === command.toLowerCase());
  }, [shortcuts]);

  // Get messages from shortcut
  const getShortcutMessages = useCallback((shortcut: Shortcut): ShortcutMessage[] => {
    if (shortcut.messages && shortcut.messages.length > 0) {
      return shortcut.messages;
    }
    return [{ text: shortcut.expanded_text, auto_send: false }];
  }, []);

  // Process input for shortcut detection and expansion
  const handleInputChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newValue = e.target.value;
    const prevValue = inputValue;
    
    // Detect if a space or newline was just added
    const justAddedSpace = (newValue.length === prevValue.length + 1) && 
      (newValue.endsWith(' ') || newValue.endsWith('\n'));
    
    if (justAddedSpace) {
      // Find the word before the space
      const textWithoutTrigger = newValue.slice(0, -1);
      const lastSpaceOrNewline = Math.max(
        textWithoutTrigger.lastIndexOf(' '),
        textWithoutTrigger.lastIndexOf('\n')
      );
      const lastWord = textWithoutTrigger.slice(lastSpaceOrNewline + 1);
      
      if (lastWord.startsWith(prefix) && lastWord.length > prefix.length) {
        const command = lastWord.slice(prefix.length);
        const shortcut = findShortcut(command);
        
        if (shortcut) {
          const shortcutMessages = getShortcutMessages(shortcut);
          
          // Apply keywords to all messages
          const expandedMessages = shortcutMessages.map(m => ({
            ...m,
            text: applyKeywords(m.text, keywords)
          }));
          
          // Process auto-send messages
          const autoSendMsgs = expandedMessages.filter(m => m.auto_send);
          const manualMsgs = expandedMessages.filter(m => !m.auto_send);
          
          // Send auto-send messages immediately
          if (autoSendMsgs.length > 0) {
            const newSentMessages: ChatMessage[] = autoSendMsgs.map((msg, idx) => ({
              id: `${Date.now()}-auto-${idx}`,
              text: msg.text,
              type: 'sent',
              shortcutUsed: shortcut.command
            }));
            setMessages(prev => [...prev, ...newSentMessages]);
          }
          
          // Replace the shortcut command with non-auto-send text
          const textBeforeShortcut = textWithoutTrigger.slice(0, lastSpaceOrNewline + 1);
          const remainingText = manualMsgs.length > 0 
            ? manualMsgs.map(m => m.text).join('\n') 
            : '';
          
          setInputValue(textBeforeShortcut + remainingText);
          setLastExpandedShortcut(shortcut.command);
          
          // Move cursor to end
          setTimeout(() => {
            if (inputRef.current) {
              inputRef.current.selectionStart = inputRef.current.value.length;
              inputRef.current.selectionEnd = inputRef.current.value.length;
            }
          }, 0);
          
          return;
        }
      }
    }
    
    setInputValue(newValue);
    setLastExpandedShortcut(null);
  };

  // Handle sending message - sends as a single message (like WhatsApp)
  const handleSend = () => {
    if (!inputValue.trim()) return;
    
    // Send entire text as a single message (preserving line breaks)
    const newMessage: ChatMessage = {
      id: `${Date.now()}`,
      text: inputValue.trim(),
      type: 'sent',
      shortcutUsed: lastExpandedShortcut || undefined
    };
    
    setMessages(prev => [...prev, newMessage]);
    setInputValue('');
    setLastExpandedShortcut(null);
    inputRef.current?.focus();
  };

  // Handle Enter key
  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  // Reset conversation
  const handleReset = () => {
    setMessages([]);
    setInputValue('');
    setLastExpandedShortcut(null);
    inputRef.current?.focus();
  };

  // Quick insert shortcut
  const insertShortcut = (command: string) => {
    const newValue = inputValue + (inputValue.endsWith(' ') || inputValue === '' ? '' : ' ') + prefix + command + ' ';
    
    // Simulate the input change to trigger expansion
    const fakeEvent = {
      target: { 
        value: newValue,
        selectionStart: newValue.length
      }
    } as React.ChangeEvent<HTMLTextAreaElement>;
    
    handleInputChange(fakeEvent);
    inputRef.current?.focus();
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[600px] h-[80vh] flex flex-col p-0 gap-0">
        <DialogHeader className="p-4 pb-2 border-b">
          <div className="flex items-center justify-between">
            <div>
              <DialogTitle className="flex items-center gap-2">
                <MessageSquare className="h-5 w-5" />
                Simulador de Atalhos
              </DialogTitle>
              <DialogDescription>
                Digite como em um chat real. Use {prefix}comando + espaço para expandir.
              </DialogDescription>
            </div>
            <Button variant="ghost" size="sm" onClick={handleReset}>
              <RotateCcw className="h-4 w-4 mr-1" />
              Limpar
            </Button>
          </div>
        </DialogHeader>

        {/* Chat area */}
        <ScrollArea className="flex-1 p-4">
          <div className="space-y-3 min-h-full">
            {messages.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full py-12 text-center text-muted-foreground">
                <Keyboard className="h-12 w-12 mb-4 opacity-20" />
                <p className="text-sm">Nenhuma mensagem ainda</p>
                <p className="text-xs mt-1">
                  Digite {prefix}comando + espaço para expandir um atalho
                </p>
              </div>
            ) : (
              messages.map((msg) => (
                <div
                  key={msg.id}
                  className="flex justify-end"
                >
                  <div className="max-w-[80%] space-y-1">
                    <div className="bg-primary text-primary-foreground rounded-2xl rounded-br-sm px-4 py-2">
                      <p className="text-sm whitespace-pre-wrap">
                        {msg.text.split('\n').map((line, idx, arr) => (
                          <span key={idx}>
                            {parseWhatsAppFormatting(line)}
                            {idx < arr.length - 1 && <br />}
                          </span>
                        ))}
                      </p>
                    </div>
                    {msg.shortcutUsed && (
                      <div className="flex justify-end">
                        <Badge variant="secondary" className="text-[10px] h-4">
                          via {prefix}{msg.shortcutUsed}
                        </Badge>
                      </div>
                    )}
                  </div>
                </div>
              ))
            )}
            <div ref={messagesEndRef} />
          </div>
        </ScrollArea>

        {/* Quick shortcuts */}
        {shortcuts.length > 0 && (
          <div className="px-4 py-2 border-t bg-muted/30">
            <div className="flex items-center gap-2 overflow-x-auto pb-1">
              <span className="text-xs text-muted-foreground shrink-0">Atalhos:</span>
              {shortcuts.slice(0, 10).map((s) => (
                <Button
                  key={s.id}
                  variant="outline"
                  size="sm"
                  className="h-6 text-xs font-mono shrink-0"
                  onClick={() => insertShortcut(s.command)}
                >
                  {prefix}{s.command}
                </Button>
              ))}
            </div>
          </div>
        )}

        {/* Input area */}
        <div className="p-4 pt-2 border-t">
          {lastExpandedShortcut && (
            <div className="mb-2 text-xs text-green-600 flex items-center gap-1">
              <span>✓</span> Atalho <code className="bg-muted px-1 rounded">{prefix}{lastExpandedShortcut}</code> expandido!
            </div>
          )}
          <div className="flex gap-2">
            <div className="relative flex-1">
              <textarea
                ref={inputRef}
                value={inputValue}
                onChange={handleInputChange}
                onKeyDown={handleKeyDown}
                placeholder={`Digite sua mensagem... (use ${prefix}comando + espaço)`}
                className="w-full min-h-[44px] max-h-[120px] px-3 py-2 pr-12 rounded-lg border bg-background resize-none text-sm focus:outline-none focus:ring-2 focus:ring-ring"
                rows={1}
                style={{
                  height: 'auto',
                  minHeight: '44px'
                }}
                onInput={(e) => {
                  const target = e.target as HTMLTextAreaElement;
                  target.style.height = 'auto';
                  target.style.height = Math.min(target.scrollHeight, 120) + 'px';
                }}
              />
            </div>
            <Button 
              onClick={handleSend} 
              disabled={!inputValue.trim()}
              size="icon"
              className="h-11 w-11 shrink-0"
            >
              <Send className="h-4 w-4" />
            </Button>
          </div>
          <p className="text-[10px] text-muted-foreground mt-1.5">
            Pressione Enter para enviar • Shift+Enter para nova linha
          </p>
        </div>
      </DialogContent>
    </Dialog>
  );
}
