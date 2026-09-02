import SwiftUI
import SwiftData

struct GestorCategoriasView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 1. Predicado Estricto: Traemos SOLO las categorías que estén activas, ordenadas alfabéticamente
    @Query(
        filter: #Predicate<CategoriaUsuario> { $0.activa == true },
        sort: \CategoriaUsuario.nombre
    ) private var categoriasActivas: [CategoriaUsuario]
    
    @State private var nombreNuevaCategoria: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Crear Nueva Categoría
                Section(header: Text("Agregar Categoría")) {
                    HStack {
                        TextField("Ej: Educación, Supermercado, Mascotas...", text: $nombreNuevaCategoria)
                            .onSubmit(agregarCategoria) // Permite guardar apretando "Enter" en el teclado
                        
                        Button(action: agregarCategoria) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(nombreNuevaCategoria.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                        }
                        .disabled(nombreNuevaCategoria.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                
                // MARK: - Lista y Edición (Renombrar)
                Section(header: Text("Categorías Activas (\(categoriasActivas.count))")) {
                    if categoriasActivas.isEmpty {
                        ContentUnavailableView(
                            "Sin categorías",
                            systemImage: "tag.slash",
                            description: Text("Creá tu primera categoría para organizar tus gastos.")
                        )
                    } else {
                        ForEach(categoriasActivas) { categoria in
                            // Delegamos la fila a una sub-vista para aprovechar el @Bindable
                            FilaEdicionCategoria(categoria: categoria)
                        }
                        .onDelete(perform: desactivarCategorias) // Acá aplicamos la baja lógica
                    }
                }
            }
            .navigationTitle("Categorías")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Lógica de Negocio
extension GestorCategoriasView {
    private func agregarCategoria() {
        let nombreLimpio = nombreNuevaCategoria.trimmingCharacters(in: .whitespaces)
        guard !nombreLimpio.isEmpty else { return }
        
        let nuevaCategoria = CategoriaUsuario(nombre: nombreLimpio)
        modelContext.insert(nuevaCategoria)
        
        // Limpiamos el input
        nombreNuevaCategoria = ""
    }
    
    private func desactivarCategorias(offsets: IndexSet) {
        for index in offsets {
            let categoriaADesactivar = categoriasActivas[index]
            // LA REGLA DE ORO: Baja Lógica.
            // NO hacemos modelContext.delete(categoriaADesactivar) para preservar integridad histórica
            categoriaADesactivar.activa = false
        }
    }
}

// MARK: - Sub-vista para Edición en Tiempo Real
struct FilaEdicionCategoria: View {
    // @Bindable crea una conexión bidireccional directa con SwiftData
    @Bindable var categoria: CategoriaUsuario
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .foregroundStyle(.blue.opacity(0.8))
            
            // Al tipear acá, el nombre se actualiza en toda la app al instante
            TextField("Nombre", text: $categoria.nombre)
                .font(.body)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    GestorCategoriasView()
        .modelContainer(for: [CategoriaUsuario.self, Transaccion.self], inMemory: true)
}
