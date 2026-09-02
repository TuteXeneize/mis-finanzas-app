import SwiftUI
import SwiftData

struct DashboardView: View {
    // 1. Conexión con SwiftData
    @Environment(\.modelContext) private var modelContext
    
    // Obtenemos las transacciones ordenadas de más nuevas a más viejas
    @Query(sort: \Transaccion.fecha, order: .reverse) private var transacciones: [Transaccion]
    
    // Obtenemos las categorías para poder buscar su nombre según el UUID
    @Query private var categorias: [CategoriaUsuario]
    
    // Estados de la vista
    @State private var textoIA: String = ""
    @State private var estaProcesandoIA: Bool = false
    @State private var mostrarFormularioManual: Bool = false
    @State private var mensajeAlerta: String = ""
    @State private var mostrarAlerta: Bool = false
    @State private var feedbackExito: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Banner de feedback exitoso
                if let feedback = feedbackExito {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(feedback)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Tarjetas superiores con los cálculos matemáticos
                tarjetasResumen
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Lista histórica de movimientos
                List {
                    Section(header: Text("Movimientos Recientes (\(transacciones.count))")) {
                        if transacciones.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("No hay transacciones todavía.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .italic()
                                Text("Escribí abajo o tocá '+' para registrar un gasto.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(transacciones) { tx in
                                filaTransaccion(tx)
                            }
                            .onDelete(perform: borrarTransacciones)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                // Input inferior conectado a la IA (NLP)
                barraInputIA
            }
            .navigationTitle("Mis Finanzas")
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { mostrarFormularioManual = true }) {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $mostrarFormularioManual) {
                NuevaTransaccionView()
            }
            .alert("Información", isPresented: $mostrarAlerta) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text(mensajeAlerta)
            }
        }
    }
}

// MARK: - Componentes Visuales
extension DashboardView {
    private var tarjetasResumen: some View {
        VStack(spacing: 12) {
            // Balance Total
            VStack(spacing: 4) {
                Text("Balance Total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(AppFormatters.formatearDinero(balanceTotal))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(balanceTotal >= 0 ? Color.primary : Color.red)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            
            // Fila de Ingresos y Gastos
            HStack(spacing: 12) {
                tarjetaChica(
                    titulo: "Ingresos",
                    monto: totalIngresos,
                    color: .green,
                    icono: "arrow.down.left.circle.fill"
                )
                tarjetaChica(
                    titulo: "Gastos",
                    monto: totalGastos,
                    color: .red,
                    icono: "arrow.up.right.circle.fill"
                )
            }
        }
    }
    
    private func tarjetaChica(titulo: String, monto: Decimal, color: Color, icono: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icono)
                .font(.title2)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(AppFormatters.formatearDinero(monto))
                    .font(.headline)
                    .bold()
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
    
    private func filaTransaccion(_ tx: Transaccion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tx.tipo == .ingreso ? "arrow.down.circle.fill" : tx.metodoPago.icono)
                .font(.title3)
                .foregroundStyle(tx.tipo == .ingreso ? .green : .blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.descripcion)
                    .font(.body)
                    .fontWeight(.semibold)
                
                HStack(spacing: 6) {
                    Text(nombreCategoria(para: tx.categoriaID))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Text(AppFormatters.formatearFechaCorta(tx.fecha))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            Text(AppFormatters.formatearDinero(tx.monto))
                .font(.callout)
                .bold()
                .foregroundStyle(tx.tipo == .ingreso ? .green : .primary)
        }
        .padding(.vertical, 4)
    }
    
    private var barraInputIA: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                TextField("Ej: Gasté 15 lucas en súper con débito...", text: $textoIA)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
                    .disabled(estaProcesandoIA)
                    .onSubmit(enviarTextoAIA)
                
                Button(action: enviarTextoAIA) {
                    if estaProcesandoIA {
                        ProgressView()
                            .tint(.white)
                            .padding(10)
                            .background(Color.blue)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(textoIA.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.6) : Color.blue)
                            .clipShape(Circle())
                    }
                }
                .disabled(textoIA.trimmingCharacters(in: .whitespaces).isEmpty || estaProcesandoIA)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: - Lógica de Negocio y Conexión con IA
extension DashboardView {
    // 1. Cálculos matemáticos usando tipo Decimal
    private var totalIngresos: Decimal {
        transacciones
            .filter { $0.tipo == .ingreso }
            .reduce(0) { $0 + $1.monto }
    }
    
    private var totalGastos: Decimal {
        transacciones
            .filter { $0.tipo == .gasto }
            .reduce(0) { $0 + $1.monto }
    }
    
    private var balanceTotal: Decimal {
        totalIngresos - totalGastos
    }
    
    // 2. Búsqueda de nombre de categoría desacoplada por UUID
    private func nombreCategoria(para id: UUID?) -> String {
        guard let id = id, let categoria = categorias.first(where: { $0.id == id }) else {
            return "Sin categoría"
        }
        return categoria.nombre
    }
    
    // 3. Borrado de transacciones
    private func borrarTransacciones(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(transacciones[index])
        }
    }
    
    // 4. Procesamiento de IA mediante el servicio asíncrono
    private func enviarTextoAIA() {
        let textoAProcesar = textoIA.trimmingCharacters(in: .whitespaces)
        guard !textoAProcesar.isEmpty else { return }
        
        estaProcesandoIA = true
        textoIA = ""
        
        Task {
            do {
                let respuesta = try await IAService.shared.procesarTexto(
                    texto: textoAProcesar,
                    fechaActual: Date(),
                    categorias: categorias.filter { $0.activa }
                )
                
                await MainActor.run {
                    estaProcesandoIA = false
                    
                    if respuesta.estado == "ok", let txDTO = respuesta.transaccion {
                        let catUUID = txDTO.categoria_id.flatMap { UUID(uuidString: $0) }
                        let fechaTx = AppFormatters.parsearFechaDelBackend(txDTO.fecha)
                        let tipoTx = TipoTransaccion(rawValue: txDTO.tipo) ?? .gasto
                        let metodoTx = MetodoPago(rawValue: txDTO.metodo_pago) ?? .noEspecificado
                        let montoFinal = NSDecimalNumber(value: txDTO.monto).decimalValue
                        
                        let nuevaTransaccion = Transaccion(
                            monto: montoFinal,
                            descripcion: txDTO.descripcion,
                            tipo: tipoTx,
                            categoriaID: catUUID,
                            metodoPago: metodoTx,
                            fecha: fechaTx,
                            moneda: txDTO.moneda
                        )
                        
                        modelContext.insert(nuevaTransaccion)
                        
                        withAnimation {
                            feedbackExito = "Registrado: \(txDTO.descripcion) - $\(String(format: "%.2f", txDTO.monto))"
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation {
                                feedbackExito = nil
                            }
                        }
                    } else if let aclaracion = respuesta.mensaje_aclaratorio {
                        mensajeAlerta = aclaracion
                        mostrarAlerta = true
                    } else {
                        mensajeAlerta = "No se pudo interpretar como una transacción. Intentá especificar monto y concepto."
                        mostrarAlerta = true
                    }
                }
            } catch {
                await MainActor.run {
                    estaProcesandoIA = false
                    mensajeAlerta = error.localizedDescription
                    mostrarAlerta = true
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Transaccion.self, CategoriaUsuario.self], inMemory: true)
}
