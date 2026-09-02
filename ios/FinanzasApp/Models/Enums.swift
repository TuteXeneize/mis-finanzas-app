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
    case noEspecificado = "no_especificado"
    case efectivo = "efectivo"
    case debito = "debito"
    case credito = "credito"
    case mercadoPago = "mercado_pago"
    case transferencia = "transferencia"
    
    var id: String { rawValue }
    
    var titulo: String {
        switch self {
        case .noEspecificado: return "No Especificado"
        case .efectivo: return "Efectivo"
        case .debito: return "Débito"
        case .credito: return "Crédito"
        case .mercadoPago: return "Mercado Pago"
        case .transferencia: return "Transferencia"
        }
    }
    
    var icono: String {
        switch self {
        case .noEspecificado: return "questionmark.circle"
        case .efectivo: return "banknote"
        case .debito: return "creditcard"
        case .credito: return "creditcard.fill"
        case .mercadoPago: return "iphone.and.arrow.forward"
        case .transferencia: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Estado de Respuesta de la API
enum EstadoRespuestaAPI: String, Codable {
    case ok = "ok"
    case requiereAclaracion = "requiere_aclaracion"
    case noTransaccion = "no_transaccion"
}
