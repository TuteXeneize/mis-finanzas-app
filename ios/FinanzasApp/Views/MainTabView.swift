import SwiftUI

struct MainTabView: View {
    @State private var tabSeleccionada: Int = 0
    
    var body: some View {
        TabView(selection: $tabSeleccionada) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "wallet.pass.fill")
                }
                .tag(0)
            
            EstadisticasView()
                .tabItem {
                    Label("Estadísticas", systemImage: "chart.pie.fill")
                }
                .tag(1)
            
            GestorCategoriasView()
                .tabItem {
                    Label("Categorías", systemImage: "tag.fill")
                }
                .tag(2)
            
            ConfiguracionView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Transaccion.self, CategoriaUsuario.self], inMemory: true)
}
