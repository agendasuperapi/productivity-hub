import { useState, useEffect, useRef } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible';
import { FlaskConical, ChevronDown, Send, RotateCcw, CheckCircle2, AlertCircle } from 'lucide-react';
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

interface ShortcutTestPanelProps {
  shortcuts: Shortcut[];
  keywords: Keyword[];
}

interface TestResult {
  command: string;
  found: boolean;
  expandedText?: string;
  messages?: ShortcutMessage[];
}

export function ShortcutTestPanel({ shortcuts, keywords }: ShortcutTestPanelProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [inputText, setInputText] = useState('');
  const [outputText, setOutputText] = useState('');
  const [lastResult, setLastResult] = useState<TestResult | null>(null);
  const [history, setHistory] = useState<TestResult[]>([]);
  const { settings } = useUserSettings();
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const prefix = settings.shortcuts.prefix || '/';

  // Process input text to detect and expand shortcuts
  const processInput = (text: string) => {
    setInputText(text);
    
    // Find shortcut commands in text
    const words = text.split(/\s+/);
    let processedText = text;
    let foundShortcut: TestResult | null = null;

    for (const word of words) {
      if (word.startsWith(prefix)) {
        const command = word.slice(prefix.length).toLowerCase();
        const shortcut = shortcuts.find(s => s.command.toLowerCase() === command);
        
        if (shortcut) {
          // Get messages or use expanded_text
          const messages = shortcut.messages && shortcut.messages.length > 0 
            ? shortcut.messages 
            : [{ text: shortcut.expanded_text, auto_send: false }];
          
          // Apply keywords to all messages
          const expandedMessages = messages.map(m => ({
            ...m,
            text: applyKeywords(m.text, keywords)
          }));
          
          // Replace in output
          const fullExpansion = expandedMessages.map(m => m.text).join('\n---\n');
          processedText = processedText.replace(word, fullExpansion);
          
          foundShortcut = {
            command: shortcut.command,
            found: true,
            expandedText: fullExpansion,
            messages: expandedMessages
          };
        } else if (command.length > 0) {
          foundShortcut = {
            command,
            found: false
          };
        }
      }
    }

    setOutputText(processedText);
    
    if (foundShortcut) {
      setLastResult(foundShortcut);
      if (foundShortcut.found && !history.some(h => h.command === foundShortcut!.command)) {
        setHistory(prev => [foundShortcut!, ...prev].slice(0, 5));
      }
    }
  };

  const handleReset = () => {
    setInputText('');
    setOutputText('');
    setLastResult(null);
    textareaRef.current?.focus();
  };

  const handleSimulateSend = () => {
    if (lastResult?.messages) {
      const autoSendMessages = lastResult.messages.filter(m => m.auto_send);
      if (autoSendMessages.length > 0) {
        // Simulate sending
        setHistory(prev => [{
          ...lastResult,
          command: `${lastResult.command} (enviado)`
        }, ...prev.filter(h => h.command !== lastResult.command)].slice(0, 5));
      }
    }
  };

  return (
    <Card>
      <Collapsible open={isOpen} onOpenChange={setIsOpen}>
        <CollapsibleTrigger asChild>
          <CardHeader className="cursor-pointer hover:bg-muted/50 transition-colors">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <FlaskConical className="h-5 w-5 text-primary" />
                <div>
                  <CardTitle className="text-lg">Testar Atalhos</CardTitle>
                  <CardDescription>
                    Digite atalhos para testar se estão funcionando corretamente
                  </CardDescription>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {shortcuts.length > 0 && (
                  <Badge variant="secondary" className="text-xs">
                    {shortcuts.length} atalhos disponíveis
                  </Badge>
                )}
                <ChevronDown className={`h-4 w-4 text-muted-foreground transition-transform ${isOpen ? 'rotate-180' : ''}`} />
              </div>
            </div>
          </CardHeader>
        </CollapsibleTrigger>
        <CollapsibleContent>
          <CardContent className="space-y-4">
            {/* Input area */}
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <label className="text-sm font-medium">
                  Digite aqui (use {prefix} + comando)
                </label>
                <Button variant="ghost" size="sm" onClick={handleReset}>
                  <RotateCcw className="h-3.5 w-3.5 mr-1" />
                  Limpar
                </Button>
              </div>
              <Textarea
                ref={textareaRef}
                placeholder={`Ex: ${prefix}obg ou ${prefix}pix`}
                value={inputText}
                onChange={(e) => processInput(e.target.value)}
                className="min-h-[80px] font-mono text-sm"
              />
            </div>

            {/* Status indicator */}
            {lastResult && (
              <div className={`flex items-center gap-2 p-3 rounded-lg ${
                lastResult.found 
                  ? 'bg-green-500/10 border border-green-500/30' 
                  : 'bg-yellow-500/10 border border-yellow-500/30'
              }`}>
                {lastResult.found ? (
                  <>
                    <CheckCircle2 className="h-4 w-4 text-green-500" />
                    <span className="text-sm">
                      Atalho <code className="bg-muted px-1.5 py-0.5 rounded font-mono">{prefix}{lastResult.command}</code> encontrado!
                    </span>
                    {lastResult.messages && lastResult.messages.some(m => m.auto_send) && (
                      <Badge variant="outline" className="ml-auto text-xs">
                        <Send className="h-3 w-3 mr-1" />
                        {lastResult.messages.filter(m => m.auto_send).length} auto-envio
                      </Badge>
                    )}
                  </>
                ) : (
                  <>
                    <AlertCircle className="h-4 w-4 text-yellow-500" />
                    <span className="text-sm">
                      Atalho <code className="bg-muted px-1.5 py-0.5 rounded font-mono">{prefix}{lastResult.command}</code> não encontrado
                    </span>
                  </>
                )}
              </div>
            )}

            {/* Output preview */}
            {outputText && lastResult?.found && (
              <div className="space-y-2">
                <label className="text-sm font-medium text-muted-foreground">
                  Resultado expandido:
                </label>
                <div className="p-3 rounded-lg bg-muted/50 border">
                  {lastResult.messages && lastResult.messages.length > 1 ? (
                    <div className="space-y-2">
                      {lastResult.messages.map((msg, idx) => (
                        <div 
                          key={idx}
                          className={`p-2 rounded text-sm ${msg.auto_send ? 'bg-primary/10 border-l-2 border-primary' : 'bg-background'}`}
                        >
                          <div className="flex items-start justify-between gap-2">
                            <p className="whitespace-pre-wrap flex-1">{msg.text}</p>
                            {msg.auto_send && (
                              <Badge variant="secondary" className="text-xs shrink-0">
                                <Send className="h-3 w-3 mr-1" />
                                Auto
                              </Badge>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-sm whitespace-pre-wrap">{lastResult.expandedText}</p>
                  )}
                </div>
              </div>
            )}

            {/* Quick test suggestions */}
            {shortcuts.length > 0 && !inputText && (
              <div className="space-y-2">
                <label className="text-sm text-muted-foreground">
                  Clique para testar:
                </label>
                <div className="flex flex-wrap gap-1.5">
                  {shortcuts.slice(0, 8).map((s) => (
                    <Button
                      key={s.id}
                      variant="outline"
                      size="sm"
                      className="h-7 text-xs font-mono"
                      onClick={() => processInput(`${prefix}${s.command}`)}
                    >
                      {prefix}{s.command}
                    </Button>
                  ))}
                  {shortcuts.length > 8 && (
                    <span className="text-xs text-muted-foreground self-center ml-1">
                      +{shortcuts.length - 8} mais
                    </span>
                  )}
                </div>
              </div>
            )}

            {/* Recent test history */}
            {history.length > 0 && (
              <div className="pt-2 border-t">
                <label className="text-xs text-muted-foreground">Testados recentemente:</label>
                <div className="flex flex-wrap gap-1 mt-1">
                  {history.map((h, idx) => (
                    <Badge 
                      key={idx} 
                      variant={h.found ? "default" : "secondary"}
                      className="text-xs cursor-pointer"
                      onClick={() => processInput(`${prefix}${h.command.replace(' (enviado)', '')}`)}
                    >
                      {prefix}{h.command}
                    </Badge>
                  ))}
                </div>
              </div>
            )}
          </CardContent>
        </CollapsibleContent>
      </Collapsible>
    </Card>
  );
}
