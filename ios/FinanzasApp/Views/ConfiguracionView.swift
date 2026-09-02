import SwiftUI
import SwiftData

struct ConfiguracionView: View {
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("backend_base_url") private var backendURL: String = "http://localhost:8000"
    @AppStorage("backend_secret_token") private var secretToken: String = "token_secreto_temporal_mvp"
    
    @State private var estadoConexion: String = "Sin probar"
    @State private var probandoConexion: Bool = false
    @State private var colorEstado: Color = .secondary
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Servidor de IA")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL del Backend")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("http://localhost:8000", text: $backendURL)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Token Secreto de la API")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("Token", text: $secretToken)
                    }
                    
                    Button(action: probarConexionBackend) {
                        HStack {
                            if probandoConexion {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text("Probar Conexión con el Servidor")
                        }
                    }
                    .disabled(probandoConexion)
                    
                    HStack {
                        Text("Estado:")
                            .font(.subheadline)
                        Spacer()
                        Text(estadoConexion)
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(colorEstado)
                    }
                }
                
                Section(header: Text("Guía para Celular Físico")) {
                    Text("💡 **Para probar desde tu iPhone en la misma red Wi-Fi:**")
                        .font(.footnote)
                    Text("En lugar de `localhost`, poné la IP local de tu computadora (ej: `http://192.168.1.45:8000`).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section(header: Text("Datos Iniciales")) {
                    Button("Cargar Categorías por Defecto") {
                        cargarCategoriasPredeterminadas()
                    }
                    
                    Button("Cargar Datos de Demostración") {
                        cargarDatosDemo()
                    }
                }
            }
            .navigationTitle("Configuración")
        }
    }
    
    private func probarConexionBackend() {
        probandoConexion = true
        estadoConexion = "Conectando..."
        colorEstado = .orange
        
        Task {
            guard let url = URL(string: "\(backendURL)/health") else {
                await MainActor.run {
                    probandoConexion = false
                    estadoConexion = "URL Inválida"
                    colorEstado = .red
                }
                return
            }
            
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    await MainActor.run {
                        probandoConexion = false
                        estadoConexion = "Conectado ✅"
                        colorEstado = .green
                    }
                } else {
                    await MainActor.run {
                        probandoConexion = false
                        estadoConexion = "Error de respuesta"
                        colorEstado = .red
                    }
                }
            } catch {
                await MainActor.run {
                    probandoConexion = false
                    estadoConexion = "Sin conexión ❌"
                    colorEstado = .red
                }
            }
        }
    }
    
    private func cargarCategoriasPredeterminadas() {
        let categoriasBase = [
            "Supermercado", "Servicios", "Transporte", "Comida", "Salud",
            "Entretenimiento", "Educación", "Sueldo", "Inversiones"
        ]
        for nombre in categoriasBase {
            let cat = CategoriaUsuario(nombre: nombre)
            modelContext.insert(cat)
        }
    }
    
    private func cargarDatosDemo() {
        cargarCategoriasPredeterminadas()
        
        let tx1 = Transaccion(
            monto: 35000,
            descripcion: "Compra semanal Coto",
            tipo: .gasto,
            metodoPago: .debito,
            fecha: Date()
        )
        let tx2 = Transaccion(
            monto: 1500000,
            descripcion: "Cobro de Sueldo",
            tipo: .ingreso,
            metodoPago: .transferencia,
            fecha: Date()
        )
        let tx3 = Transaccion(
            monto: 12500,
            descripcion: "Cena con amigos",
            tipo: .gasto,
            metodoPago: .mercadoPago,
            fecha: Date().addingTimeInterval(-86400)
        )
        let tx4 = Transaccion(
            monto: 8500,
            descripcion: "Carga de combustible",
            tipo: .gasto,
            metodoPago: .efectivo,
            fecha: Date().addingTimeInterval(-172800)
        )
        
        modelContext.insert(tx1)
        modelContext.insert(tx2)
        modelContext.insert(tx3)
        modelContext.insert(tx4)
    }
}

#Preview {
    ConfiguracionView()
        .modelContainer(for: [Transaccion.self, CategoriaUsuario.self], inMemory: true)
}
