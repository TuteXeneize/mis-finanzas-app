import Foundation
import SwiftData

@Model
final class CategoriaUsuario {
    @Attribute(.unique) var id: UUID
    var nombre: String
    var activa: Bool
    var fechaCreacion: Date
    var colorHex: String?
    var icono: String?
    
    init(
        id: UUID = UUID(),
        nombre: String,
        activa: Bool = true,
        colorHex: String? = nil,
        icono: String? = nil,
        fechaCreacion: Date = Date()
    ) {
        self.id = id
        self.nombre = nombre
        self.activa = activa
        self.colorHex = colorHex
        self.icono = icono
        self.fechaCreacion = fechaCreacion
    }
}
