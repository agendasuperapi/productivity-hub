# Productivity Hub - Electron

Aplicação Electron para gerenciar múltiplas abas e URLs de forma customizada.

## Instalação

```bash
npm install
```

## Desenvolvimento

Para executar em modo de desenvolvimento:

```bash
npm run electron:dev
```

Isso irá:
1. Compilar os arquivos TypeScript do Electron
2. Executar a aplicação Electron

## Build

Para gerar o executável .exe:

```bash
npm run electron:dist
```

O arquivo .exe será gerado em `dist/Productivity Hub-1.0.0-x64.exe`

## Estrutura

- `electron/main.ts` - Main process do Electron
- `electron/preload.ts` - Preload script (bridge seguro)
- `electron/renderer.html` - Interface HTML
- `electron/renderer.ts` - Lógica do renderer
- `electron/supabase-electron.ts` - Cliente Supabase adaptado para Electron

## Funcionalidades

- ✅ Autenticação com Supabase
- ✅ Carregamento de configurações do usuário via Edge Function
- ✅ Sistema de abas com webviews
- ✅ Suporte a múltiplas janelas
- ✅ Atalhos de teclado globais
- ✅ Layouts split (2x1, 1x2)
- ✅ Zoom por aba
- ✅ Ícones e cores customizadas

## Configuração

A aplicação se conecta ao Supabase usando as credenciais configuradas em `electron/supabase-electron.ts`.

## Build do Executável

O electron-builder está configurado para gerar um executável portável (.exe) para Windows x64.

Para personalizar o build, edite a seção `build` no `package.json`.

