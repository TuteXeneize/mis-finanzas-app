import Foundation
import SwiftData

@Model
final class TransaccionInversion: Identifiable {
    @Attribute(.unique) var id: UUID
    var ticker: String
    var tipoOperacion: String // "compra" o "venta"
    var cantidad: Decimal
    var precioUSD: Decimal
    var cotizacionDolarARS: Decimal?
    var montoTotalARS: Decimal?
    var fecha: Date
    var impactoEnPesos: Bool
    
    init(
        id: UUID = UUID(),
        ticker: String,
        tipoOperacion: String,
        cantidad: Decimal,
        precioUSD: Decimal,
        cotizacionDolarARS: Decimal? = nil,
        montoTotalARS: Decimal? = nil,
        fecha: Date = Date(),
        impactoEnPesos: Bool = false
    ) {
        self.id = id
        self.ticker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        self.tipoOperacion = tipoOperacion
        self.cantidad = cantidad
        self.precioUSD = precioUSD
        self.cotizacionDolarARS = cotizacionDolarARS
        self.montoTotalARS = montoTotalARS
        self.fecha = fecha
        self.impactoEnPesos = impactoEnPesos
    }
}
