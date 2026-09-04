import SwiftUI
import SwiftData

enum ModoRankingRendimiento: String, CaseIterable, Identifiable {
    case porcentaje = "Porcentaje %"
    case dinero = "Dólares $"
    
    var id: String { rawValue }
}

struct ItemRendimiento: Identifiable {
    var id: String { ticker }
    let ticker: String
    let nombre: String
    let rendimientoUSD: Double
    let rendimientoPorcentaje: Double
    let valorActualUSD: Double
}

struct InversionesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivoInversion.ticker) private var activos: [ActivoInversion]
    
    @State private var cotizaciones: [String: CotizacionActivoDTO] = [:]
    @State private var estaCargandoCotizaciones: Bool = false
    @State private var modoRanking: ModoRankingRendimiento = .porcentaje
    @State private var mostrarModalOperacion: Bool = false
    @State private var mensajeError: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Tarjeta de Resumen del Portafolio
                    tarjetaResumenPortafolio
                    
                    if activos.isEmpty {
                        estadoVacio
                    } else {
                        // MARK: - Ranking de Rendimiento (Mejor y Peor)
                        seccionRankingRendimiento
                        
                        // MARK: - Lista Detallada de Acciones
                        seccionDetalleAcciones
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Inversiones")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mostrarModalOperacion = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await cargarCotizaciones() }
                    } label: {
                        if estaCargandoCotizaciones {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $mostrarModalOperacion) {
                NuevaOperacionInversionView()
            }
            .task {
                await cargarCotizaciones()
            }
            .refreshable {
                await cargarCotizaciones()
            }
        }
    }
    
    // MARK: - 1. Tarjeta Resumen Portafolio (USD)
    private var tarjetaResumenPortafolio: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Portafolio Total (USD)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "$ %.2f USD", totalPortafolioUSD))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                    .padding(10)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Circle())
            }
            
            Divider()
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invertido")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "$ %.2f", totalInvertidoUSD))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Rendimiento Total")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: gananciaTotalUSD >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%@$ %.2f (%@%.2f%%)",
                                    gananciaTotalUSD >= 0 ? "+" : "",
                                    gananciaTotalUSD,
                                    gananciaTotalUSD >= 0 ? "+" : "",
                                    porcentajeGananciaTotal))
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(gananciaTotalUSD >= 0 ? .green : .red)
                }
            }
            
            HStack {
                Circle()
                    .fill(estaCargandoCotizaciones ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(estaCargandoCotizaciones ? "Actualizando cotizaciones..." : "Precios en vivo de Wall Street (ARQ)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - 2. Ranking de Rendimiento
    private var seccionRankingRendimiento: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rendimiento de Acciones")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Modo", selection: $modoRanking) {
                    ForEach(ModoRankingRendimiento.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }
            
            VStack(spacing: 8) {
                ForEach(itemsRankingOrdenados) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.ticker)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(item.nombre)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if modoRanking == .porcentaje {
                            Text(String(format: "%@%.2f%%", item.rendimientoPorcentaje >= 0 ? "+" : "", item.rendimientoPorcentaje))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(item.rendimientoPorcentaje >= 0 ? .green : .red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((item.rendimientoPorcentaje >= 0 ? Color.green : Color.red).opacity(0.12))
                                .clipShape(Capsule())
                        } else {
                            Text(String(format: "%@$ %.2f USD", item.rendimientoUSD >= 0 ? "+" : "", item.rendimientoUSD))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(item.rendimientoUSD >= 0 ? .green : .red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((item.rendimientoUSD >= 0 ? Color.green : Color.red).opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                }
            }
        }
    }
    
    // MARK: - 3. Lista Detallada de Acciones
    private var seccionDetalleAcciones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tus Posiciones")
                .font(.headline)
                .fontWeight(.bold)
            
            ForEach(activos) { activo in
                tarjetaActivoIndividual(activo)
            }
        }
    }
    
    private func tarjetaActivoIndividual(_ activo: ActivoInversion) -> some View {
        let cotiz = cotizaciones[activo.ticker]
        let precioActual = cotiz?.precio ?? NSDecimalNumber(decimal: activo.precioPromedioCompraUSD).doubleValue
        let cantidadDouble = NSDecimalNumber(decimal: activo.cantidad).doubleValue
        let precioCompraDouble = NSDecimalNumber(decimal: activo.precioPromedioCompraUSD).doubleValue
        
        let valorTotalActual = cantidadDouble * precioActual
        let diferenciaPorAccion = precioActual - precioCompraDouble
        let gananciaTotalPosicion = cantidadDouble * diferenciaPorAccion
        let porcentajeRendimiento = precioCompraDouble > 0 ? (diferenciaPorAccion / precioCompraDouble) * 100.0 : 0.0
        
        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(activo.ticker)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text(String(format: "%.2f acc.", cantidadDouble))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    
                    Text(activo.nombre)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "$ %.2f USD", valorTotalActual))
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 3) {
                        Image(systemName: gananciaTotalPosicion >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%@$ %.2f (%@%.1f%%)",
                                    gananciaTotalPosicion >= 0 ? "+" : "",
                                    gananciaTotalPosicion,
                                    porcentajeRendimiento >= 0 ? "+" : "",
                                    porcentajeRendimiento))
                    }
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(gananciaTotalPosicion >= 0 ? .green : .red)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Precio de Compra")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "$ %.2f USD", precioCompraDouble))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("Precio Actual")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "$ %.2f USD", precioActual))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Diferencia / Interés")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%@$ %.2f", diferenciaPorAccion >= 0 ? "+" : "", diferenciaPorAccion))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(diferenciaPorAccion >= 0 ? .green : .red)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(activo)
                try? modelContext.save()
            } label: {
                Label("Eliminar posición", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Estado Vacío
    private var estadoVacio: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 24)
            
            Text("No tenés acciones cargadas")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Tocá el botón '+' arriba para registrar tus compras de acciones en ARQ / DolarApp.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Button {
                mostrarModalOperacion = true
            } label: {
                Text("Registrar Primera Compra")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Lógica de Cálculos y Datos
    private var totalInvertidoUSD: Double {
        activos.reduce(0.0) { acc, a in
            let cant = NSDecimalNumber(decimal: a.cantidad).doubleValue
            let precio = NSDecimalNumber(decimal: a.precioPromedioCompraUSD).doubleValue
            return acc + (cant * precio)
        }
    }
    
    private var totalPortafolioUSD: Double {
        activos.reduce(0.0) { acc, a in
            let cant = NSDecimalNumber(decimal: a.cantidad).doubleValue
            let precioActual = cotizaciones[a.ticker]?.precio ?? NSDecimalNumber(decimal: a.precioPromedioCompraUSD).doubleValue
            return acc + (cant * precioActual)
        }
    }
    
    private var gananciaTotalUSD: Double {
        totalPortafolioUSD - totalInvertidoUSD
    }
    
    private var porcentajeGananciaTotal: Double {
        guard totalInvertidoUSD > 0 else { return 0.0 }
        return (gananciaTotalUSD / totalInvertidoUSD) * 100.0
    }
    
    private var itemsRankingOrdenados: [ItemRendimiento] {
        let items = activos.map { a -> ItemRendimiento in
            let cant = NSDecimalNumber(decimal: a.cantidad).doubleValue
            let precioCompra = NSDecimalNumber(decimal: a.precioPromedioCompraUSD).doubleValue
            let precioActual = cotizaciones[a.ticker]?.precio ?? precioCompra
            let rendimientoUSD = cant * (precioActual - precioCompra)
            let rendimientoPct = precioCompra > 0 ? ((precioActual - precioCompra) / precioCompra) * 100.0 : 0.0
            let valorActual = cant * precioActual
            
            return ItemRendimiento(
                ticker: a.ticker,
                nombre: a.nombre,
                rendimientoUSD: rendimientoUSD,
                rendimientoPorcentaje: rendimientoPct,
                valorActualUSD: valorActual
            )
        }
        
        if modoRanking == .porcentaje {
            return items.sorted { $0.rendimientoPorcentaje > $1.rendimientoPorcentaje }
        } else {
            return items.sorted { $0.rendimientoUSD > $1.rendimientoUSD }
        }
    }
    
    // MARK: - Conexión de Red
    private func cargarCotizaciones() async {
        let tickers = activos.map { $0.ticker }
        guard !tickers.isEmpty else { return }
        
        await MainActor.run { estaCargandoCotizaciones = true }
        
        do {
            let resultado = try await InversionesService.shared.obtenerCotizaciones(tickers: tickers)
            await MainActor.run {
                self.cotizaciones = resultado
                self.estaCargandoCotizaciones = false
            }
        } catch {
            await MainActor.run {
                self.estaCargandoCotizaciones = false
            }
        }
    }
}
