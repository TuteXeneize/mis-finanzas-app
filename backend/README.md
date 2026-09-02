# 🚀 Backend de Finanzas Personales con IA

Microservicio en Python con **FastAPI**, **Pydantic** e inteligencia artificial para procesar gastos e ingresos en lenguaje natural.

---

## 🌟 Características
- **Procesamiento NLP Inteligente**: Extrae montos (incluye modismos como "lucas", "palos", "k"), descripciones limpias, fechas relativas ("ayer", "hoy"), métodos de pago y clasificación automática de categorías.
- **100% Gratuito y Sin Suscripciones**:
  - Compatible con el **Free Tier de Google Gemini** (Google AI Studio).
  - Incluye un motor de reglas y expresiones regulares que funciona offline sin necesidad de ninguna API key.
- **Blindaje con Pydantic**: Validación estricta de tipos de datos.
- **Autenticación con Bearer Token**: Protección contra accesos no autorizados.
- **CORS habilitado**: Permite conexiones desde simuladores, dispositivos físicos en la misma red Wi-Fi y aplicaciones web.

---

## 🛠️ Cómo ejecutar localmente

1. **Instalar dependencias**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Configurar variables de entorno** (opcional):
   Copiá `.env.example` a `.env`:
   ```env
   API_SECRET_TOKEN=token_secreto_temporal_mvp
   GEMINI_API_KEY=tu_api_key_de_google_ai_studio_aqui
   ```
   *(Si no ponés ninguna API key, el backend funcionará en modo offline con el motor de reglas local inteligente).*

3. **Iniciar el servidor**:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

4. **Documentación Swagger Interactiva**:
   Abrí tu navegador en: [http://localhost:8000/docs](http://localhost:8000/docs)

---

## 📱 Cómo conectar tu celular en la misma red Wi-Fi
1. Averiguá la dirección IP local de tu computadora:
   - En Windows: Ejecutá `ipconfig` en la terminal (ej: `192.168.1.45`).
2. En la pantalla de **Ajustes** de la app en tu iPhone, cambiá la URL por:
   `http://192.168.1.45:8000`
3. ¡Listo! Tu teléfono se comunicará directamente con tu PC sin pasar por la nube ni pagar nada.
