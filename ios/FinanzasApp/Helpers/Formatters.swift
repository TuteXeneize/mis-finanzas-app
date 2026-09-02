import Foundation

enum AppFormatters {
    // Formateador de moneda para Decimal
    static func formatearDinero(_ valor: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: valor)) ?? "$0.00"
    }
    
    // Formateador de moneda para Double (utilizado por Swift Charts)
    static func formatearDinero(_ valor: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: valor)) ?? "$0.00"
    }
    
    // Conversión segura de texto a Decimal (soporta coma y punto decimal)
    static func formatearTextoADecimal(_ texto: String) -> Decimal? {
        let textoLimpio = texto
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: textoLimpio)
    }
    
    // Formato de fecha legible (ej: "02 Sep 2026")
    static func formatearFechaCorta(_ fecha: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "es_AR")
        return formatter.string(from: fecha)
    }
    
    // Formato de fecha para el backend (YYYY-MM-DD)
    static func formatearFechaParaBackend(_ fecha: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: fecha)
    }
    
    // Formato ISO 8601 completo para enviar en fecha_actual
    static func formatearISO8601(_ fecha: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: fecha)
    }
    
    // Parseo de fecha YYYY-MM-DD recibida del backend
    static func parsearFechaDelBackend(_ fechaStr: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let d = formatter.date(from: fechaStr) {
            return d
        }
        // Fallback si viene en ISO completo
        let isoFormatter = ISO8601DateFormatter()
        if let d = isoFormatter.date(from: fechaStr) {
            return d
        }
        return Date()
    }
}
