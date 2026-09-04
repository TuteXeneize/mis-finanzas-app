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
            
            InversionesView()
                .tabItem {
                    Label("Inversiones", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            EstadisticasView()
                .tabItem {
                    Label("Estadísticas", systemImage: "chart.pie.fill")
                }
                .tag(2)
            
            GestorCategoriasView()
                .tabItem {
                    Label("Categorías", systemImage: "tag.fill")
                }
                .tag(3)
            
            ConfiguracionView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Transaccion.self, CategoriaUsuario.self, ActivoInversion.self, TransaccionInversion.self], inMemory: true)
}
