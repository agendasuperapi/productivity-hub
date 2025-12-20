import Cocoa
import WebKit
import FlutterMacOS

/// Gerenciador de WKProcessPool isolados por domínio/URL
/// Isso permite que cada URL tenha seus próprios cookies isolados
class WebViewProcessPoolManager {
    static let shared = WebViewProcessPoolManager()
    
    // Armazena os WKProcessPool isolados por domínio da URL
    // Cada domínio terá seu próprio ProcessPool, garantindo isolamento de cookies por URL
    private var processPools: [String: WKProcessPool] = [:]
    
    private init() {}
    
    /// Extrai o domínio de uma URL
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            // Se não conseguir extrair o domínio, usa a URL completa como chave
            return urlString
        }
        return host
    }
    
    /// Cria ou retorna um WKProcessPool isolado para uma URL específica
    /// Cada domínio/URL terá seu próprio ProcessPool, garantindo isolamento completo de cookies
    func getOrCreateProcessPool(for url: String) -> WKProcessPool {
        let domain = extractDomain(from: url)
        
        // Se já existe um ProcessPool para este domínio, retorna o existente
        if let existingPool = processPools[domain] {
            return existingPool
        }
        
        // Cria um novo WKProcessPool isolado para este domínio
        // Cada ProcessPool isola cookies, mas usa WKWebsiteDataStore.default() para persistência
        let newPool = WKProcessPool()
        
        // Armazena o ProcessPool para reutilização
        processPools[domain] = newPool
        
        return newPool
    }
    
    /// Remove o ProcessPool de um domínio quando não for mais necessário
    func removeProcessPool(for url: String) {
        let domain = extractDomain(from: url)
        processPools.removeValue(forKey: domain)
    }
    
    /// Limpa todos os ProcessPools
    func clearAll() {
        processPools.removeAll()
    }
}

