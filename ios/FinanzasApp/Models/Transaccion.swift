import Foundation
import SwiftData

@Model
final class Transaccion: Identifiable {
    @Attribute(.unique) var id: UUID
    var monto: Decimal
    var descripcion: String
    var tipoRaw: String
    var categoriaID: UUID?
    var metodoPagoRaw: String
    var fecha: Date
    var moneda: String
    var fechaRegistro: Date
    var whatsappMessageId: String? = nil
    
    // Propiedad computada para tipado seguro
    var tipo: TipoTransaccion {
        get { TipoTransaccion(rawValue: tipoRaw) ?? .gasto }
        set { tipoRaw = newValue.rawValue }
    }
    
    // Propiedad computada para método de pago
    var metodoPago: MetodoPago {
        get { MetodoPago(rawValue: metodoPagoRaw) ?? .mercadoPago }
        set { metodoPagoRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        monto: Decimal,
        descripcion: String,
        tipo: TipoTransaccion = .gasto,
        categoriaID: UUID? = nil,
        metodoPago: MetodoPago = .mercadoPago,
        fecha: Date = Date(),
        moneda: String = "ARS",
        fechaRegistro: Date = Date(),
        whatsappMessageId: String? = nil
    ) {
        self.id = id
        self.monto = monto
        self.descripcion = descripcion
        self.tipoRaw = tipo.rawValue
        self.categoriaID = categoriaID
        self.metodoPagoRaw = metodoPago.rawValue
        self.fecha = fecha
        self.moneda = moneda
        self.fechaRegistro = fechaRegistro
        self.whatsappMessageId = whatsappMessageId
    }
}
