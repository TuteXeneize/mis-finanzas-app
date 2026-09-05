import Foundation
import SwiftUI
import SwiftData

struct TransaccionSyncDTO: Codable {
    let transaction_id: String
    let whatsapp_message_id: String
    let fecha_transaccion: String
    let monto: Double
    let moneda: String
    let descripcion: String
    let categoria_id: String?
    let categoria_nombre: String?
    let metodo_pago: String
    let tipo: String
    let created_at: String
}

struct SyncGetResponseDTO: Codable {
    let transacciones_pendientes: [TransaccionSyncDTO]
    let cantidad: Int
}

struct SyncConfirmRequestDTO: Codable {
    let transaction_ids: [String]
}

@MainActor
final class SyncService: ObservableObject {
    @Published var estaSincronizando: Bool = false
    @Published var ultimoError: String? = nil
    @Published var feedbackSync: String? = nil
    
    private var baseURL: String {
        UserDefaults.standard.string(forKey: "backend_base_url") ?? "http://192.168.1.38:8000"
    }
    
    func sincronizar(context: ModelContext, categoriasExistentes: [CategoriaUsuario]) async {
        guard !estaSincronizando else { return }
        estaSincronizando = true
        ultimoError = nil
        
        do {
            guard let urlGet = URL(string: "\(baseURL)/sync-transacciones") else {
                estaSincronizando = false
                return
            }
            
            var requestGet = URLRequest(url: urlGet)
            requestGet.httpMethod = "GET"
            requestGet.timeoutInterval = 8.0
            
            let (data, response) = try await URLSession.shared.data(for: requestGet)
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                estaSincronizando = false
                return
            }
            
            let syncResponse = try JSONDecoder().decode(SyncGetResponseDTO.self, from: data)
            let pendientes = syncResponse.transacciones_pendientes
            
            if pendientes.isEmpty {
                estaSincronizando = false
                return
            }
            
            var idsGuardados: [String] = []
            
            // 2. Insertar transacciones en SwiftData
            for dto in pendientes {
                guard let idUUID = UUID(uuidString: dto.transaction_id) else { continue }
                
                let fechaTx = AppFormatters.parsearFechaDelBackend(dto.fecha_transaccion)
                let tipoTx = TipoTransaccion(rawValue: dto.tipo) ?? .gasto
                let metodoTx = MetodoPago(rawValue: dto.metodo_pago) ?? .mercadoPago
                let montoDecimal = NSDecimalNumber(value: dto.monto).decimalValue
                
                // Mapear o crear categoría en base de datos local
                var catUUID: UUID? = nil
                if let nombreCat = dto.categoria_nombre {
                    if let catExistente = categoriasExistentes.first(where: { $0.nombre.lowercased() == nombreCat.lowercased() }) {
                        catUUID = catExistente.id
                    } else {
                        let nuevaCat = CategoriaUsuario(nombre: nombreCat)
                        context.insert(nuevaCat)
                        catUUID = nuevaCat.id
                    }
                }
                
                let nuevaTx = Transaccion(
                    id: idUUID,
                    monto: montoDecimal,
                    descripcion: dto.descripcion,
                    tipo: tipoTx,
                    categoriaID: catUUID,
                    metodoPago: metodoTx,
                    fecha: fechaTx,
                    moneda: dto.moneda,
                    fechaRegistro: Date(),
                    whatsappMessageId: dto.whatsapp_message_id
                )
                
                context.insert(nuevaTx)
                idsGuardados.append(dto.transaction_id)
            }
            
            // Guardar en el disco físico del iPhone
            try context.save()
            
            // 3. Confirmar con ACK al backend para marcar sincronizado
            if !idsGuardados.isEmpty {
                guard let urlConfirm = URL(string: "\(baseURL)/sync-confirm") else { return }
                var requestConfirm = URLRequest(url: urlConfirm)
                requestConfirm.httpMethod = "POST"
                requestConfirm.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let confirmPayload = SyncConfirmRequestDTO(transaction_ids: idsGuardados)
                requestConfirm.httpBody = try JSONEncoder().encode(confirmPayload)
                
                _ = try await URLSession.shared.data(for: requestConfirm)
                
                withAnimation {
                    feedbackSync = "✨ \(idsGuardados.count) gasto\(idsGuardados.count > 1 ? "s" : "") sincronizado\(idsGuardados.count > 1 ? "s" : "") de WhatsApp"
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation {
                        self.feedbackSync = nil
                    }
                }
            }
            
        } catch {
            print("[Sync] Error silencioso: \(error.localizedDescription)")
        }
        
        estaSincronizando = false
    }
}
