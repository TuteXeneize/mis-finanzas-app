import Foundation

// MARK: - Tipo de Transacción
enum TipoTransaccion: String, Codable, CaseIterable, Identifiable {
    case gasto = "gasto"
    case ingreso = "ingreso"
    
    var id: String { rawValue }
    
    var titulo: String {
        switch self {
        case .gasto: return "Gasto"
        case .ingreso: return "Ingreso"
        }
    }
}

// MARK: - Método de Pago
enum MetodoPago: String, Codable, CaseIterable, Identifiable {
    case mercadoPago = "mercado_pago"
    case efectivo = "efectivo"
    
    var id: String { rawValue }
    
    var titulo: String {
        switch self {
        case .mercadoPago: return "Mercado Pago"
        case .efectivo: return "Efectivo"
        }
    }
    
    var icono: String {
        switch self {
        case .mercadoPago: return "iphone.and.arrow.forward"
        case .efectivo: return "banknote"
        }
    }
}

// MARK: - Estado de Respuesta de la API
enum EstadoRespuestaAPI: String, Codable {
    case ok = "ok"
    case requiereAclaracion = "requiere_aclaracion"
    case noTransaccion = "no_transaccion"
}
