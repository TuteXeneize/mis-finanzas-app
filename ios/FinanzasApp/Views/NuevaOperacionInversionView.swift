import SwiftUI
import SwiftData

enum TipoOperacionInversion: String, CaseIterable, Identifiable {
    case compra = "compra"
    case venta = "venta"
    
    var id: String { rawValue }
    var titulo: String {
        switch self {
        case .compra: return "Comprar"
        case .venta: return "Vender"
        }
    }
}

struct NuevaOperacionInversionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var activosExistentes: [ActivoInversion]
    @Query private var categorias: [CategoriaUsuario]
    
    @State private var tipoOperacion: TipoOperacionInversion = .compra
    @State private var ticker: String = ""
    @State private var nombreEmpresa: String = ""
    @State private var cantidadTexto: String = ""
    @State private var precioUSDTexto: String = ""
    
    // Impacto en pesos
    @State private var impactarEnPesos: Bool = true
    @State private var cotizacionDolarTexto: String = "1320"
    
    // Estado de consulta de cotización
    @State private var estaConsultandoCotizacion: Bool = false
    @State private var mensajeError: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Tipo de Operación
                Section {
                    Picker("Operación", selection: $tipoOperacion) {
                        ForEach(TipoOperacionInversion.allCases) { op in
                            Text(op.titulo).tag(op)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // MARK: - Datos de la Acción
                Section("Detalle de la Acción") {
                    HStack {
                        TextField("Ticker (ej: AAPL, TSLA, NVDA)", text: $ticker)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        
                        Button {
                            consultarCotizacionEnVivo()
                        } label: {
                            if estaConsultandoCotizacion {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Cotizar")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(ticker.trimmingCharacters(in: .whitespaces).isEmpty || estaConsultandoCotizacion)
                    }
                    
                    if !nombreEmpresa.isEmpty {
                        HStack {
                            Text("Empresa:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(nombreEmpresa)
                                .font(.caption)
                                .bold()
                        }
                    }
                    
                    HStack {
                        Text("Cantidad:")
                        Spacer()
                        TextField("Ej: 1.5", text: $cantidadTexto)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Precio por acción (USD):")
                        Spacer()
                        TextField("Ej: 220.50", text: $precioUSDTexto)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if let totalUSD = totalOperacionUSD {
                        HStack {
                            Text("Total en Dólares:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "$ %.2f USD", NSDecimalNumber(decimal: totalUSD).doubleValue))
                                .bold()
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // MARK: - Vinculación con Finanzas en Pesos (Dashboard)
                Section("Conversión a Pesos (Dashboard)") {
                    Toggle("Impactar en balance de pesos", isOn: $impactarEnPesos)
                    
                    if impactarEnPesos {
                        HStack {
                            Text("Precio del Dólar (ARS):")
                            Spacer()
                            TextField("Ej: 1320", text: $cotizacionDolarTexto)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        if let totalARS = totalOperacionARS {
                            HStack {
                                Text("Total en Pesos:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(AppFormatters.formatearDinero(totalARS))
                                    .bold()
                                    .foregroundColor(tipoOperacion == .compra ? .red : .green)
                            }
                            
                            Text(tipoOperacion == .compra ? "Se registrará un gasto en tu Dashboard bajo la categoría Inversiones." : "Se registrará un ingreso en tu Dashboard bajo la categoría Inversiones.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let error = mensajeError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(tipoOperacion == .compra ? "Comprar Acción" : "Vender Acción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guardarOperacion()
                    }
                    .bold()
                    .disabled(!esValido)
                }
            }
        }
    }
    
    // MARK: - Cálculos Auxiliares
    private var cantidadDecimal: Decimal? {
        let clean = cantidadTexto.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: clean)
    }
    
    private var precioUSDDecimal: Decimal? {
        let clean = precioUSDTexto.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: clean)
    }
    
    private var cotizacionDolarDecimal: Decimal? {
        let clean = cotizacionDolarTexto.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: clean)
    }
    
    private var totalOperacionUSD: Decimal? {
        guard let cant = cantidadDecimal, let precio = precioUSDDecimal, cant > 0, precio > 0 else { return nil }
        return cant * precio
    }
    
    private var totalOperacionARS: Decimal? {
        guard let totalUSD = totalOperacionUSD, let cotiz = cotizacionDolarDecimal, cotiz > 0 else { return nil }
        return totalUSD * cotiz
    }
    
    private var esValido: Bool {
        let tickerValido = !ticker.trimmingCharacters(in: .whitespaces).isEmpty
        let cantValida = (cantidadDecimal ?? 0) > 0
        let precioValido = (precioUSDDecimal ?? 0) > 0
        
        if tipoOperacion == .venta {
            let tickerUpper = ticker.uppercased().trimmingCharacters(in: .whitespaces)
            if let activo = activosExistentes.first(where: { $0.ticker == tickerUpper }) {
                if (cantidadDecimal ?? 0) > activo.cantidad {
                    return false
                }
            } else {
                return false
            }
        }
        
        return tickerValido && cantValida && precioValido
    }
    
    // MARK: - Consulta de Cotización en Vivo
    private func consultarCotizacionEnVivo() {
        let t = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        
        estaConsultandoCotizacion = true
        mensajeError = nil
        
        Task {
            do {
                if let dto = try await InversionesService.shared.obtenerCotizacionIndividual(ticker: t) {
                    await MainActor.run {
                        nombreEmpresa = dto.nombre ?? t
                        precioUSDTexto = String(format: "%.2f", dto.precio)
                        estaConsultandoCotizacion = false
                    }
                } else {
                    await MainActor.run {
                        mensajeError = "No se encontró cotización para \(t). Podés ingresar el precio manualmente."
                        estaConsultandoCotizacion = false
                    }
                }
            } catch {
                await MainActor.run {
                    mensajeError = "No se pudo conectar para obtener cotización en vivo."
                    estaConsultandoCotizacion = false
                }
            }
        }
    }
    
    // MARK: - Guardado en SwiftData
    private func guardarOperacion() {
        guard let cant = cantidadDecimal, let precioUSD = precioUSDDecimal else { return }
        let tickerUpper = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        let nombreFinal = nombreEmpresa.isEmpty ? tickerUpper : nombreEmpresa
        
        // 1. Guardar Transacción de Inversión
        let txInversion = TransaccionInversion(
            ticker: tickerUpper,
            tipoOperacion: tipoOperacion.rawValue,
            cantidad: cant,
            precioUSD: precioUSD,
            cotizacionDolarARS: impactarEnPesos ? cotizacionDolarDecimal : nil,
            montoTotalARS: impactarEnPesos ? totalOperacionARS : nil,
            fecha: Date(),
            impactoEnPesos: impactarEnPesos
        )
        modelContext.insert(txInversion)
        
        // 2. Actualizar o Insertar Activo en Cartera
        if let activoExistente = activosExistentes.first(where: { $0.ticker == tickerUpper }) {
            if tipoOperacion == .compra {
                // Precio promedio ponderado
                let cantidadAnterior = activoExistente.cantidad
                let valorAnterior = cantidadAnterior * activoExistente.precioPromedioCompraUSD
                let valorNuevo = cant * precioUSD
                let cantidadTotal = cantidadAnterior + cant
                
                activoExistente.cantidad = cantidadTotal
                activoExistente.precioPromedioCompraUSD = (valorAnterior + valorNuevo) / cantidadTotal
                activoExistente.fechaActualizacion = Date()
            } else {
                // Venta: reducir cantidad
                let cantidadRestante = activoExistente.cantidad - cant
                if cantidadRestante <= 0.00001 {
                    modelContext.delete(activoExistente)
                } else {
                    activoExistente.cantidad = cantidadRestante
                    activoExistente.fechaActualizacion = Date()
                }
            }
        } else {
            if tipoOperacion == .compra {
                let nuevoActivo = ActivoInversion(
                    ticker: tickerUpper,
                    nombre: nombreFinal,
                    cantidad: cant,
                    precioPromedioCompraUSD: precioUSD,
                    fechaActualizacion: Date()
                )
                modelContext.insert(nuevoActivo)
            }
        }
        
        // 3. Impactar en el Dashboard de Finanzas en Pesos si está habilitado
        if impactarEnPesos, let totalARS = totalOperacionARS {
            // Buscar o crear la categoría Inversiones
            var catInversiones = categorias.first(where: { $0.nombre.lowercased() == "inversiones" })
            if catInversiones == nil {
                let nuevaCat = CategoriaUsuario(nombre: "Inversiones")
                modelContext.insert(nuevaCat)
                catInversiones = nuevaCat
            }
            
            let descTx = "\(tipoOperacion == .compra ? "Compra" : "Venta") \(cant) \(tickerUpper)"
            let txFinanzas = Transaccion(
                monto: totalARS,
                descripcion: descTx,
                tipo: tipoOperacion == .compra ? .gasto : .ingreso,
                categoriaID: catInversiones?.id,
                metodoPago: .mercadoPago,
                fecha: Date()
            )
            modelContext.insert(txFinanzas)
        }
        
        try? modelContext.save()
        dismiss()
    }
}
