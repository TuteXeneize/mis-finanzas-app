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

    async def enviar_mensaje(self, numero_destino: str, texto: str) -> bool:
        """
        Envía un mensaje de WhatsApp al usuario utilizando la API de Meta.
        Si las credenciales no están configuradas, lo registra en consola sin crashear.
        """
        if not settings.META_ACCESS_TOKEN or not settings.META_PHONE_NUMBER_ID:
            logger.info(f"📱 [WhatsApp Mock/Local] Para: {numero_destino} | Mensaje: \n{texto}")
            return True

        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": numero_destino,
            "type": "text",
            "text": {
                "preview_url": False,
                "body": texto
            }
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(self.base_url, headers=self.headers, json=payload)
                if response.status_code in [200, 201]:
                    logger.info(f"✉️ Mensaje enviado exitosamente a {numero_destino}")
                    return True
                else:
                    logger.error(f"❌ Error de Meta enviando mensaje ({response.status_code}): {response.text}")
                    return False
        except httpx.RequestError as e:
            logger.error(f"❌ Error de red conectando con Meta: {e}")
            return False

whatsapp_sender = WhatsAppSender()
