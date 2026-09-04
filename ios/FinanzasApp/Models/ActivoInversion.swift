import Foundation
import SwiftData

@Model
final class ActivoInversion: Identifiable {
    @Attribute(.unique) var id: UUID
    var ticker: String
    var nombre: String
    var cantidad: Decimal
    var precioPromedioCompraUSD: Decimal
    var fechaActualizacion: Date
    
    init(
        id: UUID = UUID(),
        ticker: String,
        nombre: String,
        cantidad: Decimal,
        precioPromedioCompraUSD: Decimal,
        fechaActualizacion: Date = Date()
    ) {
        self.id = id
        self.ticker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        self.nombre = nombre
        self.cantidad = cantidad
        self.precioPromedioCompraUSD = precioPromedioCompraUSD
        self.fechaActualizacion = fechaActualizacion
    }
}
