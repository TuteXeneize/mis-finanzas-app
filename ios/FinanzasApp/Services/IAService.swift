import Foundation

enum IANetworkError: LocalizedError {
    case urlInvalida
    case errorServidor(codigo: Int, mensaje: String)
    case decodificacionFallida(String)
    case conexionRechazada
    case errorDesconocido(String)
    
    var errorDescription: String? {
        switch self {
        case .urlInvalida:
            return "La URL del servidor no es válida."
        case .errorServidor(let codigo, let mensaje):
            return "Error del servidor (\(codigo)): \(mensaje)"
        case .decodificacionFallida(let detalle):
            return "No se pudo interpretar la respuesta del servidor: \(detalle)"
        case .conexionRechazada:
            return "No se pudo conectar con el servidor. Verificá que el backend esté corriendo y que la URL sea correcta."
        case .errorDesconocido(let detalle):
            return "Error inesperado: \(detalle)"
        }
    }
}

final class IAService {
    static let shared = IAService()
    
    // Configuración por defecto (modificable desde Ajustes)
    var baseURL: String {
        get {
            UserDefaults.standard.string(forKey: "backend_base_url") ?? "http://localhost:8000"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "backend_base_url")
        }
    }
    
    var secretToken: String {
        get {
            UserDefaults.standard.string(forKey: "backend_secret_token") ?? "token_secreto_temporal_mvp"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "backend_secret_token")
        }
    }
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    func procesarTexto(
        texto: String,
        fechaActual: Date = Date(),
        categorias: [CategoriaUsuario]
    ) async throws -> RespuestaAPIDTO {
        // 1. Validar URL
        guard let url = URL(string: "\(baseURL)/procesar-transaccion") else {
            throw IANetworkError.urlInvalida
        }
        
        // 2. Preparar DTO de categorías
        let categoriasDTO = categorias.map {
            CategoriaInputDTO(id: $0.id.uuidString, nombre: $0.nombre)
        }
        
        // 3. Preparar Request Payload
        let payload = TransaccionRequestDTO(
            texto: texto,
            fecha_actual: AppFormatters.formatearISO8601(fechaActual),
            timezone: TimeZone.current.identifier,
            categorias: categoriasDTO
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secretToken)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            throw IANetworkError.errorDesconocido("Error codificando la solicitud.")
        }
        
        // 4. Ejecutar petición HTTP
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw IANetworkError.conexionRechazada
        }
        
        // 5. Validar código de estado HTTP
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IANetworkError.errorDesconocido("Respuesta inválida del servidor.")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Sin detalle"
            throw IANetworkError.errorServidor(codigo: httpResponse.statusCode, mensaje: errorBody)
        }
        
        // 6. Decodificar respuesta
        do {
            let respuesta = try JSONDecoder().decode(RespuestaAPIDTO.self, from: data)
            return respuesta
        } catch {
            throw IANetworkError.decodificacionFallida(error.localizedDescription)
        }
    }
}
