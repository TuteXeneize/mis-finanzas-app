import json
import os
import re
from datetime import datetime, timedelta
from typing import Optional, List
from app.schemas import TransaccionRequest, RespuestaAPI, TransaccionDTO

# Soporte para Google GenAI SDK
try:
    from google import genai
    from google.genai import types
    GEMINI_AVAILABLE = True
except ImportError:
    try:
        import google.generativeai as genai
        GEMINI_AVAILABLE = True
    except ImportError:
        GEMINI_AVAILABLE = False

# Soporte para OpenAI SDK
try:
    from openai import OpenAI
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False


SYSTEM_PROMPT = """Eres un asistente financiero experto en procesar lenguaje natural (especialmente modismos argentinos y latinoamericanos) y convertirlo en transacciones financieras estructuradas.

Instrucciones:
1. Analiza el texto del usuario, la fecha actual de referencia ({fecha_actual}) y la lista de categorías disponibles: {categorias_json}.
2. Extrae:
   - monto (número float > 0). Comprende modismos: "15 lucas" = 15000, "1 palo / 1 millón" = 1000000, "20k" = 20000, "3 gambas" = 300.
   - moneda ("ARS", "USD", etc. Por defecto "ARS").
   - descripcion (breve y concisa, ej. "Pizza de muzzarella", "Carga de combustible", "Cobro de sueldo").
   - tipo ("gasto" o "ingreso"). Si es confuso o es un gasto explícito, clasifícalo como "gasto". Si dice "me pagaron", "cobré", "ingreso", "sueldo", clasifícalo como "ingreso".
   - categoria_id: El ID exacto de la categoría más adecuada de la lista proporcionada. Si ninguna coincide claramente, devuelve null.
   - metodo_pago: Uno de los siguientes: "efectivo", "debito", "credito", "mercado_pago", "transferencia", "no_especificado".
   - fecha: Formato YYYY-MM-DD. Si menciona "ayer", "hoy", "hace 2 días", calcula la fecha exacta respecto a {fecha_actual}.

3. Casos de respuesta:
   - Si se extrae una transacción válida: estado = "ok", transaccion = {monto, moneda, descripcion, tipo, categoria_id, metodo_pago, fecha}.
   - Si parece una intención de registrar pero falta el monto: estado = "requiere_aclaracion", campos_faltantes = ["monto"], mensaje_aclaratorio = "Por favor indica el monto del movimiento.".
   - Si el texto no es una transacción (ej. "hola", "¿cómo estás?", "probando"): estado = "no_transaccion", mensaje_aclaratorio = "No detecté ningún gasto o ingreso en tu mensaje.".

Responde ÚNICAMENTE un objeto JSON válido con la siguiente estructura (sin formato Markdown ni bloques de código extraños):
{{
  "estado": "ok" | "requiere_aclaracion" | "no_transaccion",
  "transaccion": {{
    "monto": float,
    "moneda": "ARS",
    "descripcion": "string",
    "tipo": "gasto" | "ingreso",
    "categoria_id": "string o null",
    "metodo_pago": "string",
    "fecha": "YYYY-MM-DD"
  }} | null,
  "campos_faltantes": ["string"] | null,
  "mensaje_aclaratorio": "string" | null
}}
"""


