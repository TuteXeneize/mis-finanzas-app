import uuid
import logging
from datetime import datetime
from fastapi import APIRouter, Request, BackgroundTasks, Query, HTTPException
from fastapi.responses import PlainTextResponse, JSONResponse

from app.core.config import settings
from app.core.whatsapp_sender import whatsapp_sender
from app.repositories.sqlite_repo import SQLiteMessageLogRepository, SQLiteTransactionRepository
from app.schemas import (
    TransaccionRequest,
    CategoriaInput,
    SyncGetResponse,
    SyncConfirmRequest,
    TransaccionSyncResponse
)
from app.services import procesar_transaccion_con_ia

logger = logging.getLogger("FinanzasBot")
router = APIRouter(tags=["WhatsApp & Sincronización"])

message_log_repo = SQLiteMessageLogRepository()
transaction_repo = SQLiteTransactionRepository()


# MARK: - 1. Verificación del Webhook de Meta (GET)
@router.get("/webhook")
def verify_webhook(
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_challenge: str = Query(None, alias="hub.challenge"),
    hub_verify_token: str = Query(None, alias="hub.verify_token")
):
    """
    Meta envía un GET a esta URL con un challenge para verificar la propiedad del servidor.
    Si el token coincide con META_VERIFY_TOKEN, devolvemos el challenge en texto plano.
    """
    if hub_mode == "subscribe" and hub_verify_token == settings.META_VERIFY_TOKEN:
        logger.info("✅ Webhook verificado correctamente por Meta.")
        return PlainTextResponse(content=hub_challenge, status_code=200)
        
    logger.warning(f"❌ Intento de verificación fallido. Token recibido: '{hub_verify_token}'")
    raise HTTPException(status_code=403, detail="Token de verificación inválido")


# MARK: - 2. Recepción de Mensajes de WhatsApp (POST)
@router.post("/webhook")
async def receive_webhook(request: Request, background_tasks: BackgroundTasks):
    """
    Punto de entrada de mensajes de Meta. Responde 200 OK de inmediato
    y delega el procesamiento inteligente a segundo plano.
    """
    try:
        body = await request.json()
        if body.get("object") == "whatsapp_business_account":
            entry = body.get("entry", [{}])[0]
            changes = entry.get("changes", [{}])[0]
            value = changes.get("value", {})
            
            # Ignoramos notificaciones de estado (delivered, read) y procesamos solo mensajes
            if "messages" in value:
                mensaje = value["messages"][0]
                message_id = mensaje.get("id")
                sender_id = mensaje.get("from")
                
                # REGLA DE IDEMPOTENCIA: Si ya lo procesamos, abortar sin duplicar
                mensaje_previo = message_log_repo.get_message(message_id)
                if mensaje_previo:
                    logger.info(f"⚠️ Mensaje {message_id} ya existe en log ({mensaje_previo.get('status')}). Abortando duplicado.")
                    return JSONResponse(content={"status": "ok"}, status_code=200)
                
                if mensaje.get("type") == "text":
                    texto_usuario = mensaje["text"]["body"]
                    
                    # 1. Guardar estado RECEIVED
                    message_log_repo.create_message(message_id, sender_id, "RECEIVED")
                    
                    # 2. Delegar a la cola asíncrona
                    background_tasks.add_task(
                        procesar_mensaje_whatsapp_background,
                        message_id=message_id,
                        sender_id=sender_id,
                        texto=texto_usuario
                    )
                elif mensaje.get("type") == "audio":
                    message_log_repo.create_message(message_id, sender_id, "RECEIVED")
                    background_tasks.add_task(
                        whatsapp_sender.enviar_mensaje,
                        numero_destino=sender_id,
                        texto="🎤 Recibí tu audio. Por el momento podés escribirlo en texto (ej: 'Gasté 1500 en carne' o '15 lucas en nafta')."
                    )
    except Exception as e:
        logger.error(f"❌ Error parseando payload de WhatsApp: {e}")
        
    # RETORNO INMEDIATO: Siempre 200 OK a Meta para evitar reintentos en bucle
    return JSONResponse(content={"status": "ok"}, status_code=200)


