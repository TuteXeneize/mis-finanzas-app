import SwiftUI
import SwiftData

@main
struct FinanzasApp: App {
    // Configuración del contenedor de SwiftData
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaccion.self,
            CategoriaUsuario.self,
            ActivoInversion.self,
            TransaccionInversion.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Sembrado inicial de categorías predeterminadas en el primer inicio
            let context = container.mainContext
            let descriptor = FetchDescriptor<CategoriaUsuario>()
            let count = (try? context.fetchCount(descriptor)) ?? 0
            
            if count == 0 {
                let categoriasIniciales = [
                    "Supermercado",
                    "Comida & Salidas",
                    "Servicios & Impuestos",
                    "Transporte & Combustible",
                    "Salud & Farmacia",
                    "Educación",
                    "Entretenimiento",
                    "Sueldo & Honorarios",
                    "Inversiones",
                    "Otros"
                ]
                for nombre in categoriasIniciales {
                    context.insert(CategoriaUsuario(nombre: nombre))
                }
                try? context.save()
            } else {
                // Asegurar que la categoría Inversiones exista
                let todasCats = (try? context.fetch(descriptor)) ?? []
                if !todasCats.contains(where: { $0.nombre.lowercased() == "inversiones" }) {
                    context.insert(CategoriaUsuario(nombre: "Inversiones"))
                    try? context.save()
                }
            }
            
            return container
        } catch {
            fatalError("No se pudo inicializar el ModelContainer de SwiftData: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
