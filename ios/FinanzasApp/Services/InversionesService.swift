import Foundation

struct CotizacionActivoDTO: Codable, Identifiable {
    var id: String { ticker }
    let ticker: String
    let nombre: String?
    let precio: Double
    let moneda: String
    let cambio_porcentual_dia: Double?
    let ultimo_cierre: Double?
}

final class InversionesService {
    static let shared = InversionesService()
    private init() {}
    
    private var baseURL: String {
        UserDefaults.standard.string(forKey: "backend_base_url") ?? "http://192.168.1.38:8000"
    }
    
    /// Obtiene las cotizaciones en tiempo real para una lista de tickers (ej: ["AAPL", "TSLA"])
    func obtenerCotizaciones(tickers: [String]) async throws -> [String: CotizacionActivoDTO] {
        guard !tickers.isEmpty else { return [:] }
        let tickersParam = tickers.map { $0.uppercased().trimmingCharacters(in: .whitespaces) }.joined(separator: ",")
        
        guard let url = URL(string: "\(baseURL)/cotizaciones?tickers=\(tickersParam)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let resultado = try decoder.decode([String: CotizacionActivoDTO?].self, from: data)
        
        var cotizacionesValidas: [String: CotizacionActivoDTO] = [:]
        for (k, v) in resultado {
            if let dto = v {
                cotizacionesValidas[k] = dto
            }
        }
        return cotizacionesValidas
    }
    
    /// Consulta la cotización en vivo de un ticker individual
    func obtenerCotizacionIndividual(ticker: String) async throws -> CotizacionActivoDTO? {
        let tickerLimpio = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        guard !tickerLimpio.isEmpty else { return nil }
        guard let url = URL(string: "\(baseURL)/cotizacion/\(tickerLimpio)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return nil
        }
        
        return try? JSONDecoder().decode(CotizacionActivoDTO.self, from: data)
    }
}
