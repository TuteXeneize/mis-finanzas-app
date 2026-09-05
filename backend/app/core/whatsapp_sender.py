import httpx
import logging
from app.core.config import settings

logger = logging.getLogger("FinanzasBot")

class WhatsAppSender:
    def __init__(self):
        self.api_version = settings.META_API_VERSION
        
    @property
    def base_url(self) -> str:
        return f"https://graph.facebook.com/{self.api_version}/{settings.META_PHONE_NUMBER_ID}/messages"
        
    @property
    def headers(self) -> dict:
        return {
            "Authorization": f"Bearer {settings.META_ACCESS_TOKEN}",
            "Content-Type": "application/json"
        }

    def _obtener_candidatos_destino(self, numero_destino: str) -> list[str]:
        """
        En Argentina, Meta Webhook entrega el número como '54911...' (+54 9 11...),
        pero en la lista de prueba (Sandbox) suele guardarse como '5411...' (sin el 9).
        Devolvemos ambos formatos para garantizar entrega inmediata 200 OK.
        """
        candidatos = [numero_destino]
        if numero_destino.startswith("549") and len(numero_destino) >= 12:
            candidatos.append("54" + numero_destino[3:])
        elif numero_destino.startswith("54") and not numero_destino.startswith("549"):
            candidatos.append("549" + numero_destino[2:])
        return candidatos

    async def enviar_mensaje(self, numero_destino: str, texto: str) -> bool:
        """
        Envía un mensaje de WhatsApp al usuario utilizando la API de Meta.
        Si las credenciales no están configuradas, lo registra en consola sin crashear.
        """
        if not settings.META_ACCESS_TOKEN or not settings.META_PHONE_NUMBER_ID:
            logger.info(f"📱 [WhatsApp Mock/Local] Para: {numero_destino} | Mensaje: \n{texto}")
            return True

        candidatos = self._obtener_candidatos_destino(numero_destino)

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                for dest in candidatos:
                    payload = {
                        "messaging_product": "whatsapp",
                        "recipient_type": "individual",
                        "to": dest,
                        "type": "text",
                        "text": {
                            "preview_url": False,
                            "body": texto
                        }
                    }
                    response = await client.post(self.base_url, headers=self.headers, json=payload)
                    if response.status_code in [200, 201]:
                        logger.info(f"✉️ Mensaje enviado exitosamente a {dest}")
                        return True
                    else:
                        logger.warning(f"⚠️ Intento fallido con {dest} ({response.status_code}): {response.text}")
                
                logger.error(f"❌ No se pudo enviar mensaje a ningún candidato de {numero_destino}")
                return False
        except httpx.RequestError as e:
            logger.error(f"❌ Error de red conectando con Meta: {e}")
            return False

whatsapp_sender = WhatsAppSender()
