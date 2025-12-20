#!/bin/bash

# Script para corrigir código duplicado no InAppWebView.swift

PLUGIN_PATH=$(find ~/.pub-cache/hosted/pub.dev/flutter_inappwebview_macos* -name "InAppWebView.swift" -type f 2>/dev/null | head -1)

if [ -z "$PLUGIN_PATH" ] || [ ! -f "$PLUGIN_PATH" ]; then
    echo "❌ Plugin não encontrado"
    exit 1
fi

echo "✅ Corrigindo código duplicado em: $PLUGIN_PATH"

# Remove as linhas duplicadas e deixa apenas a versão correta
# Procura pelo padrão duplicado e remove
sed -i '' '/\/\/ if settings.incognito {/,/configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()/{ 
    /\/\/ if settings.incognito {/d
    /configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()/d
    /\/\/ } else if settings.cacheEnabled {/d
    /configuration.websiteDataStore = WKWebsiteDataStore.default()/d
    /}/d
}' "$PLUGIN_PATH"

# Remove linhas vazias duplicadas
sed -i '' '/^[[:space:]]*$/N;/^\n$/d' "$PLUGIN_PATH"

echo "✅ Código duplicado removido"