# MARK: - 3. Procesamiento Asíncrono en Segundo Plano
async def procesar_mensaje_whatsapp_background(message_id: str, sender_id: str, texto: str):
    logger.info(f"⚙️ Procesando WhatsApp {message_id} de {sender_id}: '{texto}'")
    try:
        now_iso = datetime.now().isoformat()
        
        # Categorías estándar de la app para que la IA clasifique con precisión
        categorias_app = [
            CategoriaInput(id="cat-super", nombre="Supermercado"),
            CategoriaInput(id="cat-comida", nombre="Comida & Salidas"),
            CategoriaInput(id="cat-servicios", nombre="Servicios & Impuestos"),
            CategoriaInput(id="cat-transporte", nombre="Transporte & Combustible"),
            CategoriaInput(id="cat-salud", nombre="Salud & Farmacia"),
            CategoriaInput(id="cat-educacion", nombre="Educación"),
            CategoriaInput(id="cat-ocio", nombre="Entretenimiento"),
            CategoriaInput(id="cat-sueldo", nombre="Sueldo & Honorarios"),
            CategoriaInput(id="cat-inversiones", nombre="Inversiones"),
            CategoriaInput(id="cat-otros", nombre="Otros")
        ]
        
        payload = TransaccionRequest(
            texto=texto,
            fecha_actual=now_iso,
            timezone="America/Argentina/Buenos_Aires",
            categorias=categorias_app
        )
        
        # Invocamos la IA con todas las reglas argentinas
        respuesta = procesar_transaccion_con_ia(payload)
        
        if respuesta.estado == "ok" and respuesta.transaccion:
            tx = respuesta.transaccion
            tx_id = str(uuid.uuid4())
            
            cat_nombres = {
                "cat-super": "Supermercado",
                "cat-comida": "Comida & Salidas",
                "cat-servicios": "Servicios & Impuestos",
                "cat-transporte": "Transporte & Combustible",
                "cat-salud": "Salud & Farmacia",
                "cat-educacion": "Educación",
                "cat-ocio": "Entretenimiento",
                "cat-sueldo": "Sueldo & Honorarios",
                "cat-inversiones": "Inversiones",
                "cat-otros": "Otros"
            }
            nombre_cat = cat_nombres.get(tx.categoria_id, "General")
            
            datos_tx = {
                "transaction_id": tx_id,
                "whatsapp_message_id": message_id,
                "fecha_transaccion": tx.fecha,
                "monto": tx.monto,
                "moneda": tx.moneda,
                "descripcion": tx.descripcion,
                "categoria_id": tx.categoria_id,
                "categoria_nombre": nombre_cat,
                "metodo_pago": tx.metodo_pago,
                "tipo": tx.tipo
            }
            
            # 1. Guardar en SQLite (Atomicidad)
            transaction_repo.create_transaction(datos_tx)
            
            # 2. Actualizar estado del log a PROCESSED
            message_log_repo.update_status(message_id, "PROCESSED", transaction_id=tx_id)
            
            # 3. Responder al usuario por WhatsApp
            monto_formateado = f"{tx.monto:,.0f}".replace(",", ".")
            metodo_display = "Mercado Pago" if tx.metodo_pago == "mercado_pago" else "Efectivo"
            icono_tipo = "🔴 Gasto" if tx.tipo == "gasto" else "🟢 Ingreso"
            
            mensaje_exito = (
                f"✅ *{icono_tipo} Guardado:*\n\n"
                f"💵 *${monto_formateado} {tx.moneda}*\n"
                f"📝 Concepto: *{tx.descripcion}*\n"
                f"📂 Categoría: {nombre_cat}\n"
                f"💳 Pago: {metodo_display}\n\n"
                f"📲 _Se sincronizará en tu iPhone apenas abras la app._"
            )
            await whatsapp_sender.enviar_mensaje(sender_id, mensaje_exito)
            logger.info(f"✅ Transacción guardada y notificada exitosamente: {tx_id}")
            
        elif respuesta.estado == "requiere_aclaracion":
            mensaje_aclara = respuesta.mensaje_aclaratorio or "No pude identificar el monto exacto. ¿Cuánto gastaste o ingresaste?"
            message_log_repo.update_status(message_id, "REQUIRES_CLARIFICATION")
            await whatsapp_sender.enviar_mensaje(sender_id, f"⚠️ {mensaje_aclara}")
            
        else:
            mensaje_no_tx = respuesta.mensaje_aclaratorio or "No detecté ningún gasto o ingreso en tu mensaje. Probá algo como: 'Gasté 1500 en carne' o '15 lucas en nafta'."
            message_log_repo.update_status(message_id, "NO_TRANSACTION")
            await whatsapp_sender.enviar_mensaje(sender_id, f"ℹ️ {mensaje_no_tx}")
            
    except Exception as e:
        logger.error(f"❌ Error crítico procesando WhatsApp {message_id}: {e}")
        message_log_repo.update_status(message_id, "FAILED", error=str(e))
        await whatsapp_sender.enviar_mensaje(
            sender_id,
            "⚠️ Ocurrió un error al procesar el mensaje. Por favor intentá enviarlo nuevamente."
        )


# MARK: - 4. Endpoints de Sincronización para iOS (Patrón ACK)

@router.get("/sync-transacciones", response_model=SyncGetResponse)
def obtener_transacciones_pendientes():
    """
    El iPhone llama a este endpoint al abrir la app o hacer pull-to-refresh.
    Devuelve las transacciones cargadas por WhatsApp que aún no están en el iPhone.
    """
    pendientes = transaction_repo.get_pending_transactions()
    lista_dtos = [
        TransaccionSyncResponse(
            transaction_id=p["transaction_id"],
            whatsapp_message_id=p.get("whatsapp_message_id", ""),
            fecha_transaccion=p["fecha_transaccion"],
            monto=float(p["monto"]),
            moneda=p.get("moneda", "ARS"),
            descripcion=p["descripcion"],
            categoria_id=p.get("categoria_id"),
            categoria_nombre=p.get("categoria_nombre"),
            metodo_pago=p.get("metodo_pago", "mercado_pago"),
            tipo=p.get("tipo", "gasto"),
            created_at=p.get("created_at", "")
        )
        for p in pendientes
    ]
    logger.info(f"📲 Sync: Entregando {len(lista_dtos)} transacciones pendientes al iPhone.")
    return SyncGetResponse(
        transacciones_pendientes=lista_dtos,
        cantidad=len(lista_dtos)
    )


@router.post("/sync-confirm")
def confirmar_sincronizacion(request: SyncConfirmRequest):
    """
    El iPhone confirma que ya guardó físicamente en SwiftData las transacciones indicadas.
    El backend las marca como 'sincronizado_ios = 1'.
    """
    ids = request.transaction_ids
    if not ids:
        return {"status": "ignored", "detail": "Array de IDs vacío"}
        
    actualizadas = transaction_repo.mark_as_synchronized(ids)
    logger.info(f"🔐 ACK recibido del iPhone: {actualizadas} transacciones marcadas como sincronizadas.")
    return {
        "status": "success",
        "filas_actualizadas": actualizadas,
        "ids_solicitados": len(ids)
    }
