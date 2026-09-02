import Foundation

// MARK: - Payload de Entrada para el Backend
struct CategoriaInputDTO: Codable {
    let id: String
    let nombre: String
}

struct TransaccionRequestDTO: Codable {
    let texto: String
    let fecha_actual: String
    let timezone: String
    let categorias: [CategoriaInputDTO]
}

// MARK: - Payload de Salida del Backend
struct TransaccionDTO: Codable {
    let monto: Double
    let moneda: String
    let descripcion: String
    let tipo: String
    let categoria_id: String?
    let metodo_pago: String
    let fecha: String
}

struct RespuestaAPIDTO: Codable {
    let estado: String
    let transaccion: TransaccionDTO?
    let campos_faltantes: [String]?
    let mensaje_aclaratorio: String?
}
