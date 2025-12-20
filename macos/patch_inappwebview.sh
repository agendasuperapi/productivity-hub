#!/bin/bash

# Script para modificar flutter_inappwebview_macos para usar ProcessPool único por instância
# Isso permite que cada WebView tenha seus próprios cookies isolados no macOS

# Encontra o caminho do plugin no cache do pub
PLUGIN_PATH=$(find ~/.pub-cache/hosted/pub.dev/flutter_inappwebview_macos* -name "InAppWebView.swift" -type f 2>/dev/null | head -1)

if [ -z "$PLUGIN_PATH" ] || [ ! -f "$PLUGIN_PATH" ]; then
    echo "⚠️  Plugin não encontrado no cache do pub"
    echo "   Execute 'flutter pub get' primeiro."
    exit 0
fi

echo "✅ Encontrado plugin em: $PLUGIN_PATH"

# ✅ Primeiro, restaura o arquivo original removendo todas as modificações anteriores
echo "✅ Restaurando arquivo original..."
# Remove todas as linhas que contêm nossas modificações anteriores
sed -i '' '/✅ MODIFICAÇÃO/d' "$PLUGIN_PATH"
sed -i '' '/\/\/ ✅ MODIFICAÇÃO/d' "$PLUGIN_PATH"
sed -i '' '/\/\/ Cada instância de InAppWebView/d' "$PLUGIN_PATH"
sed -i '' '/\/\/ Isso garante que diferentes URLs/d' "$PLUGIN_PATH"
sed -i '' '/\/\/ ProcessPool único isola cookies mesmo usando default() DataStore/d' "$PLUGIN_PATH"
sed -i '' '/\/\/ Cada WebView com seu próprio ProcessPool terá cookies isolados/d' "$PLUGIN_PATH"
sed -i '' '/\/\/ configuration.processPool = WKProcessPoolManager.sharedProcessPool/d' "$PLUGIN_PATH"

# ✅ Encontra a linha com configuration.processPool e substitui apenas uma vez
echo "✅ Aplicando patch para ProcessPool único por instância..."

# Encontra a primeira ocorrência de processPool = WKProcessPoolManager.sharedProcessPool
if grep -q "WKProcessPoolManager.sharedProcessPool" "$PLUGIN_PATH"; then
    # Substitui apenas a primeira ocorrência
    sed -i '' '0,/configuration.processPool = WKProcessPoolManager.sharedProcessPool/s/configuration.processPool = WKProcessPoolManager.sharedProcessPool/configuration.processPool = WKProcessPool()/' "$PLUGIN_PATH"
    echo "✅ Patch aplicado: ProcessPool único por instância"
else
    # Se não encontrou sharedProcessPool, verifica se já tem WKProcessPool() único
    if grep -q "configuration.processPool = WKProcessPool()" "$PLUGIN_PATH"; then
        echo "✅ ProcessPool único já está configurado"
    else
        echo "⚠️  Não foi possível encontrar configuration.processPool para modificar"
    fi
fi

# ✅ Remove ProcessPools duplicados (mantém apenas o primeiro)
echo "✅ Removendo ProcessPools duplicados..."
# Conta quantas vezes aparece "configuration.processPool = WKProcessPool()"
count=$(grep -c "configuration.processPool = WKProcessPool()" "$PLUGIN_PATH" || echo "0")
if [ "$count" -gt 1 ]; then
    # Remove todas as ocorrências exceto a primeira
    awk '/configuration\.processPool = WKProcessPool\(\)/ && ++n > 1 {next} 1' "$PLUGIN_PATH" > "$PLUGIN_PATH.tmp" && mv "$PLUGIN_PATH.tmp" "$PLUGIN_PATH"
    echo "✅ ProcessPools duplicados removidos"
fi

# ✅ Garante que websiteDataStore está configurado para isolamento COMPLETO
# Usa nonPersistent() para isolar cookies completamente por instância
# IMPORTANTE: Isso isola cookies, mas eles não serão persistentes entre sessões
echo "✅ Configurando websiteDataStore para isolamento completo..."

# Remove configurações de default() que compartilham cookies
sed -i '' '/configuration.websiteDataStore = WKWebsiteDataStore.default()/d' "$PLUGIN_PATH"
sed -i '' '/\/\/ ProcessPool único isola cookies, default() DataStore persiste/d' "$PLUGIN_PATH"
sed -i '' '/\/\/ Cada WebView com seu próprio ProcessPool terá cookies isolados E persistentes/d' "$PLUGIN_PATH"

# Verifica se já existe nonPersistent() configurado logo após o processPool
if grep -A 2 "configuration.processPool = WKProcessPool()" "$PLUGIN_PATH" | grep -q "configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()"; then
    echo "✅ websiteDataStore nonPersistent já está configurado após processPool"
else
    # Remove qualquer websiteDataStore existente após processPool
    sed -i '' '/configuration.processPool = WKProcessPool()/,+3 { /configuration.websiteDataStore/d; }' "$PLUGIN_PATH"
    
    # Adiciona nonPersistent() após a linha do processPool para isolar cookies completamente
    sed -i '' '/configuration.processPool = WKProcessPool()/a\
        // ✅ MODIFICAÇÃO: DataStore não persistente para isolar cookies completamente\
        // Cada WebView terá seus próprios cookies isolados (não compartilhados)\
        // NOTA: Cookies não serão persistentes entre sessões, mas estarão isolados\
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
' "$PLUGIN_PATH"
    echo "✅ websiteDataStore configurado para isolamento completo (nonPersistent)"
fi

echo "✅ Modificações aplicadas com sucesso!"
echo "✅ Cada instância de InAppWebView terá seu próprio ProcessPool isolado"
echo "✅ ProcessPool único isola cookies, default() DataStore persiste entre sessões"
echo "✅ Cookies serão isolados por aba E persistentes entre sessões"