def _procesar_con_reglas_locales(payload: TransaccionRequest) -> RespuestaAPI:
    """
    Parser determinista inteligente con soporte para modismos argentinos.
    Se utiliza como fallback instantáneo y para pruebas sin necesidad de API keys.
    """
    texto = payload.texto.strip().lower()

    # 1. Detección de no transacción
    saludos = ["hola", "buenas", "chau", "gracias", "test", "ayuda", "ok", "que tal", "cómo estás", "como estas", "que onda"]
    es_saludo_o_charla = any(s in texto for s in saludos) and not any(char.isdigit() for char in texto)
    if es_saludo_o_charla or len(texto) < 3:
        return RespuestaAPI(
            estado="no_transaccion",
            mensaje_aclaratorio="No detecté ningún gasto o ingreso en tu mensaje. Probá algo como: 'Gasté 15 lucas en súper con débito'."
        )

    # 2. Detección de tipo
    palabras_ingreso = ["cobre", "cobré", "sueldo", "ingreso", "recibi", "recibí", "me transfirieron", "deposito", "depósito", "gane", "gané"]
    es_ingreso = any(p in texto for p in palabras_ingreso)
    tipo = "ingreso" if es_ingreso else "gasto"

    # 3. Detección de monto
    monto: Optional[float] = None

    # Patrón "X lucas" o "X luca" (1 luca = 1000)
    match_lucas = re.search(r'(\d+(?:[.,]\d+)?)\s*(?:lucas?|lukas?)', texto)
    if match_lucas:
        val = float(match_lucas.group(1).replace(',', '.'))
        monto = val * 1000.0

    # Patrón "X k" (1k = 1000)
    if monto is None:
        match_k = re.search(r'(\d+(?:[.,]\d+)?)\s*k\b', texto)
        if match_k:
            val = float(match_k.group(1).replace(',', '.'))
            monto = val * 1000.0

    # Patrón "X palos" o "X palo / millón / millones"
    if monto is None:
        match_palos = re.search(r'(\d+(?:[.,]\d+)?)\s*(?:palos?|millones?|millon|millón)', texto)
        if match_palos:
            val = float(match_palos.group(1).replace(',', '.'))
            monto = val * 1000000.0

    # Patrón número estándar (ej: $15000, 15.000, 15000, 150.50)
    if monto is None:
        match_num = re.search(r'\$?\s*(\d{1,3}(?:[.]\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)', texto)
        if match_num:
            raw_str = match_num.group(1)
            # Si tiene formato con puntos de miles (ej: 15.000)
            if '.' in raw_str and ',' not in raw_str and len(raw_str.split('.')[-1]) == 3:
                raw_str = raw_str.replace('.', '')
            elif ',' in raw_str:
                raw_str = raw_str.replace('.', '').replace(',', '.')
            try:
                monto = float(raw_str)
            except ValueError:
                monto = None

    # Si no tiene monto, verificar si al menos tenía intención de transacción
    if monto is None or monto <= 0:
        palabras_intencion = ["gast", "pagu", "compr", "cobr", "ingres", "transfer", "plata", "pesos", "dolares", "dólares", "factura", "ticket"]
        if any(p in texto for p in palabras_intencion):
            return RespuestaAPI(
                estado="requiere_aclaracion",
                campos_faltantes=["monto"],
                mensaje_aclaratorio="Entendí la intención pero no pude identificar el monto. ¿Cuánto gastaste o ingresaste?"
            )
        return RespuestaAPI(
            estado="no_transaccion",
            mensaje_aclaratorio="No identifiqué un gasto o ingreso claro. Intentá indicar el monto y qué compraste o cobraste."
        )

    # 4. Detección de método de pago
    metodo_pago = "no_especificado"
    if "mercado pago" in texto or "mercadopago" in texto or "mp" in texto:
        metodo_pago = "mercado_pago"
    elif "transferencia" in texto or "transfer" in texto:
        metodo_pago = "transferencia"
    elif "debito" in texto or "débito" in texto:
        metodo_pago = "debito"
    elif "credito" in texto or "crédito" in texto or "tarjeta" in texto:
        metodo_pago = "credito"
    elif "efectivo" in texto or "cash" in texto:
        metodo_pago = "efectivo"

    # 5. Detección de fecha
    fecha_base = payload.fecha_actual.split("T")[0]
    fecha_transaccion = fecha_base
    try:
        dt_base = datetime.fromisoformat(payload.fecha_actual.replace("Z", "+00:00"))
        if "ayer" in texto:
            fecha_transaccion = (dt_base - timedelta(days=1)).strftime("%Y-%m-%d")
        elif "anteayer" in texto or "antes de ayer" in texto:
            fecha_transaccion = (dt_base - timedelta(days=2)).strftime("%Y-%m-%d")
        else:
            fecha_transaccion = dt_base.strftime("%Y-%m-%d")
    except Exception:
        fecha_transaccion = fecha_base

    # 6. Detección de categoría
    categoria_id: Optional[str] = None
    for cat in payload.categorias:
        nombre_cat = cat.nombre.lower()
        if nombre_cat in texto:
            categoria_id = cat.id
            break

    if categoria_id is None:
        keywords_cat = {
            "super": ["super", "súper", "coto", "dia", "carrefour", "vea", "chango", "almacen", "comida", "pizza", "hamburguesa", "asado", "cena", "almuerzo"],
            "servicios": ["luz", "gas", "agua", "internet", "fibertel", "edenor", "edesur", "metrogas", "telecentro", "personal", "flow"],
            "transporte": ["uber", "cabify", "didi", "nafta", "ypf", "shell", "axion", "sube", "colectivo", "peaje", "estacionamiento"],
            "sueldo": ["sueldo", "salario", "honorarios", "quincena"],
            "salud": ["farmacia", "remedio", "medico", "médico", "dentista", "osde", "swiss"],
            "ocio": ["cine", "teatro", "boliche", "bar", "salida", "juego", "steam"]
        }
        for cat in payload.categorias:
            nom = cat.nombre.lower()
            for key, kws in keywords_cat.items():
                if (key in nom or nom in key) and any(kw in texto for kw in kws):
                    categoria_id = cat.id
                    break
            if categoria_id:
                break

    if categoria_id is None and payload.categorias and len(payload.categorias) == 1:
        categoria_id = payload.categorias[0].id

    # 7. Construcción de descripción limpia
    descripcion = payload.texto.strip()
    desc_limpia = re.sub(r'^(gast[eé]|pagu[eé]|compr[eé]|cobr[eé]|ingres[eé])\s+', '', descripcion, flags=re.IGNORECASE)
    desc_limpia = re.sub(r'\b(con|en|por)\s+(efectivo|debito|débito|credito|crédito|mercado pago|mp|transferencia)\b', '', desc_limpia, flags=re.IGNORECASE)
    desc_limpia = desc_limpia.strip()
    if not desc_limpia:
        desc_limpia = "Gasto registrado" if tipo == "gasto" else "Ingreso registrado"

    desc_limpia = desc_limpia[:1].upper() + desc_limpia[1:]

    return RespuestaAPI(
        estado="ok",
        transaccion=TransaccionDTO(
            monto=monto,
            moneda="ARS",
            descripcion=desc_limpia,
            tipo=tipo,
            categoria_id=categoria_id,
            metodo_pago=metodo_pago,
            fecha=fecha_transaccion
        )
    )


