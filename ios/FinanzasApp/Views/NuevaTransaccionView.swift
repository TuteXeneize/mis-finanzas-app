import SwiftUI
import SwiftData

struct NuevaTransaccionView: View {
    // 1. Entorno de SwiftData y control de la vista
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 2. Traemos SOLO las categorías activas (respetando la regla de "baja lógica")
    @Query(filter: #Predicate<CategoriaUsuario> { $0.activa == true })
    private var categoriasActivas: [CategoriaUsuario]
    
    // 3. Estados del formulario
    @State private var tipo: TipoTransaccion = .gasto
    @State private var montoTexto: String = ""
    @State private var descripcion: String = ""
    @State private var categoriaID: UUID? = nil
    @State private var metodoPago: MetodoPago = .mercadoPago
    @State private var fecha: Date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Sección Principal
                Section {
                    Picker("Tipo de Movimiento", selection: $tipo) {
                        Text("Gasto").tag(TipoTransaccion.gasto)
                        Text("Ingreso").tag(TipoTransaccion.ingreso)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("$")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.secondary)
                        TextField("Monto (ej: 15000)", text: $montoTexto)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                            .bold()
                    }
                    
                    TextField("Descripción (ej: Pizza de muzzarella)", text: $descripcion)
                } header: {
                    Text("Información Principal")
                }
                
                // MARK: - Sección de Clasificación
                Section {
                    Picker("Categoría", selection: $categoriaID) {
                        Text("Sin categoría").tag(UUID?(nil))
                        ForEach(categoriasActivas) { categoria in
                            Text(categoria.nombre).tag(UUID?(categoria.id))
                        }
                    }
                    
                    Picker("Método de Pago", selection: $metodoPago) {
                        ForEach(MetodoPago.allCases) { metodo in
                            Label(metodo.titulo, systemImage: metodo.icono).tag(metodo)
                        }
                    }
                } header: {
                    Text("Clasificación")
                }
                
                // MARK: - Sección Fecha
                Section {
                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                } header: {
                    Text("Fecha de la Transacción")
                }
            }
            .navigationTitle("Nueva Transacción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: guardarTransaccion)
                        .bold()
                        .disabled(formularioInvalido)
                }
            }
        }
    }
}

// MARK: - Lógica de Validación y Guardado
extension NuevaTransaccionView {
    // Bloquea el botón de guardar si falta información vital o el monto no es un número válido
    private var formularioInvalido: Bool {
        montoTexto.trimmingCharacters(in: .whitespaces).isEmpty ||
        descripcion.trimmingCharacters(in: .whitespaces).isEmpty ||
        AppFormatters.formatearTextoADecimal(montoTexto) == nil
    }
    
    private func guardarTransaccion() {
        // Obtenemos el Decimal seguro
        guard let montoFinal = AppFormatters.formatearTextoADecimal(montoTexto) else { return }
        
        let nuevaTx = Transaccion(
            monto: montoFinal,
            descripcion: descripcion.trimmingCharacters(in: .whitespaces),
            tipo: tipo,
            categoriaID: categoriaID,
            metodoPago: metodoPago,
            fecha: fecha
        )
        
        // Guardamos en la base de datos local y cerramos la pantalla
        modelContext.insert(nuevaTx)
        dismiss()
    }
}

#Preview {
    NuevaTransaccionView()
        .modelContainer(for: [Transaccion.self, CategoriaUsuario.self], inMemory: true)
}
