import SwiftUI
import SwiftData
import Charts

// MARK: - Estructura Auxiliar para el Gráfico
struct GastoPorCategoria: Identifiable {
    let id = UUID()
    let nombreCategoria: String
    let montoTotal: Double // Swift Charts renderiza con Double; convertimos Decimal solo para dibujar
}

struct EstadisticasView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Traemos las transacciones y las categorías
    @Query private var transacciones: [Transaccion]
    @Query private var categorias: [CategoriaUsuario]
    
    // Estado para guardar los datos ya calculados
    @State private var datosGrafico: [GastoPorCategoria] = []
    
    var body: some View {
        NavigationStack {
            VStack {
                if datosGrafico.isEmpty {
                    ContentUnavailableView(
                        "Sin Datos de Gastos",
                        systemImage: "chart.pie.fill",
                        description: Text("Cargá algunos gastos para ver tus estadísticas y distribución mensual.")
                    )
                } else {
                    List {
                        Section(header: Text("Distribución de Gastos")) {
                            // MARK: - El Gráfico de Swift Charts
                            Chart(datosGrafico) { dato in
                                SectorMark(
                                    angle: .value("Total Gastado", dato.montoTotal),
                                    innerRadius: .ratio(0.55), // Gráfico de Dona moderno
                                    angularInset: 2.0 // Separación visual entre porciones
                                )
                                .cornerRadius(6)
                                .foregroundStyle(by: .value("Categoría", dato.nombreCategoria))
                                .annotation(position: .overlay) {
                                    let porcentaje = calcularPorcentaje(de: dato.montoTotal)
                                    if porcentaje >= 5 {
                                        Text(String(format: "%.0f%%", porcentaje))
                                            .font(.caption2)
                                            .bold()
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .frame(height: 280)
                            .padding(.vertical, 8)
                        }
                        
                        // MARK: - Leyenda y Detalle por Categoría
                        Section(header: Text("Detalle por Categoría")) {
                            ForEach(datosGrafico) { dato in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(dato.nombreCategoria)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        Text(String(format: "%.1f%% del total", calcularPorcentaje(de: dato.montoTotal)))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(AppFormatters.formatearDinero(dato.montoTotal))
                                        .font(.headline)
                                        .bold()
                                }
                                .padding(.vertical, 2)
                            }
                            
                            // Fila de Total de Gastos
                            HStack {
                                Text("Total de Gastos")
                                    .fontWeight(.bold)
                                Spacer()
                                Text(AppFormatters.formatearDinero(totalGastosDouble))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Estadísticas")
            .onAppear(perform: procesarDatos)
            .onChange(of: transacciones) {
                procesarDatos()
            }
        }
    }
}

// MARK: - Lógica de Agrupación y Matemática Determinista
extension EstadisticasView {
    private func procesarDatos() {
        // 1. Filtramos solo los EGRESOS
        let egresos = transacciones.filter { $0.tipo == .gasto }
        
        // 2. Agrupamos y sumamos usando un Diccionario con tipo Decimal para máxima precisión
        var sumaPorCategoria: [UUID?: Decimal] = [:]
        for gasto in egresos {
            sumaPorCategoria[gasto.categoriaID, default: 0] += gasto.monto
        }
        
        // 3. Convertimos el diccionario al array ordenado que necesita Swift Charts
        datosGrafico = sumaPorCategoria.map { (idCategoria, sumaDecimal) in
            let nombre = nombreCategoria(para: idCategoria)
            // Convertimos Decimal a Double EXCLUSIVAMENTE para la vista del gráfico
            let sumaDouble = NSDecimalNumber(decimal: sumaDecimal).doubleValue
            return GastoPorCategoria(nombreCategoria: nombre, montoTotal: sumaDouble)
        }.sorted { $0.montoTotal > $1.montoTotal }
    }
    
    private var totalGastosDouble: Double {
        datosGrafico.reduce(0) { $0 + $1.montoTotal }
    }
    
    private func calcularPorcentaje(de monto: Double) -> Double {
        guard totalGastosDouble > 0 else { return 0 }
        return (monto / totalGastosDouble) * 100
    }
    
    private func nombreCategoria(para id: UUID?) -> String {
        guard let id = id, let categoria = categorias.first(where: { $0.id == id }) else {
            return "Sin Categoría"
        }
        return categoria.nombre
    }
}

#Preview {
    EstadisticasView()
        .modelContainer(for: [Transaccion.self, CategoriaUsuario.self], inMemory: true)
}