def procesar_transaccion_con_ia(payload: TransaccionRequest) -> RespuestaAPI:
    """
    Función orquestadora que procesa la transacción utilizando el LLM configurado
    (Google Gemini Free Tier o OpenAI), con fallback automático al parser local.
    """
    gemini_key = os.getenv("GEMINI_API_KEY")
    openai_key = os.getenv("OPENAI_API_KEY")

    # 1. Opción Gemini (Google AI Studio Free Tier)
    if gemini_key and GEMINI_AVAILABLE:
        try:
            cats_json = json.dumps([{"id": c.id, "nombre": c.nombre} for c in payload.categorias], ensure_ascii=False)
            prompt = SYSTEM_PROMPT.format(
                fecha_actual=payload.fecha_actual,
                categorias_json=cats_json
            ) + f"\n\nTexto del usuario: \"{payload.texto}\""

            if hasattr(genai, 'Client'):
                client = genai.Client(api_key=gemini_key)
                model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json"
                    )
                )
                data = json.loads(response.text)
                return RespuestaAPI(**data)
            elif hasattr(genai, 'GenerativeModel'):
                genai.configure(api_key=gemini_key)
                model_name = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
                model = genai.GenerativeModel(
                    model_name=model_name,
                    generation_config={"response_mime_type": "application/json"}
                )
                response = model.generate_content(prompt)
                data = json.loads(response.text)
                return RespuestaAPI(**data)
        except Exception as e:
            print(f"[Warning] Error llamando a Gemini API: {e}. Usando parser determinista local.")

    # 2. Opción OpenAI
    if openai_key and OPENAI_AVAILABLE:
        try:
            client = OpenAI(api_key=openai_key)
            cats_json = json.dumps([{"id": c.id, "nombre": c.nombre} for c in payload.categorias], ensure_ascii=False)
            prompt = SYSTEM_PROMPT.format(
                fecha_actual=payload.fecha_actual,
                categorias_json=cats_json
            )

            response = client.chat.completions.create(
                model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
                messages=[
                    {"role": "system", "content": prompt},
                    {"role": "user", "content": payload.texto}
                ],
                response_format={"type": "json_object"},
                temperature=0.1
            )
            data = json.loads(response.choices[0].message.content)
            return RespuestaAPI(**data)
        except Exception as e:
            print(f"[Warning] Error llamando a OpenAI API: {e}. Usando parser determinista local.")

    # 3. Fallback inteligente determinista local
    return _procesar_con_reglas_locales(payload)
